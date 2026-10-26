# Prayer Reminder - a small Windows tray app that pops up a reminder before each prayer,
# using prayer times for wherever the laptop happens to be.
#
# Times come from the Aladhan API and are cached per month, so it keeps working offline.
# Settings live in %APPDATA%\PrayerReminder so the app folder stays read-only.
# Right-click the tray icon for today's times, Settings, Test popup, Pause and Exit.
# -NoRun loads the functions without starting the tray app, so build tools can reuse the real UI.
param([switch]$Settings, [switch]$NoRun)

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---- paths ----------------------------------------------------------------
# AppDir holds the bundled sounds and is read-only once installed; DataDir is writable.
# Resolved for both ways the app runs: as a .ps1 and as the compiled .exe.
$script:HostExe = try { [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName } catch { '' }
$script:IsExe   = [IO.Path]::GetFileName($HostExe) -like 'PrayerReminder*.exe'
$script:AppDir  = if ($IsExe) { Split-Path -Parent $HostExe }
                  elseif ($PSScriptRoot) { $PSScriptRoot }
                  else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$script:DataDir    = Join-Path $env:APPDATA 'PrayerReminder'
$script:ConfigPath = Join-Path $DataDir 'config.json'
$script:CacheDir   = Join-Path $DataDir 'cache'
$script:LogPath    = Join-Path $DataDir 'prayer-reminder.log'
$script:SoundsDir  = Join-Path $AppDir 'sounds'
$script:Inv        = [Globalization.CultureInfo]::InvariantCulture
New-Item -ItemType Directory -Force $CacheDir | Out-Null

# ---- single instance ------------------------------------------------------
$created = $NoRun
if (-not $NoRun) {
    $script:Mutex = New-Object System.Threading.Mutex($true, 'Local\PrayerReminderTray', [ref]$created)
    if (-not $created) {
        [System.Windows.Forms.MessageBox]::Show('Prayer Reminder is already running - see the tray icon near the clock.', 'Prayer Reminder') | Out-Null
        exit
    }
}

$script:Prayers = @('Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha')
$script:Arabic  = @{ Fajr = 'الفجر'; Sunrise = 'الشروق'; Dhuhr = 'الظهر'; Asr = 'العصر'; Maghrib = 'المغرب'; Isha = 'العشاء' }
$script:Methods = [ordered]@{
    3 = 'Muslim World League'; 5 = 'Egyptian General Authority of Survey'; 4 = 'Umm Al-Qura, Makkah'
    2 = 'ISNA (North America)'; 1 = 'University of Islamic Sciences, Karachi'; 8 = 'Gulf Region'
    9 = 'Kuwait'; 10 = 'Qatar'; 16 = 'Dubai'; 23 = 'Jordan'; 13 = 'Diyanet, Turkey'; 11 = 'Singapore'
    17 = 'JAKIM, Malaysia'; 20 = 'Kemenag, Indonesia'; 12 = 'UOIF, France'; 14 = 'Russia'
    15 = 'Moonsighting Committee'; 18 = 'Tunisia'; 19 = 'Algeria'; 21 = 'Morocco'; 22 = 'Portugal'
    7 = 'Institute of Geophysics, Tehran'; 0 = 'Shia Ithna-Ashari (Jafari)'
}

# ---- WinRT helpers --------------------------------------------------------
# WinRT async methods return IAsyncOperation; this turns one into a result we can wait on.
function Invoke-Async($operation, [type]$resultType) {
    if (-not $script:AsTaskMethod) {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        $script:AsTaskMethod = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
            $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
    }
    $task = $script:AsTaskMethod.MakeGenericMethod($resultType).Invoke($null, @($operation))
    [void]$task.Wait(15000)
    return $task.Result
}

# True when running from an installed MSIX package (the Microsoft Store build).
function Test-Packaged {
    if ($null -ne $script:Packaged) { return $script:Packaged }
    $script:Packaged = try {
        $null = [Windows.ApplicationModel.Package,Windows.ApplicationModel,ContentType=WindowsRuntime]
        $null -ne [Windows.ApplicationModel.Package]::Current.Id.FamilyName
    } catch { $false }
    return $script:Packaged
}

function Write-Log($msg) {
    try {
        if ((Test-Path $LogPath) -and (Get-Item $LogPath).Length -gt 512KB) {
            Move-Item $LogPath "$LogPath.old" -Force -ErrorAction SilentlyContinue
        }
        Add-Content -Path $LogPath -Value ("{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $msg) -Encoding UTF8
    } catch {}
}

# ---- config ---------------------------------------------------------------
function Get-DefaultConfig {
    $p = [ordered]@{}
    foreach ($n in $Prayers) { $p[$n] = [pscustomobject]@{ enabled = ($n -ne 'Sunrise'); offsetMinutes = 0 } }
    [pscustomobject]@{
        location            = [pscustomobject]@{ mode = 'auto'; city = ''; latitude = $null; longitude = $null }
        method              = 3
        school              = 0
        prayers             = [pscustomobject]$p
        remindBeforeMinutes = 15
        popupAtPrayerTime   = $true
        snoozeMinutes       = 5
        autoCloseSeconds    = 0
        playSound           = $true
        reminderSound       = 'takbeer.mp3'
        speakReminder       = $true
        adhanFile           = ''
        startWithWindows    = $true
        paused              = $false
    }
}

function Import-Config {
    $def = Get-DefaultConfig
    # First run after an install: pick up a config.json shipped or left next to the app.
    $seed = Join-Path $AppDir 'config.json'
    if (-not (Test-Path $ConfigPath) -and (Test-Path $seed)) {
        Copy-Item $seed $ConfigPath -ErrorAction SilentlyContinue
        Write-Log "Imported existing settings from $seed"
    }
    $c = $null
    if (Test-Path $ConfigPath) {
        try { $c = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Write-Log "Bad config.json, using defaults: $_" }
    }
    if (-not $c) { $c = $def; $script:FirstRun = $true }
    foreach ($prop in $def.PSObject.Properties) {
        if (-not $c.PSObject.Properties[$prop.Name]) { $c | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value }
    }
    foreach ($n in $Prayers) {
        if (-not $c.prayers.PSObject.Properties[$n]) { $c.prayers | Add-Member -NotePropertyName $n -NotePropertyValue $def.prayers.$n }
    }
    $script:Config = $c
    Save-Config
}

function Save-Config {
    try { $Config | ConvertTo-Json -Depth 6 | Set-Content -Path $ConfigPath -Encoding UTF8 }
    catch { Write-Log "Could not save settings: $_" }
}

# ---- location -------------------------------------------------------------
function Get-WindowsLocation {
    try {
        Add-Type -AssemblyName System.Device
        $w = New-Object System.Device.Location.GeoCoordinateWatcher
        if (-not $w.TryStart($true, [TimeSpan]::FromSeconds(5))) { return $null }
        $deadline = (Get-Date).AddSeconds(10)
        while ($w.Position.Location.IsUnknown -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 300 }
        $loc = $w.Position.Location
        $w.Stop(); $w.Dispose()
        if ($loc.IsUnknown) { return $null }
        return @{ lat = [math]::Round($loc.Latitude, 4); lon = [math]::Round($loc.Longitude, 4); city = '' }
    } catch { Write-Log "Windows location failed: $_"; return $null }
}

function Get-IpLocation {
    try {
        $r = Invoke-RestMethod 'http://ip-api.com/json/?fields=status,city,country,lat,lon' -TimeoutSec 10
        if ($r.status -ne 'success') { return $null }
        return @{ lat = [double]$r.lat; lon = [double]$r.lon; city = "$($r.city), $($r.country)" }
    } catch { Write-Log "IP location failed: $_"; return $null }
}

function Get-CityName($lat, $lon) {
    try {
        $u = 'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude={0}&longitude={1}&localityLanguage=en' -f $lat.ToString($Inv), $lon.ToString($Inv)
        $r = Invoke-RestMethod $u -TimeoutSec 10
        $name = @($r.city, $r.locality, $r.principalSubdivision) | Where-Object { $_ } | Select-Object -First 1
        if ($name) { return "$name, $($r.countryName)" }
    } catch { Write-Log "Reverse geocode failed: $_" }
    return ('{0:0.00}, {1:0.00}' -f $lat, $lon)
}

# Windows location first (precise), internet IP lookup as fallback.
function Find-Location {
    $win = Get-WindowsLocation
    if ($win) { $win.city = Get-CityName $win.lat $win.lon; return $win }
    return Get-IpLocation
}

function Get-DistanceKm($lat1, $lon1, $lat2, $lon2) {
    $r = 6371.0
    $dLat = ($lat2 - $lat1) * [math]::PI / 180
    $dLon = ($lon2 - $lon1) * [math]::PI / 180
    $a = [math]::Sin($dLat / 2) * [math]::Sin($dLat / 2) +
         [math]::Cos($lat1 * [math]::PI / 180) * [math]::Cos($lat2 * [math]::PI / 180) *
         [math]::Sin($dLon / 2) * [math]::Sin($dLon / 2)
    return $r * 2 * [math]::Atan2([math]::Sqrt($a), [math]::Sqrt(1 - $a))
}

# Only accept a new position once it is a real move. Wi-Fi positioning jitters by
# tens of kilometres, which would otherwise make the city and the times jump around.
function Update-AutoLocation {
    $found = Find-Location
    if (-not $found) {
        if ($null -eq $Config.location.latitude) { throw 'Could not detect location (no Windows location and no internet). Set it manually in Settings.' }
        return
    }
    if ($null -ne $Config.location.latitude) {
        $moved = Get-DistanceKm ([double]$Config.location.latitude) ([double]$Config.location.longitude) $found.lat $found.lon
        if ($moved -lt 25) { return }
        Write-Log ("Moved {0:N0} km -> {1}" -f $moved, $found.city)
    }
    $Config.location.latitude  = $found.lat
    $Config.location.longitude = $found.lon
    $Config.location.city      = $found.city
    Save-Config
}

# ---- prayer times ---------------------------------------------------------
function Get-TuneString {
    # Aladhan order: Imsak,Fajr,Sunrise,Dhuhr,Asr,Maghrib,Sunset,Isha,Midnight
    $o = $Config.prayers
    '0,{0},{1},{2},{3},{4},0,{5},0' -f $o.Fajr.offsetMinutes, $o.Sunrise.offsetMinutes, $o.Dhuhr.offsetMinutes,
        $o.Asr.offsetMinutes, $o.Maghrib.offsetMinutes, $o.Isha.offsetMinutes
}

function Get-MonthData([datetime]$date) {
    $lat = ([double]$Config.location.latitude).ToString('0.####', $Inv)
    $lon = ([double]$Config.location.longitude).ToString('0.####', $Inv)
    # Cache key is coarse (~1 km) so small position changes reuse the same month file.
    $klat = ([double]$Config.location.latitude).ToString('0.00', $Inv)
    $klon = ([double]$Config.location.longitude).ToString('0.00', $Inv)
    $tune = Get-TuneString
    $key  = ('{0:yyyy-MM}_{1}_{2}_m{3}_s{4}_{5}' -f $date, $klat, $klon, $Config.method, $Config.school, $tune) -replace '[^\w\.\-]', '_'
    $file = Join-Path $CacheDir "$key.json"
    if (Test-Path $file) { return (Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json) }

    $url = "https://api.aladhan.com/v1/calendar/$($date.Year)/$($date.Month)?latitude=$lat&longitude=$lon&method=$($Config.method)&school=$($Config.school)&tune=$tune"
    $r = Invoke-RestMethod $url -TimeoutSec 20 -ErrorAction Stop
    if ($r.code -ne 200) { throw "Prayer API returned $($r.code)" }
    $r.data | ConvertTo-Json -Depth 8 | Set-Content -Path $file -Encoding UTF8
    Get-ChildItem $CacheDir -Filter '2*.json' | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-70) } | Remove-Item -ErrorAction SilentlyContinue
    return $r.data
}

