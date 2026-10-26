# Store listing copy

Paste each block into the matching field in Partner Center → **Store listings → English**.

---

## Product name (must match the reserved name)

```
مذّكر الصلاة - Prayer Reminder
```

Bilingual on purpose: Arabic speakers find it by name, everyone else finds it by keyword.
Reserve this exact string in Partner Center, and keep `DisplayName` in `build/msix.json`
identical to it.

> This is the name reserved in Partner Center, so the manifest's `DisplayName` must match it
> character for character — including the shadda on the ذ. (Strictly, the shadda belongs on
> the ك: مُذكِّر. To switch, reserve the corrected name as a second name for the same product,
> make it the product name, then change `DisplayName` in `build/msix.json` to match.)

## Short description (max 1000 characters)

```
A quiet desktop reminder before every prayer, using accurate prayer times for wherever your PC is. No account, no ads, no tracking - and it works offline.
```

## Description (max 10,000 characters)

```
Prayer Reminder sits quietly in your system tray and reminds you before each prayer, so a deadline or a long meeting doesn't make you miss one.

A small popup appears a few minutes before the prayer, and again at the exact time. Snooze it, dismiss it, or let it close by itself.

WHAT IT DOES

• Reminds you before Fajr, Dhuhr, Asr, Maghrib and Isha - 15 minutes ahead by default, or any gap you choose
• Pops up again at the exact prayer time
• Plays a short takbeer, a Windows sound, or any audio file you choose - including your own Adhan recording
• Full Arabic interface, right-to-left, following your Windows language or set by hand
• Can speak the reminder aloud, in Arabic when an Arabic voice is installed in Windows
• Finds your location automatically and follows your laptop when you travel, or set your coordinates by hand
• Shows today's times, and the time remaining until the next prayer, right from the tray icon
• Pause reminders whenever you need to

ACCURATE, AND ADJUSTABLE

Prayer times come from the Aladhan API, using standard astronomical calculation. You choose:

• 23 calculation methods, including Muslim World League, Egyptian General Authority, Umm Al-Qura (Makkah), ISNA, Karachi, Diyanet, JAKIM and Kemenag
• Standard (Shafi, Maliki, Hanbali) or Hanafi calculation for Asr
• A separate adjustment of up to 30 minutes for each prayer, so you can match your local mosque exactly

WORKS OFFLINE

A whole month of prayer times is downloaded at once and stored on your PC, so reminders keep arriving when you have no internet.

PRIVATE BY DESIGN

No account. No advertising. No analytics. No tracking of any kind. Your settings never leave your PC, and your location is used only to calculate your prayer times.

FREE AND OPEN SOURCE

The complete source code is public under the MIT licence:
https://github.com/YRamzy993/prayer-reminder

Please check the first day's times against your local mosque and use the per-prayer adjustment if they differ - small differences between mosques are normal.
```

## What's new in this version

```
First release.
```

## Product features (up to 20, short bullets)

```
Popup reminder before every prayer
A second popup at the exact prayer time
Takbeer, Windows sound, or your own Adhan file
Full Arabic interface, right-to-left
Spoken reminder, in Arabic when available
Automatic location that follows your laptop
23 calculation methods and Hanafi or Standard Asr
Per-prayer adjustment to match your local mosque
Today's times from the tray icon
Snooze, dismiss, or auto-close
Works offline with a cached month of times
No account, no ads, no tracking
Free and open source
```

## Search terms (up to 7, not shown to users)

```
prayer times
salah
athan
adhan
namaz
islamic
muslim
```

## Copyright and trademark info

```
© 2026 YRamzy993. MIT licensed.
```

## Additional licence terms

```
MIT License - https://github.com/YRamzy993/prayer-reminder/blob/main/LICENSE
```

---

# Arabic listing (add a second Store listing, language: العربية)

In Partner Center → **Store listings** → **Add a language** → Arabic, then paste these.

## اسم المنتج

```
مذّكر الصلاة - Prayer Reminder
```

## الوصف المختصر

```
تذكير هادئ بمواقيت الصلاة على حاسوبك، محسوبة لمكانك أنت. بلا حساب ولا إعلانات ولا تتبع، ويعمل بدون إنترنت.
```

## الوصف

