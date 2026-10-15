// Un'immagine con gli angoli arrotondati (un cerchio con radius pari a metà
// del lato). Il ritaglio usa QtQuick.Effects di Qt, senza dipendenze extra.
import QtQuick
import QtQuick.Effects

Item {
    id: rounded

    property alias source: image.source
    property real radius: 0
    readonly property alias status: image.status

    Image {
        id: image
        anchors.fill: parent
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: rounded.radius
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        visible: image.status === Image.Ready
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