function Get-DayTimes([datetime]$date) {
    $day = Get-MonthData $date | Where-Object { [int]$_.date.gregorian.day -eq $date.Day } | Select-Object -First 1
    if (-not $day) { throw "No prayer times for $($date.ToShortDateString())" }
    $t = [ordered]@{}
    foreach ($n in $Prayers) {
        $hhmm = ($day.timings.$n -split ' ')[0]      # "05:16 (EET)" -> "05:16"
        $t[$n] = $date.Date + [TimeSpan]::ParseExact($hhmm, 'hh\:mm', $Inv)
    }
    return $t
}

function Update-Times([switch]$Relocate) {
    try {
        if ($Config.location.mode -eq 'auto' -and ($Relocate -or $null -eq $Config.location.latitude)) { Update-AutoLocation }
        if ($null -eq $Config.location.latitude) { throw 'No location set. Open Settings and enter latitude/longitude.' }
        $today = (Get-Date).Date
        $script:Times = Get-DayTimes $today
        $script:TomorrowTimes = try { Get-DayTimes $today.AddDays(1) } catch { $null }
        $script:TimesDate = $today
        $script:LastError = $null
        $script:NextRetry = $null
        Write-Log ("Times for {0:yyyy-MM-dd} @ {1}: {2}" -f $today, $Config.location.city, (($Times.Keys | ForEach-Object { "$_ {0:HH:mm}" -f $Times[$_] }) -join ', '))
    } catch {
        $script:LastError = $_.Exception.Message
        $script:NextRetry = (Get-Date).AddMinutes(5)
        Write-Log "Update-Times failed: $($_.Exception.Message)"
    }
    Update-TrayText
}

