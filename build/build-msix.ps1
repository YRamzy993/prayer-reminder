# Builds dist\PrayerReminder-<version>.msix for the Microsoft Store.
#
# The Store re-signs the package itself, so no code-signing certificate is needed to submit.
# Pass -SelfSign to sign it with a throwaway certificate, which is only needed to install
# and test the package on this machine before uploading.
#
# Identity values come from build\msix.json - fill them in from Partner Center first.
param(
    [string]$Version,
    [switch]$SelfSign,
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
$repo  = Split-Path -Parent $PSScriptRoot
$dist  = Join-Path $repo 'dist'
$stage = Join-Path $dist 'msix-stage'

# -Encoding UTF8 matters: PowerShell 5.1 otherwise reads this as ANSI and mangles a
# non-Latin DisplayName into mojibake that ships all the way into the Store listing.
$cfg = Get-Content (Join-Path $PSScriptRoot 'msix.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($Version) { $cfg.Version = $Version }
if ($cfg.Version -notmatch '^\d+\.\d+\.\d+\.0$') { throw "Version must be x.y.z.0 (the Store reserves the last part). Got '$($cfg.Version)'" }
if (-not $SelfSign -and ($cfg.IdentityName -like 'REPLACE*' -or $cfg.Publisher -like '*REPLACE*')) {
    throw "Fill in build\msix.json with the identity values from Partner Center first (or use -SelfSign to build a test package)."
}

# makeappx.exe / signtool.exe, from the Windows SDK or the SDK build tools NuGet package.
function Get-SdkTool([string]$name) {
    $found = @(
        Get-ChildItem "$env:LOCALAPPDATA\PrayerReminder-build\sdk" -Filter $name -Recurse -EA 0
        Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin' -Filter $name -Recurse -EA 0
    ) | Where-Object { $_.FullName -match '\\x64\\' } | Sort-Object FullName -Descending | Select-Object -First 1
    if ($found) { return $found.FullName }

    # Not present: fetch just the tools (~22 MB) instead of the full SDK.
    $sdk = "$env:LOCALAPPDATA\PrayerReminder-build\sdk"
    New-Item -ItemType Directory -Force $sdk | Out-Null
    $zip = Join-Path $sdk 'buildtools.zip'
    Write-Host '    fetching Windows SDK build tools from nuget.org'
    Invoke-WebRequest 'https://www.nuget.org/api/v2/package/Microsoft.Windows.SDK.BuildTools' -OutFile $zip
    Expand-Archive $zip $sdk -Force
    Remove-Item $zip -Force
    $found = Get-ChildItem $sdk -Filter $name -Recurse | Where-Object { $_.FullName -match '\\x64\\' } | Select-Object -First 1
    if (-not $found) { throw "$name not found after downloading the SDK build tools" }
    return $found.FullName
}

Write-Host '==> exe + icon + logos'
& (Join-Path $PSScriptRoot 'build.ps1') -Version ($cfg.Version -replace '\.0$', '') -ExeOnly
& (Join-Path $PSScriptRoot 'make-assets.ps1')

Write-Host '==> staging'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $stage 'Assets') | Out-Null
New-Item -ItemType Directory -Force (Join-Path $stage 'sounds') | Out-Null
Copy-Item (Join-Path $dist 'PrayerReminder.exe') $stage
Copy-Item (Join-Path $repo 'src\app.ico') $stage
Copy-Item (Join-Path $repo 'assets\msix\*.png') (Join-Path $stage 'Assets')
Copy-Item (Join-Path $repo 'assets\sounds\*') (Join-Path $stage 'sounds')
Copy-Item (Join-Path $repo 'README.md'), (Join-Path $repo 'CREDITS.md'), (Join-Path $repo 'LICENSE'), (Join-Path $repo 'PRIVACY.md') $stage
Remove-Item (Join-Path $stage 'Assets\StoreListing-300x300.png') -EA 0

$manifest = Get-Content (Join-Path $PSScriptRoot 'AppxManifest.template.xml') -Raw -Encoding UTF8
foreach ($k in 'IdentityName', 'Publisher', 'PublisherDisplayName', 'DisplayName', 'Version') {
    $manifest = $manifest.Replace("{{$k}}", $cfg.$k)
}
if ($SelfSign) {
    # A test package must be signed by a certificate whose subject equals Publisher.
    $manifest = $manifest -replace 'Publisher="[^"]*"', 'Publisher="CN=PrayerReminder-Test"'
}
[IO.File]::WriteAllText((Join-Path $stage 'AppxManifest.xml'), $manifest, (New-Object Text.UTF8Encoding $false))

Write-Host '==> packing'
$msix = Join-Path $dist "PrayerReminder-$($cfg.Version).msix"
Remove-Item $msix -EA 0
$makeappx = Get-SdkTool 'makeappx.exe'
& $makeappx pack /d $stage /p $msix /o | Select-Object -Last 2
if ($LASTEXITCODE -ne 0) { throw "makeappx failed ($LASTEXITCODE)" }

if ($SelfSign) {
    Write-Host '==> self-signing (test only)'
    $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -eq 'CN=PrayerReminder-Test' } | Select-Object -First 1
    if (-not $cert) {
        $cert = New-SelfSignedCertificate -Type Custom -Subject 'CN=PrayerReminder-Test' `
            -KeyUsage DigitalSignature -FriendlyName 'Prayer Reminder test signing' `
            -CertStoreLocation 'Cert:\CurrentUser\My' `
            -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}')
    }
    $pfx = Join-Path $dist 'test-signing.pfx'
    $pw = ConvertTo-SecureString -String 'prayer-test' -Force -AsPlainText
    Export-PfxCertificate -Cert $cert -FilePath $pfx -Password $pw | Out-Null
    $signtool = Get-SdkTool 'signtool.exe'
    & $signtool sign /fd SHA256 /f $pfx /p 'prayer-test' $msix | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0) { throw "signtool failed ($LASTEXITCODE)" }
    Write-Host "    to trust it locally (one-off, needs admin):"
    Write-Host "    Import-Certificate -FilePath '$(Join-Path $dist 'test-signing.cer')' -CertStoreLocation Cert:\LocalMachine\TrustedPeople"
    Export-Certificate -Cert $cert -FilePath (Join-Path $dist 'test-signing.cer') | Out-Null
}

"    {0}  {1:N0} KB" -f (Split-Path $msix -Leaf), ((Get-Item $msix).Length / 1KB)

if ($Install) {
    Write-Host '==> installing locally'
    Add-AppxPackage -Path $msix
    Get-AppxPackage *PrayerReminder* | Select-Object Name, Version, PackageFullName
}
