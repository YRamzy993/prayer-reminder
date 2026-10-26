# Submitting Prayer Reminder to the Microsoft Store

Everything on the build side is done. This is the part only you can do — it needs your
Microsoft account and a photo ID.

Budget about **45 minutes** of your time, then 24–48 hours of waiting for certification.

---

## Step 1 — Create the developer account (free)

1. Go to **<https://storedeveloper.microsoft.com>**
2. Click **Get started for free**
3. Choose **Individual developer**
   - Individual is the right choice: publishing under your own name, not a registered business.
   - You cannot convert Individual → Company later, so pick Company now if this is a business.
4. Sign in with your Microsoft account (or create one)
5. **Identity verification**: you photograph a government-issued ID (passport or national ID)
   and take a selfie. Easiest on your phone, in good light.
6. Wait for verification — usually minutes, sometimes a day.

There is **no registration fee**. Microsoft removed it for individual developers in
September 2025.

## Step 2 — Reserve the app name

1. In [Partner Center](https://partner.microsoft.com/dashboard), open **Apps and games**
2. **New product → MSIX or PWA app**
3. Reserve this exact name:

   ```
   مذكر الصلاة - Prayer Reminder
   ```

   Bilingual on purpose — Arabic speakers find it by name, everyone else by keyword.
   It is already set as `DisplayName` in `build/msix.json`.

> ⚠️ If that name is taken, reserve one of these and change `DisplayName` in
> `build/msix.json` to match exactly: **مذكر الصلاة - Salah Reminder**,
> **مواقيت الصلاة - Prayer Times Reminder**, **Minaret - Prayer Times & Reminders**.
> Plain "Prayer Reminder" on its own is very likely already reserved.

## Step 3 — Copy your identity values into the build

1. In Partner Center, open your product → **Product management → Product identity**
2. Copy these three values:

   | Partner Center shows | Put it in `build/msix.json` as |
   |---|---|
   | Package/Identity/Name | `IdentityName` |
   | Package/Identity/Publisher | `Publisher` |
   | Package/Properties/PublisherDisplayName | `PublisherDisplayName` |

3. Edit [`build/msix.json`](../build/msix.json) and replace the three `REPLACE...` placeholders.
   They must match **character for character**, including the `CN=` prefix.

## Step 4 — Build the package to upload

```powershell
cd C:\Users\user\Projects\prayer-reminder
.\build\build-msix.ps1
```

This produces **`dist\PrayerReminder-1.0.0.0.msix`**.

Do **not** sign it. The Store signs it with a Microsoft certificate during certification —
that is why MSIX costs nothing, while an .exe/.msi submission would require buying a code
signing certificate.

## Step 5 — Fill in the submission

In Partner Center, your product has these sections. Everything you need to paste is in
[`listing.md`](listing.md).

| Section | What to do |
|---|---|
| **Pricing and availability** | Price: **Free**. Markets: **All**. Visibility: **Public**. |
| **Properties** | Category: **Lifestyle**. Privacy policy URL (required — the app uses your location): `https://github.com/YRamzy993/prayer-reminder/blob/main/PRIVACY.md`. Support contact: `https://github.com/YRamzy993/prayer-reminder/issues` |
| **Age ratings** | Fill in the IARC questionnaire. Answer **No** to every content question — no violence, no user-to-user communication, no purchases, no personal data shared. You'll get a 3+/Everyone rating. |
| **Packages** | Upload `dist\PrayerReminder-1.0.0.0.msix` |
| **Store listings (English)** | Paste the text from [`listing.md`](listing.md), upload the three screenshots from `assets/store-screenshots/`, and the 300×300 icon from `assets/msix/StoreListing-300x300.png` |
| **Store listings (العربية)** | Add Arabic as a second language and paste the Arabic block from [`listing.md`](listing.md). Same screenshots. Worth the five minutes — it is how Arabic speakers will find the app. |
| **Submission options** | Leave the defaults |

Then click **Submit to the Store**.

## Step 6 — Certification

- Usually **24–48 hours**
- You get an email either way; failures list the exact policy and how to fix it
- Once it passes, your Store link is `https://apps.microsoft.com/detail/<your-product-id>`

### If certification fails

The most likely reason for this app is the **malware/AV scan**. The executable is a
PowerShell script compiled with PS2EXE, and some scanners treat that pattern as suspicious.
If the rejection mentions malware, a false positive, or the scan, say so — the fix is to
rebuild the app as a plain C# program, which removes the pattern entirely. It is a
mechanical rewrite of the same logic.

## Updating later

1. Bump the version in `build/msix.json` (keep the last part `.0`, e.g. `1.0.1.0`)
2. `.\build\build-msix.ps1`
3. Partner Center → your product → **Update** → upload the new `.msix` → Submit

---

## What was already done for you

- MSIX manifest with the correct capabilities (`runFullTrust`, `internetClient`, `location`)
- Run-at-sign-in converted to a declared `startupTask` — a Startup-folder shortcut is
  virtualised inside a package and would silently never run
- All 22 Store logo sizes, including the unplated taskbar variants
- Three 1920×1080 screenshots rendered from the app's real windows
- A privacy policy, which the Store requires for any app that uses location
- Listing copy, category and age-rating answers