function Get-NextPrayer {
    $now = Get-Date
    if ($Times) {
        foreach ($n in $Prayers) { if ($n -ne 'Sunrise' -and $Times[$n] -gt $now) { return @{ Name = $n; Time = $Times[$n] } } }
    }
    if ($TomorrowTimes) { return @{ Name = 'Fajr'; Time = $TomorrowTimes['Fajr'] } }
    return $null
}

# ---- sound ----------------------------------------------------------------
$script:MediaDir = Join-Path $env:WINDIR 'Media'
$script:BuiltInSounds = @('Alarm01', 'Alarm02', 'Alarm03', 'Alarm04', 'Alarm05', 'Alarm06', 'Alarm07', 'Alarm08', 'Alarm09', 'Alarm10',
    'Ring01', 'Ring02', 'Ring03', 'Ring04', 'Ring05', 'Ring06', 'Ring07', 'Ring08', 'Ring09', 'Ring10',
    'chimes', 'chord', 'ding', 'notify', 'tada', 'Windows Notify Calendar', 'Windows Notify System Generic', 'Windows Notify Messaging')

# Accepts a bundled file name ("takbeer.mp3"), a Windows sound name ("Alarm01"), or a full path.
function Resolve-SoundPath([string]$s) {
    if (-not $s) { return $null }
    if (Test-Path $s) { return $s }
    foreach ($p in @((Join-Path $SoundsDir $s), (Join-Path $MediaDir "$s.wav"))) { if (Test-Path $p) { return $p } }
    return $null
}

# Plays one or more files in sequence; returns the player so the popup can stop it.
function Start-Sound([string[]]$files) {
    try {
        $files = @($files | Where-Object { $_ })
        if (-not $files) { [System.Media.SystemSounds]::Exclamation.Play(); return $null }
        $pl = New-Object -ComObject WMPlayer.OCX
        $pl.settings.volume = 100
        if ($files.Count -eq 1) { $pl.URL = $files[0] }
        else {
            $list = $pl.newPlaylist('PrayerReminder', '')
            foreach ($f in $files) { $list.appendItem($pl.newMedia($f)) }
            $pl.currentPlaylist = $list
        }
        $pl.controls.play()
        return $pl
    } catch { Write-Log "Sound failed: $_"; return $null }
}

