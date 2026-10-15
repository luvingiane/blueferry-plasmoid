// La scheda Notifiche, nello stile del centro notifiche dell'iPhone: icona
// dell'app a sinistra, titolo in grassetto con l'ora, testo sotto. Gli SMS
// vengono dallo storico di BlueFerry, le altre dal modello di Plasma.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

Item {
    id: page

    required property var applet

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: page.applet.notifications.length > 0

        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: i18np("%1 notifica", "%1 notifiche", page.applet.notifications.length)
                opacity: 0.7
                Layout.fillWidth: true
            }
            PlasmaComponents.ToolButton {
                visible: page.applet.appNotifications.length > 0
                icon.name: "edit-clear-history"
                text: i18n("Cancella")
                onClicked: page.applet.clearNotifications()
                PlasmaComponents.ToolTip.text: i18n("Cancella le notifiche delle app (gli SMS restano in BlueFerry)")
                PlasmaComponents.ToolTip.visible: hovered
                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            contentItem: ListView {
                id: list
                model: page.applet.notifications
                clip: true

                delegate: Item {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property string heading: modelData.title !== "" ? modelData.title : modelData.app
                    readonly property string appIcon: page.applet.appIcons[modelData.app] || ""

                    width: ListView.view.width
                    implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2

                    RowLayout {
                        id: content
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.largeSpacing

                        // Icona dell'app; senza corrispondenza nel tema, la
                        // campanella col telefono in basso a destra.
                        Item {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.large
                            Layout.preferredHeight: Kirigami.Units.iconSizes.large
                            Layout.alignment: Qt.AlignTop

                            Kirigami.Icon {
                                anchors.fill: parent
                                source: entry.appIcon !== "" ? entry.appIcon : "preferences-desktop-notification-bell"
                            }
                            Kirigami.Icon {
                                visible: entry.appIcon === ""
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                width: Kirigami.Units.iconSizes.small
                                height: width
                                source: "phone-symbolic"
                            }
                        }

                        ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing / 2
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Layout.fillWidth: true
                                PlasmaComponents.Label {
                                    text: page.applet.styled(entry.heading)
                                    textFormat: Text.StyledText
                                    font.bold: true
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    Layout.fillWidth: true
                                }
                                PlasmaComponents.Label {
                                    text: page.applet.timeText(entry.modelData.time)
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.7
                                }
                            }
                            PlasmaComponents.Label {
                                visible: entry.modelData.body !== ""
                                text: page.applet.styled(entry.modelData.body)
                                textFormat: Text.StyledText
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Kirigami.Separator {
                        visible: entry.index < list.count - 1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Kirigami.Units.largeSpacing * 2 + Kirigami.Units.iconSizes.large
                    }
                }
            }
        }
    }

    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        visible: page.applet.notifications.length === 0
        iconName: "notifications"
        text: i18n("Nessuna notifica")
        explanation: i18n("Gli SMS arrivano dallo storico di BlueFerry. Le notifiche delle app compaiono qui da quando Plasma è avviato, perché Plasma non le conserva.")
    }
}
