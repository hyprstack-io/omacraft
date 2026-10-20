import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

// Any colour at all: hue round the wheel, saturation out from its middle,
// brightness on the slider below, or a hex typed in. open(hex) starts it on
// a colour; picked(hex) comes back as #rrggbb when it is applied.
Popup {
    id: picker

    property string title: "Pick a colour"
    signal picked(string hex)

    property real hue: 0
    property real sat: 0
    property real val: 1
    readonly property color current: Qt.hsva(hue, sat, val, 1)
    readonly property string hex: picker.toHex(current)

    function toHex(c) {
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }
    // Takes the hue and saturation from c, keeping the hue when c is grey.
    function setColor(c) {
        c = Qt.color(c);
        if (c.hsvSaturation > 0 && c.hsvHue >= 0)
            hue = c.hsvHue;
        sat = Math.max(0, c.hsvSaturation);
        val = Math.max(0, c.hsvValue);
    }
    function openWith(value) {
        const v = String(value || "");
        setColor(/^#[0-9a-fA-F]{6}$/.test(v) ? v : "#ffffff");
        start = hex;
        hexField.text = hex;
        open();
    }
    property string start: "#ffffff"

    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: 18
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onHexChanged: if (!hexField.activeFocus) hexField.text = hex

    background: Rectangle {
        radius: 14
        color: theme.raised
        border.color: theme.borderStrong
    }

    contentItem: ColumnLayout {
        spacing: 14

        Label { text: picker.title; color: theme.text; font.pixelSize: 15; font.weight: Font.DemiBold }

        // The wheel: a conical hue sweep, white in the middle, darkened by
        // the brightness slider.
        Item {
            id: wheel
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 240
            implicitHeight: 240
            readonly property real r: width / 2

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillGradient: ConicalGradient {
                        centerX: wheel.r; centerY: wheel.r; angle: 0
                        GradientStop { position: 0 / 6; color: Qt.hsva(0 / 6, 1, 1, 1) }
                        GradientStop { position: 1 / 6; color: Qt.hsva(1 / 6, 1, 1, 1) }
                        GradientStop { position: 2 / 6; color: Qt.hsva(2 / 6, 1, 1, 1) }
                        GradientStop { position: 3 / 6; color: Qt.hsva(3 / 6, 1, 1, 1) }
                        GradientStop { position: 4 / 6; color: Qt.hsva(4 / 6, 1, 1, 1) }
                        GradientStop { position: 5 / 6; color: Qt.hsva(5 / 6, 1, 1, 1) }
                        GradientStop { position: 6 / 6; color: Qt.hsva(0, 1, 1, 1) }
                    }
                    PathAngleArc { centerX: wheel.r; centerY: wheel.r; radiusX: wheel.r; radiusY: wheel.r; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeWidth: -1
                    fillGradient: RadialGradient {
                        centerX: wheel.r; centerY: wheel.r; centerRadius: wheel.r
                        focalX: wheel.r; focalY: wheel.r
                        GradientStop { position: 0; color: "white" }
                        GradientStop { position: 1; color: "#00ffffff" }
                    }
                    PathAngleArc { centerX: wheel.r; centerY: wheel.r; radiusX: wheel.r; radiusY: wheel.r; startAngle: 0; sweepAngle: 360 }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "black"
                opacity: 1 - picker.val
                border.color: theme.borderStrong
                border.width: 1
            }
            // Where the colour sits: hue as the angle (counter-clockwise from
            // three o'clock, as the conical gradient runs), saturation as the
            // distance out.
            Rectangle {
                width: 16; height: 16; radius: 8
                x: wheel.r + Math.cos(picker.hue * 2 * Math.PI) * picker.sat * wheel.r - width / 2
                y: wheel.r - Math.sin(picker.hue * 2 * Math.PI) * picker.sat * wheel.r - height / 2
                color: picker.current
                border.color: picker.val > 0.5 ? "black" : "white"
                border.width: 2
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                preventStealing: true
                function pick(mouse) {
                    const dx = mouse.x - wheel.r, dy = mouse.y - wheel.r;
                    picker.hue = ((Math.atan2(-dy, dx) / (2 * Math.PI)) + 1) % 1;
                    picker.sat = Math.min(1, Math.hypot(dx, dy) / wheel.r);
                    if (picker.val < 0.05)
                        picker.val = 1;
                }
                onPressed: mouse => pick(mouse)
                onPositionChanged: mouse => { if (pressed) pick(mouse); }
            }
        }

        // Brightness, black to the wheel's colour at full.
        Item {
            Layout.fillWidth: true
            implicitHeight: 22
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                radius: 7
                border.color: theme.border
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "black" }
                    GradientStop { position: 1; color: Qt.hsva(picker.hue, picker.sat, 1, 1) }
                }
            }
            Rectangle {
                width: 10; height: parent.height; radius: 4
                x: picker.val * (parent.width - width)
                color: picker.current
                border.color: theme.text
                border.width: 2
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                function pick(mouse) { picker.val = Math.max(0, Math.min(1, mouse.x / width)); }
                onPressed: mouse => pick(mouse)
                onPositionChanged: mouse => { if (pressed) pick(mouse); }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            // Before and after.
            Row {
                Rectangle { width: 30; height: 30; color: picker.start; border.color: theme.border; topLeftRadius: 7; bottomLeftRadius: 7 }
                Rectangle { width: 30; height: 30; color: picker.current; border.color: theme.border; topRightRadius: 7; bottomRightRadius: 7 }
            }
            TextField {
                id: hexField
                Layout.fillWidth: true
                font.family: "monospace"
                placeholderText: "#rrggbb"
                selectByMouse: true
                validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{0,6}/ }
                onTextEdited: {
                    const t = text.trim();
                    if (/^#?[0-9a-fA-F]{6}$/.test(t))
                        picker.setColor(t.startsWith("#") ? t : "#" + t);
                }
                onAccepted: apply.clicked()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Button { text: "Cancel"; flat: true; focusPolicy: Qt.NoFocus; onClicked: picker.close() }
            AccentButton {
                id: apply
                text: "Apply"
                onClicked: {
                    picker.picked(picker.hex);
                    picker.close();
                }
            }
        }
    }
}