# Spoken reminder rendered to a cached WAV with Windows text-to-speech.
# Uses an Arabic voice when one is installed (Settings > Time & language > Speech), English otherwise.
function Get-SpeechFile([string]$prayer, [string]$kind, [int]$mins) {
    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        $null = [Windows.Media.SpeechSynthesis.SpeechSynthesizer,Windows.Media.SpeechSynthesis,ContentType=WindowsRuntime]
        $ar = [Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Where-Object { $_.Language -like 'ar*' } | Select-Object -First 1
        $isSunrise = $prayer -eq 'Sunrise'
        if ($ar) {
            $lang = 'ar'
            $name = if ($isSunrise) { $Arabic[$prayer] } else { "صلاة $($Arabic[$prayer])" }
            $text = if ($kind -eq 'pre') { "باقي $mins دقيقة على $name" } elseif ($isSunrise) { 'حان الآن وقت الشروق' } else { "حان الآن موعد $name" }
        } else {
            $lang = 'en'
            $name = if ($isSunrise) { 'Sunrise' } else { "$prayer prayer" }
            $text = if ($kind -eq 'pre') { "$name in $mins minutes." } elseif ($isSunrise) { 'It is now sunrise.' } else { "It is now time for $name." }
        }
        $file = Join-Path $CacheDir ('speech_{0}_{1}_{2}_{3}.wav' -f $lang, $prayer, $kind, $(if ($kind -eq 'pre') { $mins } else { 0 }))
        if (Test-Path $file) { return $file }

        $synth = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
        if ($ar) { $synth.Voice = $ar }
        $stream = Invoke-Async ($synth.SynthesizeTextToStreamAsync($text)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
        $src = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)
        $fs = [IO.File]::Create($file); $src.CopyTo($fs); $fs.Close()
        return $file
    } catch { Write-Log "Speech failed: $_"; return $null }
}

# ---- popup ----------------------------------------------------------------
$script:OpenPopups = New-Object System.Collections.ArrayList
$script:Snoozes    = New-Object System.Collections.ArrayList

function Show-PrayerPopup([string]$prayer, [datetime]$time, [string]$kind) {
    $w = 380; $h = 178
    $f = New-Object System.Windows.Forms.Form
    $f.FormBorderStyle = 'None'; $f.TopMost = $true; $f.ShowInTaskbar = $false
    $f.StartPosition = 'Manual'; $f.Size = New-Object System.Drawing.Size($w, $h)
    $f.BackColor = [System.Drawing.Color]::FromArgb(16, 58, 46)
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $f.Location = New-Object System.Drawing.Point(($wa.Right - $w - 16), ($wa.Bottom - $h - 16 - ($OpenPopups.Count * ($h + 10))))

    $bar = New-Object System.Windows.Forms.Panel
    $bar.BackColor = [System.Drawing.Color]::FromArgb(214, 175, 84); $bar.Dock = 'Left'; $bar.Width = 6
    $f.Controls.Add($bar)

    $white = [System.Drawing.Color]::White
    $gold  = [System.Drawing.Color]::FromArgb(233, 205, 140)
    $mute  = [System.Drawing.Color]::FromArgb(190, 215, 205)

    $cap = New-Object System.Windows.Forms.Label
    $cap.Text = if ($kind -eq 'pre') { 'PRAYER REMINDER' } else { 'حان الآن موعد الصلاة  -  TIME TO PRAY' }
    $cap.ForeColor = $gold; $cap.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $cap.Location = New-Object System.Drawing.Point(22, 14); $cap.AutoSize = $true
    $f.Controls.Add($cap)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "$prayer   $($Arabic[$prayer])"
    $title.ForeColor = $white; $title.Font = New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
    $title.Location = New-Object System.Drawing.Point(20, 36); $title.AutoSize = $true
    $f.Controls.Add($title)

    $mins = [math]::Max(0, [math]::Ceiling(($time - (Get-Date)).TotalMinutes))
    $sub = New-Object System.Windows.Forms.Label
    $sub.Text = if ($kind -eq 'pre') { "At {0:HH:mm}  -  in $mins min" -f $time } else { "{0:HH:mm}  -  $($Config.location.city)" -f $time }
    $sub.ForeColor = $mute; $sub.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)
    $sub.Location = New-Object System.Drawing.Point(22, 82); $sub.AutoSize = $true
    $f.Controls.Add($sub)

    $mk = {
        param($text, $x, $primary)
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $text; $b.FlatStyle = 'Flat'; $b.Size = New-Object System.Drawing.Size(150, 34)
        $b.Location = New-Object System.Drawing.Point($x, 124); $b.Cursor = 'Hand'
        $b.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
        if ($primary) { $b.BackColor = [System.Drawing.Color]::FromArgb(214, 175, 84); $b.ForeColor = [System.Drawing.Color]::FromArgb(16, 58, 46); $b.FlatAppearance.BorderSize = 0 }
        else { $b.ForeColor = [System.Drawing.Color]::White; $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(90, 130, 115) }
        $b
    }
    $snooze  = & $mk "Snooze $($Config.snoozeMinutes) min" 22 $false
    $dismiss = & $mk 'Dismiss' 206 $true
    $f.Controls.Add($snooze); $f.Controls.Add($dismiss)

    # Order: tone then voice; at prayer time with an Adhan file: voice then Adhan.
    $player = $null
    $speech = if ($Config.speakReminder) { Get-SpeechFile $prayer $kind $mins } else { $null }
    $useAdhan = $kind -eq 'now' -and $Config.adhanFile -and (Test-Path $Config.adhanFile)
    $queue = @()
    if ($useAdhan -and $Config.playSound) { $queue = @($speech, $Config.adhanFile) }
    else {
        if ($Config.playSound) {
            $tone = Resolve-SoundPath $Config.reminderSound
            if (-not $tone) { $tone = Join-Path $MediaDir 'Windows Notify System Generic.wav' }
            $queue += $tone
        }
        $queue += $speech
    }
    if (@($queue | Where-Object { $_ }).Count) { $player = Start-Sound $queue }

    $f.Tag = @{ Prayer = $prayer; Time = $time; Kind = $kind; Player = $player }
    $snooze.add_Click({
        $frm = $this.FindForm(); $d = $frm.Tag
        [void]$Snoozes.Add(@{ At = (Get-Date).AddMinutes([int]$Config.snoozeMinutes); Prayer = $d.Prayer; Time = $d.Time; Kind = $d.Kind })
        $frm.Close()
    })
    $dismiss.add_Click({ $this.FindForm().Close() })
    $f.add_FormClosed({
        $d = $this.Tag
        if ($d.Player) { try { $d.Player.controls.stop(); $d.Player.close() } catch {} }
        [void]$OpenPopups.Remove($this)
    })

    if ([int]$Config.autoCloseSeconds -gt 0) {
        $t = New-Object System.Windows.Forms.Timer
        $t.Interval = [int]$Config.autoCloseSeconds * 1000; $t.Tag = $f
        $t.add_Tick({ $this.Stop(); if (-not $this.Tag.IsDisposed) { $this.Tag.Close() }; $this.Dispose() })
        $t.Start()
    }

    [void]$OpenPopups.Add($f)
    $f.Show(); $f.Activate()
}

