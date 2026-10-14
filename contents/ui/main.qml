// Stato iPhone: batteria, segnale e rete dell'iPhone letti da BlueFerry.
//
// `blueferry phone-status --json` espone le cinque chiavi phone_* ma non dice
// se l'iPhone è connesso, quindi l'applet chiama direttamente il metodo D-Bus
// che anche il CLI usa: io.weirdware.BlueFerry.Messages1.GetStatus, che
// restituisce un'unica stringa JSON con tutto lo stato del backend.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import "order.js" as Order

PlasmoidItem {
    id: root

    // LC_ALL=C: i messaggi di errore di gdbus restano in inglese, così si
    // possono riconoscere. Il timeout evita che una chiamata bloccata
    // sovrapponga i cicli di polling.
    readonly property string command: "LC_ALL=C gdbus call --session --timeout 5"
        + " --dest io.weirdware.BlueFerry --object-path /io/weirdware/BlueFerry"
        + " --method io.weirdware.BlueFerry.Messages1.GetStatus"
    readonly property int pollInterval: 10000
    readonly property string dash: "—"

    readonly property string title: Plasmoid.configuration.title.trim() || i18n("iPhone")
    readonly property var panelItems: Order.shown(Plasmoid.configuration.panelItems, Order.PANEL_IDS)
    readonly property var popupItems: Order.shown(Plasmoid.configuration.popupItems, Order.POPUP_IDS)

    // Esito dell'ultima lettura.
    property bool loaded: false
    property string error: ""            // non vuoto: comando fallito o daemon spento
    property bool connected: false       // BR/EDR o LE dell'iPhone collegati
    property string connectivityDetail: ""
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
            return i18n("Lettura dello stato in corso…")
        if (error !== "")
            return error
        if (!connected)
            return connectivityDetail !== ""
                ? i18n("iPhone non connesso (%1)", connectivityDetail)
                : i18n("iPhone non connesso")
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

    function sourceText(source) {
        switch (source) {
        case "gatt": return i18n("Bluetooth LE (GATT), esatta")
        case "bluez": return i18n("Bluetooth LE (BlueZ)")
        case "hfp": return i18n("Vivavoce HFP, passi del 20 %")
        case null: return dash
        default: return source
        }
    }

    function registrationText(status) {
        switch (status) {
        case "registered": return i18n("Registrato")
        case "roaming": return i18n("In roaming")
        case "searching": return i18n("Ricerca rete…")
        case "unregistered": return i18n("Non registrato")
        case "denied": return i18n("Registrazione negata")
        case "unknown": return i18n("Sconosciuto")
        case null: return dash
        default: return status
        }
    }

    // gdbus stampa la risposta come tupla GVariant: ('…json…',) con la stringa
    // tra apici singoli (o doppi se contiene un apice) e i caratteri speciali
    // con escape. Restituisce la stringa decodificata, o null.
    function gvariantString(text) {
        const match = /^\s*\((['"])([\s\S]*)\1,\)\s*$/.exec(text)
        if (!match)
            return null
        const simple = { a: "\x07", b: "\b", f: "\f", n: "\n", r: "\r", t: "\t", v: "\v" }
        return match[2].replace(/\\(u[0-9a-fA-F]{4}|U[0-9a-fA-F]{8}|x[0-9a-fA-F]{2}|[\s\S])/g,
            (all, esc) => {
                if (esc.length > 1)
                    return String.fromCodePoint(parseInt(esc.slice(1), 16))
                return simple[esc] !== undefined ? simple[esc] : esc
            })
    }

    function describeFailure(exitCode, stderr) {
        if (exitCode === 127 || /not found/i.test(stderr) && !/GDBus\.Error/.test(stderr))
            return i18n("Comando gdbus non trovato")
        if (/ServiceUnknown|NameHasNoOwner|not provided by any/.test(stderr))
            return i18n("BlueFerry non è in esecuzione")
        if (/NoReply|Timeout|timed out/i.test(stderr))
            return i18n("BlueFerry non risponde")
        if (/AccessDenied|NotAuthorized/.test(stderr))
            return i18n("BlueFerry ha negato l'accesso allo stato")
        const line = stderr.trim().split("\n")[0].replace(/^Error:\s*/, "").replace(/^GDBus\.Error:/, "")
        return line !== "" ? i18n("Errore: %1", line) : i18n("Il comando è terminato con codice %1", exitCode)
    }

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

    function apply(exitCode, stdout, stderr) {
        loaded = true
        lastUpdate = new Date()
        if (exitCode !== 0) {
            clearPhone()
            error = describeFailure(exitCode, stderr || "")
            return
        }
        let status
        try {
            const json = gvariantString(stdout)
            if (json === null)
                throw new Error("formato")
            status = JSON.parse(json)
        } catch (e) {
            clearPhone()
            error = i18n("Risposta di BlueFerry non leggibile")
            return
        }
        if (status.daemon === false) {
            clearPhone()
            error = i18n("Il daemon BlueFerry non è attivo")
            return
        }
        error = ""
        connected = status.bredr === true || status.le === true
        connectivityDetail = status.connectivity_detail || ""
        batteryLevel = typeof status.phone_battery_level === "number" ? status.phone_battery_level : null
        batterySource = nullable(status.phone_battery_source)
        signalStrength = typeof status.phone_signal_strength === "number" ? status.phone_signal_strength : null
        networkName = nullable(status.phone_network_name)
        networkStatus = nullable(status.phone_network_status)
    }

    function refresh() {
        executable.connectSource(command)
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            root.apply(data["exit code"], data["stdout"], data["stderr"])
        }
    }

    Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    onExpandedChanged: if (expanded) refresh()

    // Elementi del pannello visibili adesso: i testi spariscono senza dati, e
    // se non resta niente un'icona del telefono tiene l'applet cliccabile.
    readonly property var panelVisible: {
        const items = panelItems.filter(id => id === "title" || id.endsWith("Icon")
            || active && panelText(id) !== dash)
        return items.length > 0 ? items : ["placeholder"]
    }

    function panelIcon(id) {
        switch (id) {
        case "batteryIcon": return batteryIcon
        case "signalIcon": return signalIcon
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
        default: return ""
        }
    }

    function rowIcon(id) {
        switch (id) {
        case "battery": return batteryIcon
        case "signal": return signalIcon
        case "bluetooth": return active ? "network-connect" : "network-disconnect"
        default: return ""
        }
    }

    function rowCaption(id) {
        switch (id) {
        case "battery": return i18n("Batteria:")
        case "source": return i18n("Fonte:")
        case "signal": return i18n("Segnale:")
        case "operator": return i18n("Operatore:")
        case "registration": return i18n("Registrazione:")
        case "bluetooth": return i18n("Bluetooth:")
        default: return ""
        }
    }

    function rowValue(id) {
        switch (id) {
        case "battery": return batteryText
        case "source": return sourceText(batterySource)
        case "signal": return signalText
        case "operator": return networkText
        case "registration": return registrationText(networkStatus)
        case "bluetooth":
            return !loaded || error !== "" ? dash : connected ? i18n("Connesso") : i18n("Disconnesso")
        default: return ""
        }
    }

    Plasmoid.icon: "smartphone"
    Plasmoid.title: title
    toolTipMainText: title
    toolTipTextFormat: Text.PlainText
    toolTipSubText: active
        ? i18n("Operatore: %1\nBatteria: %2\nSegnale: %3", networkText, batteryText, signalText)
        : reason

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
            opacity: root.active ? 1 : 0.5

            Repeater {
                model: root.panelVisible

                delegate: Item {
                    id: element
                    required property string modelData
                    readonly property string icon: root.panelIcon(modelData)

                    implicitWidth: icon !== "" ? compact.iconSize
                        : compact.vertical ? Math.min(label.implicitWidth, compact.width) : label.implicitWidth
                    implicitHeight: icon !== "" ? compact.iconSize : label.implicitHeight
                    Layout.alignment: Qt.AlignCenter

                    Kirigami.Icon {
                        anchors.fill: parent
                        visible: element.icon !== ""
                        source: element.icon
                    }
                    PlasmaComponents.Label {
                        id: label
                        anchors.fill: parent
                        visible: element.icon === ""
                        text: root.panelText(element.modelData)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Layout.minimumHeight
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

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
                        text: root.title
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    PlasmaComponents.Label {
                        text: root.active ? i18n("Connesso") : i18n("Disconnesso")
                        color: root.active ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                        font: Kirigami.Theme.smallFont
                        Layout.fillWidth: true
                    }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Aggiorna")
                    onClicked: root.refresh()
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents.Label {
                visible: root.reason !== ""
                text: root.reason
                wrapMode: Text.Wrap
                color: root.loaded ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                Layout.fillWidth: true
            }

            // Tre colonne (icona, etichetta, valore) riempite da tre Repeater:
            // ogni cella dichiara riga e colonna, così l'ordine resta quello
            // scelto nelle impostazioni.
            GridLayout {
                visible: root.popupItems.length > 0
                columns: 3
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.smallSpacing
                Layout.fillWidth: true

                Repeater {
                    model: root.popupItems
                    delegate: Kirigami.Icon {
                        required property string modelData
                        required property int index
                        source: root.rowIcon(modelData)
                        Layout.row: index
                        Layout.column: 0
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }
                }
                Repeater {
                    model: root.popupItems
                    delegate: PlasmaComponents.Label {
                        required property string modelData
                        required property int index
                        text: root.rowCaption(modelData)
                        opacity: 0.7
                        Layout.row: index
                        Layout.column: 1
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    }
                }
                Repeater {
                    model: root.popupItems
                    delegate: PlasmaComponents.Label {
                        required property string modelData
                        required property int index
                        text: root.rowValue(modelData)
                        wrapMode: Text.Wrap
                        Layout.row: index
                        Layout.column: 2
                        Layout.fillWidth: true
                    }
                }
            }

            Item { Layout.fillHeight: true }

            PlasmaComponents.Label {
                visible: root.loaded
                text: i18n("Aggiornato alle %1", Qt.formatTime(root.lastUpdate, "hh:mm:ss"))
                font: Kirigami.Theme.smallFont
                opacity: 0.6
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
