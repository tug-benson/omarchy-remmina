import QtQuick
import qs.Commons

// Ring gauge inspired by BVisagie/omarchy-quadrant RingGauge
// Shows a single arc fraction (0..1) with a Nerd Font glyph centred.
// No numeric label — the ring itself conveys quantity.
Item {
    id: root
    property real fraction: 0
    property color color: Color.accent
    property color trackColor: Util.alpha(Color.foreground, 0.10)
    property real thickness: Style.space(7)
    property string glyph: "󰢹"
    property real glyphSize: Style.font.title + 4
    property real size: Style.space(72)
    property string label: ""

    implicitWidth: size
    implicitHeight: size + (label !== "" ? Style.font.caption + Style.space(4) : 0)

    Canvas {
        id: canvas
        width: root.size
        height: root.size
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2
            var cy = height / 2
            var t = root.thickness
            var r = Math.max(1, Math.min(cx, cy) - t / 2)
            var start = -Math.PI / 2
            ctx.lineWidth = t
            ctx.lineCap = "round"
            // track
            ctx.strokeStyle = root.trackColor
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.stroke()
            // fraction
            var f = Number(root.fraction) || 0
            f = f < 0 ? 0 : (f > 1 ? 1 : f)
            if (f > 0) {
                ctx.strokeStyle = root.color
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + f * 2 * Math.PI)
                ctx.stroke()
            }
        }
        onVisibleChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }

    // glyph centred in ring (offset -2px to compensate Nerd Font side-bearing, was 1px right)
    Text {
        anchors.centerIn: canvas
        anchors.horizontalCenterOffset: -2
        anchors.verticalCenterOffset: -1
        textFormat: Text.PlainText
        text: root.glyph
        color: root.color
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: root.glyphSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // label below ring (Windows / Linux / Total)
    Text {
        visible: root.label !== ""
        anchors.top: canvas.bottom
        anchors.topMargin: Style.space(4)
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        textFormat: Text.PlainText
        text: root.label
        color: Qt.darker(root.color, 1.2)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    onFractionChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onThicknessChanged: canvas.requestPaint()
}
