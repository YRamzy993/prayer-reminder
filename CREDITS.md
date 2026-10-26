# Credits

## Prayer times

[Aladhan API](https://aladhan.com/prayer-times-api) — free prayer-time calculation API.
The app requests one month at a time and caches the result locally.

## Location

- Windows Location Service (precise, used first)
- [ip-api.com](http://ip-api.com) — fallback when Windows location is unavailable
- [BigDataCloud](https://www.bigdatacloud.com/) reverse geocoding — turns coordinates into a city name

## Bundled sound

`assets/sounds/takbeer.mp3` — the opening takbeer, trimmed to 16 seconds with a fade-out from
[Beautiful adhan.ogg](https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg) on
Wikimedia Commons, released under **CC0 1.0** (public domain dedication).

No copyrighted recitation is bundled with this app. To use a particular reciter, supply your
own file in Settings.

## Build tools

- [PS2EXE](https://github.com/MScholtes/PS2EXE) (MIT) — wraps the PowerShell app as an .exe
- [Inno Setup](https://jrsoftware.org/isinfo.php) — builds the installer
