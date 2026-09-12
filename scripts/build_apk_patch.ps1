# Build APK with PATCH version increment (e.g., 0.3.0 -> 0.3.1)
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$PubspecPath = Join-Path $RepoRoot "pubspec.yaml"
$Content = Get-Content $PubspecPath -Raw

if ($Content -match '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?') {
    $Major = [int]$Matches[1]
    $Minor = [int]$Matches[2]
    $Patch = [int]$Matches[3] + 1
    $Build = if ($Matches[4]) { [int]$Matches[4] + 1 } else { 1 }

    $OldVersion = $Matches[0]
    $NewVersion = "version: $Major.$Minor.$Patch+$Build"

    Write-Host "Bumping PATCH version: $OldVersion -> $NewVersion" -ForegroundColor Green

    $UpdatedContent = $Content -replace '(?m)^version:\s*[^\r\n]+', $NewVersion
    Set-Content -Path $PubspecPath -Value $UpdatedContent -NoNewline

    Write-Host "Building APK..." -ForegroundColor Cyan
    flutter build apk
} else {
    Write-Error "Could not find 'version:' line in pubspec.yaml"
}
