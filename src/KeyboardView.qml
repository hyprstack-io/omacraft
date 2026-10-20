import QtQuick
import QtQuick.Controls

// The keyboard as it lights, key for key, laid out like the laptop's. With
// `interactive`, a left click or drag paints keys with the brush and a right
// click erases them.
Item {
    id: board

    property var colors: lights.frame
    property bool interactive: false
    property bool labels: true
    // The soft underglow round each key; off for the small tiles.
    property bool glow: true

    readonly property real unit: Math.min(width / 15, height / 6)
    readonly property real gap: Math.max(1, unit * 0.09)

    implicitHeight: width * 6 / 15

    function keyAt(px, py) {
        const ux = (px - deck.x) / unit, uy = (py - deck.y) / unit;
        const keys = lights.keys;
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i];
            if (ux >= k.x && ux < k.x + k.w && uy >= k.y && uy < k.y + k.h)
                return k;
        }
        return null;
    }

    Item {
        id: deck
        width: board.unit * 15
        height: board.unit * 6
        anchors.centerIn: parent

        Repeater {
            model: lights.keys
            delegate: Item {
                id: key
                required property var modelData
                required property int index
                readonly property color led: board.colors[index] || "#000000"
                readonly property real level: Math.max(led.r, led.g, led.b)
                readonly property real luma: 0.2126 * led.r + 0.7152 * led.g + 0.0722 * led.b

                x: modelData.x * board.unit + board.gap / 2
                y: modelData.y * board.unit + board.gap / 2
                width: modelData.w * board.unit - board.gap
                height: modelData.h * board.unit - board.gap

                // Light spilling from under the cap.
                Rectangle {
                    visible: board.glow && key.modelData.lit && key.level > 0.04
                    anchors.centerIn: parent
                    width: parent.width + board.unit * 0.22
                    height: parent.height + board.unit * 0.22
                    radius: board.unit * 0.2
                    color: key.led
                    opacity: 0.28 * key.level
                }
                Rectangle {
                    anchors.fill: parent
                    radius: board.unit * 0.12
                    // A dark key still shows its shape; a lit one takes the
                    // led's colour.
                    color: key.modelData.lit
                           ? Qt.rgba(0.075 + key.led.r * 0.925, 0.075 + key.led.g * 0.925, 0.085 + key.led.b * 0.915, 1)
                           : theme.sunken
                    border.color: key.modelData.lit ? Qt.lighter(color, 1.25) : theme.border
                    border.width: 1

                    Label {
                        visible: board.labels
                        anchors.centerIn: parent
                        width: parent.width - 4
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: key.modelData.lit ? key.modelData.label : "no light"
                        color: !key.modelData.lit ? theme.textFaint : key.luma > 0.45 ? "#000000" : "#ffffff"
                        opacity: key.modelData.lit ? 0.78 : 1
                        font.pixelSize: Math.max(7, board.unit * (key.modelData.h < 1 ? 0.22 : 0.26))
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: board.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: board.interactive ? Qt.CrossCursor : Qt.ArrowCursor
        property bool erasing: false

        function touch(mouse) {
            const k = board.keyAt(mouse.x, mouse.y);
            if (!k || !k.lit) return;
            if (erasing) lights.eraseKey(k.id);
            else lights.paintKey(k.id);
        }
        onPressed: mouse => { erasing = mouse.button === Qt.RightButton; touch(mouse); }
        onPositionChanged: mouse => { if (pressed) touch(mouse); }
        onReleased: lights.endStroke()
        onCanceled: lights.endStroke()
    }
}