# ---- scheduler ------------------------------------------------------------
$script:Fired = @{}

function Invoke-Tick {
    $now = Get-Date
    if (($TimesDate -ne $now.Date -or $LastError) -and (-not $NextRetry -or $now -ge $NextRetry)) {
        if ($TimesDate -ne $now.Date) { $script:Fired = @{} }
        Update-Times -Relocate
    }
    Update-TrayText
    if ($Config.paused -or -not $Times) { return }

    $before = [int]$Config.remindBeforeMinutes
    foreach ($n in $Prayers) {
        if (-not $Config.prayers.$n.enabled) { continue }
        $t = $Times[$n]
        $day = '{0:yyyyMMdd}' -f $t
        if ($before -gt 0) {
            $key = "$day|$n|pre"
            if (-not $Fired[$key] -and $now -ge $t.AddMinutes(-$before) -and $now -lt $t) {
                $Fired[$key] = $true; Show-PrayerPopup $n $t 'pre'
            }
        }
        if ($Config.popupAtPrayerTime) {
            $key = "$day|$n|now"
            if (-not $Fired[$key] -and $now -ge $t -and $now -lt $t.AddMinutes(10)) {
                $Fired[$key] = $true; Show-PrayerPopup $n $t 'now'
            }
        }
    }
    foreach ($s in @($Snoozes)) {
        if ($now -ge $s.At) { [void]$Snoozes.Remove($s); Show-PrayerPopup $s.Prayer $s.Time $s.Kind }
    }
}

# ---- run at sign-in -------------------------------------------------------
# Two mechanisms: the MSIX build declares a startupTask in its manifest and toggles it
# through WinRT (a Startup-folder shortcut would be virtualised away inside the package);
# the plain build writes an ordinary shortcut.
$script:StartupTaskId = 'PrayerReminderStartup'

function Set-StartupTask([bool]$enable) {
    $null = [Windows.ApplicationModel.StartupTask,Windows.ApplicationModel,ContentType=WindowsRuntime]
    $task = Invoke-Async ([Windows.ApplicationModel.StartupTask]::GetAsync($StartupTaskId)) ([Windows.ApplicationModel.StartupTask])
    if ($enable) {
        if ("$($task.State)" -like 'Disabled*') { [void](Invoke-Async ($task.RequestEnableAsync()) ([Windows.ApplicationModel.StartupTaskState])) }
    } elseif ("$($task.State)" -like 'Enabled*') {
        $task.Disable()
    }
    Write-Log "Startup task state: $($task.State)"
    return "$($task.State)"
}

function Set-Startup([bool]$enable) {
    if (Test-Packaged) {
        $state = Set-StartupTask $enable
        # Windows lets the user veto this in Settings > Apps > Startup; respect that.
        if ($enable -and $state -eq 'DisabledByUser') {
            [System.Windows.Forms.MessageBox]::Show(
                "Windows has blocked Prayer Reminder from starting automatically.`n`nTurn it on in Settings > Apps > Startup.",
                'Prayer Reminder') | Out-Null
            $Config.startWithWindows = $false
            Save-Config
        }
        return
    }
    $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'Prayer Reminder.lnk'
    if ($enable) {
        $sh = New-Object -ComObject WScript.Shell
        $s = $sh.CreateShortcut($lnk)
        if ($IsExe) {
            $s.TargetPath = $HostExe
        } else {
            $s.TargetPath = "$env:WINDIR\System32\wscript.exe"
            $s.Arguments = '"' + (Join-Path $AppDir 'PrayerReminder.vbs') + '"'
        }
        $s.WorkingDirectory = $AppDir
        $s.Description = 'Prayer time reminders'
        $s.Save()
    } elseif (Test-Path $lnk) { Remove-Item $lnk -Force }
}

