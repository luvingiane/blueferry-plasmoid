// Una lista di elementi da mostrare o nascondere e da riordinare con le
// frecce. Non salva niente: annuncia la nuova lista con edited().
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "order.js" as Order

ColumnLayout {
    id: list

    property var entries: []
    property var ids: []
    property var labels: ({})

    signal edited(var entries)

    readonly property var items: Order.parse(entries, ids)

    function copy() {
        return items.map(item => ({ id: item.id, shown: item.shown }))
    }

    function move(from, to) {
        const next = copy()
        const moved = next.splice(from, 1)[0]
        next.splice(to, 0, moved)
        edited(Order.serialize(next))
    }

    function toggle(index, shown) {
        const next = copy()
        next[index].shown = shown
        edited(Order.serialize(next))
    }

    spacing: 0

    Repeater {
        model: list.items

        delegate: RowLayout {
            required property var modelData
            required property int index

            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            QQC2.CheckBox {
                text: list.labels[modelData.id] || modelData.id
                checked: modelData.shown
                onToggled: list.toggle(index, checked)
                Layout.fillWidth: true
            }
            QQC2.ToolButton {
                icon.name: "arrow-up"
                text: i18n("Sposta su")
                display: QQC2.AbstractButton.IconOnly
                enabled: index > 0
                onClicked: list.move(index, index - 1)
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            QQC2.ToolButton {
                icon.name: "arrow-down"
                text: i18n("Sposta giù")
                display: QQC2.AbstractButton.IconOnly
                enabled: index < list.items.length - 1
                onClicked: list.move(index, index + 1)
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }
    }
}
