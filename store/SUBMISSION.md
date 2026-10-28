# Submitting Prayer Reminder to the Microsoft Store

**Status: live. Submitted 26 October 2026, passed certification and published 28 October 2026.**

| | |
|---|---|
| Store listing | <https://apps.microsoft.com/detail/9N0PNDJPZ6ZX> |
| Store ID | `9N0PNDJPZ6ZX` |
| Dashboard | <https://partner.microsoft.com/dashboard/products/9N0PNDJPZ6ZX/overview> |
| Package published | `dist\PrayerReminder-1.1.0.0.msix` (358 KB, unsigned — the Store signed it) |

Certification passed first time, including the malware scan that the PS2EXE executable was
expected to trip. The pre-emptive explanation in **Additional Testing Information** may be
why; keep it there on future submissions.

Steps 1 to 5 below are a record of what was done, kept because you repeat most of
them for every update. The part worth reading before your next submission is
[Things that will trip you up](#things-that-will-trip-you-up) at the end — none of
it is obvious from Microsoft's own documentation.

---

## Step 1 — Create the developer account (free) ✅

1. Go to **<https://storedeveloper.microsoft.com>**
2. Click **Get started for free**
3. Choose **Individual developer**
   - Individual is the right choice: publishing under your own name, not a registered business.
   - You cannot convert Individual → Company later, so pick Company now if this is a business.
4. Sign in with your Microsoft account (or create one)
5. **Identity verification**: you photograph a government-issued ID (passport or national ID)
   and take a selfie. Easiest on your phone, in good light.

There is **no registration fee**. Microsoft removed it for individual developers in
September 2025.

## Step 2 — Reserve the app name ✅

Reserved as:

```
مذّكر الصلاة - Prayer Reminder
```

Bilingual on purpose — Arabic speakers find it by name, everyone else by keyword.

> The shadda sits on the ذ because that is how the name was reserved. Strictly it
> belongs on the ك: مُذكِّر. `DisplayName` in `build/msix.json` must match the reserved
> name character for character, so do not "fix" one without reserving the other first.

## Step 3 — Copy your identity values into the build ✅

Partner Center → your product → **Product management → Product identity**:

| Partner Center shows | `build/msix.json` key | Value |
|---|---|---|
| Package/Identity/Name | `IdentityName` | `YoussefRamzy.620211EF6810F` |
| Package/Identity/Publisher | `Publisher` | `CN=21176712-4313-4D40-B18F-F89B43F9D474` |
| Package/Properties/PublisherDisplayName | `PublisherDisplayName` | `Youssef Ramzy` |

These three are public — they are embedded in every published MSIX and shown on the
listing — so they are committed to the repo to keep the build reproducible.

## Step 4 — Build the package ✅

```powershell
cd C:\Users\user\Projects\prayer-reminder
.\build\build-msix.ps1
```

Do **not** sign it. The Store signs it with a Microsoft certificate during certification —
that is why MSIX costs nothing, while an .exe/.msi submission would require buying a code
signing certificate.

Verify before uploading, by codepoint rather than by eye — PowerShell 5.1 will happily
mangle the Arabic `DisplayName` into mojibake if anything reads `msix.json` without
`-Encoding UTF8`:

```powershell
# expect 1605,1584,1617,1603,1585 - the 1617 is the shadda
[int[]][char[]]'مذّكر'
```

## Step 5 — Fill in the submission ✅

What went into each section. The copy itself lives in [`listing.md`](listing.md).

| Section | What was set |
|---|---|
| **Packages** | `PrayerReminder-1.1.0.0.msix`. Validated; Windows 10/11 Desktop auto-selected, rank 1, min version 10.0.17763.0 |
| **Pricing and availability** | Base price currency **USD – United States**, retail price **0**. Markets: all 240. Visibility: Public. Release: as soon as possible |
| **Properties** | Category **Lifestyle**. Privacy policy `https://github.com/YRamzy993/prayer-reminder/blob/main/PRIVACY.md`. Website and support URLs set. Phone and postal address left blank — optional, and personal data |
| **Age ratings** | IARC questionnaire, app type **All Other App Types**, **No** to every content question. Result: IARC 3+, PEGI 3, ESRB Everyone, USK 0, All ages elsewhere |
| **Store listings** | English and العربية. Description, what's new, product features, screenshots, 300×300 app tile icon, keywords, copyright, licence terms |
| **Submission options** | Publish as soon as it passes certification. **runFullTrust justification** — see below |
| **Additional Testing Information** | Notes for certification: how to reach the tray menu, that "Test popup" shows the reminder without waiting, that no sign-in is needed, what the app talks to over the network, and that the PS2EXE executable may trip an automated scanner |

## Step 6 — Certification

- Usually a few hours, up to **3 business days**
- You get an email either way; failures list the exact policy and how to fix it
- It publishes automatically on success

### If certification fails

The most likely reason for this app is the **malware/AV scan**. The executable is a
PowerShell script compiled with PS2EXE, and some scanners treat that pattern as suspicious.
This is pre-empted in the certification notes, but if the rejection mentions malware, a
false positive, or the scan, the fix is to rebuild the app as a plain C# program, which
removes the pattern entirely. It is a mechanical rewrite of the same logic.

---

## Things that will trip you up

Everything here cost real time on the first submission.

### runFullTrust needs a written justification, and it is capped at 500 characters

Uploading the package raises *"Package acceptance validation warning: the following
restricted capabilities require approval: runFullTrust"*. The justification box is on
**Submission options**, not on the Packages page, and the submission cannot be completed
until it is filled.

The cap is **500 characters**, which is not stated until you try to save — a longer answer
is rejected with `(1771/500)` and the Save silently does nothing. What is there now:

> Prayer Reminder is a Win32 desktop app packaged as MSIX, not UWP, so runFullTrust is
> required to run. It is used only for: a Windows Forms system-tray icon and context menu
> showing today's prayer times; borderless popup reminder windows; reading/writing the
> user's own settings and cached prayer times in %APPDATA%; playing a bundled takbeer clip
> or an audio file the user picks; and the Windows speech synthesizer. No elevation,
> drivers or services. Source: github.com/YRamzy993/prayer-reminder

Put the long version in **Additional Testing Information** instead, which has room.

### "You must configure a price" on a free app

Pricing and availability opens with two errors — *"No PriceSchedule created"* and *"You must
configure a price"* — even though the app is free. You have to pick a **Currency** first
(the Retail price dropdown stays disabled until you do), then choose **0** from Retail price.
There is no "Free" option; 0 is the first entry in the price list.

The currency filter matches the **currency code only**. Typing "United States" finds nothing;
type `USD` and then pick United States from the list.

### Keywords are silently rejected

Partner Center refuses some typed keywords with no error at all — the text vanishes and no
tag appears. `salah`, `islamic`, `muslim`, `أذان` and `مواقيت الصلاة` were all refused;
`prayer times`, `athan`, `adhan` and `namaz` were accepted. There is no visible rule.

Two things help: wait for the AI suggestion dropdown to finish loading before pressing Enter
(pressing it too early loses the word), and take keywords from that dropdown, which are always
accepted. The current sets are 7 English and 5 Arabic.

Do not pad the list with terms the app does not deliver. `قبلة` (qibla) and `إمساكية` were in
the original draft and were dropped — there is no qibla compass and no Ramadan timetable, and
keywords for features you do not ship are a certification-policy risk.

### Screenshots upload one at a time

Passing three files to the screenshot picker in one go uploads only the first, with no error.
Upload them individually and wait for each thumbnail to appear.

### You do not need to "add a language" for Arabic

The package manifest already declares Arabic and English, so both listings are waiting under
**Store listings** from the start. The "Manage additional languages" button is for languages
the package does not declare.

### The IARC terms checkbox is yours to tick

The last thing in Age ratings is a box agreeing to the IARC Terms of Use and attesting that
you are of the age of majority in your jurisdiction. It is a personal legal statement, so it
has to be you who ticks it. Nothing else in the section can be saved until it is.

### The packaged build reads the real `%APPDATA%`, so settings survive

Verified on 28 October 2026 by uninstalling the Inno build and installing from the Store:
`%APPDATA%\PrayerReminder\config.json` was picked up unchanged, method and all. Desktop-bridge
AppData redirection does not apply here, so users moving from the installer to the Store keep
their settings.

What does **not** survive is anything the user dropped into the app's own `sounds\` folder.
That folder lives inside the install directory, which the uninstaller deletes and which is
read-only once the app comes from the Store. `Resolve-SoundPath` only looks in `sounds\` and
`%WINDIR%\Media`, so a `reminderSound` pointing at a custom file silently falls back to a
Windows beep. Custom audio has to go in the **Adhan** field instead, which takes an absolute
path anywhere on disk — at the cost of playing on time rather than at the early reminder.

### Store logos are optional

The **Store logos** and **Store display images** blocks on the listing page can all be left
empty — by default the Store uses the logo images from the package, and the package carries
all 22 sizes. The 300×300 app tile icon is uploaded anyway because it is the one customers
on Windows 10/11 actually see.

---

## Updating later

1. Bump the version in `build/msix.json` (keep the last part `.0`, e.g. `1.1.1.0`)
2. `.\build\build-msix.ps1`
3. Partner Center → your product → **Update** → upload the new `.msix`
4. Re-check **Submission options**: the runFullTrust justification has to be present on
   every submission, not just the first
5. Update **What's new in this version** in both listings — it still says "First release."
6. Submit