# ---- settings window ------------------------------------------------------
function Show-Settings {
    $F = New-Object System.Windows.Forms.Form
    $F.Text = 'Prayer Reminder - Settings'; $F.StartPosition = 'CenterScreen'
    $F.FormBorderStyle = 'FixedDialog'; $F.MaximizeBox = $false; $F.MinimizeBox = $false
    $F.ClientSize = New-Object System.Drawing.Size(520, 730); $F.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $F.TopMost = $true
    try { $F.Icon = $Tray.Icon } catch {}
    $script:S = @{}

    function Add-Ctl($ctl, $x, $y, $w, $h, $parent = $F) {
        $ctl.Location = New-Object System.Drawing.Point($x, $y)
        if ($w) { $ctl.Width = $w }; if ($h) { $ctl.Height = $h }
        $parent.Controls.Add($ctl); $ctl
    }
    function New-Label($text) { $l = New-Object System.Windows.Forms.Label; $l.Text = $text; $l.AutoSize = $true; $l }
    function New-Num($min, $max, $val) { $n = New-Object System.Windows.Forms.NumericUpDown; $n.Minimum = $min; $n.Maximum = $max; $n.Value = [decimal]$val; $n }

    # Location
    $g = Add-Ctl (New-Object System.Windows.Forms.GroupBox) 12 10 496 150
    $g.Text = 'Location'
    $S.Auto = Add-Ctl (New-Object System.Windows.Forms.RadioButton) 14 24 460 24 $g
    $S.Auto.Text = 'Detect automatically (Windows location, internet as fallback) - follows the laptop'
    $S.Manual = Add-Ctl (New-Object System.Windows.Forms.RadioButton) 14 50 200 24 $g
    $S.Manual.Text = 'Set manually'
    $S.Auto.Checked = ($Config.location.mode -ne 'manual'); $S.Manual.Checked = -not $S.Auto.Checked
    [void](Add-Ctl (New-Label 'City / label') 14 84 0 0 $g)
    $S.City = Add-Ctl (New-Object System.Windows.Forms.TextBox) 110 81 220 0 $g; $S.City.Text = $Config.location.city
    [void](Add-Ctl (New-Label 'Latitude') 14 116 0 0 $g)
    $S.Lat = Add-Ctl (New-Object System.Windows.Forms.TextBox) 110 113 90 0 $g
    [void](Add-Ctl (New-Label 'Longitude') 212 116 0 0 $g)
    $S.Lon = Add-Ctl (New-Object System.Windows.Forms.TextBox) 280 113 90 0 $g
    if ($null -ne $Config.location.latitude) {
        $S.Lat.Text = ([double]$Config.location.latitude).ToString($Inv); $S.Lon.Text = ([double]$Config.location.longitude).ToString($Inv)
    }
    $detect = Add-Ctl (New-Object System.Windows.Forms.Button) 380 80 100 58 $g; $detect.Text = 'Detect now'
    $detect.add_Click({
        $F.Cursor = 'WaitCursor'
        $loc = Find-Location
        $F.Cursor = 'Default'
        if ($loc) { $S.Lat.Text = $loc.lat.ToString($Inv); $S.Lon.Text = $loc.lon.ToString($Inv); $S.City.Text = $loc.city }
        else { [System.Windows.Forms.MessageBox]::Show('Could not detect location.', 'Prayer Reminder') | Out-Null }
    })

    # Calculation
    [void](Add-Ctl (New-Label 'Calculation method') 14 176)
    $S.Method = Add-Ctl (New-Object System.Windows.Forms.ComboBox) 160 172 348
    $S.Method.DropDownStyle = 'DropDownList'
    # Enumerate rather than index: an ordered dictionary treats $Methods[3] as position 3, not key 3.
    foreach ($m in $Methods.GetEnumerator()) {
        [void]$S.Method.Items.Add("$($m.Key) - $($m.Value)")
        if ([int]$m.Key -eq [int]$Config.method) { $S.Method.SelectedIndex = $S.Method.Items.Count - 1 }
    }
    if ($S.Method.SelectedIndex -lt 0) { $S.Method.SelectedIndex = 0 }
    [void](Add-Ctl (New-Label 'Asr calculation') 14 210)
    $S.School = Add-Ctl (New-Object System.Windows.Forms.ComboBox) 160 206 348
    $S.School.DropDownStyle = 'DropDownList'
    [void]$S.School.Items.AddRange(@('Standard (Shafi, Maliki, Hanbali)', 'Hanafi'))
    $S.School.SelectedIndex = [int]$Config.school

    # Prayers
    $gp = Add-Ctl (New-Object System.Windows.Forms.GroupBox) 12 242 496 128
    $gp.Text = 'Prayers to remind  (adjust = +/- minutes to fine-tune vs. your local mosque)'
    $S.Chk = @{}; $S.Off = @{}
    $i = 0
    foreach ($n in $Prayers) {
        $col = [math]::Floor($i / 3); $row = $i % 3
        $x = 14 + $col * 244; $y = 26 + $row * 32
        $c = Add-Ctl (New-Object System.Windows.Forms.CheckBox) $x $y 140 24 $gp
        $c.Text = "$n  $($Arabic[$n])"; $c.Checked = [bool]$Config.prayers.$n.enabled
        $S.Chk[$n] = $c
        $S.Off[$n] = Add-Ctl (New-Num -30 30 $Config.prayers.$n.offsetMinutes) ($x + 150) $y 60 0 $gp
        $i++
    }

    # Reminder behaviour
    [void](Add-Ctl (New-Label 'Remind me before prayer (minutes, 0 = off)') 14 386)
    $S.Before = Add-Ctl (New-Num 0 120 $Config.remindBeforeMinutes) 420 383 88
    $S.AtTime = Add-Ctl (New-Object System.Windows.Forms.CheckBox) 14 414 494 24
    $S.AtTime.Text = 'Also pop up exactly at prayer time'; $S.AtTime.Checked = [bool]$Config.popupAtPrayerTime
    [void](Add-Ctl (New-Label 'Snooze length (minutes)') 14 448)
    $S.Snooze = Add-Ctl (New-Num 1 60 $Config.snoozeMinutes) 420 445 88
    [void](Add-Ctl (New-Label 'Auto-close popup after (seconds, 0 = stay until dismissed)') 14 480)
    $S.AutoClose = Add-Ctl (New-Num 0 3600 $Config.autoCloseSeconds) 420 477 88

    $S.Sound = Add-Ctl (New-Object System.Windows.Forms.CheckBox) 14 512 494 24
    $S.Sound.Text = 'Play sound'; $S.Sound.Checked = [bool]$Config.playSound
    $audioFilter = 'Audio (*.mp3;*.wav;*.wma;*.m4a)|*.mp3;*.wav;*.wma;*.m4a|All files|*.*'

    [void](Add-Ctl (New-Label 'Reminder sound') 14 544)
    $S.Tone = Add-Ctl (New-Object System.Windows.Forms.ComboBox) 150 541 186
    $S.Tone.DropDownStyle = 'DropDown'
    if (Test-Path $SoundsDir) { foreach ($f in Get-ChildItem $SoundsDir -Include *.mp3,*.wav -File) { [void]$S.Tone.Items.Add($f.Name) } }
    foreach ($n in $BuiltInSounds) { if (Test-Path (Join-Path $MediaDir "$n.wav")) { [void]$S.Tone.Items.Add($n) } }
    $S.Tone.Text = $Config.reminderSound
    $play = Add-Ctl (New-Object System.Windows.Forms.Button) 342 540 78 26; $play.Text = 'Play'
    $play.add_Click({
        if ($script:Preview) { try { $script:Preview.controls.stop() } catch {} }
        $f = Resolve-SoundPath $S.Tone.Text
        if (-not $f) { [System.Windows.Forms.MessageBox]::Show('Sound not found. Pick one from the list or Browse to a file.', 'Prayer Reminder') | Out-Null; return }
        $script:Preview = Start-Sound $f
    })
    $browseTone = Add-Ctl (New-Object System.Windows.Forms.Button) 428 540 80 26; $browseTone.Text = 'Browse...'
    $browseTone.add_Click({
        $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Filter = $audioFilter
        if ($d.ShowDialog() -eq 'OK') { $S.Tone.Text = $d.FileName }
    })

    [void](Add-Ctl (New-Label 'Adhan at prayer time (optional)') 14 578)
    $S.Adhan = Add-Ctl (New-Object System.Windows.Forms.TextBox) 214 575 206; $S.Adhan.Text = $Config.adhanFile
    $browse = Add-Ctl (New-Object System.Windows.Forms.Button) 428 574 80 26; $browse.Text = 'Browse...'
    $browse.add_Click({
        $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Filter = $audioFilter
        if ($d.ShowDialog() -eq 'OK') { $S.Adhan.Text = $d.FileName }
    })
    $hint = Add-Ctl (New-Label 'Leave Adhan empty to use the reminder sound at prayer time too.') 14 602
    $hint.ForeColor = [System.Drawing.Color]::Gray

    $S.Speak = Add-Ctl (New-Object System.Windows.Forms.CheckBox) 14 626 494 24
    $S.Speak.Text = 'Speak the reminder aloud  (Arabic if an Arabic voice is installed)'; $S.Speak.Checked = [bool]$Config.speakReminder

    $S.Startup = Add-Ctl (New-Object System.Windows.Forms.CheckBox) 14 652 494 24
    $S.Startup.Text = 'Start automatically when I sign in to Windows'; $S.Startup.Checked = [bool]$Config.startWithWindows

    $ok = Add-Ctl (New-Object System.Windows.Forms.Button) 316 688 90 30; $ok.Text = 'Save'
    $cancel = Add-Ctl (New-Object System.Windows.Forms.Button) 418 688 90 30; $cancel.Text = 'Cancel'
    $F.AcceptButton = $ok; $F.CancelButton = $cancel
    $F.add_FormClosed({ if ($script:Preview) { try { $script:Preview.controls.stop() } catch {}; $script:Preview = $null } })
    $cancel.add_Click({ $F.Close() })
    $ok.add_Click({
        $lat = 0.0; $lon = 0.0
        $hasCoords = [double]::TryParse($S.Lat.Text.Trim(), [Globalization.NumberStyles]::Float, $Inv, [ref]$lat) -and
                     [double]::TryParse($S.Lon.Text.Trim(), [Globalization.NumberStyles]::Float, $Inv, [ref]$lon) -and
                     [math]::Abs($lat) -le 90 -and [math]::Abs($lon) -le 180
        if ($S.Manual.Checked -and -not $hasCoords) {
            [System.Windows.Forms.MessageBox]::Show('Enter a valid latitude (-90..90) and longitude (-180..180), e.g. 30.0444 and 31.2357 for Cairo.', 'Prayer Reminder') | Out-Null
            return
        }
        $Config.location.mode = if ($S.Manual.Checked) { 'manual' } else { 'auto' }
        $Config.location.city = $S.City.Text.Trim()
        if ($hasCoords) { $Config.location.latitude = $lat; $Config.location.longitude = $lon }
        $Config.method = [int](($S.Method.SelectedItem -split ' ')[0])
        $Config.school = $S.School.SelectedIndex
        foreach ($n in $Prayers) { $Config.prayers.$n.enabled = $S.Chk[$n].Checked; $Config.prayers.$n.offsetMinutes = [int]$S.Off[$n].Value }
        $Config.remindBeforeMinutes = [int]$S.Before.Value
        $Config.popupAtPrayerTime   = $S.AtTime.Checked
        $Config.snoozeMinutes       = [int]$S.Snooze.Value
        $Config.autoCloseSeconds    = [int]$S.AutoClose.Value
        $Config.playSound           = $S.Sound.Checked
        $Config.reminderSound       = $S.Tone.Text.Trim()
        $Config.speakReminder       = $S.Speak.Checked
        $Config.adhanFile           = $S.Adhan.Text.Trim()
        $Config.startWithWindows    = $S.Startup.Checked
        Save-Config
        try { Set-Startup $Config.startWithWindows } catch { Write-Log "Startup shortcut failed: $_" }
        $script:Fired = @{}
        $F.Cursor = 'WaitCursor'
        Update-Times
        $F.Cursor = 'Default'
        if ($LastError) { [System.Windows.Forms.MessageBox]::Show("Saved, but prayer times could not be loaded:`n$LastError", 'Prayer Reminder') | Out-Null }
        $F.Close()
    })
    [void]$F.ShowDialog()
    $F.Dispose()
}

