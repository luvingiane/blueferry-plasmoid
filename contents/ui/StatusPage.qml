// The Status tab: battery, cellular network and Bluetooth as sections in the
// style of Plasma's Battery applet (icon, title and value, bar, detail), in the
// order chosen in the settings.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property var applet

    function batterySourceText(source) {
        switch (source) {
        case "gatt": return i18n("Bluetooth LE, exact value")
        case "bluez": return i18n("Bluetooth LE, through BlueZ")
        case "hfp": return i18n("Hands-free, in 20 % steps")
        default: return ""
        }
    }

    // {icon, title, value, progress (0-100, or -1 without a bar), detail}
    function section(id) {
        switch (id) {
        case "battery":
            return {
                icon: applet.batteryIcon,
                title: i18n("Battery"),
                value: applet.batteryText,
                progress: applet.active && applet.batteryLevel !== null ? applet.batteryLevel : -1,
                detail: !applet.active ? ""
                    : applet.charging ? batterySourceText(applet.batterySource) + " · " + applet.chargingText
                    : batterySourceText(applet.batterySource)
            }
        case "network": {
            const parts = []
            if (applet.networkText !== applet.dash)
                parts.push(applet.networkText)
            if (applet.wifiCalling)
                parts.push(i18n("Wi-Fi calling"))
            const registration = applet.registrationText(applet.networkStatus)
            if (registration !== applet.dash)
                parts.push(registration)
            return {
                icon: applet.signalIcon,
                title: i18n("Cellular network"),
                value: applet.signalBars < 0 ? applet.dash : i18n("%1/5", applet.signalBars),
                progress: applet.active && applet.signalStrength !== null ? applet.signalStrength : -1,
                detail: applet.active ? parts.join(" · ") : ""
            }
        }
        case "bluetooth":
            return {
                icon: applet.active ? "network-bluetooth-activated" : "network-bluetooth",
                title: i18n("Bluetooth"),
                value: !applet.loaded || applet.error !== "" ? applet.dash
                    : applet.connected ? i18n("Connected") : i18n("Disconnected"),
                progress: -1,
                detail: applet.connectivityDetail
            }
        default:
            return { icon: "", title: id, value: "", progress: -1, detail: "" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing * 2

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.applet.loaded && page.applet.reason !== ""
            type: Kirigami.MessageType.Warning
            text: page.applet.reason
        }

        Repeater {
            model: page.applet.statusSections

            delegate: RowLayout {
                id: row
                required property string modelData
                readonly property var info: page.section(modelData)

                spacing: Kirigami.Units.largeSpacing
                Layout.fillWidth: true

                Kirigami.Icon {
                    source: row.info.icon
                    fallback: "network-connect"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    Layout.alignment: Qt.AlignTop
                    opacity: page.applet.active ? 1 : 0.5
                }

                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: row.info.title
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.Label {
                            text: row.info.value
                            font.bold: true
                        }
                    }

                    PlasmaComponents.ProgressBar {
                        visible: row.info.progress >= 0
                        from: 0
                        to: 100
                        value: Math.max(0, row.info.progress)
                        Layout.fillWidth: true
                    }

                    PlasmaComponents.Label {
                        visible: row.info.detail !== ""
                        text: page.applet.styled(row.info.detail)
                        textFormat: Text.StyledText
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        PlasmaComponents.Label {
            visible: page.applet.loaded
            text: i18n("Updated at %1", Qt.formatTime(page.applet.lastUpdate, "hh:mm:ss"))
            font: Kirigami.Theme.smallFont
            opacity: 0.6
            horizontalAlignment: Text.AlignRight
            Layout.fillWidth: true
        }
    }
}
