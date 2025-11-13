param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("monolith", "microservices")]
    [string]$Architecture,

    [Parameter(Mandatory=$false)]
    [int]$TestDuration = 240,  # 4 minutes

    [Parameter(Mandatory=$false)]
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Step {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host $Message -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error-Message {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Warning-Message {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

# Header
Clear-Host
Write-Host @"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║       E-COMMERCE ARCHITECTURE LOAD TESTING SUITE          ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""
Write-Info "Architecture: $Architecture"
Write-Info "Test Duration: $TestDuration seconds"
Write-Info "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# Set paths
$rootPath = Split-Path -Parent $PSScriptRoot
if ($Architecture -eq "monolith") {
    $dockerPath = Join-Path $rootPath "Mono"
} else {
    $dockerPath = Join-Path $rootPath "Microservices"
}

$k6TestsPath = Join-Path $PSScriptRoot "k6-tests"
$resultsPath = Join-Path $k6TestsPath "results"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Verify paths exist
if (-not (Test-Path $dockerPath)) {
    Write-Error-Message "Docker path not found: $dockerPath"
    exit 1
}

if (-not (Test-Path $k6TestsPath)) {
    Write-Error-Message "k6 tests path not found: $k6TestsPath"
    exit 1
}

# Create results directory
if (-not (Test-Path $resultsPath)) {
    New-Item -ItemType Directory -Path $resultsPath | Out-Null
    Write-Success "Created results directory"
}

# ============================================
# Step 1: Stop and clean existing containers
# ============================================
Write-Step "[1/7] Cleaning up existing Docker containers"
Write-Info "Stopping any running containers..."

Push-Location $dockerPath
try {
    $stopOutput = docker compose down -v 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Existing containers cleaned up"
    } else {
        Write-Warning-Message "No containers to clean up or cleanup had issues"
    }
}
catch {
    Write-Warning-Message "Cleanup encountered an error: $($_.Exception.Message)"
}
finally {
    Pop-Location
}

Start-Sleep -Seconds 3

# ============================================
# Step 2: Start Docker services
# ============================================
Write-Step "[2/7] Starting Docker services for $Architecture"
Write-Info "Building and starting containers..."

Push-Location $dockerPath
try {
    Write-Host "Running: docker compose up -d --build" -ForegroundColor Gray
    $buildOutput = docker compose up -d --build 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error-Message "Failed to start Docker services"
        Write-Host $buildOutput
        exit 1
    }

    Write-Success "Docker services started successfully"
}
finally {
    Pop-Location
}

# ============================================
# Step 3: Wait for services to be ready
# ============================================
Write-Step "[3/7] Waiting for services to be healthy"
Write-Info "Giving services time to initialize (30 seconds)..."

for ($i = 30; $i -gt 0; $i--) {
    Write-Host "`rWaiting... $i seconds remaining " -NoNewline -ForegroundColor Yellow
    Start-Sleep -Seconds 1
}
Write-Host ""

# ============================================
# Step 4: Verify services are responding
# ============================================
Write-Step "[4/7] Verifying service health"
$maxRetries = 5
$retryCount = 0
$serviceHealthy = $false

while ($retryCount -lt $maxRetries -and -not $serviceHealthy) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5000/api/products" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue

        if ($response.StatusCode -eq 200) {
            $serviceHealthy = $true
            Write-Success "Services are responding and healthy!"
        }
    }
    catch {
        $retryCount++
        Write-Warning-Message "Attempt $retryCount/$maxRetries - Services not ready yet, retrying in 5 seconds..."
        Start-Sleep -Seconds 5
    }
}

if (-not $serviceHealthy) {
    Write-Error-Message "Services failed to become healthy after $maxRetries attempts"
    Write-Info "Checking Docker logs..."
    Push-Location $dockerPath
    docker compose logs --tail=50
    Pop-Location
    exit 1
}

# ============================================
# Step 5: Start resource monitoring
# ============================================
Write-Step "[5/7] Starting resource monitoring"
Write-Info "Launching background monitoring job..."

$monitorScript = Join-Path $PSScriptRoot "monitor-resources.ps1"
$monitorJob = Start-Job -ScriptBlock {
    param($script, $arch, $duration)
    & $script -Architecture $arch -Duration $duration
} -ArgumentList $monitorScript, $Architecture, $TestDuration