# ---- tray -----------------------------------------------------------------
function New-TrayIcon {
    $ico = Join-Path $AppDir 'app.ico'
    if (Test-Path $ico) { try { return New-Object System.Drawing.Icon $ico } catch {} }
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(16, 58, 46))), 0, 0, 31, 31)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(233, 195, 100))), 5, 5, 22, 22)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(16, 58, 46))), 11, 3, 20, 20)
    $g.Dispose()
    [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}

function Update-TrayText {
    if (-not $Tray) { return }
    $txt = if ($LastError -and -not $Times) { 'Prayer Reminder - error, see menu' }
    elseif ($Config.paused) { 'Prayer Reminder - paused' }
    else {
        $np = Get-NextPrayer
        if ($np) {
            $span = $np.Time - (Get-Date)
            'Next: {0} {1:HH:mm} (in {2}h {3}m)' -f $np.Name, $np.Time, [int][math]::Floor($span.TotalHours), $span.Minutes
        } else { 'Prayer Reminder' }
    }
    $Tray.Text = $txt.Substring(0, [math]::Min(63, $txt.Length))
}

function Show-TodayBalloon {
    if (-not $Times) { $Tray.ShowBalloonTip(5000, 'Prayer Reminder', "Times not loaded: $LastError", 'Warning'); return }
    $lines = foreach ($n in $Prayers) { '{0,-8} {1:HH:mm}' -f $n, $Times[$n] }
    $Tray.ShowBalloonTip(8000, "Today - $($Config.location.city)", ($lines -join "`n"), 'Info')
}

