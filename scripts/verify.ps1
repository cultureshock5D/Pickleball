# ==============================================================================
# Pickleball Flutter Application - Local Verification Script
# ==============================================================================
# Enforces quality gates:
#   1. Dependency resolution (flutter pub get)
#   2. Static Analysis with fatal infos (dart analyze --fatal-infos)
#   3. Full Automated Test Suite (flutter test)
# ==============================================================================

$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Text)
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Text)
    Write-Host " [PASS] $Text" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Text)
    Write-Host " [FAIL] $Text" -ForegroundColor Red
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

# Prepend Flutter and Dart SDK locations to PATH if not present
if (Test-Path "C:\flutter\bin") {
    $env:PATH = "C:\flutter\bin;C:\flutter\bin\cache\dart-sdk\bin;" + $env:PATH
}

Write-Header "Pickleball App - Local Quality Gate Verification"
Write-Host "Working Directory: $RepoRoot" -ForegroundColor Gray

# Step 1: Resolve Dependencies
Write-Host "`n--> Resolving dependencies (flutter pub get)..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Failure "Failed to resolve Flutter dependencies."
    exit $LASTEXITCODE
}
Write-Success "Dependencies resolved successfully."

# Step 2: Static Analysis
Write-Host "`n--> Running Dart Static Analysis (dart analyze --fatal-infos)..." -ForegroundColor Yellow
dart analyze --fatal-infos
if ($LASTEXITCODE -ne 0) {
    Write-Failure "Dart static analysis failed with warnings or errors."
    exit $LASTEXITCODE
}
Write-Success "Static analysis passed with 0 errors and 0 warnings."

# Step 3: Run Automated Test Suite
Write-Host "`n--> Running Automated Test Suite (flutter test)..." -ForegroundColor Yellow
flutter test
if ($LASTEXITCODE -ne 0) {
    Write-Failure "One or more automated tests failed."
    exit $LASTEXITCODE
}
Write-Success "All automated unit, widget, and feature tests passed (100%)."

# Summary
Write-Header "ALL QUALITY GATES PASSED (100% GREEN)"
Write-Host "The application is verified and ready for pull request / deployment.`n" -ForegroundColor Green
exit 0
