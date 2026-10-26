# Draws every logo the MSIX manifest and the Store listing need, into assets/msix/.
Add-Type -AssemblyName System.Drawing
$repo = Split-Path -Parent $PSScriptRoot
$out = Join-Path $repo 'assets\msix'
New-Item -ItemType Directory -Force $out | Out-Null

$green = [System.Drawing.Color]::FromArgb(16, 58, 46)
$gold  = [System.Drawing.Color]::FromArgb(233, 195, 100)

# Crescent inside a square, drawn at any size. Transparent plate for the unplated
# taskbar variants, solid green otherwise.
function New-Logo([int]$w, [int]$h, [bool]$plate = $true, [string]$text = '') {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)
    if ($plate) { $g.FillRectangle((New-Object System.Drawing.SolidBrush $green), 0, 0, $w, $h) }

    # The glyph occupies a square box, left-aligned when there is text beside it.
    $box = if ($text) { [math]::Min($h, [int]($w * 0.34)) } else { [math]::Min($w, $h) }
    $pad = $box * 0.16
    $d = $box - 2 * $pad
    $ox = if ($text) { $box * 0.22 } else { ($w - $box) / 2 + $pad }
    $oy = ($h - $box) / 2 + $pad

    $g.FillEllipse((New-Object System.Drawing.SolidBrush $gold), $ox, $oy, $d, $d)
    # Punch the inner disc out with the plate colour, or with transparency when unplated.
    if ($plate) {
        $g.FillEllipse((New-Object System.Drawing.SolidBrush $green), ($ox + $d * 0.27), ($oy - $d * 0.1), ($d * 0.92), ($d * 0.92))
    } else {
        $g.CompositingMode = 'SourceCopy'
        $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::Transparent)), ($ox + $d * 0.27), ($oy - $d * 0.1), ($d * 0.92), ($d * 0.92))
        $g.CompositingMode = 'SourceOver'
    }

    if ($text) {
        $font = New-Object System.Drawing.Font 'Segoe UI', ($h * 0.19), ([System.Drawing.FontStyle]::Bold), 'Pixel'
        $sf = New-Object System.Drawing.StringFormat
        $sf.LineAlignment = 'Center'
        $g.DrawString($text, $font, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)),
            (New-Object System.Drawing.RectangleF ($box * 1.05), 0, ($w - $box * 1.1), $h), $sf)
    }
    $g.Dispose()
    return $bmp
}

# name = size, plated, optional wordmark
$specs = @(
    @{ n = 'Square44x44Logo.png';                      w = 44;   h = 44 }
    @{ n = 'Square44x44Logo.scale-200.png';            w = 88;   h = 88 }
    @{ n = 'Square44x44Logo.targetsize-16.png';        w = 16;   h = 16;  plate = $false }
    @{ n = 'Square44x44Logo.targetsize-24.png';        w = 24;   h = 24;  plate = $false }
    @{ n = 'Square44x44Logo.targetsize-32.png';        w = 32;   h = 32;  plate = $false }
    @{ n = 'Square44x44Logo.targetsize-48.png';        w = 48;   h = 48;  plate = $false }
    @{ n = 'Square44x44Logo.targetsize-256.png';       w = 256;  h = 256; plate = $false }
    @{ n = 'Square44x44Logo.altform-unplated_targetsize-16.png';  w = 16;  h = 16;  plate = $false }
    @{ n = 'Square44x44Logo.altform-unplated_targetsize-32.png';  w = 32;  h = 32;  plate = $false }
    @{ n = 'Square44x44Logo.altform-unplated_targetsize-48.png';  w = 48;  h = 48;  plate = $false }
    @{ n = 'Square44x44Logo.altform-unplated_targetsize-256.png'; w = 256; h = 256; plate = $false }
    @{ n = 'Square71x71Logo.png';                      w = 71;   h = 71 }
    @{ n = 'Square71x71Logo.scale-200.png';            w = 142;  h = 142 }
    @{ n = 'Square150x150Logo.png';                    w = 150;  h = 150 }
    @{ n = 'Square150x150Logo.scale-200.png';          w = 300;  h = 300 }
    @{ n = 'Square310x310Logo.png';                    w = 310;  h = 310 }
    @{ n = 'Wide310x150Logo.png';                      w = 310;  h = 150; text = 'Prayer`nReminder' }
    @{ n = 'Wide310x150Logo.scale-200.png';            w = 620;  h = 300; text = 'Prayer`nReminder' }
    @{ n = 'StoreLogo.png';                            w = 50;   h = 50 }
    @{ n = 'StoreLogo.scale-200.png';                  w = 100;  h = 100 }
    @{ n = 'SplashScreen.png';                         w = 620;  h = 300; text = 'Prayer`nReminder' }
)

foreach ($s in $specs) {
    $plate = if ($s.ContainsKey('plate')) { $s.plate } else { $true }
    $text = if ($s.text) { $s.text -replace '`n', "`n" } else { '' }
    $bmp = New-Logo $s.w $s.h $plate $text
    $bmp.Save((Join-Path $out $s.n), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# 300x300 PNG for the Store listing's app icon slot.
$bmp = New-Logo 300 300 $true ''
$bmp.Save((Join-Path $out 'StoreListing-300x300.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "Wrote $((Get-ChildItem $out -Filter *.png).Count) images to $out"