function Update-Menu {
    $m = $Tray.ContextMenuStrip
    $m.Items.Clear()
    $head = $m.Items.Add("Prayer times - $($Config.location.city)"); $head.Enabled = $false
    if ($Times) {
        $np = Get-NextPrayer
        foreach ($n in $Prayers) {
            $mark = if (-not $Config.prayers.$n.enabled) { '   (off)' } else { '' }
            $it = $m.Items.Add(("{0}   {1}   {2:HH:mm}{3}" -f $n, $Arabic[$n], $Times[$n], $mark))
            if ($np -and $np.Name -eq $n -and $np.Time.Date -eq $Times[$n].Date) { $it.Font = New-Object System.Drawing.Font($it.Font, [System.Drawing.FontStyle]::Bold) }
        }
    } else {
        $e = $m.Items.Add("Error: $LastError"); $e.Enabled = $false
    }
    [void]$m.Items.Add('-')
    $m.Items.Add('Settings...').add_Click({ Show-Settings })
    $m.Items.Add('Refresh times / location').add_Click({ Update-Times -Relocate; Show-TodayBalloon })
    $m.Items.Add('Test popup').add_Click({
        $np = Get-NextPrayer
        if ($np) { Show-PrayerPopup $np.Name $np.Time 'pre' } else { Show-PrayerPopup 'Dhuhr' (Get-Date).AddMinutes(10) 'pre' }
    })
    $p = $m.Items.Add('Pause reminders'); $p.Checked = [bool]$Config.paused
    $p.add_Click({ $Config.paused = -not $Config.paused; Save-Config; Update-TrayText })
    $m.Items.Add('Open settings folder').add_Click({ Start-Process explorer.exe $DataDir })
    [void]$m.Items.Add('-')
    $m.Items.Add('Exit').add_Click({
        $Tray.Visible = $false; $Timer.Stop()
        [System.Windows.Forms.Application]::Exit()
    })
}

# ---- main -----------------------------------------------------------------
if ($NoRun) { return }

Write-Log "Starting (app: $AppDir)"
Import-Config
try { Set-Startup ([bool]$Config.startWithWindows) } catch { Write-Log "Startup shortcut failed: $_" }

$script:Tray = New-Object System.Windows.Forms.NotifyIcon
$Tray.Icon = New-TrayIcon
$Tray.Text = 'Prayer Reminder'
$Tray.ContextMenuStrip = New-Object System.Windows.Forms.ContextMenuStrip
$Tray.ContextMenuStrip.add_Opening({ Update-Menu })
$Tray.add_MouseDoubleClick({ Show-TodayBalloon })
$Tray.Visible = $true

Update-Times -Relocate
Update-Menu

# Timer first, so reminders still fire while the Settings window is open.
$script:Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 15000
$Timer.add_Tick({ try { Invoke-Tick } catch { Write-Log "Tick error: $_" } })
$Timer.Start()
Invoke-Tick

if ($Settings -or $FirstRun) { Show-Settings }
else { $Tray.ShowBalloonTip(6000, 'Prayer Reminder is running', "Location: $($Config.location.city). Right-click the tray icon for times and settings.", 'Info') }

[System.Windows.Forms.Application]::Run()
$Tray.Dispose()
$Mutex.ReleaseMutex()
Write-Log 'Stopped'
