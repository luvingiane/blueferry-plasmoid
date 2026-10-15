// An image with rounded corners (a circle with radius set to half the side).
// The clipping uses Qt's QtQuick.Effects, with no extra dependency.
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
