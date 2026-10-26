# Privacy Policy — Prayer Reminder

_Last updated: 26 October 2026_

Prayer Reminder is a free, open-source Windows app. It has no account, no advertising and no
analytics. Nothing you do in the app is tracked, profiled or sold.

## What stays on your PC

Everything the app remembers is stored locally, in `%APPDATA%\PrayerReminder` (or inside the
app's own package folder for the Microsoft Store version):

- Your settings, including your location and chosen calculation method
- A cached month of prayer times, so the app works offline
- Short spoken-reminder audio clips the app generates with the Windows speech engine
- A small log file for troubleshooting

This data never leaves your PC. Uninstalling the app or deleting that folder removes it.

## What is sent over the internet

To calculate prayer times for your location, the app contacts these services. No name, email,
account, device identifier or advertising ID is ever sent — only what is listed here.

| Service | What is sent | Why |
|---|---|---|
| [Aladhan API](https://aladhan.com/prayer-times-api) (`api.aladhan.com`) | Your approximate latitude and longitude, the month, and your calculation settings | To get that month's prayer times |
| [BigDataCloud](https://www.bigdatacloud.com/privacy-and-terms) (`api.bigdatacloud.net`) | Your approximate latitude and longitude | To turn the coordinates into a city name to show you |
| [ip-api.com](https://ip-api.com/docs/legal) (`ip-api.com`) | Your IP address, by the nature of the request | Used **only** as a fallback, to estimate your city when Windows Location is turned off or unavailable |

Each request happens roughly once a month, plus whenever you press **Refresh** or change your
settings. If you set your location manually in Settings, Windows Location is not used at all.

## Location

The app asks Windows for your approximate location so prayer times match where you are. You can
revoke this at any time in **Windows Settings → Privacy & security → Location**, and instead enter
your coordinates manually in the app's Settings. Your location is used only to calculate prayer
times and show your city, and is sent only to the services listed above.

## Microphone, camera, contacts, files

Not used. The app has no access to them.

## Children

The app is suitable for all ages and does not knowingly collect any personal information.

## Changes

Any change to this policy will be published in this file, and its history is public in the
project's Git repository.

## Contact

Questions or concerns: open an issue at
<https://github.com/YRamzy993/prayer-reminder/issues>.
