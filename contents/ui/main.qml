// Stato iPhone: batteria, segnale, notifiche, player e chiamate recenti
// dell'iPhone, letti da BlueFerry.
//
// Tutto passa dall'API D-Bus di BlueFerry (bus di sessione, oggetto
// /io/weirdware/BlueFerry), chiamata con gdbus: GetStatus per batteria e rete,
// GetNowPlaying e SendMediaCommand per il player, ListCallHistory e
// GetContactPhoto per le chiamate, ListEvents per gli SMS. Le notifiche delle
// app arrivano a Plasma da BlueFerry come transienti e non restano nello
// storico: l'applet le copia dal modello delle notifiche mentre compaiono.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager
import "order.js" as Order
import "util.js" as Util

PlasmoidItem {
    id: root

    // LC_ALL=C: i messaggi di errore di gdbus restano in inglese, così si
    // possono riconoscere. Il timeout evita che una chiamata bloccata
    // sovrapponga i cicli di polling.
    readonly property string gdbusCall: "LC_ALL=C gdbus call --session --timeout 5"
        + " --dest io.weirdware.BlueFerry --object-path /io/weirdware/BlueFerry"
        + " --method io.weirdware.BlueFerry."
    readonly property string dash: "—"
    readonly property int callsShown: 15
    readonly property int messagesShown: 20
    readonly property int appNotificationsKept: 50

    readonly property string title: Plasmoid.configuration.title.trim() || i18n("iPhone")
    readonly property string emojiFont: Plasmoid.configuration.emojiFont
    readonly property var panelItems: Order.shown(Plasmoid.configuration.panelItems, Order.PANEL_IDS)
    readonly property var statusSections: Order.shown(Plasmoid.configuration.statusSections, Order.SECTION_IDS)
    readonly property var popupTabs: Order.shown(Plasmoid.configuration.popupTabs, Order.TAB_IDS)
    readonly property bool onlineArtwork: Plasmoid.configuration.onlineArtwork

    // --- Stato del telefono (GetStatus) -----------------------------------

    property bool loaded: false
    property string error: ""            // non vuoto: comando fallito o daemon spento
    property bool connected: false       // BR/EDR o LE dell'iPhone collegati
    property string connectivityDetail: ""
    property bool callsEnabled: false    // chiamate HFP attive in BlueFerry
    property date lastUpdate

    // Le chiavi phone_* di GetStatus; null quando sconosciute.
    property var batteryLevel: null
    property var batterySource: null     // "gatt", "bluez" o "hfp"
    property var signalStrength: null    // 0-100, in passi di 20 via HFP
    property var networkName: null
    property var networkStatus: null

    // Telefono raggiungibile e dati validi.
    readonly property bool active: loaded && error === "" && connected

    // Perché l'icona è disattivata; vuoto quando è tutto a posto.
    readonly property string reason: {
        if (!loaded)
            return i18n("Reading the status…")
        if (error !== "")
            return error
        if (!connected)
            return connectivityDetail !== ""
                ? i18n("iPhone not connected (%1)", connectivityDetail)
                : i18n("iPhone not connected")
        return ""
    }

    readonly property string batteryText: batteryLevel === null ? dash
        : (batterySource === "hfp" ? "~" : "") + i18n("%1 %", batteryLevel)

    // 0-100 → 0-5 tacche; -1 se sconosciuto.
    readonly property int signalBars: signalStrength === null ? -1
        : Math.max(0, Math.min(5, Math.round(signalStrength / 20)))
    readonly property string signalText: signalBars < 0 ? dash
        : i18n("%1 % (%2/5)", signalStrength, signalBars)

    readonly property string networkText: networkName === null || networkName === "" ? dash : networkName

    readonly property string batteryIcon: {
        if (!active || batteryLevel === null)
            return "battery-missing"
        const step = Math.max(0, Math.min(100, Math.round(batteryLevel / 10) * 10))
        return "battery-" + String(step).padStart(3, "0")
    }
    readonly property string signalIcon: !active || signalBars < 0
        ? "network-mobile-off" : "network-mobile-" + (signalBars * 20)

    // --- Player (GetNowPlaying) -------------------------------------------

    property var nowPlaying: null        // la risposta di GetNowPlaying
    property double mediaFetchedAt: 0    // quando è arrivata, in ms
    property double clock: Date.now()    // avanza ogni secondo durante la riproduzione

    // Il brano dell'iPhone via Bluetooth (AMS): titolo, artista, album, durata.
    readonly property var amsTrack: nowPlaying && nowPlaying.available === true && nowPlaying.track
        ? nowPlaying.track : null
    readonly property bool amsPlaying: amsTrack !== null && !!nowPlaying.player
        && nowPlaying.player.state === "playing"

    // shairport-sync (AirPlay verso questo computer), letto via MPRIS:
    // {status, title, artist, album, art, length} o null.
    property var airplay: null
    readonly property bool airplayPlaying: !!airplay && airplay.status === "Playing"
    readonly property bool airplaySameTrack: !!airplay && amsTrack !== null
        && Util.sameTitle(airplay.title, amsTrack.title)
    // AirPlay suona un brano diverso da quello che AMS riporta (per esempio
    // un'altra app): si mostra quello.
    readonly property bool showAirplay: airplayPlaying && !amsPlaying && !airplaySameTrack
        && airplay.title !== ""

    readonly property var track: showAirplay
        ? { title: airplay.title, artist: airplay.artist, album: airplay.album,
            duration: airplay.length > 0 ? airplay.length : 0 }
        : amsTrack
    readonly property bool mediaAvailable: track !== null
    readonly property bool playing: showAirplay || amsPlaying || (airplayPlaying && airplaySameTrack)
    readonly property string mediaSource: showAirplay ? i18n("AirPlay")
        : nowPlaying && nowPlaying.player && nowPlaying.player.name
            ? i18n("%1 · iPhone", nowPlaying.player.name) : i18n("iPhone")
    readonly property var mediaCommands: nowPlaying && nowPlaying.supported_commands ? nowPlaying.supported_commands : []
    readonly property real mediaDuration: track && typeof track.duration === "number" ? track.duration : 0
    // AMS dà il tempo trascorso; shairport-sync no, quindi senza AMS niente barra.
    readonly property bool mediaHasProgress: !showAirplay && !!amsTrack && typeof amsTrack.elapsed === "number"
        && mediaDuration > 0
    readonly property real mediaElapsed: {
        if (!mediaHasProgress)
            return 0
        const rate = nowPlaying.player && typeof nowPlaying.player.rate === "number" ? nowPlaying.player.rate : 1
        const extra = amsPlaying ? Math.max(0, clock - mediaFetchedAt) / 1000 * rate : 0
        return Math.min(amsTrack.elapsed + extra, mediaDuration)
    }
    readonly property string mediaText: !mediaAvailable ? ""
        : [track.title, track.artist].filter(part => !!part).join(" – ")

    // Copertina: quella di shairport-sync se è lo stesso brano, altrimenti la
    // ricerca su iTunes (se attiva); "" senza copertina.
    property var artworkCache: ({})      // "artista|titolo" → URL, "" se assente
    readonly property string artworkKey: track ? (track.artist || "") + "|" + (track.title || "") : ""
    readonly property string artwork: {
        if (airplay && airplay.art !== "" && (showAirplay || airplaySameTrack))
            return airplay.art
        return onlineArtwork && artworkKey !== "" ? artworkCache[artworkKey] || "" : ""
    }
    onArtworkKeyChanged: fetchArtwork()
    onOnlineArtworkChanged: fetchArtwork()

    // L'ultimo errore di un comando del player, mostrato per qualche secondo.
    property string mediaError: ""

    // --- Chiamate recenti (ListCallHistory, GetContactPhoto) ---------------

    property var calls: []               // [{direction, timestamp, address, name, contact_name}]
    property var photos: ({})            // numero → data URI, "" se senza foto
    property var photoQueue: []
    property bool photoBusy: false

    // --- Notifiche: SMS (ListEvents) e app (modello di Plasma) -------------

    property var messages: []            // [{kind, app, title, body, time}]
    property var appNotifications: []    // stesse chiavi, più id
    property int unseen: 0               // arrivate dall'ultima apertura del popup

    readonly property var notifications: messages.concat(appNotifications)
        .sort((a, b) => b.time - a.time)

    // Nome dell'app → icona del tema, "" se il tema non ne ha una.
    property var appIcons: ({})

    // Cerca nel tema d'icone, una volta per app, il primo nome candidato che
    // esiste. Kirigami.Icon dichiara valida anche un'icona inesistente, quindi
    // decide kiconfinder6 (KIconThemes, parte di KDE Frameworks).
    function ensureAppIcon(name) {
        const key = String(name || "")
        if (key === "" || appIcons[key] !== undefined)
            return
        const pending = Object.assign({}, appIcons)
        pending[key] = ""
        appIcons = pending
        const candidates = Util.iconCandidates(key)
        if (candidates.length === 0)
            return
        run("for n in " + candidates.map(Util.shellQuote).join(" ")
            + '; do kiconfinder6 "$n" >/dev/null 2>&1 && { echo "$n"; exit 0; }; done; exit 1', (code, out) => {
            const found = out.trim()
            if (code !== 0 || candidates.indexOf(found) < 0)
                return
            const next = Object.assign({}, appIcons)
            next[key] = found
            appIcons = next
        })
    }

    // --- Testo ------------------------------------------------------------

    function styled(text) {
        return Util.styled(text, emojiFont)
    }

    // "ora", "5 min fa", "14:32", "ieri 14:32", "lun 14:32" o "12/10/26".
    function timeText(date) {
        if (!(date instanceof Date) || isNaN(date.getTime()))
            return ""
        const now = new Date()
        const minutes = Math.floor((now - date) / 60000)
        if (minutes >= 0 && minutes < 1)
            return i18n("now")
        if (minutes >= 1 && minutes < 60)
            return i18n("%1 min ago", minutes)
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        const thatDay = new Date(date.getFullYear(), date.getMonth(), date.getDate())
        const diffDays = Math.round((today - thatDay) / 86400000)
        const time = Qt.formatTime(date, "hh:mm")
        if (diffDays <= 0)
            return time
        if (diffDays === 1)
            return i18n("yesterday %1", time)
        if (diffDays < 7)
            return Qt.locale().dayName(date.getDay(), Locale.ShortFormat) + " " + time
        return Qt.formatDate(date, "dd/MM/yy")
    }

    function durationText(seconds) {
        const total = Math.max(0, Math.floor(seconds))
        return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0")
    }

    function registrationText(status) {
        switch (status) {
        case "registered": return i18n("Registered")
        case "roaming": return i18n("Roaming")
        case "searching": return i18n("Searching for a network…")
        case "unregistered": return i18n("Not registered")
        case "denied": return i18n("Registration denied")
        case "unknown": return i18n("Unknown")
        case null: return dash
        default: return status
        }
    }

    function describeFailure(exitCode, stderr) {
        if (exitCode === 127 || /not found/i.test(stderr) && !/GDBus\.Error/.test(stderr))
            return i18n("The gdbus command was not found")
        if (/ServiceUnknown|NameHasNoOwner|not provided by any/.test(stderr))
            return i18n("BlueFerry is not running")
        if (/NoReply|Timeout|timed out/i.test(stderr))
            return i18n("BlueFerry is not responding")
        if (/AccessDenied|NotAuthorized/.test(stderr))
            return i18n("BlueFerry denied access to the status")
        const line = stderr.trim().split("\n")[0].replace(/^Error:\s*/, "").replace(/^GDBus\.Error:/, "")
        return line !== "" ? i18n("Error: %1", line) : i18n("The command exited with code %1", exitCode)
    }

    // --- Esecuzione dei comandi -------------------------------------------

    // Il motore "executable" è unico per tutto plasmashell e identifica le
    // sorgenti dal testo del comando. Il commento finale con l'id dell'applet
    // e un contatore dà a ogni chiamata una sorgente sua: altrimenti due copie
    // dell'applet, o due chiamate uguali, si contendono la stessa esecuzione.
    property var pending: ({})
    property int sequence: 0

    function run(command, callback) {
        sequence += 1
        const source = command + " # org.matt.iphonestatus " + Plasmoid.id + " " + sequence
        pending[source] = callback
        executable.connectSource(source)
    }

    // Un metodo di BlueFerry; args è già pronto per la shell.
    function call(method, args, callback) {
        run(gdbusCall + method + (args ? " " + args : ""), callback)
    }

    // Una stringa per gdbus: letterale GVariant tra virgolette, poi quotata
    // per la shell. Va usata solo con testo già validato.
    function gvariantArg(text) {
        return Util.shellQuote('"' + text + '"')
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            // Un aggiornamento senza codice di uscita arriva prima che il
            // processo sia finito: si aspetta il risultato vero.
            if (data["exit code"] === undefined)
                return
            disconnectSource(source)
            const callback = root.pending[source]
            delete root.pending[source]
            if (callback)
                callback(data["exit code"], data["stdout"] || "", data["stderr"] || "")
        }
    }

    // --- Lettura dei dati -------------------------------------------------

    property bool statusBusy: false
    property bool mediaBusy: false
    property bool callsBusy: false
    property bool messagesBusy: false
    property bool airplayBusy: false

    function nullable(value) {
        return value === undefined ? null : value
    }

    function clearPhone() {
        batteryLevel = null
        batterySource = null
        signalStrength = null
        networkName = null
        networkStatus = null
        connected = false
        connectivityDetail = ""
    }

    function applyStatus(exitCode, stdout, stderr) {
        loaded = true
        lastUpdate = new Date()
        if (exitCode !== 0) {
            clearPhone()
            error = describeFailure(exitCode, stderr)
            return
        }
        const status = Util.gvariantJson(stdout)
        if (!status || typeof status !== "object") {
            clearPhone()
            error = i18n("BlueFerry's answer could not be read")
            return
        }
        if (status.daemon === false) {
            clearPhone()
            error = i18n("The BlueFerry daemon is not active")
            return
        }
        error = ""
        connected = status.bredr === true || status.le === true
        connectivityDetail = status.connectivity_detail || ""
        callsEnabled = status.calls_enabled === true
        batteryLevel = typeof status.phone_battery_level === "number" ? status.phone_battery_level : null
        batterySource = nullable(status.phone_battery_source)
        signalStrength = typeof status.phone_signal_strength === "number" ? status.phone_signal_strength : null
        networkName = nullable(status.phone_network_name)
        networkStatus = nullable(status.phone_network_status)
    }

    function refreshStatus() {
        if (statusBusy)
            return
        statusBusy = true
        call("Messages1.GetStatus", "", (code, out, err) => {
            statusBusy = false
            applyStatus(code, out, err)
        })
    }

    function refreshMedia() {
        if (mediaBusy)
            return
        mediaBusy = true
        call("Media1.GetNowPlaying", "", (code, out) => {
            mediaBusy = false
            const value = code === 0 ? Util.gvariantJson(out) : undefined
            nowPlaying = value && typeof value === "object" ? value : null
            mediaFetchedAt = Date.now()
            clock = mediaFetchedAt
        })
        refreshAirplay()
    }

    // shairport-sync espone su MPRIS il brano in AirPlay con la copertina in
    // un file della sua cache.
    function refreshAirplay() {
        if (airplayBusy)
            return
        airplayBusy = true
        run("LC_ALL=C gdbus call --session --timeout 3 --dest org.mpris.MediaPlayer2.ShairportSync"
            + " --object-path /org/mpris/MediaPlayer2 --method org.freedesktop.DBus.Properties.GetAll"
            + " org.mpris.MediaPlayer2.Player", (code, out) => {
            airplayBusy = false
            if (code !== 0) {
                airplay = null
                return
            }
            const art = Util.gvariantField(out, "mpris:artUrl")
            const length = Util.gvariantNumber(out, "mpris:length")
            airplay = {
                status: Util.gvariantField(out, "PlaybackStatus"),
                title: Util.gvariantField(out, "xesam:title"),
                artist: Util.gvariantField(out, "xesam:artist"),
                album: Util.gvariantField(out, "xesam:album"),
                // Solo i file della cache di shairport-sync.
                art: art.startsWith("file:///tmp/shairport-sync/") ? art : "",
                length: isNaN(length) ? 0 : length / 1000000
            }
        })
    }

    // La copertina dall'API di ricerca di iTunes, una richiesta per brano.
    function fetchArtwork() {
        if (!onlineArtwork || !track || !track.title || artworkCache[artworkKey] !== undefined)
            return
        const key = artworkKey
        const remember = url => {
            const next = Object.assign({}, artworkCache)
            next[key] = url
            artworkCache = next
        }
        remember("")   // segna la richiesta come fatta, anche se fallisce
        const country = (Qt.locale().name.split("_")[1] || "US").toLowerCase()
        const request = new XMLHttpRequest()
        request.onreadystatechange = () => {
            if (request.readyState !== XMLHttpRequest.DONE || request.status !== 200)
                return
            try {
                const result = JSON.parse(request.responseText).results[0]
                if (result && typeof result.artworkUrl100 === "string"
                        && result.artworkUrl100.startsWith("https://"))
                    remember(result.artworkUrl100.replace(/\/\d+x\d+bb\./, "/600x600bb."))
            } catch (e) {
            }
        }
        request.open("GET", "https://itunes.apple.com/search?media=music&entity=song&limit=1&country="
            + country + "&term=" + encodeURIComponent([track.artist, track.title].filter(p => !!p).join(" ")))
        request.send()
    }

    // Un comando del player. Se BlueFerry non ha ancora la lista dei comandi
    // dell'iPhone si prova comunque: l'eventuale rifiuto compare nel popup.
    function mediaCommand(command) {
        if (mediaCommands.length > 0 && mediaCommands.indexOf(command) < 0
                && !(command === "toggle" && mediaCommands.indexOf(amsPlaying ? "pause" : "play") >= 0))
            return
        call("Media1.SendMediaCommand", gvariantArg(command), (code, out, err) => {
            if (code !== 0) {
                mediaError = err.trim().split("\n")[0].replace(/^Error:\s*/, "")
                    .replace(/^GDBus\.Error:[\w.]+:\s*/, "")
                mediaErrorTimer.restart()
            }
            mediaAfterCommand.restart()
        })
    }

    function refreshCalls() {
        if (callsBusy)
            return
        callsBusy = true
        call("CallHistory1.ListCallHistory", String(callsShown), (code, out) => {
            callsBusy = false
            const value = code === 0 ? Util.gvariantJson(out) : undefined
            if (!Array.isArray(value))
                return
            calls = value.filter(entry => entry && typeof entry === "object")
            for (const entry of calls) {
                if (Util.isPhoneAddress(entry.address) && photos[entry.address] === undefined
                        && photoQueue.indexOf(entry.address) < 0)
                    photoQueue.push(entry.address)
            }
            fetchNextPhoto()
        })
    }

    // Una foto alla volta: sono risposte da qualche centinaio di KB.
    function fetchNextPhoto() {
        if (photoBusy || photoQueue.length === 0)
            return
        const address = photoQueue.shift()
        photoBusy = true
        call("Messages1.GetContactPhoto", gvariantArg(address), (code, out) => {
            photoBusy = false
            // Un errore (foto in aggiornamento) lascia il numero da riprovare
            // al prossimo giro.
            if (code === 0) {
                const next = Object.assign({}, photos)
                next[address] = Util.imageUri(Util.gvariantBytes(out))
                photos = next
            }
            fetchNextPhoto()
        })
    }

    function callName(entry) {
        return entry.contact_name || entry.name || entry.address || i18n("Unknown")
    }

    function dial(address) {
        if (callsEnabled && Util.isPhoneAddress(address))
            call("Calls1.Dial", gvariantArg(address), () => {})
    }

    function refreshMessages() {
        if (messagesBusy)
            return
        messagesBusy = true
        call("Messages1.ListEvents", Util.shellQuote('["sms_received"]') + " " + messagesShown, (code, out) => {
            messagesBusy = false
            const value = code === 0 ? Util.gvariantJson(out) : undefined
            if (!Array.isArray(value))
                return
            ensureAppIcon(i18n("Messages"))
            const before = messages.length > 0 ? messages[0].time : null
            messages = value.filter(event => event && typeof event === "object").map(event => ({
                kind: "sms",
                app: i18n("Messages"),
                title: Util.cleanText(event.group_name || event.contact_name || event.sender_address)
                    || i18n("Unknown"),
                body: Util.cleanText(event.body),
                time: new Date(event.timestamp || event.seen_at || 0)
            })).sort((a, b) => b.time - a.time)
            if (before !== null && !root.expanded)
                unseen += messages.filter(message => message.time > before).length
        })
    }

    // --- Notifiche delle app, dal modello di Plasma -----------------------

    // Testo semplice da quello (eventualmente HTML) del modello, senza i
    // caratteri invisibili che BlueFerry rende come "�".
    function plainText(text) {
        return Util.cleanText(String(text || "").replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"')
            .replace(/&#39;|&apos;/g, "'").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&"))
    }

    readonly property string phoneMark: "📱"   // 📱, prefisso dei titoli ANCS

    function captureNotification(row) {
        const index = notificationModel.index(row, 0)
        const role = which => notificationModel.data(index, which)
        if (role(NotificationManager.Notifications.ApplicationNameRole) !== "BlueFerry")
            return
        // BlueFerry intitola le notifiche delle app "📱 App · Titolo"; SMS e
        // chiamate perse arrivano già dalle sue liste.
        const summary = plainText(role(NotificationManager.Notifications.SummaryRole))
        if (!summary.startsWith(phoneMark))
            return
        const id = role(NotificationManager.Notifications.IdRole)
        if (appNotifications.some(item => item.id === id))
            return
        const heading = summary.slice(phoneMark.length).trim()
        const separator = heading.indexOf(" · ")
        const created = role(NotificationManager.Notifications.CreatedRole)
        const item = {
            id: id,
            kind: "app",
            app: separator >= 0 ? heading.slice(0, separator) : heading,
            title: separator >= 0 ? heading.slice(separator + 3) : "",
            body: plainText(role(NotificationManager.Notifications.BodyRole)),
            time: created instanceof Date ? created : new Date()
        }
        ensureAppIcon(item.app)
        appNotifications = [item].concat(appNotifications).slice(0, appNotificationsKept)
        if (!root.expanded)
            unseen += 1
    }

    function clearNotifications() {
        appNotifications = []
        unseen = 0
    }

    NotificationManager.Notifications {
        id: notificationModel
        showNotifications: true
        showJobs: false
        showExpired: true
        showDismissed: true
        groupMode: NotificationManager.Notifications.GroupDisabled
        Component.onCompleted: {
            for (let row = 0; row < count; ++row)
                root.captureNotification(row)
        }
    }

    Connections {
        target: notificationModel
        function onRowsInserted(parent, first, last) {
            for (let row = first; row <= last; ++row)
                root.captureNotification(row)
        }
    }

    // --- Tempi ------------------------------------------------------------

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshStatus()
    }
    Timer {
        interval: root.expanded ? 3000 : 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshMedia()
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshCalls()
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshMessages()
    }
    // Fa avanzare la barra del brano tra una lettura e l'altra.
    Timer {
        interval: 1000
        running: root.playing
        repeat: true
        onTriggered: root.clock = Date.now()
    }
    Timer {
        id: mediaAfterCommand
        interval: 600
        onTriggered: root.refreshMedia()
    }
    Timer {
        id: mediaErrorTimer
        interval: 6000
        onTriggered: root.mediaError = ""
    }

    function refreshAll() {
        refreshStatus()
        refreshMedia()
        refreshCalls()
        refreshMessages()
    }

    onExpandedChanged: {
        if (root.expanded) {
            unseen = 0
            refreshAll()
        }
    }

    Plasmoid.icon: "smartphone"
    Plasmoid.title: title
    toolTipMainText: title
    toolTipTextFormat: Text.PlainText
    toolTipSubText: {
        if (!active)
            return reason
        const lines = [i18n("Carrier: %1", networkText), i18n("Battery: %1", batteryText),
            i18n("Signal: %1", signalText)]
        if (mediaText !== "")
            lines.push((playing ? "▶ " : "⏸ ") + mediaText)
        if (unseen > 0)
            lines.push(i18np("%1 new notification", "%1 new notifications", unseen))
        return lines.join("\n")
    }

    // --- Pannello ---------------------------------------------------------

    function panelIcon(id) {
        switch (id) {
        case "batteryIcon": return batteryIcon
        case "signalIcon": return signalIcon
        case "media": return playing ? "media-playback-start" : "media-playback-pause"
        case "notifications": return "notifications"
        case "placeholder": return "smartphone"
        default: return ""
        }
    }

    function panelText(id) {
        switch (id) {
        case "batteryText": return batteryText
        case "signalText": return signalBars < 0 ? dash : i18n("%1 %", signalStrength)
        case "operator": return networkText
        case "title": return title
        case "media": return mediaText
        case "notifications": return String(unseen)
        default: return ""
        }
    }

    // Elementi del pannello visibili adesso: i testi spariscono senza dati, e
    // se non resta niente un'icona del telefono tiene l'applet cliccabile.
    readonly property var panelVisible: {
        const items = panelItems.filter(id => {
            switch (id) {
            case "batteryIcon":
            case "signalIcon":
            case "title":
                return true
            case "media":
                return mediaText !== ""
            case "notifications":
                return unseen > 0
            default:
                return active && panelText(id) !== dash
            }
        })
        return items.length > 0 ? items : ["placeholder"]
    }

    compactRepresentation: MouseArea {
        id: compact

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property int iconSize: Kirigami.Units.iconSizes.roundedIconSize(
            Math.min(Kirigami.Units.iconSizes.medium, vertical ? width : height))
        property bool wasExpanded: false

        Layout.minimumWidth: vertical ? -1 : layout.implicitWidth
        Layout.minimumHeight: vertical ? layout.implicitHeight : -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        GridLayout {
            id: layout
            anchors.centerIn: parent
            flow: compact.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.smallSpacing

            Repeater {
                model: root.panelVisible

                delegate: RowLayout {
                    id: element
                    required property string modelData
                    readonly property string icon: root.panelIcon(modelData)
                    readonly property bool iconOnly: modelData === "batteryIcon" || modelData === "signalIcon"
                        || modelData === "placeholder"
                    readonly property string text: iconOnly ? "" : root.panelText(modelData)
                    // Il player e le notifiche hanno senso anche a telefono
                    // irraggiungibile; il resto si attenua.
                    readonly property bool dimmed: !root.active && modelData !== "media"
                        && modelData !== "notifications"

                    spacing: Kirigami.Units.smallSpacing / 2
                    opacity: dimmed ? 0.5 : 1
                    Layout.alignment: Qt.AlignCenter

                    Kirigami.Icon {
                        visible: element.icon !== ""
                        source: element.icon
                        Layout.preferredWidth: element.modelData === "media"
                            ? Math.round(compact.iconSize * 0.75) : compact.iconSize
                        Layout.preferredHeight: Layout.preferredWidth
                        Layout.alignment: Qt.AlignCenter
                    }
                    PlasmaComponents.Label {
                        visible: element.text !== ""
                        text: root.styled(element.text)
                        textFormat: Text.StyledText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        Layout.maximumWidth: element.modelData === "media" ? Kirigami.Units.gridUnit * 10
                            : compact.vertical ? compact.width : -1
                        Layout.alignment: Qt.AlignCenter
                    }
                }
            }
        }
    }

    // --- Popup ------------------------------------------------------------

    fullRepresentation: PlasmaExtras.Representation {
        id: full

        readonly property var tabs: root.popupTabs.length > 0 ? root.popupTabs : ["status"]

        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        Layout.preferredHeight: Kirigami.Units.gridUnit * 26
        collapseMarginsHint: true

        function tabLabel(id) {
            switch (id) {
            case "status": return i18n("Status")
            case "notifications": return i18n("Notifications")
            case "player": return i18n("Player")
            case "calls": return i18n("Calls")
            default: return id
            }
        }

        function tabIcon(id) {
            switch (id) {
            case "status": return "smartphone"
            case "notifications": return "notifications"
            case "player": return "media-playback-start"
            case "calls": return "call-start"
            default: return ""
            }
        }

        header: PlasmaExtras.PlasmoidHeading {
            ColumnLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true

                    Kirigami.Icon {
                        source: "smartphone"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        opacity: root.active ? 1 : 0.5
                    }
                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true
                        PlasmaExtras.Heading {
                            level: 3
                            text: root.styled(root.title)
                            textFormat: Text.StyledText
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.Label {
                            text: root.active ? i18n("Connected") : i18n("Disconnected")
                            color: root.active ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                            font: Kirigami.Theme.smallFont
                            Layout.fillWidth: true
                        }
                    }
                    PlasmaComponents.ToolButton {
                        icon.name: "view-refresh"
                        display: PlasmaComponents.AbstractButton.IconOnly
                        text: i18n("Refresh")
                        onClicked: root.refreshAll()
                        PlasmaComponents.ToolTip.text: text
                        PlasmaComponents.ToolTip.visible: hovered
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                }

                PlasmaComponents.TabBar {
                    id: tabBar
                    visible: full.tabs.length > 1
                    Layout.fillWidth: true

                    Repeater {
                        model: full.tabs
                        delegate: PlasmaComponents.TabButton {
                            required property string modelData
                            text: full.tabLabel(modelData)
                            icon.name: full.tabIcon(modelData)
                        }
                    }
                }
            }
        }

        StackLayout {
            anchors.fill: parent
            currentIndex: Math.min(tabBar.currentIndex, full.tabs.length - 1)

            Repeater {
                model: full.tabs
                delegate: Loader {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // Le pagine ricevono l'applet come proprietà iniziale, così
                    // i loro binding non vedono mai un applet nullo.
                    Component.onCompleted: {
                        const pages = {
                            notifications: "NotificationsPage.qml",
                            player: "PlayerPage.qml",
                            calls: "CallsPage.qml"
                        }
                        setSource(pages[modelData] || "StatusPage.qml", { applet: root })
                    }
                }
            }
        }
    }
}
