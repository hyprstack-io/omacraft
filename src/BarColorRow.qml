import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One colour of the bar: what it is now, typed or picked on the wheel, and a
// way back to whatever it follows when it's left unset.
RowLayout {
    id: row
    property string label
    // The colour set here (#rrggbb), or "" when it follows something else.
    property string value
    // What shows when it isn't set.
    property color shown: theme.accent
    property string followsText: "theme"
    property int labelWidth: 120
    signal picked(string hex)
    signal cleared()

    readonly property bool set: /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(value)

    Layout.fillWidth: true
    spacing: 8

    Label {
        Layout.preferredWidth: row.labelWidth
        text: row.label
        color: theme.textSoft
        elide: Text.ElideRight
    }
    Rectangle {
        width: 26; height: 26; radius: 6
        color: row.set ? row.value.slice(0, 7) : row.shown
        border.color: theme.borderStrong
        // A faint stripe for "following".
        Rectangle {
            visible: !row.set
            anchors.fill: parent
            anchors.margins: 8
            radius: 3
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.55)
            border.width: 1
        }
    }
    TextField {
        id: hexField
        Layout.preferredWidth: 104
        text: row.value
        placeholderText: row.followsText
        font.family: "monospace"
        font.pixelSize: 12
        onEditingFinished: {
            const v = text.trim();
            if (v === row.value) return;
            if (v === "") row.cleared();
            else if (/^#?[0-9a-fA-F]{6}$/.test(v)) row.picked(v.startsWith("#") ? v : "#" + v);
            else text = row.value;
        }
    }
    ColorButton {
        value: row.value
        fallback: row.shown
        title: row.label
        onPicked: hex => row.picked(hex)
    }
    ToolButton {
        text: "\u{f0450}"
        enabled: row.set
        opacity: enabled ? 1 : 0.3
        implicitWidth: 30; implicitHeight: 30
        font.pixelSize: 14
        focusPolicy: Qt.NoFocus
        onClicked: row.cleared()
        ToolTip.visible: hovered
        ToolTip.text: "Follow the " + row.followsText + " again"
    }
    Item { Layout.fillWidth: true }
}
