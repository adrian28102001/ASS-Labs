#!/usr/bin/env python3
"""
Performance Test Results Analyzer
Analyzes k6 and Docker resource monitoring results for Monolithic vs Microservices comparison
"""

import json
import csv
import os
import sys
from datetime import datetime
from pathlib import Path
from collections import defaultdict
import statistics

try:
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    from matplotlib.ticker import MaxNLocator
    PLOTTING_AVAILABLE = True
except ImportError:
    PLOTTING_AVAILABLE = False
    print("Warning: matplotlib not installed. Charts will not be generated.")
    print("Install with: pip install matplotlib")


class ResultsAnalyzer:
    def __init__(self, results_dir):
        self.results_dir = Path(results_dir)
        self.k6_dir = self.results_dir / "k6-tests" / "results"
        self.resource_dir = self.results_dir / "results"

    def find_latest_files(self, architecture):
        """Find the most recent result files for the given architecture"""
        k6_pattern = f"{architecture}-results-*.json"
        resource_pattern = f"resources-{architecture}-*.csv"

        # Find k6 results
        k6_files = list(self.k6_dir.glob(k6_pattern))
        if not k6_files:
            print(f"Error: No k6 results found for {architecture}")
            return None, None

        k6_file = max(k6_files, key=lambda p: p.stat().st_mtime)

        # Find resource monitoring results
        resource_files = list(self.resource_dir.glob(resource_pattern))
        if not resource_files:
            print(f"Warning: No resource monitoring results found for {architecture}")
            resource_file = None
        else:
            resource_file = max(resource_files, key=lambda p: p.stat().st_mtime)

        return k6_file, resource_file

    def analyze_k6_results(self, k6_file):
        """Analyze k6 JSON output"""
        print(f"\n{'='*60}")
        print(f"Analyzing k6 results: {k6_file.name}")
        print(f"{'='*60}")

        metrics = defaultdict(list)

        with open(k6_file, 'r') as f:
            for line in f:
                try:
                    data = json.loads(line)
                    if data.get('type') == 'Point':
                        metric_name = data.get('metric')
                        value = data.get('data', {}).get('value')

                        if metric_name and value is not None:
                            metrics[metric_name].append(value)
                except json.JSONDecodeError:
                    continue

        # Calculate statistics
        stats = {}
        for metric_name, values in metrics.items():
            if values:
                stats[metric_name] = {
                    'count': len(values),
                    'min': min(values),
                    'max': max(values),
                    'mean': statistics.mean(values),
                    'median': statistics.median(values),
                }

                if len(values) > 1:
                    stats[metric_name]['stdev'] = statistics.stdev(values)
                    stats[metric_name]['p95'] = self.percentile(values, 95)
                    stats[metric_name]['p99'] = self.percentile(values, 99)

        return stats

    def analyze_resource_usage(self, resource_file):
        """Analyze Docker resource monitoring CSV"""
        if not resource_file:
            return None

        print(f"\n{'='*60}")
        print(f"Analyzing resource usage: {resource_file.name}")
        print(f"{'='*60}")

        container_stats = defaultdict(lambda: {
            'cpu': [],
            'memory_mb': [],
            'memory_percent': [],
            'network_rx_mb': [],
            'network_tx_mb': []
        })

        with open(resource_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                container = row['Container']

                try:
                    cpu = float(row['CPU_Percent'])
                    mem_pct = float(row['Memory_Percent'])

                    # Parse memory usage
                    mem_str = row['Memory_Usage']
                    mem_mb = self.parse_memory(mem_str)

                    # Parse network I/O
                    net_rx_mb = self.parse_size(row['Network_RX'])
                    net_tx_mb = self.parse_size(row['Network_TX'])

                    container_stats[container]['cpu'].append(cpu)
                    container_stats[container]['memory_mb'].append(mem_mb)
                    container_stats[container]['memory_percent'].append(mem_pct)
                    container_stats[container]['network_rx_mb'].append(net_rx_mb)
                    container_stats[container]['network_tx_mb'].append(net_tx_mb)

                except (ValueError, KeyError) as e:
                    continue

        # Calculate summary statistics
        summary = {}
        for container, data in container_stats.items():
            summary[container] = {
                'cpu_avg': statistics.mean(data['cpu']) if data['cpu'] else 0,
                'cpu_max': max(data['cpu']) if data['cpu'] else 0,
                'memory_avg_mb': statistics.mean(data['memory_mb']) if data['memory_mb'] else 0,
                'memory_max_mb': max(data['memory_mb']) if data['memory_mb'] else 0,
                'network_rx_total_mb': max(data['network_rx_mb']) if data['network_rx_mb'] else 0,
                'network_tx_total_mb': max(data['network_tx_mb']) if data['network_tx_mb'] else 0,
            }

        return summary

    def parse_memory(self, mem_str):
        """Parse memory string like '150MiB' to MB"""
        mem_str = mem_str.strip()
        if 'GiB' in mem_str or 'GB' in mem_str:
            return float(mem_str.replace('GiB', '').replace('GB', '').strip()) * 1024
        elif 'MiB' in mem_str or 'MB' in mem_str:
            return float(mem_str.replace('MiB', '').replace('MB', '').strip())
        elif 'KiB' in mem_str or 'KB' in mem_str:
            return float(mem_str.replace('KiB', '').replace('KB', '').strip()) / 1024
        return 0

    def parse_size(self, size_str):
        """Parse size string like '1.2MB' to MB"""
        size_str = size_str.strip()
        if 'GB' in size_str or 'GiB' in size_str:
            return float(size_str.replace('GB', '').replace('GiB', '').strip()) * 1024
        elif 'MB' in size_str or 'MiB' in size_str:
            return float(size_str.replace('MB', '').replace('MiB', '').strip())
        elif 'KB' in size_str or 'KiB' in size_str:
            return float(size_str.replace('KB', '').replace('KiB', '').strip()) / 1024
        elif 'B' in size_str:
            return float(size_str.replace('B', '').strip()) / (1024 * 1024)
        return 0

    @staticmethod
    def percentile(values, p):
        """Calculate percentile"""
        sorted_values = sorted(values)
        k = (len(sorted_values) - 1) * (p / 100)
        f = int(k)
        c = f + 1
        if c >= len(sorted_values):
            return sorted_values[-1]
        d0 = sorted_values[f] * (c - k)
        d1 = sorted_values[c] * (k - f)
        return d0 + d1

    def print_comparison(self, monolith_stats, microservices_stats):
        """Print side-by-side comparison"""
        print(f"\n{'='*80}")
        print(f"{'PERFORMANCE COMPARISON':^80}")
        print(f"{'='*80}\n")

        # HTTP Request Duration
        if 'http_req_duration' in monolith_stats and 'http_req_duration' in microservices_stats:
            print(f"{'HTTP Request Duration (ms)':^80}")
            print(f"{'-'*80}")
            print(f"{'Metric':<20} {'Monolith':>25} {'Microservices':>25}")
            print(f"{'-'*80}")

            mono = monolith_stats['http_req_duration']
            micro = microservices_stats['http_req_duration']

            print(f"{'Average':<20} {mono['mean']:>22.2f} ms {micro['mean']:>22.2f} ms")
            print(f"{'Median':<20} {mono['median']:>22.2f} ms {micro['median']:>22.2f} ms")
            print(f"{'95th Percentile':<20} {mono.get('p95', 0):>22.2f} ms {micro.get('p95', 0):>22.2f} ms")
            print(f"{'99th Percentile':<20} {mono.get('p99', 0):>22.2f} ms {micro.get('p99', 0):>22.2f} ms")
            print(f"{'Min':<20} {mono['min']:>22.2f} ms {micro['min']:>22.2f} ms")
            print(f"{'Max':<20} {mono['max']:>22.2f} ms {micro['max']:>22.2f} ms")
            print()

        # Request rate
        if 'http_reqs' in monolith_stats and 'http_reqs' in microservices_stats:
            print(f"{'Throughput':^80}")
            print(f"{'-'*80}")
            mono_count = monolith_stats['http_reqs']['count']
            micro_count = microservices_stats['http_reqs']['count']
            print(f"{'Total Requests':<20} {mono_count:>25.0f} {micro_count:>25.0f}")
            print()

        # Error rates
        if 'errors' in monolith_stats and 'errors' in microservices_stats:
            mono_errors = monolith_stats['errors']['mean'] * 100
            micro_errors = microservices_stats['errors']['mean'] * 100
            print(f"{'Error Rate':^80}")
            print(f"{'-'*80}")
            print(f"{'Error Rate %':<20} {mono_errors:>23.2f} % {micro_errors:>23.2f} %")
            print()

    def print_resource_comparison(self, monolith_resources, microservices_resources):
        """Print resource usage comparison"""
        if not monolith_resources or not microservices_resources:
            return

        print(f"\n{'='*80}")
        print(f"{'RESOURCE USAGE COMPARISON':^80}")
        print(f"{'='*80}\n")

        # Calculate totals
        mono_cpu_total = sum(c['cpu_avg'] for c in monolith_resources.values())
        micro_cpu_total = sum(c['cpu_avg'] for c in microservices_resources.values())

        mono_mem_total = sum(c['memory_avg_mb'] for c in monolith_resources.values())
        micro_mem_total = sum(c['memory_avg_mb'] for c in microservices_resources.values())

        print(f"{'Aggregate Resource Usage':^80}")
        print(f"{'-'*80}")
        print(f"{'Metric':<30} {'Monolith':>20} {'Microservices':>20}")
        print(f"{'-'*80}")
        print(f"{'Total Avg CPU %':<30} {mono_cpu_total:>18.2f} % {micro_cpu_total:>18.2f} %")
        print(f"{'Total Avg Memory':<30} {mono_mem_total:>17.2f} MB {micro_mem_total:>17.2f} MB")
        print(f"{'Container Count':<30} {len(monolith_resources):>20} {len(microservices_resources):>20}")
        print()

        print(f"{'Per-Container Breakdown':^80}")
        print(f"{'-'*80}")
        print("\nMonolith:")
        for container, stats in sorted(monolith_resources.items()):
            print(f"  {container:<30} CPU: {stats['cpu_avg']:>6.2f}%  RAM: {stats['memory_avg_mb']:>7.2f} MB")

        print("\nMicroservices:")
        for container, stats in sorted(microservices_resources.items()):
            print(f"  {container:<30} CPU: {stats['cpu_avg']:>6.2f}%  RAM: {stats['memory_avg_mb']:>7.2f} MB")
        print()

    def generate_report(self):
        """Generate comprehensive comparison report"""
        print("\n" + "="*80)
        print("E-COMMERCE ARCHITECTURE PERFORMANCE TEST ANALYSIS")
        print("="*80)

        # Find and analyze monolith results
        mono_k6, mono_resource = self.find_latest_files('monolith')
        if not mono_k6:
            print("Error: Monolith results not found")
            return

        mono_k6_stats = self.analyze_k6_results(mono_k6)
        mono_resource_stats = self.analyze_resource_usage(mono_resource) if mono_resource else None

        # Find and analyze microservices results
        micro_k6, micro_resource = self.find_latest_files('microservices')
        if not micro_k6:
            print("Error: Microservices results not found")
            return

        micro_k6_stats = self.analyze_k6_results(micro_k6)
        micro_resource_stats = self.analyze_resource_usage(micro_resource) if micro_resource else None

        # Print comparisons
        self.print_comparison(mono_k6_stats, micro_k6_stats)
        self.print_resource_comparison(mono_resource_stats, micro_resource_stats)

        # Generate summary report file
        self.save_summary_report(mono_k6_stats, micro_k6_stats,
                                mono_resource_stats, micro_resource_stats)

        print(f"\n{'='*80}")
        print("Analysis complete!")
        print(f"{'='*80}\n")

    def save_summary_report(self, mono_k6, micro_k6, mono_res, micro_res):
        """Save summary report to text file"""
        report_file = self.results_dir / f"performance-report-{datetime.now().strftime('%Y%m%d-%H%M%S')}.txt"

        with open(report_file, 'w') as f:
            f.write("="*80 + "\n")
            f.write("E-COMMERCE ARCHITECTURE PERFORMANCE TEST REPORT\n")
            f.write("="*80 + "\n\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")

            # Performance metrics
            f.write("PERFORMANCE METRICS\n")
            f.write("-"*80 + "\n\n")

            if 'http_req_duration' in mono_k6 and 'http_req_duration' in micro_k6:
                mono = mono_k6['http_req_duration']
                micro = micro_k6['http_req_duration']

                f.write(f"HTTP Request Duration (ms):\n")
                f.write(f"  Metric              Monolith    Microservices    Difference\n")
                f.write(f"  Average             {mono['mean']:>8.2f}    {micro['mean']:>13.2f}    {((micro['mean']/mono['mean']-1)*100):>+8.2f}%\n")
                f.write(f"  Median              {mono['median']:>8.2f}    {micro['median']:>13.2f}    {((micro['median']/mono['median']-1)*100):>+8.2f}%\n")
                f.write(f"  95th Percentile     {mono.get('p95',0):>8.2f}    {micro.get('p95',0):>13.2f}    {((micro.get('p95',1)/(mono.get('p95',1) or 1)-1)*100):>+8.2f}%\n")
                f.write(f"  99th Percentile     {mono.get('p99',0):>8.2f}    {micro.get('p99',0):>13.2f}    {((micro.get('p99',1)/(mono.get('p99',1) or 1)-1)*100):>+8.2f}%\n\n")

            # Resource usage
            if mono_res and micro_res:
                f.write("RESOURCE USAGE\n")
                f.write("-"*80 + "\n\n")

                mono_cpu = sum(c['cpu_avg'] for c in mono_res.values())
                micro_cpu = sum(c['cpu_avg'] for c in micro_res.values())
                mono_mem = sum(c['memory_avg_mb'] for c in mono_res.values())
                micro_mem = sum(c['memory_avg_mb'] for c in micro_res.values())

                f.write(f"  Metric                Monolith    Microservices    Difference\n")
                f.write(f"  Total Avg CPU%        {mono_cpu:>8.2f}    {micro_cpu:>13.2f}    {((micro_cpu/mono_cpu-1)*100):>+8.2f}%\n")
                f.write(f"  Total Avg Memory MB   {mono_mem:>8.2f}    {micro_mem:>13.2f}    {((micro_mem/mono_mem-1)*100):>+8.2f}%\n")
                f.write(f"  Container Count       {len(mono_res):>8}    {len(micro_res):>13}    {len(micro_res)-len(mono_res):>+9}\n\n")

        print(f"Summary report saved to: {report_file}")


def main():
    # Get the LoadTests directory
    script_dir = Path(__file__).parent

    analyzer = ResultsAnalyzer(script_dir)
    analyzer.generate_report()


if __name__ == "__main__":
    main()
