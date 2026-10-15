# iPhone Status for Plasma 6

**English** · [Italiano](README.it.md)

A KDE Plasma 6 applet (QML only) that shows your iPhone's battery, signal,
carrier, notifications, now playing track and recent calls, read from
[BlueFerry](https://github.com/erikwb/blueferry).

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
has Battery Level, and HFP only the level). The applet estimates it: a level
that rises between two exact LE readings shows the charging icon and
"probably charging", one that drops clears it. It cannot tell at 100 % or
while iOS holds the charge at 80 %.

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
