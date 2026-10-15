# Stato iPhone per Plasma 6

[English](README.md) · **Italiano**

Plasmoide KDE Plasma 6 (solo QML) che mostra batteria, segnale, operatore,
notifiche, brano in riproduzione e chiamate recenti dell'iPhone, letti da
[BlueFerry](https://github.com/erikwb/blueferry).

- **Pannello**: icona batteria, percentuale, icona segnale (5 tacche),
  percentuale segnale, operatore, titolo, brano in riproduzione e contatore
  delle notifiche nuove, da riordinare o nascondere.
- **Popup a schede**, riordinabili o nascondibili:
  - **Stato**: sezioni Batteria (con "~" se arriva dal vivavoce HFP), Rete
    cellulare e Bluetooth, nello stile dell'applet Batteria di Plasma;
  - **Notifiche**: SMS dallo storico di BlueFerry e notifiche delle app
    dell'iPhone, in stile iOS, con l'icona dell'app presa dal tema d'icone;
  - **Player**: copertina, brano, artista, album, avanzamento e comandi;
  - **Chiamate**: ultime chiamate con foto del contatto (o iniziali) e
    pulsante per richiamare quando le chiamate HFP sono attive.
- **Emoji** nel font scelto (predefinito Apple Color Emoji), il resto del
  testo nel font del tema.
- **Tooltip**: operatore, batteria e segnale, oppure il motivo per cui il
  telefono non è raggiungibile.

## Fonte dati

L'applet chiama l'API D-Bus di BlueFerry (bus di sessione, oggetto
`/io/weirdware/BlueFerry`) con `gdbus`:

| Dato | Metodo | Ogni |
| --- | --- | --- |
| Batteria, segnale, rete | `Messages1.GetStatus` | 10 s |
| Player | `Media1.GetNowPlaying`, `Media1.SendMediaCommand` | 15 s (3 s a popup aperto) |
| Chiamate | `CallHistory1.ListCallHistory`, `Messages1.GetContactPhoto` | 60 s |
| SMS | `Messages1.ListEvents` | 30 s |
| AirPlay | `org.mpris.MediaPlayer2.ShairportSync` (MPRIS) | con il player |

`blueferry phone-status --json` espone le stesse chiavi `phone_*` ma non dice
se l'iPhone è connesso; il telefono è considerato connesso quando BlueFerry
riporta `bredr` o `le`.

Le notifiche delle app (ANCS) non sono nell'API: BlueFerry le manda a Plasma
come transienti, che non restano nello storico. L'applet le copia dal modello
delle notifiche di Plasma mentre compaiono, quindi la lista riparte vuota a
ogni riavvio di Plasma.

BlueFerry sostituisce con "�" i caratteri di controllo e i marcatori di
direzione del testo (Discord, per esempio, racchiude i nomi tra bidi isolate).
Su iOS sono invisibili, quindi l'applet li toglie.

L'icona di un'app si cerca nel tema d'icone con `kiconfinder6` (KIconThemes),
provando il nome dell'app in minuscolo e qualche alias noto (Telegram →
`org.telegram.desktop`). Senza corrispondenza resta l'icona delle notifiche.

Via Bluetooth l'iPhone non manda la copertina: gli attributi AMS sono solo
artista, album, titolo e durata. Durante AirPlay verso questo computer la
copertina arriva da shairport-sync (MPRIS, `mpris:artUrl`); altrimenti, se
l'opzione è attiva, si cercano artista e titolo sull'API pubblica di ricerca
di iTunes (Apple vede i titoli cercati).

I comandi del player seguono la lista che l'iPhone annuncia a BlueFerry; se è
vuota si provano comunque e un eventuale rifiuto compare nel popup.

Le foto dei contatti richiedono `BLUEFERRY_CONTACT_PHOTOS=true` in
`~/.config/blueferry/local.env`, un riavvio di BlueFerry e
`blueferry contacts-sync`.

Il servizio è attivabile via D-Bus: se BlueFerry è spento, la prima lettura
lo avvia.

L'iPhone non dice se è in carica (il suo servizio batteria ha solo Battery
Level, e HFP solo il livello). L'applet lo stima: una percentuale che sale tra
due letture LE esatte mostra l'icona di ricarica e "probabilmente in carica",
una che scende la toglie. Al 100 % o con la carica ferma all'80 % di iOS non
si può capire.

Il tipo di rete (LTE, 5G…) non è disponibile: il profilo vivavoce Bluetooth
dell'iPhone espone solo stato, operatore, segnale e modalità.

## Requisiti

- KDE Plasma 6
- BlueFerry 0.8.1 o successivo; segnale e operatore richiedono le chiamate
  attive (`blueferry calls enable`)

## Installazione

```bash
kpackagetool6 -t Plasma/Applet -i .
```

Aggiornamento dopo una modifica:

```bash
kpackagetool6 -t Plasma/Applet -u .
systemctl --user restart plasma-plasmashell
```

## Traduzioni

Le stringhe sorgente sono in inglese; l'italiano sta in `po/it.po`. Dopo una
modifica alle stringhe:

```bash
po/build.sh
```

aggiorna `po/template.pot`, unisce il template ai cataloghi e compila i file
`.mo` in `contents/locale/`. Per una lingua nuova:
`msginit --locale=<codice> --input=po/template.pot --output-file=po/<codice>.po`.

Prova senza pannello (pacchetto `plasma-sdk`):

```bash
plasmoidviewer -a org.matt.iphonestatus
```

## Licenza

MIT, vedi [LICENSE](LICENSE).