Write-Success "Resource monitoring started (Job ID: $($monitorJob.Id))"

# Give monitoring time to start
Start-Sleep -Seconds 2

# ============================================
# Step 6: Run k6 load tests
# ============================================
Write-Step "[6/7] Running k6 load tests"
Write-Info "Test script: $Architecture-test.js"
Write-Info "Expected duration: ~3 minutes"
Write-Host ""

Push-Location $k6TestsPath
try {
    $k6OutputFile = Join-Path $resultsPath "$Architecture-results-$timestamp.json"
    $k6HtmlReport = Join-Path $resultsPath "$Architecture-report-$timestamp.html"

    Write-Host "k6 command: k6 run --out json=$k6OutputFile $Architecture-test.js" -ForegroundColor Gray
    Write-Host ""

    # Check if k6 is installed
    $k6Installed = Get-Command k6 -ErrorAction SilentlyContinue
    if (-not $k6Installed) {
        Write-Error-Message "k6 is not installed!"
        Write-Info "Please install k6 from: https://k6.io/docs/getting-started/installation/"
        Write-Info "For Windows: choco install k6"
        Write-Info "Or download from: https://github.com/grafana/k6/releases"
        throw "k6 not found"
    }

    # Run k6 tests
    k6 run --out json=$k6OutputFile "$Architecture-test.js"

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Success "k6 tests completed successfully!"
        Write-Info "Results saved to: $k6OutputFile"
    } else {
        Write-Error-Message "k6 tests encountered errors (exit code: $LASTEXITCODE)"
    }
}
catch {
    Write-Error-Message "Failed to run k6 tests: $($_.Exception.Message)"
}
finally {
    Pop-Location
}

# ============================================
# Step 7: Wait for monitoring to complete
# ============================================
Write-Step "[7/7] Finalizing resource monitoring"
Write-Info "Waiting for monitoring job to complete..."

$monitoringComplete = Wait-Job $monitorJob -Timeout 30
if ($monitoringComplete) {
    $monitorOutput = Receive-Job $monitorJob
    Write-Host $monitorOutput
    Write-Success "Resource monitoring completed"
} else {
    Write-Warning-Message "Monitoring job is still running, stopping it..."
    Stop-Job $monitorJob
    Receive-Job $monitorJob
}

Remove-Job $monitorJob -Force

# ============================================
# Cleanup (optional)
# ============================================
if (-not $SkipCleanup) {
    Write-Host ""
    Write-Info "Cleaning up Docker containers..."
    Push-Location $dockerPath
    docker compose down 2>&1 | Out-Null
    Pop-Location
    Write-Success "Docker containers stopped"
}

# ============================================
# Summary
# ============================================
Write-Host ""
Write-Step "Test Execution Complete!"

Write-Host ""
Write-Host "📊 Test Results Summary" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host ""
Write-Host "  Architecture:  " -NoNewline -ForegroundColor White
Write-Host $Architecture -ForegroundColor Yellow
Write-Host "  Test Duration: " -NoNewline -ForegroundColor White
Write-Host "$TestDuration seconds" -ForegroundColor Yellow
Write-Host "  Timestamp:     " -NoNewline -ForegroundColor White
Write-Host $timestamp -ForegroundColor Yellow
Write-Host ""
Write-Host "📁 Results Location:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "  k6 Results:        " -NoNewline -ForegroundColor White
Write-Host "$k6TestsPath\results\$Architecture-results-$timestamp.json" -ForegroundColor Green
Write-Host "  Resource Monitor:  " -NoNewline -ForegroundColor White
Write-Host "$PSScriptRoot\results\resources-$Architecture-$timestamp.csv" -ForegroundColor Green
Write-Host ""

Write-Host "🔍 Next Steps:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "  1. Run tests for the other architecture:" -ForegroundColor White
if ($Architecture -eq "monolith") {
    Write-Host "     .\run-all-tests.ps1 -Architecture microservices" -ForegroundColor Yellow
} else {
    Write-Host "     .\run-all-tests.ps1 -Architecture monolith" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  2. Analyze results using:" -ForegroundColor White
Write-Host "     python analyze-results.py" -ForegroundColor Yellow
Write-Host ""
Write-Host "  3. View results in the results\ directory" -ForegroundColor White
Write-Host ""

Write-Host "✓ All tests completed successfully!" -ForegroundColor Green
Write-Host ""
