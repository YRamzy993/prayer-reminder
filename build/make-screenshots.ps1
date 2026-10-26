# Renders Store screenshots (1920x1080 PNG) from the app's real windows.
# The windows are created off-screen and drawn to a bitmap, so nothing from the
# desktop ends up in the images.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$out = Join-Path $repo 'assets\store-screenshots'
New-Item -ItemType Directory -Force $out | Out-Null

# Load the app's functions without starting the tray app.
. (Join-Path $repo 'src\PrayerReminder.ps1') -NoRun

$script:Config = Get-DefaultConfig
$Config.location.city = 'Cairo, Egypt'
# Keep the real defaults visible in the shots, but stay silent while rendering.
function Start-Sound { return $null }
function Get-SpeechFile { return $null }

$W = 1920; $H = 1080
$bg1 = [System.Drawing.Color]::FromArgb(10, 38, 31)
$bg2 = [System.Drawing.Color]::FromArgb(22, 78, 62)
$gold = [System.Drawing.Color]::FromArgb(233, 205, 140)

function New-Canvas([string]$caption, [string]$sub) {
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'
    $rect = New-Object System.Drawing.Rectangle 0, 0, $W, $H
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $bg1, $bg2, 55.0
    $g.FillRectangle($brush, $rect)

    $f1 = New-Object System.Drawing.Font 'Segoe UI', 40, ([System.Drawing.FontStyle]::Bold)
    $f2 = New-Object System.Drawing.Font 'Segoe UI', 20
    $g.DrawString($caption, $f1, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)), 110, 96)
    $g.DrawString($sub, $f2, (New-Object System.Drawing.SolidBrush $gold), 114, 168)
    return @{ bmp = $bmp; g = $g }
}

# Draws a bitmap onto the canvas, scaled and centred, with a soft drop shadow.
function Add-Image($canvas, $shot, [double]$scale, [int]$top) {
    # Note: PowerShell variable names are case-insensitive, so these must not be $w/$h.
    $iw = [int]($shot.Width * $scale); $ih = [int]($shot.Height * $scale)
    $x = [int](($W - $iw) / 2)
    $y = if ($top) { $top } else { [int](($H - $ih) / 2) + 60 }
    for ($i = 22; $i -ge 1; $i--) {
        $b = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(3, 0, 0, 0))
        $canvas.g.FillRectangle($b, ($x - $i), ($y - $i + 8), ($iw + 2 * $i), ($ih + 2 * $i))
    }
    $canvas.g.InterpolationMode = 'HighQualityBicubic'
    $canvas.g.PixelOffsetMode = 'HighQuality'
    $canvas.g.DrawImage($shot, $x, $y, $iw, $ih)
}

# Grabs a control's pixels into a bitmap.
function Get-Shot($ctl) {
    $b = New-Object System.Drawing.Bitmap $ctl.Width, $ctl.Height
    $ctl.DrawToBitmap($b, (New-Object System.Drawing.Rectangle 0, 0, $ctl.Width, $ctl.Height))
    return $b
}

function Save-Canvas($canvas, [string]$name) {
    $p = Join-Path $out $name
    $canvas.bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
    $canvas.g.Dispose(); $canvas.bmp.Dispose()
    Write-Host "    $name"
}

# Show a form off-screen so it paints without appearing on the desktop.
function Show-Offscreen($form) {
    $form.StartPosition = 'Manual'
    $form.Location = New-Object System.Drawing.Point -4000, -4000
    $form.ShowInTaskbar = $false
    $form.Show()
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 400
    [System.Windows.Forms.Application]::DoEvents()
}

Write-Host '==> screenshots'

# 1 - the reminder popup, before a prayer
Show-PrayerPopup 'Asr' ((Get-Date).Date.AddHours(15).AddMinutes(54)) 'pre'
$popup = $OpenPopups[0]
Show-Offscreen $popup
$c = New-Canvas 'A quiet reminder before every prayer' 'Pops up 15 minutes ahead - snooze it or dismiss it'
Add-Image $c (Get-Shot $popup) 2.2 360
Save-Canvas $c '01-reminder.png'

# 2 - the popup at prayer time
Show-PrayerPopup 'Maghrib' ((Get-Date).Date.AddHours(18).AddMinutes(17)) 'now'
$popup2 = $OpenPopups[1]
Show-Offscreen $popup2
$c = New-Canvas 'And again when the time arrives' 'Plays a takbeer, a chime, or your own Adhan file'
Add-Image $c (Get-Shot $popup2) 2.2 360
Save-Canvas $c '02-prayer-time.png'
$popup.Close(); $popup2.Close()

# 3 - the settings window, built by the app itself
$script:Tray = $null
$settingsForm = $null
$probe = New-Object System.Windows.Forms.Timer
$probe.Interval = 700
$probe.add_Tick({
    $this.Stop()
    $f = [System.Windows.Forms.Application]::OpenForms | Where-Object { $_.Text -like '*Settings*' } | Select-Object -First 1
    if ($f) {
        $script:Captured = New-Object System.Drawing.Bitmap $f.Width, $f.Height
        $f.DrawToBitmap($script:Captured, (New-Object System.Drawing.Rectangle 0, 0, $f.Width, $f.Height))
        $f.Close()
    }
})
$probe.Start()
Show-Settings
$probe.Dispose()

if ($script:Captured) {
    $c = New-Canvas 'Everything in one window' '23 calculation methods, per-prayer adjustments, your own sounds'
    Add-Image $c $script:Captured 1.0 250
    Save-Canvas $c '03-settings.png'
} else {
    Write-Warning 'Could not capture the Settings window'
}

Write-Host "Screenshots in $out"

