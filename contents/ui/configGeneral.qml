// La pagina delle impostazioni: il titolo e quali elementi mostrare, e in che
// ordine, nel pannello e nel popup.
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

    // Plasma passa alla pagina anche i valori predefiniti.
    property string cfg_titleDefault
    property var cfg_panelItemsDefault: []
    property var cfg_statusSectionsDefault: []
    property bool cfg_onlineArtworkDefault
    property var cfg_popupTabsDefault: []
    property string cfg_emojiFontDefault

    Kirigami.FormLayout {
        QQC2.TextField {
            id: title
            Kirigami.FormData.label: i18n("Titolo:")
            placeholderText: i18n("iPhone")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Pannello")
        }

        OrderList {
            Kirigami.FormData.label: i18n("Elementi:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            ids: Order.PANEL_IDS
            labels: ({
                batteryIcon: i18n("Icona batteria"),
                batteryText: i18n("Percentuale batteria"),
                signalIcon: i18n("Icona segnale"),
                signalText: i18n("Percentuale segnale"),
                operator: i18n("Operatore"),
                title: i18n("Titolo"),
                media: i18n("Brano in riproduzione"),
                notifications: i18n("Contatore notifiche nuove")
            })
            entries: page.cfg_panelItems
            onEdited: entries => page.cfg_panelItems = entries
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Popup")
        }

        OrderList {
            Kirigami.FormData.label: i18n("Schede:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            ids: Order.TAB_IDS
            labels: ({
                status: i18n("Stato"),
                notifications: i18n("Notifiche"),
                player: i18n("Player"),
                calls: i18n("Chiamate recenti")
            })
            entries: page.cfg_popupTabs
            onEdited: entries => page.cfg_popupTabs = entries
        }

        OrderList {
            Kirigami.FormData.label: i18n("Sezioni dello stato:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            ids: Order.SECTION_IDS
            labels: ({
                battery: i18n("Batteria"),
                network: i18n("Rete cellulare"),
                bluetooth: i18n("Bluetooth")
            })
            entries: page.cfg_statusSections
            onEdited: entries => page.cfg_statusSections = entries
        }

        QQC2.CheckBox {
            id: onlineArtwork
            Kirigami.FormData.label: i18n("Copertine:")
            text: i18n("Cercale online su iTunes")
        }
        QQC2.Label {
            text: i18n("Via Bluetooth l'iPhone non manda la copertina. Durante AirPlay arriva da shairport-sync; altrimenti si cerca artista e titolo sull'API di iTunes.")
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }

        QQC2.ComboBox {
            id: emojiFont
            Kirigami.FormData.label: i18n("Font delle emoji:")
            editable: true
            // I font installati con "emoji" nel nome, più quello scelto.
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
            text: i18n("Il tipo di rete (LTE, 5G…) non è disponibile: il profilo vivavoce Bluetooth dell'iPhone non lo trasmette.")
            wrapMode: Text.Wrap
            opacity: 0.7
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
