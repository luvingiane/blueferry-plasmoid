// La scheda Player, nello stile del lettore multimediale di Plasma: sfondo
// con la copertina sfocata, copertina, titolo, avanzamento e comandi. Il brano
// viene dall'iPhone (Apple Media Service tramite BlueFerry) o da AirPlay
// (shairport-sync); la copertina da shairport-sync o dalla ricerca di iTunes.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property var applet

    readonly property var track: applet.track
    readonly property var player: applet.nowPlaying && applet.nowPlaying.player ? applet.nowPlaying.player : null
    readonly property bool hasVolume: !applet.showAirplay && !!player && typeof player.volume === "number"
    readonly property real artSize: Math.max(Kirigami.Units.gridUnit * 5,
        Math.min(width - Kirigami.Units.gridUnit * 6, height * 0.38))

    // Un componente inline non vede gli id del file: l'applet gli arriva
    // come proprietà. Se BlueFerry non ha ancora la lista dei comandi
    // dell'iPhone il pulsante resta attivo e il comando si prova comunque.
    component MediaButton: PlasmaComponents.ToolButton {
        required property var applet
        property string command
        property int size: Kirigami.Units.iconSizes.medium
        enabled: applet.mediaCommands.length === 0 || applet.mediaCommands.indexOf(command) >= 0
            || (command === "toggle" && applet.mediaCommands.indexOf(applet.amsPlaying ? "pause" : "play") >= 0)
        display: PlasmaComponents.AbstractButton.IconOnly
        icon.width: size
        icon.height: size
        onClicked: applet.mediaCommand(command)
        PlasmaComponents.ToolTip.text: text
        PlasmaComponents.ToolTip.visible: hovered
        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
    }

    // Sfondo: la copertina sfocata e attenuata.
    Item {
        anchors.fill: parent
        clip: true
        visible: page.applet.mediaAvailable && backgroundArt.status === Image.Ready

        Image {
            id: backgroundArt
            anchors.fill: parent
            source: page.applet.artwork
            sourceSize.width: 256
            sourceSize.height: 256
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: backgroundArt
            blurEnabled: true
            blurMax: 64
            blur: 1.0
            saturation: 0.3
            opacity: 0.25
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        visible: page.applet.mediaAvailable
        spacing: Kirigami.Units.smallSpacing

        Item { Layout.fillHeight: true }

        Item {
            Layout.preferredWidth: page.artSize
            Layout.preferredHeight: page.artSize
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Kirigami.Units.largeSpacing

            Rectangle {
                anchors.fill: parent
                radius: Kirigami.Units.cornerRadius * 2
                color: Kirigami.Theme.alternateBackgroundColor
                visible: art.status !== Image.Ready
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: parent.width * 0.45
                    height: width
                    source: "audio-x-generic"
                }
            }
            RoundedImage {
                id: art
                anchors.fill: parent
                radius: Kirigami.Units.cornerRadius * 2
                source: page.applet.artwork
            }
        }

        PlasmaExtras.Heading {
            level: 2
            text: page.applet.styled(page.track ? page.track.title || i18n("Senza titolo") : "")
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        PlasmaComponents.Label {
            visible: text !== ""
            text: page.applet.styled(page.track ? page.track.artist || "" : "")
            textFormat: Text.StyledText
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        PlasmaComponents.Label {
            visible: text !== ""
            text: page.applet.styled(page.track ? page.track.album || "" : "")
            textFormat: Text.StyledText
            elide: Text.ElideRight
            opacity: 0.7
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }

        RowLayout {
            visible: page.applet.mediaHasProgress
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing

            PlasmaComponents.Label {
                text: page.applet.durationText(page.applet.mediaElapsed)
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
            PlasmaComponents.ProgressBar {
                from: 0
                to: page.applet.mediaDuration
                value: page.applet.mediaElapsed
                Layout.fillWidth: true
            }
            PlasmaComponents.Label {
                text: page.applet.durationText(page.applet.mediaDuration)
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }

        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.smallSpacing

            MediaButton {
                applet: page.applet
                command: "previous"
                icon.name: "media-skip-backward"
                text: i18n("Precedente")
            }
            MediaButton {
                applet: page.applet
                command: "toggle"
                size: Kirigami.Units.iconSizes.large
                icon.name: page.applet.playing ? "media-playback-pause" : "media-playback-start"
                text: page.applet.playing ? i18n("Pausa") : i18n("Riproduci")
            }
            MediaButton {
                applet: page.applet
                command: "next"
                icon.name: "media-skip-forward"
                text: i18n("Successivo")
            }
        }

        RowLayout {
            visible: page.hasVolume
            spacing: Kirigami.Units.smallSpacing
            Layout.alignment: Qt.AlignHCenter

            MediaButton {
                applet: page.applet
                command: "volume-down"
                size: Kirigami.Units.iconSizes.small
                icon.name: "audio-volume-low"
                text: i18n("Abbassa il volume")
            }
            PlasmaComponents.ProgressBar {
                from: 0
                to: 1
                value: page.hasVolume ? page.player.volume : 0
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
            }
            MediaButton {
                applet: page.applet
                command: "volume-up"
                size: Kirigami.Units.iconSizes.small
                icon.name: "audio-volume-high"
                text: i18n("Alza il volume")
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.applet.mediaError !== ""
            type: Kirigami.MessageType.Error
            text: i18n("BlueFerry ha rifiutato il comando: %1", page.applet.mediaError)
        }

        PlasmaComponents.Label {
            text: page.applet.mediaSource
            font: Kirigami.Theme.smallFont
            opacity: 0.6
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true }
    }

    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: !page.applet.mediaAvailable
        iconName: "media-playback-stop"
        text: i18n("Niente in riproduzione")
        explanation: {
            const status = page.applet.nowPlaying
            if (!status)
                return i18n("BlueFerry non ha risposto sul player.")
            if (status.enabled === false)
                return i18n("Il controllo dei media è spento in BlueFerry: «blueferry media enable».")
            if (status.available !== true)
                return i18n("Il player dell'iPhone non è raggiungibile (serve il collegamento Bluetooth LE).")
            return i18n("Avvia la musica sull'iPhone e comparirà qui.")
        }
    }
}
