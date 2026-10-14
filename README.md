# Stato iPhone per Plasma 6

Plasmoide KDE Plasma 6 (solo QML) che mostra batteria, segnale, operatore e
stato di registrazione dell'iPhone, letti da
[BlueFerry](https://github.com/erikwb/blueferry).

- **Pannello**: icona batteria, percentuale, icona segnale (5 tacche),
  percentuale segnale, operatore e titolo, da riordinare o nascondere.
- **Popup**: batteria (con "~" se arriva dal vivavoce HFP), fonte, segnale,
  operatore, registrazione e stato Bluetooth, anche queste riordinabili.
- **Tooltip**: operatore, batteria e segnale, oppure il motivo per cui il
  telefono non è raggiungibile.

## Fonte dati

Ogni 10 secondi l'applet chiama il metodo D-Bus di BlueFerry
`io.weirdware.BlueFerry.Messages1.GetStatus` (bus di sessione, oggetto
`/io/weirdware/BlueFerry`) con `gdbus`. `blueferry phone-status --json`
espone le stesse chiavi `phone_*` ma non dice se l'iPhone è connesso; il
telefono è considerato connesso quando BlueFerry riporta `bredr` o `le`.

Il servizio è attivabile via D-Bus: se BlueFerry è spento, la prima lettura
lo avvia.

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

Prova senza pannello (pacchetto `plasma-sdk`):

```bash
plasmoidviewer -a org.matt.iphonestatus
```
