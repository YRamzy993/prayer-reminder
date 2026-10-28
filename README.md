# Prayer Reminder

**English** · [العربية](README.ar.md)

A small Windows tray app that reminds you before each prayer, using prayer times for
wherever your laptop actually is.

No account, no ads, no telemetry. It downloads a month of prayer times at a time, so it
keeps reminding you even with no internet.

## Download

[<img src="https://get.microsoft.com/images/en-us%20dark.svg" height="48" alt="Get it from the Microsoft Store">](https://apps.microsoft.com/detail/9N0PNDJPZ6ZX)

Or from a terminal:

```powershell
winget install --id 9N0PNDJPZ6ZX --source msstore
```

The Store build is signed by Microsoft, so there is no warning screen, and it updates itself.
That is the recommended way in.

<details>
<summary>Prefer a plain installer, or no Store account?</summary>

**[⬇ Download the installer](../../releases/latest)** — `PrayerReminder-Setup-x.y.z.exe`

Per-user install, so Windows does not ask for administrator rights.

> Windows shows a blue "Windows protected your PC" screen, because this installer is not
> code-signed (a certificate costs a few hundred dollars a year). Click **More info →
> Run anyway**, or build it from source with the steps below. The Store build does not have
> this problem — Microsoft signs it.

</details>

Either way you're done once it runs: the app lands in your tray and starts with Windows.

## What it does

- 🕌 A popup before each prayer (15 minutes by default) and another at the exact time
- 🌍 Full **Arabic** and English interface — right-to-left, following your Windows language
- 🔊 Plays a takbeer, a Windows sound, or any audio file you choose
- 🗣️ Optionally says the reminder aloud, in Arabic when an Arabic voice is installed
- 📍 Finds your location automatically and follows the laptop when you travel
- 💤 Snooze or dismiss, with an optional auto-close
- 📴 Works offline from a cached month of times
- ⏸️ Pause whenever you need to

Right-click the tray icon for today's times, **Settings**, **Test popup**, **Pause** and
**Exit**. Hover over it to see the next prayer and how long until it.

## Settings

Everything is in one window: right-click the tray icon → **Settings…**

| Setting | Notes |
|---|---|
| Location | Automatic (follows the laptop) or manual latitude/longitude |
| Calculation method | 23 methods — Muslim World League, Egyptian, Umm Al-Qura, ISNA, Karachi, Diyanet, JAKIM… |
| Asr calculation | Standard (Shafi, Maliki, Hanbali) or Hanafi |
| Prayers | Which ones remind you, plus a ±30 minute adjustment each to match your local mosque |
| Remind before | Minutes before the prayer, or 0 to turn the early reminder off |
| At prayer time | A second popup exactly on time |
| Snooze / auto-close | Snooze length, and whether the popup closes by itself |
| Reminder sound | The bundled takbeer, any Windows sound, or your own mp3/wav — with a **Play** button |
| Adhan at prayer time | Optional full Adhan file, used only for the on-time popup |
| Speak aloud | Says which prayer it is, in Arabic if available |
| Start with Windows | On by default |
| Language | Automatic (follows Windows), العربية, or English |

### Arabic voice

The spoken reminder uses English until you add an Arabic voice:
**Settings → Time & language → Speech → Add voices → Arabic**. Then it says
*«باقي ١٥ دقيقة على صلاة العصر»* instead of the English line.

### Your own Adhan

The app ships with a short public-domain takbeer. To use a particular reciter, put the file
anywhere on your PC and pick it in Settings — as the **Reminder sound** for a short clip, or
as the **Adhan** for the full call at prayer time. Please use a copy you are allowed to use;
none is bundled.

## Where your settings live

```
%APPDATA%\PrayerReminder\config.json   settings
%APPDATA%\PrayerReminder\cache\        cached prayer times + spoken clips
%APPDATA%\PrayerReminder\prayer-reminder.log
```

Uninstalling leaves `config.json` in place, so reinstalling keeps your settings. Delete that
folder for a clean slate.

## Prayer times

Times come from the [Aladhan API](https://aladhan.com/prayer-times-api), which uses the
standard astronomical calculations. **Check the first day against your local mosque** —
if it differs, adjust the method, the Asr school, or the per-prayer ± minutes until it matches.
Minor differences between mosques are normal.

## Run from source

No build needed — PowerShell 5.1 ships with Windows 10 and 11:

```powershell
git clone https://github.com/YRamzy993/prayer-reminder
cd prayer-reminder
wscript src\PrayerReminder.vbs
```

## Build it yourself

```powershell
Install-Module ps2exe -Scope CurrentUser
winget install JRSoftware.InnoSetup

.\build\build.ps1 -Version 1.0.0        # dist\PrayerReminder.exe + the installer
.\build\build-msix.ps1                  # dist\*.msix, unsigned, for the Store to sign
.\build\build-msix.ps1 -SelfSign        # the same, self-signed, to install and test locally
.\build\make-screenshots.ps1            # Store screenshots, rendered from the real UI
.\build\make-screenshots.ps1 -Lang ar   # the same, in Arabic (RTL)
```

`build-msix.ps1` downloads the ~22 MB Windows SDK build tools from nuget.org on first run,
rather than requiring the full SDK. Store submission details are in
[store/SUBMISSION.md](store/SUBMISSION.md).

## Privacy

No account, no ads, no analytics. Your settings stay on your PC; your coordinates are sent
only to the prayer-time and geocoding services that calculate the times. Full detail in
[PRIVACY.md](PRIVACY.md).

## Credits and licence

Code is MIT licensed — see [LICENSE](LICENSE). The bundled sound and the prayer-time API are
credited in [CREDITS.md](CREDITS.md).
