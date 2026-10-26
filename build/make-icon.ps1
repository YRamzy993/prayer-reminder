# Draws the crescent app icon and writes src/app.ico (PNG-compressed, 256px).
Add-Type -AssemblyName System.Drawing
$out = Join-Path (Split-Path -Parent $PSScriptRoot) 'src\app.ico'
$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::Transparent)

$green = [System.Drawing.Color]::FromArgb(16, 58, 46)
$gold  = [System.Drawing.Color]::FromArgb(233, 195, 100)

$g.FillEllipse((New-Object System.Drawing.SolidBrush $green), 0, 0, $size - 1, $size - 1)
# Crescent: a gold disc with a green disc punched out of its upper right.
$g.FillEllipse((New-Object System.Drawing.SolidBrush $gold), 40, 40, 176, 176)
$g.FillEllipse((New-Object System.Drawing.SolidBrush $green), 88, 24, 160, 160)
$g.Dispose()

$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$png = $ms.ToArray()
$bmp.Dispose()

# ICONDIR + one ICONDIRENTRY pointing at the PNG payload.
$fs = [IO.File]::Create($out)
$bw = New-Object IO.BinaryWriter $fs
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)   # reserved, type=icon, count
$bw.Write([byte]0); $bw.Write([byte]0)                             # 0 x 0 means 256 x 256
$bw.Write([byte]0); $bw.Write([byte]0)                             # palette, reserved
$bw.Write([uint16]1); $bw.Write([uint16]32)                        # planes, bpp
$bw.Write([uint32]$png.Length); $bw.Write([uint32]22)              # size, offset
$bw.Write($png)
$bw.Close()
Write-Host "Wrote $out ($((Get-Item $out).Length) bytes)"
