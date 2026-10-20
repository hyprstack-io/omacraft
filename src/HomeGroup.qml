import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// One kind of thing in the home folder (settings, secrets, caches, personal
// folders): a checkbox for the lot, and each piece when opened.
ColumnLayout {
    id: group

    property string kind
    property string title
    property string detail
    property color accent
    property bool open: false

    readonly property var items: iso.homeItems.filter(item => item.kind === kind)
    readonly property int chosen: items.filter(item => item.on).length

    visible: items.length > 0
    Layout.fillWidth: true
    spacing: 2

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        CheckBox {
            focusPolicy: Qt.NoFocus
            tristate: true
            checkState: group.chosen === 0 ? Qt.Unchecked
                      : group.chosen === group.items.length ? Qt.Checked : Qt.PartiallyChecked
            nextCheckState: () => checkState === Qt.Checked ? Qt.Unchecked : Qt.Checked
            onClicked: iso.setHomeKind(group.kind, checkState === Qt.Checked)
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                text: group.title + "  <font color=\"#74747d\">" + group.chosen + " of " + group.items.length + "</font>"
                textFormat: Text.StyledText
                color: theme.text
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: group.detail
                color: theme.textDim
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }
        Label {
            text: group.open ? "▾" : "▸"
            color: theme.textMuted
            font.pixelSize: 14
            Layout.rightMargin: 4
        }
        TapHandler { onTapped: group.open = !group.open }
    }

    Repeater {
        model: group.open ? group.items : []
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            Layout.leftMargin: 28
            spacing: 4
            CheckBox {
                focusPolicy: Qt.NoFocus
                checked: modelData.on
                padding: 2
                onClicked: iso.setHomeItem(modelData.path, checked)
            }
            Label {
                Layout.fillWidth: true
                text: "~/" + modelData.path
                color: modelData.on ? theme.textSoft : theme.textDim
                font.family: "monospace"
                font.pixelSize: 12
                elide: Text.ElideMiddle
            }
            Label {
                text: modelData.size
                color: theme.textDim
                font.pixelSize: 11
                font.family: "monospace"
            }
        }
    }
}
