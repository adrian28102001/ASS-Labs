param(
    [Parameter(Mandatory=$true)]
    [string]$Architecture,

    [Parameter(Mandatory=$false)]
    [int]$Duration = 240,  # 4 minutes (240 seconds)

    [Parameter(Mandatory=$false)]
    [int]$Interval = 2  # Sample every 2 seconds
)

$ErrorActionPreference = "Stop"

# Create results directory if it doesn't exist
$resultsDir = Join-Path $PSScriptRoot "results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = Join-Path $resultsDir "resources-$Architecture-$timestamp.csv"

# Write CSV header
$header = "Timestamp,Container,CPU_Percent,Memory_Usage,Memory_Limit,Memory_Percent,Network_RX,Network_TX,Block_Read,Block_Write"
$header | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "========================================" -ForegroundColor Green
Write-Host "Docker Resource Monitor" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Architecture: $Architecture" -ForegroundColor Cyan
Write-Host "Duration: $Duration seconds" -ForegroundColor Cyan
Write-Host "Interval: $Interval seconds" -ForegroundColor Cyan
Write-Host "Output: $outputFile" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

$endTime = (Get-Date).AddSeconds($Duration)
$sampleCount = 0

# Track container statistics
$containerStats = @{}

while ((Get-Date) -lt $endTime) {
    $currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $sampleCount++

    # Get docker stats in custom format
    try {
        $stats = docker stats --no-stream --format "{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.NetIO}}|{{.BlockIO}}"

        if ($stats) {
            foreach ($line in $stats) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }

                $parts = $line -split '\|'
                if ($parts.Count -ge 6) {
                    $containerName = $parts[0]
                    $cpuPercent = $parts[1] -replace '%', ''
                    $memUsage = $parts[2]
                    $memPercent = $parts[3] -replace '%', ''
                    $netIO = $parts[4]
                    $blockIO = $parts[5]

                    # Parse memory usage (e.g., "150MiB / 2GiB")
                    if ($memUsage -match '(.+?)\s*/\s*(.+)') {
                        $memUsed = $matches[1].Trim()
                        $memLimit = $matches[2].Trim()
                    } else {
                        $memUsed = $memUsage
                        $memLimit = "N/A"
                    }

                    # Parse network I/O (e.g., "1.2MB / 3.4MB")
                    if ($netIO -match '(.+?)\s*/\s*(.+)') {
                        $netRX = $matches[1].Trim()
                        $netTX = $matches[2].Trim()
                    } else {
                        $netRX = "0B"
                        $netTX = "0B"
                    }

                    # Parse block I/O (e.g., "10MB / 20MB")
                    if ($blockIO -match '(.+?)\s*/\s*(.+)') {
                        $blockRead = $matches[1].Trim()
                        $blockWrite = $matches[2].Trim()
                    } else {
                        $blockRead = "0B"
                        $blockWrite = "0B"
                    }

                    # Write to CSV
                    $csvLine = "$currentTime,$containerName,$cpuPercent,$memUsed,$memLimit,$memPercent,$netRX,$netTX,$blockRead,$blockWrite"
                    $csvLine | Out-File -FilePath $outputFile -Append -Encoding UTF8

                    # Update running statistics
                    if (-not $containerStats.ContainsKey($containerName)) {
                        $containerStats[$containerName] = @{
                            MaxCPU = [double]$cpuPercent
                            MaxMem = $memUsed
                            Samples = 1
                        }
                    } else {
                        $containerStats[$containerName].Samples++
                        if ([double]$cpuPercent -gt $containerStats[$containerName].MaxCPU) {
                            $containerStats[$containerName].MaxCPU = [double]$cpuPercent
                            $containerStats[$containerName].MaxMem = $memUsed
                        }
                    }
                }
            }

            # Progress indicator
            $remaining = ($endTime - (Get-Date)).TotalSeconds
            $progress = [math]::Round((($Duration - $remaining) / $Duration) * 100, 1)
            Write-Host "`r[Sample $sampleCount] Progress: $progress% | Remaining: $([math]::Round($remaining, 0))s     " -NoNewline -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "`nWarning: Failed to collect stats - $($_.Exception.Message)" -ForegroundColor Red
    }

    Start-Sleep -Seconds $Interval
}

Write-Host "`n`n========================================" -ForegroundColor Green
Write-Host "Monitoring Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Total samples collected: $sampleCount" -ForegroundColor Cyan
Write-Host ""
Write-Host "Container Statistics Summary:" -ForegroundColor Yellow
Write-Host "----------------------------" -ForegroundColor Yellow

foreach ($container in $containerStats.Keys | Sort-Object) {
    $stats = $containerStats[$container]
    Write-Host "  $container" -ForegroundColor White
    Write-Host "    Max CPU: $($stats.MaxCPU)%" -ForegroundColor Cyan
    Write-Host "    Max Memory: $($stats.MaxMem)" -ForegroundColor Cyan
    Write-Host "    Samples: $($stats.Samples)" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "Results saved to: $outputFile" -ForegroundColor Green
Write-Host ""
