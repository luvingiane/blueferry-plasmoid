# iPhone Status for Plasma 6

**English** · [Italiano](README.it.md)

A KDE Plasma 6 applet (QML only) that shows your iPhone's battery, signal,
carrier, notifications, now playing track and recent calls, read from
[BlueFerry](https://github.com/erikwb/blueferry).

<img width="494" height="609" alt="Schermata_20261015_160728" src="https://github.com/user-attachments/assets/ad7c3771-dc84-4484-9284-62c33324271a" />
<img width="526" height="634" alt="Schermata_20261015_160700" src="https://github.com/user-attachments/assets/268d43fe-8705-429b-b2ad-4800dae6095a" />
<img width="578" height="355" alt="Schermata_20261015_160029" src="https://github.com/user-attachments/assets/38f73d31-bb41-4b26-a6da-34c72ccd2fe4" />
<img width="530" height="418" alt="Schermata_20261015_155934" src="https://github.com/user-attachments/assets/c926d6cd-bd96-4b9d-a2bf-1b79cbff8395" />


- **Panel**: battery icon, percentage, signal icon (5 bars), signal
  percentage, carrier, title, now playing track and a count of new
  notifications, each one reorderable or hidden.
- **Tabbed popup**, with tabs you can reorder or hide:
  - **Status**: Battery (with "~" when it comes from the HFP hands-free
    link), Cellular network and Bluetooth sections, in the style of Plasma's
    Battery applet;
  - **Notifications**: SMS from BlueFerry's history and the iPhone's app
    notifications, iOS style, with the app icon taken from the icon theme;
  - **Player**: artwork, track, artist, album, progress and controls;
  - **Calls**: recent calls with the contact's photo (or initials) and a
    call back button when HFP calls are on.
- **Emoji** in a font of your choice (Apple Color Emoji by default), the rest
  of the text in the theme font.
- **Tooltip**: carrier, battery and signal, or the reason the phone cannot be
  reached.
- English and Italian user interface.

## Data source

The applet calls BlueFerry's D-Bus API (session bus, object
`/io/weirdware/BlueFerry`) with `gdbus`:

| Data | Method | Every |
| --- | --- | --- |
| Battery, signal, network | `Messages1.GetStatus` | 10 s |
| Player | `Media1.GetNowPlaying`, `Media1.SendMediaCommand` | 15 s (3 s with the popup open) |
| Calls | `CallHistory1.ListCallHistory`, `Messages1.GetContactPhoto` | 60 s |
| SMS | `Messages1.ListEvents` | 30 s |
| AirPlay | `org.mpris.MediaPlayer2.ShairportSync` (MPRIS) | with the player |

`blueferry phone-status --json` exposes the same `phone_*` keys but does not
say whether the iPhone is connected; the phone counts as connected when
BlueFerry reports `bredr` or `le`.

App notifications (ANCS) are not part of the API: BlueFerry sends them to
Plasma as transient notifications, which do not stay in the history. The
applet copies them from Plasma's notification model as they appear, so the
list starts empty again whenever Plasma restarts.

BlueFerry replaces control characters and text direction marks with "�"
(Discord, for example, wraps names in bidi isolates). They are invisible on
iOS, so the applet removes them.

An app's icon is looked up in the icon theme with `kiconfinder6`
(KIconThemes), trying the app name in lower case and a few known aliases
(Telegram → `org.telegram.desktop`). Without a match the notification icon
stays.

The iPhone does not send artwork over Bluetooth: the AMS attributes are only
artist, album, title and duration. During AirPlay to this computer the
artwork comes from shairport-sync (MPRIS, `mpris:artUrl`); otherwise, if the
option is on, the artist and title are looked up with the public iTunes
search API (Apple sees the titles looked up).

Player controls follow the list of commands the iPhone announces to
BlueFerry; when that list is empty they are tried anyway and a refusal shows
up in the popup.

Contact photos need `BLUEFERRY_CONTACT_PHOTOS=true` in
`~/.config/blueferry/local.env`, a BlueFerry restart and
`blueferry contacts-sync`.

The service is D-Bus activatable: if BlueFerry is not running, the first read
starts it.

The iPhone does not report whether it is charging (its Battery Service only
has Battery Level, and HFP only the level). The applet estimates it from exact
LE readings: a rising level shows the charging icon and "probably charging",
with the measured rate ("1 % every 45 s"). If the next point does not arrive
within 2.5 times that interval (at least 90 s, at most 25 min; 5 min before a
rate is known) the estimate expires, and a drop ends it at once, so a full
phone or one held at 80 % by iOS is no longer announced. A missed reading or
a disconnect shorter than 2 minutes keeps the estimate.

The network type (LTE, 5G…) is not available: the iPhone's Bluetooth
hands-free profile only reports status, carrier, signal and mode.

## Requirements

- KDE Plasma 6
- BlueFerry 0.8.1 or later; signal and carrier need calls turned on
  (`blueferry calls enable`)

## Installation

```bash
kpackagetool6 -t Plasma/Applet -i .
```

Updating after a change:

```bash
kpackagetool6 -t Plasma/Applet -u .
systemctl --user restart plasma-plasmashell
```

## Translations

Source strings are in English; Italian lives in `po/it.po`. After changing
any string:

```bash
po/build.sh
```

refreshes `po/template.pot`, merges it into the catalogues and compiles the
`.mo` files into `contents/locale/`. For a new language:
`msginit --locale=<code> --input=po/template.pot --output-file=po/<code>.po`.

Trying it without a panel (`plasma-sdk` package):

```bash
plasmoidviewer -a org.matt.iphonestatus
```

## License

MIT, see [LICENSE](LICENSE).
