// iPhone Status: the iPhone's battery, signal, notifications, player and recent
// calls, read from BlueFerry.
//
// Everything goes through BlueFerry's D-Bus API (session bus, object
// /io/weirdware/BlueFerry), called with gdbus: GetStatus for battery and
// network, GetNowPlaying and SendMediaCommand for the player, ListCallHistory
// and GetContactPhoto for calls, ListEvents for SMS. BlueFerry sends app
// notifications to Plasma as transient ones that do not stay in the history:
// the applet copies them from the notification model as they appear.
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

    // LC_ALL=C keeps gdbus error messages in English, so they can be
    // recognised. The timeout stops a stuck call from overlapping the polling
    // cycles.
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

    // --- Phone status (GetStatus) ----------------------------------------

    property bool loaded: false
    property string error: ""            // not empty: the command failed or the daemon is off
    property bool connected: false       // the iPhone's BR/EDR or LE link is up
    property string connectivityDetail: ""
    property bool callsEnabled: false    // HFP calls are on in BlueFerry
    property date lastUpdate

    // GetStatus's phone_* keys; null when unknown.
    property var batteryLevel: null
    property var batterySource: null     // "gatt", "bluez" o "hfp"
    property var signalStrength: null    // 0-100, in steps of 20 over HFP
    property var networkName: null
    property var networkStatus: null

    // Phone reachable and data valid.
    readonly property bool active: loaded && error === "" && connected

    // Why the icon is dimmed; empty when all is well.
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

    // 0-100 → 0-5 bars; -1 when unknown.
    readonly property int signalBars: signalStrength === null ? -1
        : Math.max(0, Math.min(5, Math.round(signalStrength / 20)))
    readonly property string signalText: signalBars < 0 ? dash
        : i18n("%1 % (%2/5)", signalStrength, signalBars)

    readonly property string networkText: networkName === null || networkName === "" ? dash : networkName

    // The iPhone does not report whether it is charging (its Battery Service
    // only has Battery Level, and HFP only the level), so it is estimated: a
    // level that rises between two exact LE readings means charging, one that
    // drops means not. Unchanged levels keep the last verdict, which covers a
    // phone held at 100 % on the charger.
    property bool charging: false
    property var lastExactLevel: null
    property var lastExactSource: null

    function estimateCharging() {
        const exact = active && batteryLevel !== null && (batterySource === "gatt" || batterySource === "bluez")
        if (!exact) {
            charging = false
            lastExactLevel = null
            lastExactSource = null
            return
        }
        // A new source (BlueZ's cached value against the live GATT one) is
        // not comparable with the previous reading.
        if (lastExactLevel !== null && lastExactSource === batterySource) {
            if (batteryLevel > lastExactLevel)
                charging = true
            else if (batteryLevel < lastExactLevel)
                charging = false
        }
        lastExactLevel = batteryLevel
        lastExactSource = batterySource
    }

    readonly property string batteryIcon: {
        if (!active || batteryLevel === null)
            return "battery-missing"
        const step = Math.max(0, Math.min(100, Math.round(batteryLevel / 10) * 10))
        return "battery-" + String(step).padStart(3, "0") + (charging ? "-charging" : "")
    }
    readonly property string signalIcon: !active || signalBars < 0
        ? "network-mobile-off" : "network-mobile-" + (signalBars * 20)

    // --- Player (GetNowPlaying) ------------------------------------------

    property var nowPlaying: null        // the GetNowPlaying answer
    property double mediaFetchedAt: 0    // when it arrived, in ms
    property double clock: Date.now()    // ticks every second during playback

    // The iPhone's track over Bluetooth (AMS): title, artist, album, duration.
    readonly property var amsTrack: nowPlaying && nowPlaying.available === true && nowPlaying.track
        ? nowPlaying.track : null
    readonly property bool amsPlaying: amsTrack !== null && !!nowPlaying.player
        && nowPlaying.player.state === "playing"

    // shairport-sync (AirPlay to this computer), read over MPRIS: {status,
    // title, artist, album, art, length} or null.
    property var airplay: null
    readonly property bool airplayPlaying: !!airplay && airplay.status === "Playing"
    readonly property bool airplaySameTrack: !!airplay && amsTrack !== null
        && Util.sameTitle(airplay.title, amsTrack.title)
    // AirPlay plays a different track from the one AMS reports (another app,
    // for instance): that one is shown.
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
    // AMS gives the elapsed time; shairport-sync does not, so without AMS there
    // is no bar.
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

    // Artwork: shairport-sync's when it is the same track, otherwise the iTunes
    // search (when enabled); "" without artwork.
    property var artworkCache: ({})      // "artista|titolo" → URL, "" se assente
    readonly property string artworkKey: track ? (track.artist || "") + "|" + (track.title || "") : ""
    readonly property string artwork: {
        if (airplay && airplay.art !== "" && (showAirplay || airplaySameTrack))
            return airplay.art
        return onlineArtwork && artworkKey !== "" ? artworkCache[artworkKey] || "" : ""
    }
    onArtworkKeyChanged: fetchArtwork()
    onOnlineArtworkChanged: fetchArtwork()

    // The last error of a player command, shown for a few seconds.
    property string mediaError: ""

    // --- Recent calls (ListCallHistory, GetContactPhoto) -----------------

    property var calls: []               // [{direction, timestamp, address, name, contact_name}]
    property var photos: ({})            // number → data URI, "" without a photo
    property var photoQueue: []
    property bool photoBusy: false

    // --- Notifications: SMS (ListEvents) and apps (Plasma's model) -------

    property var messages: []            // [{kind, app, title, body, time}]
    property var appNotifications: []    // same keys, plus id
    property int unseen: 0               // arrived since the popup was last opened

    readonly property var notifications: messages.concat(appNotifications)
        .sort((a, b) => b.time - a.time)

    // App name → theme icon, "" when the theme has none.
    property var appIcons: ({})

    // Looks in the icon theme, once per app, for the first candidate name that
    // exists. Kirigami.Icon reports even a missing icon as valid, so
    // kiconfinder6 (KIconThemes, part of KDE Frameworks) decides.
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

    // --- Text ------------------------------------------------------------

    function styled(text) {
        return Util.styled(text, emojiFont)
    }

    // "now", "5 min ago", "14:32", "yesterday 14:32", "Mon 14:32" or
    // "12/10/26".
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

    // --- Running commands ------------------------------------------------

    // The "executable" engine is shared by all of plasmashell and identifies
    // sources by the command text. The trailing comment with the applet id and
    // a counter gives every call its own source: otherwise two copies of the
    // applet, or two identical calls, would compete for the same run.
    property var pending: ({})
    property int sequence: 0

    function run(command, callback) {
        sequence += 1
        const source = command + " # org.matt.iphonestatus " + Plasmoid.id + " " + sequence
        pending[source] = callback
        executable.connectSource(source)
    }

    // A BlueFerry method; args is already shell-ready.
    function call(method, args, callback) {
        run(gdbusCall + method + (args ? " " + args : ""), callback)
    }

    // A string for gdbus: a quoted GVariant literal, then quoted for the shell.
    // Use it only with text that was already validated.
    function gvariantArg(text) {
        return Util.shellQuote('"' + text + '"')
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            // An update without an exit code arrives before the process has
            // finished: wait for the real result.
            if (data["exit code"] === undefined)
                return
            disconnectSource(source)
            const callback = root.pending[source]
            delete root.pending[source]
            if (callback)
                callback(data["exit code"], data["stdout"] || "", data["stderr"] || "")
        }
    }

    // --- Reading the data ------------------------------------------------

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
        estimateCharging()
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
        estimateCharging()
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

    // shairport-sync exposes the AirPlay track over MPRIS, with the artwork in
    // a file of its cache.
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
                // Only files in shairport-sync's cache.
                art: art.startsWith("file:///tmp/shairport-sync/") ? art : "",
                length: isNaN(length) ? 0 : length / 1000000
            }
        })
    }

    // The artwork from the iTunes search API, one request per track.
    function fetchArtwork() {
        if (!onlineArtwork || !track || !track.title || artworkCache[artworkKey] !== undefined)
            return
        const key = artworkKey
        const remember = url => {
            const next = Object.assign({}, artworkCache)
            next[key] = url
            artworkCache = next
        }
        remember("")   // marks the request as done, even if it fails
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

    // A player command. While BlueFerry has no list of the iPhone's commands
    // yet it is tried anyway: a refusal shows up in the popup.
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

    // One photo at a time: the answers are a few hundred KB each.
    function fetchNextPhoto() {
        if (photoBusy || photoQueue.length === 0)
            return
        const address = photoQueue.shift()
        photoBusy = true
        call("Messages1.GetContactPhoto", gvariantArg(address), (code, out) => {
            photoBusy = false
            // An error (photos being updated) leaves the number to retry on the
            // next round.
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

    // --- App notifications, from Plasma's model --------------------------

    // Plain text from the model's (possibly HTML) text, without the invisible
    // characters that BlueFerry renders as "�".
    function plainText(text) {
        return Util.cleanText(String(text || "").replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"')
            .replace(/&#39;|&apos;/g, "'").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&"))
    }

    readonly property string phoneMark: "📱"   // 📱, prefix of ANCS titles

    function captureNotification(row) {
        const index = notificationModel.index(row, 0)
        const role = which => notificationModel.data(index, which)
        if (role(NotificationManager.Notifications.ApplicationNameRole) !== "BlueFerry")
            return
        // BlueFerry titles app notifications "📱 App · Title"; SMS and missed
        // calls already come from its own lists.
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

    // --- Timers ----------------------------------------------------------

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
    // Moves the track's progress bar between two reads.
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
        const lines = [i18n("Carrier: %1", networkText), charging
            ? i18n("Battery: %1, probably charging", batteryText) : i18n("Battery: %1", batteryText),
            i18n("Signal: %1", signalText)]
        if (mediaText !== "")
            lines.push((playing ? "▶ " : "⏸ ") + mediaText)
        if (unseen > 0)
            lines.push(i18np("%1 new notification", "%1 new notifications", unseen))
        return lines.join("\n")
    }

    // --- Panel -----------------------------------------------------------

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

    // Panel items visible right now: texts disappear without data, and when
    // nothing is left a phone icon keeps the applet clickable.
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
                    // The player and the notifications still make sense with
                    // the phone unreachable; the rest is dimmed.
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

    // --- Popup -----------------------------------------------------------

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
                    // The pages receive the applet as an initial property, so
                    // their bindings never see a null applet.
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
