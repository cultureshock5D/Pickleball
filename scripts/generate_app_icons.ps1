# Generate all launcher icons from cashier_pos/cj-logo.png
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SourcePath = Join-Path $RepoRoot "cashier_pos\cj-logo.png"

if (!(Test-Path $SourcePath)) {
    Write-Error "Source image not found: $SourcePath"
}

$srcImg = [System.Drawing.Image]::FromFile($SourcePath)

function Generate-SquareIcon {
    param(
        [string]$DestinationPath,
        [int]$Size
    )

    $destDir = Split-Path -Parent $DestinationPath
    if (!(Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $destBmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($destBmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # Fill background with #FEFEFD matching cj-logo background
    $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 254, 254, 253))
    $g.FillRectangle($bgBrush, 0, 0, $Size, $Size)
    $bgBrush.Dispose()

    # Calculate centered bounding box preserving aspect ratio (inset for visual balance)
    $paddingRatio = 0.85
    $drawW = [int]($Size * $paddingRatio)
    $drawH = [int]($drawW * ($srcImg.Height / $srcImg.Width))
    if ($drawH -gt ($Size * $paddingRatio)) {
        $drawH = [int]($Size * $paddingRatio)
        $drawW = [int]($drawH * ($srcImg.Width / $srcImg.Height))
    }

    $drawX = [int](($Size - $drawW) / 2)
    $drawY = [int](($Size - $drawH) / 2)

    $destRect = New-Object System.Drawing.Rectangle($drawX, $drawY, $drawW, $drawH)
    $srcRect = New-Object System.Drawing.Rectangle(0, 0, $srcImg.Width, $srcImg.Height)

    $g.DrawImage($srcImg, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()

    $destBmp.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBmp.Dispose()
    Write-Host "Generated Square: $DestinationPath ($Size x $Size)" -ForegroundColor Cyan
}

function Generate-RoundIcon {
    param(
        [string]$DestinationPath,
        [int]$Size
    )

    $destDir = Split-Path -Parent $DestinationPath
    if (!(Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $destBmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($destBmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # Clip to circular path
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse(0, 0, $Size - 1, $Size - 1)
    $g.SetClip($path)

    # Fill circular background with #FEFEFD
    $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 254, 254, 253))
    $g.FillEllipse($bgBrush, 0, 0, $Size - 1, $Size - 1)
    $bgBrush.Dispose()

    # Calculate centered bounding box (circular safe area ratio is ~0.72)
    $paddingRatio = 0.72
    $drawW = [int]($Size * $paddingRatio)
    $drawH = [int]($drawW * ($srcImg.Height / $srcImg.Width))
    if ($drawH -gt ($Size * $paddingRatio)) {
        $drawH = [int]($Size * $paddingRatio)
        $drawW = [int]($drawH * ($srcImg.Width / $srcImg.Height))
    }

    $drawX = [int](($Size - $drawW) / 2)
    $drawY = [int](($Size - $drawH) / 2)

    $destRect = New-Object System.Drawing.Rectangle($drawX, $drawY, $drawW, $drawH)
    $srcRect = New-Object System.Drawing.Rectangle(0, 0, $srcImg.Width, $srcImg.Height)

    $g.DrawImage($srcImg, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $path.Dispose()
    $g.Dispose()

    $destBmp.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBmp.Dispose()
    Write-Host "Generated Round: $DestinationPath ($Size x $Size)" -ForegroundColor Cyan
}

function Generate-ForegroundIcon {
    param(
        [string]$DestinationPath,
        [int]$Size
    )

    $destDir = Split-Path -Parent $DestinationPath
    if (!(Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    # Android adaptive icon viewport: 108dp. Safe zone is centered 72dp (ratio = 72/108 = 0.666)
    $destBmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($destBmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $safeRatio = 0.60
    $drawW = [int]($Size * $safeRatio)
    $drawH = [int]($drawW * ($srcImg.Height / $srcImg.Width))
    if ($drawH -gt ($Size * $safeRatio)) {
        $drawH = [int]($Size * $safeRatio)
        $drawW = [int]($drawH * ($srcImg.Width / $srcImg.Height))
    }

    $drawX = [int](($Size - $drawW) / 2)
    $drawY = [int](($Size - $drawH) / 2)

    $destRect = New-Object System.Drawing.Rectangle($drawX, $drawY, $drawW, $drawH)
    $srcRect = New-Object System.Drawing.Rectangle(0, 0, $srcImg.Width, $srcImg.Height)

    $g.DrawImage($srcImg, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()

    $destBmp.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBmp.Dispose()
    Write-Host "Generated Foreground: $DestinationPath ($Size x $Size)" -ForegroundColor Cyan
}

Write-Host "Generating Android icons (Square, Round, Foreground)..." -ForegroundColor Green
$androidRes = Join-Path $RepoRoot "android\app\src\main\res"

# Standard / Legacy Square Icons
Generate-SquareIcon (Join-Path $androidRes "mipmap-mdpi\ic_launcher.png") 48
Generate-SquareIcon (Join-Path $androidRes "mipmap-hdpi\ic_launcher.png") 72
Generate-SquareIcon (Join-Path $androidRes "mipmap-xhdpi\ic_launcher.png") 96
Generate-SquareIcon (Join-Path $androidRes "mipmap-xxhdpi\ic_launcher.png") 144
Generate-SquareIcon (Join-Path $androidRes "mipmap-xxxhdpi\ic_launcher.png") 192

# Round Icons (for round icon launchers: Pixel, Samsung One UI, etc.)
Generate-RoundIcon (Join-Path $androidRes "mipmap-mdpi\ic_launcher_round.png") 48
Generate-RoundIcon (Join-Path $androidRes "mipmap-hdpi\ic_launcher_round.png") 72
Generate-RoundIcon (Join-Path $androidRes "mipmap-xhdpi\ic_launcher_round.png") 96
Generate-RoundIcon (Join-Path $androidRes "mipmap-xxhdpi\ic_launcher_round.png") 144
Generate-RoundIcon (Join-Path $androidRes "mipmap-xxxhdpi\ic_launcher_round.png") 192

# Adaptive Icon Foregrounds (108dp base: mdpi=108, hdpi=162, xhdpi=216, xxhdpi=324, xxxhdpi=432)
Generate-ForegroundIcon (Join-Path $androidRes "mipmap-mdpi\ic_launcher_foreground.png") 108
Generate-ForegroundIcon (Join-Path $androidRes "mipmap-hdpi\ic_launcher_foreground.png") 162
Generate-ForegroundIcon (Join-Path $androidRes "mipmap-xhdpi\ic_launcher_foreground.png") 216
Generate-ForegroundIcon (Join-Path $androidRes "mipmap-xxhdpi\ic_launcher_foreground.png") 324
Generate-ForegroundIcon (Join-Path $androidRes "mipmap-xxxhdpi\ic_launcher_foreground.png") 432

Write-Host "`nGenerating Web icons & favicon..." -ForegroundColor Green
$webDir = Join-Path $RepoRoot "web"
Generate-SquareIcon (Join-Path $webDir "favicon.png") 64
Generate-SquareIcon (Join-Path $webDir "icons\Icon-192.png") 192
Generate-SquareIcon (Join-Path $webDir "icons\Icon-512.png") 512
Generate-SquareIcon (Join-Path $webDir "icons\Icon-maskable-192.png") 192
Generate-SquareIcon (Join-Path $webDir "icons\Icon-maskable-512.png") 512

Write-Host "`nGenerating iOS AppIcon set..." -ForegroundColor Green
$iosAppIcon = Join-Path $RepoRoot "ios\Runner\Assets.xcassets\AppIcon.appiconset"
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-1024x1024@1x.png") 1024
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-20x20@1x.png") 20
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-20x20@2x.png") 40
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-20x20@3x.png") 60
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-29x29@1x.png") 29
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-29x29@2x.png") 58
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-29x29@3x.png") 87
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-40x40@1x.png") 40
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-40x40@2x.png") 80
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-40x40@3x.png") 120
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-60x60@2x.png") 120
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-60x60@3x.png") 180
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-76x76@1x.png") 76
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-76x76@2x.png") 152
Generate-SquareIcon (Join-Path $iosAppIcon "Icon-App-83.5x83.5@2x.png") 167

$srcImg.Dispose()
Write-Host "`nAll app icons successfully generated!" -ForegroundColor Green

