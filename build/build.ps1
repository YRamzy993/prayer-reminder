# Builds dist\PrayerReminder.exe and dist\PrayerReminder-Setup-<version>.exe
#
# Requirements (both free):
#   Install-Module ps2exe -Scope CurrentUser
#   winget install JRSoftware.InnoSetup
param([string]$Version = '1.0.0', [switch]$ExeOnly)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $repo 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null

Write-Host '==> icon'
& (Join-Path $PSScriptRoot 'make-icon.ps1')

Write-Host '==> PrayerReminder.exe'
Import-Module ps2exe
$exe = Join-Path $dist 'PrayerReminder.exe'
Invoke-PS2EXE -InputFile (Join-Path $repo 'src\PrayerReminder.ps1') -OutputFile $exe `
    -iconFile (Join-Path $repo 'src\app.ico') -noConsole -STA `
    -title 'Prayer Reminder' -description 'Prayer time reminders for Windows' `
    -product 'Prayer Reminder' -company 'YRamzy993' -version $Version `
    -copyright 'MIT License' | Out-Null
if (-not (Test-Path $exe)) { throw 'ps2exe did not produce an exe' }
Write-Host ("    {0:N0} KB" -f ((Get-Item $exe).Length / 1KB))

if ($ExeOnly) { return }

Write-Host '==> installer'
$iscc = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
    'C:\Program Files\Inno Setup 6\ISCC.exe'
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup not found. Run: winget install JRSoftware.InnoSetup' }

& $iscc "/DAppVersion=$Version" (Join-Path $PSScriptRoot 'installer.iss') | Select-Object -Last 3
if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)" }

Get-ChildItem $dist -Filter *.exe | ForEach-Object { "    {0}  {1:N0} KB" -f $_.Name, ($_.Length / 1KB) }
