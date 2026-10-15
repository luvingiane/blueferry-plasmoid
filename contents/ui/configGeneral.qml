// The settings page: the title and which items to show, and in what order, in
// the panel and the popup.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "order.js" as Order

KCM.SimpleKCM {
    id: page

    property alias cfg_title: title.text
    property var cfg_panelItems: []
    property var cfg_statusSections: []
    property alias cfg_onlineArtwork: onlineArtwork.checked
    property var cfg_popupTabs: []
    property string cfg_emojiFont

    // Plasma also hands the page every default value.
    property string cfg_titleDefault
    property var cfg_panelItemsDefault: []
    property var cfg_statusSectionsDefault: []
    property bool cfg_onlineArtworkDefault
    property var cfg_popupTabsDefault: []
    property string cfg_emojiFontDefault

    Kirigami.FormLayout {
        QQC2.TextField {
            id: title
            Kirigami.FormData.label: i18n("Title:")
            placeholderText: i18n("iPhone")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Panel")
        }

        OrderList {
            Kirigami.FormData.label: i18n("Items:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            ids: Order.PANEL_IDS
            labels: ({
                batteryIcon: i18n("Battery icon"),
                batteryText: i18n("Battery percentage"),
                signalIcon: i18n("Signal icon"),
                signalText: i18n("Signal percentage"),
                operator: i18n("Carrier"),
                title: i18n("Title"),
                media: i18n("Now playing"),
                notifications: i18n("New notification count")
            })
            entries: page.cfg_panelItems
            onEdited: entries => page.cfg_panelItems = entries
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Popup")
        }

        OrderList {
            Kirigami.FormData.label: i18n("Tabs:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            ids: Order.TAB_IDS
            labels: ({
                status: i18n("Status"),
                notifications: i18n("Notifications"),
                player: i18n("Player"),
                calls: i18n("Recent calls")
            })
            entries: page.cfg_popupTabs
            onEdited: entries => page.cfg_popupTabs = entries
        }

        OrderList {
            Kirigami.FormData.label: i18n("Status sections:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            ids: Order.SECTION_IDS
            labels: ({
                battery: i18n("Battery"),
                network: i18n("Cellular network"),
                bluetooth: i18n("Bluetooth")
            })
            entries: page.cfg_statusSections
            onEdited: entries => page.cfg_statusSections = entries
        }

        QQC2.CheckBox {
            id: onlineArtwork
            Kirigami.FormData.label: i18n("Artwork:")
            text: i18n("Look it up online on iTunes")
        }
        QQC2.Label {
            text: i18n("The iPhone does not send artwork over Bluetooth. During AirPlay it comes from shairport-sync; otherwise the artist and title are looked up with the iTunes API.")
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }

        QQC2.ComboBox {
            id: emojiFont
            Kirigami.FormData.label: i18n("Emoji font:")
            editable: true
            // The installed fonts with "emoji" in their name, plus the chosen
            // one.
            model: {
                const fonts = Qt.fontFamilies().filter(name => /emoji/i.test(name))
                if (page.cfg_emojiFont !== "" && fonts.indexOf(page.cfg_emojiFont) < 0)
                    fonts.unshift(page.cfg_emojiFont)
                return fonts
            }
            Component.onCompleted: editText = page.cfg_emojiFont
            onActivated: page.cfg_emojiFont = currentText
            onAccepted: page.cfg_emojiFont = editText
            Connections {
                target: page
                function onCfg_emojiFontChanged() {
                    if (emojiFont.editText !== page.cfg_emojiFont)
                        emojiFont.editText = page.cfg_emojiFont
                }
            }
        }

        QQC2.Label {
            text: i18n("The network type (LTE, 5G…) is not available: the iPhone's Bluetooth hands-free profile does not report it.")
            wrapMode: Text.Wrap
            opacity: 0.7
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
