// La foto rotonda di un contatto, oppure le sue iniziali su un colore che
// dipende dal nome. Kirigami.Avatar in KF6 sta in Kirigami Addons, che non
// fa parte di Plasma.
import QtQuick
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "util.js" as Util

Item {
    id: avatar

    property string source
    property string name

    readonly property string initials: Util.initials(name)

    // Una tinta stabile per nome, come fanno le rubriche.
    readonly property color tint: {
        let hash = 0
        for (let i = 0; i < name.length; ++i)
            hash = (hash * 31 + name.charCodeAt(i)) >>> 0
        return Qt.hsla((hash % 360) / 360, 0.45, 0.45, 1)
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: avatar.tint
        visible: photo.status !== Image.Ready

        PlasmaComponents.Label {
            anchors.centerIn: parent
            visible: avatar.initials !== ""
            text: avatar.initials
            color: "white"
            font.bold: true
            font.pixelSize: parent.height * 0.4
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            visible: avatar.initials === ""
            width: parent.width * 0.6
            height: width
            source: "user-identity"
            color: "white"
            isMask: true
        }
    }

    RoundedImage {
        id: photo
        anchors.fill: parent
        radius: width / 2
        source: avatar.source
    }
}