```
يعمل «مذّكر الصلاة» بهدوء في شريط المهام، وينبّهك قبل كل صلاة حتى لا يفوتك وقتها وأنت منشغل بعملك.

تظهر نافذة صغيرة قبل الصلاة بدقائق، ثم مرة أخرى عند دخول الوقت. يمكنك تأجيل التنبيه أو إغلاقه.

المميزات

• تنبيه قبل الفجر والظهر والعصر والمغرب والعشاء — قبل ١٥ دقيقة افتراضيًا، أو أي مدة تختارها
• تنبيه آخر عند دخول وقت الصلاة تمامًا
• تشغيل تكبير قصير، أو صوت من أصوات ويندوز، أو أي ملف صوتي تختاره — بما في ذلك أذان بصوت من تفضّل
• واجهة عربية كاملة من اليمين إلى اليسار، تتبع لغة ويندوز تلقائيًا ويمكن تغييرها من الإعدادات
• نطق التذكير بصوت مسموع بالعربية عند تثبيت صوت عربي في ويندوز
• تحديد موقعك تلقائيًا ومتابعة الحاسوب أثناء السفر، أو إدخال الإحداثيات يدويًا
• عرض مواقيت اليوم والوقت المتبقي للصلاة القادمة من أيقونة شريط المهام
• إيقاف التنبيهات مؤقتًا متى شئت

دقة قابلة للضبط

المواقيت من واجهة Aladhan بالحساب الفلكي المعتمد، ويمكنك اختيار:

• ٢٣ طريقة حساب، منها رابطة العالم الإسلامي، والهيئة المصرية العامة للمساحة، وأم القرى بمكة، وجامعة العلوم الإسلامية بكراتشي، وديانت التركية، وغيرها
• حساب العصر على مذهب الجمهور (الشافعي والمالكي والحنبلي) أو على المذهب الحنفي
• تعديل مستقل لكل صلاة حتى ٣٠ دقيقة لمطابقة مسجدك

يعمل بدون إنترنت

يُحمِّل التطبيق مواقيت شهر كامل دفعة واحدة ويحفظها على جهازك، فتستمر التنبيهات دون اتصال.

خصوصية تامة

بلا حساب، وبلا إعلانات، وبلا أي تتبع. إعداداتك لا تغادر جهازك، ويُستخدم موقعك لحساب المواقيت فقط.

مجاني ومفتوح المصدر

الشيفرة كاملة ومتاحة برخصة MIT:
https://github.com/YRamzy993/prayer-reminder

يُرجى مقارنة مواقيت أول يوم بمسجدك، واستخدام خيار التعديل لكل صلاة إن اختلفت — والاختلاف اليسير بين المساجد أمر معتاد.
```

## مميزات المنتج

```
تنبيه قبل كل صلاة
تنبيه آخر عند دخول الوقت
تكبير أو أذان بصوت من تفضّل
نطق التذكير بالعربية
تحديد الموقع تلقائيًا
٢٣ طريقة حساب، والعصر حنفي أو جمهور
تعديل لكل صلاة لمطابقة مسجدك
مواقيت اليوم من شريط المهام
تأجيل التنبيه أو إغلاقه
يعمل بدون إنترنت
بلا حساب وبلا إعلانات وبلا تتبع
مجاني ومفتوح المصدر
```

## كلمات البحث

```
مواقيت الصلاة
أذان
الصلاة
تذكير الصلاة
إمساكية
أوقات الصلاة
قبلة
```

---

## Field values outside the listing page

| Field | Value |
|---|---|
| Price | Free |
| Markets | All markets |
| Category | Lifestyle |
| Privacy policy URL | `https://github.com/YRamzy993/prayer-reminder/blob/main/PRIVACY.md` |
| Website | `https://github.com/YRamzy993/prayer-reminder` |
| Support contact | `https://github.com/YRamzy993/prayer-reminder/issues` |

## Images to upload

| Slot | File |
|---|---|
| Screenshot 1 | `assets/store-screenshots/01-reminder.png` |
| Screenshot 2 | `assets/store-screenshots/02-prayer-time.png` |
| Screenshot 3 | `assets/store-screenshots/03-settings.png` |
| Store logo (300×300) | `assets/msix/StoreListing-300x300.png` |

For the **Arabic** listing use the right-to-left set instead, which shows the app's own
Arabic interface: `assets/store-screenshots-ar/`.

## Age rating questionnaire

Answer **No** to every question. The app has no violence, no sexual content, no profanity,
no gambling, no in-app purchases, no user-to-user communication, no user-generated content,
and shares no personal information with third parties. Expected result: **3+ / Everyone**.

Note on the location question: the app uses your location only on your device and to request
prayer times. It does not share your location with other users, which is what the
questionnaire is asking about.
