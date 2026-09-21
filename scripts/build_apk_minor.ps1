# Build APK with MINOR version increment (e.g., 0.3.0 -> 0.4.0)
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$PubspecPath = Join-Path $RepoRoot "pubspec.yaml"
$Content = Get-Content $PubspecPath -Raw

if ($Content -match '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?') {
    $Major = [int]$Matches[1]
    $Minor = [int]$Matches[2] + 1
    $Patch = 0
    $Build = if ($Matches[4]) { [int]$Matches[4] + 1 } else { 1 }

    $OldVersion = $Matches[0]
    $NewVersion = "version: $Major.$Minor.$Patch+$Build"

    Write-Host "Bumping MINOR version: $OldVersion -> $NewVersion" -ForegroundColor Green

    $UpdatedContent = $Content -replace '(?m)^version:\s*[^\r\n]+', $NewVersion
    Set-Content -Path $PubspecPath -Value $UpdatedContent -NoNewline

    Write-Host "Building APK..." -ForegroundColor Cyan
    flutter build apk

    $SourceApk = Join-Path $RepoRoot "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $SourceApk) {
        $ReleasesDir = Join-Path $RepoRoot "releases"
        if (!(Test-Path $ReleasesDir)) {
            New-Item -ItemType Directory -Path $ReleasesDir -Force | Out-Null
        }
        $DestApk = Join-Path $ReleasesDir "Pickleball-v$Major.$Minor.$Patch.apk"
        Copy-Item -Path $SourceApk -Destination $DestApk -Force
        $ApkSizeMB = [math]::Round((Get-Item $DestApk).Length / 1MB, 2)

        Write-Host "`n=======================================================" -ForegroundColor Green
        Write-Host "  [SUCCESS] APK BUILT & READY!" -ForegroundColor Green
        Write-Host "=======================================================" -ForegroundColor Green
        Write-Host "Version   : $Major.$Minor.$Patch+$Build" -ForegroundColor White
        Write-Host "File Size : $ApkSizeMB MB" -ForegroundColor White
        Write-Host "Saved to  : $DestApk" -ForegroundColor Cyan
        Write-Host "Original  : $SourceApk" -ForegroundColor Gray
        Write-Host "=======================================================`n" -ForegroundColor Green

        # Open folder and highlight the new APK
        Start-Process explorer.exe -ArgumentList "/select,`"$DestApk`""
    } else {
        Write-Error "Build finished but app-release.apk was not found."
    }
} else {
    Write-Error "Could not find 'version:' line in pubspec.yaml"
}
