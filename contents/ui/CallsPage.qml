// La scheda Chiamate: le ultime chiamate dell'iPhone (rubrica PBAP tramite
// BlueFerry), con la foto del contatto quando BlueFerry la conserva.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "util.js" as Util

Item {
    id: page

    required property var applet

    function directionIcon(direction) {
        switch (direction) {
        case "incoming": return "call-incoming"
        case "outgoing": return "call-outgoing"
        case "missed": return "call-missed"
        default: return "call-start"
        }
    }

    function directionText(direction) {
        switch (direction) {
        case "incoming": return i18n("Incoming")
        case "outgoing": return i18n("Outgoing")
        case "missed": return i18n("Missed")
        default: return ""
        }
    }

    PlasmaComponents.ScrollView {
        anchors.fill: parent
        visible: page.applet.calls.length > 0

        contentItem: ListView {
            model: page.applet.calls
            clip: true
            topMargin: Kirigami.Units.smallSpacing
            bottomMargin: Kirigami.Units.smallSpacing

            delegate: PlasmaComponents.ItemDelegate {
                id: entry
                required property var modelData
                readonly property string name: page.applet.callName(modelData)
                readonly property bool missed: modelData.direction === "missed"
                readonly property string photo: page.applet.photos[modelData.address] || ""

                width: ListView.view.width
                leftPadding: Kirigami.Units.largeSpacing
                rightPadding: Kirigami.Units.largeSpacing
                hoverEnabled: false
                down: false

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    // Foto del contatto, oppure le sue iniziali.
                    Avatar {
                        source: entry.photo
                        name: entry.name
                        Layout.preferredWidth: Kirigami.Units.iconSizes.large
                        Layout.preferredHeight: Kirigami.Units.iconSizes.large
                    }

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true

                        PlasmaComponents.Label {
                            text: page.applet.styled(entry.name)
                            textFormat: Text.StyledText
                            color: entry.missed ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                            font.bold: entry.missed
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Icon {
                                source: page.directionIcon(entry.modelData.direction)
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            }
                            PlasmaComponents.Label {
                                text: [page.directionText(entry.modelData.direction),
                                    page.applet.timeText(new Date(entry.modelData.timestamp))]
                                    .filter(part => part !== "").join(" · ")
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    PlasmaComponents.ToolButton {
                        visible: page.applet.callsEnabled && Util.isPhoneAddress(entry.modelData.address)
                        icon.name: "call-start"
                        text: i18n("Call %1 back", entry.name)
                        display: PlasmaComponents.AbstractButton.IconOnly
                        onClicked: page.applet.dial(entry.modelData.address)
                        PlasmaComponents.ToolTip.text: text
                        PlasmaComponents.ToolTip.visible: hovered
                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                }
            }
        }
    }

    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: page.applet.calls.length === 0
        iconName: "call-start"
        text: i18n("No recent calls")
        explanation: i18n("BlueFerry's call history is empty or turned off (“blueferry call-history enable”).")
    }
}
