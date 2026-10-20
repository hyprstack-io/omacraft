import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A font family: typed, or picked from the installed ones (each shown in
// itself). Empty means "whatever it follows".
RowLayout {
    id: row
    property string label
    property string value
    property string placeholder: "Default"
    property int labelWidth: 78
    signal picked(string family)

    Layout.fillWidth: true
    spacing: 8

    Label {
        Layout.preferredWidth: row.labelWidth
        text: row.label
        color: theme.textSoft
        elide: Text.ElideRight
    }
    TextField {
        id: field
        Layout.fillWidth: true
        text: row.value
        placeholderText: row.placeholder
        font.family: row.value !== "" ? row.value : font.family
        onEditingFinished: if (text.trim() !== row.value) row.picked(text.trim())
    }
    ToolButton {
        text: "\u{f0140}"
        implicitWidth: 30
        focusPolicy: Qt.NoFocus
        onClicked: { list.filter = ""; menu.open(); }
        ToolTip.visible: hovered
        ToolTip.text: "Installed fonts"
    }

    Popup {
        id: menu
        y: row.height
        x: row.width - width
        width: Math.max(280, row.width)
        height: 320
        padding: 6
        background: Rectangle { radius: 8; color: theme.raised; border.color: theme.border }
        onOpened: filterField.forceActiveFocus()
        ColumnLayout {
            anchors.fill: parent
            spacing: 4
            TextField {
                id: filterField
                Layout.fillWidth: true
                placeholderText: "Filter fonts"
                onTextChanged: list.filter = text
            }
            ListView {
                id: list
                property string filter: ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                model: [""].concat(Qt.fontFamilies().filter(f => !f.startsWith(".") && (filter === "" || f.toLowerCase().indexOf(filter.toLowerCase()) >= 0)))
                delegate: ItemDelegate {
                    required property string modelData
                    width: list.width
                    height: 30
                    text: modelData === "" ? row.placeholder : modelData
                    font.family: modelData === "" ? font.family : modelData
                    font.pixelSize: 13
                    highlighted: modelData === row.value
                    onClicked: { row.picked(modelData); menu.close(); }
                }
            }
        }
    }
}
