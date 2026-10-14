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
    property var cfg_popupItems: []

    // Plasma passa alla pagina anche i valori predefiniti.
    property string cfg_titleDefault
    property var cfg_panelItemsDefault: []
    property var cfg_popupItemsDefault: []

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
                title: i18n("Titolo")
            })
            entries: page.cfg_panelItems
            onEdited: entries => page.cfg_panelItems = entries
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Popup")
        }

        OrderList {
            Kirigami.FormData.label: i18n("Righe:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            ids: Order.POPUP_IDS
            labels: ({
                battery: i18n("Batteria"),
                source: i18n("Fonte della batteria"),
                signal: i18n("Segnale"),
                operator: i18n("Operatore"),
                registration: i18n("Registrazione"),
                bluetooth: i18n("Bluetooth")
            })
            entries: page.cfg_popupItems
            onEdited: entries => page.cfg_popupItems = entries
        }

        QQC2.Label {
            text: i18n("Il tipo di rete (LTE, 5G…) non è disponibile: il profilo vivavoce Bluetooth dell'iPhone non lo trasmette.")
            wrapMode: Text.Wrap
            opacity: 0.7
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
