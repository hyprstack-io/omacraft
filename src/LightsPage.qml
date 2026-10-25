import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Alienflare: AlienFlare inside OmaCraft. The same view and scene file as
// the AlienFlare app (~/.config/alienflare/state.json), so a change in one
// shows in the other, and the alienflare service puts it on the keys.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property bool dialogOpen: false
    readonly property var shortcuts: view.shortcuts

    function handleEscape() { return view.handleEscape(); }
    function acceptDialog() {}

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        PageHeader {
            title: "Alienflare"
            subtitle: "Per-key lighting for the Alienware x15, shared with AlienFlare in ~/.config/alienflare/state.json"
            glyph: "\u{f030c}"
            Button { text: "Undo"; flat: true; enabled: lights.canUndo; focusPolicy: Qt.NoFocus; onClicked: lights.undo() }
            Button { text: "Redo"; flat: true; enabled: lights.canRedo; focusPolicy: Qt.NoFocus; onClicked: lights.redo() }
            Switch {
                checked: lights.on
                focusPolicy: Qt.NoFocus
                onToggled: lights.setOn(checked)
            }
            KeyCap { text: "Space" }
        }

        LightsView {
            id: view
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: page.active
            keysFree: page.keysFree
        }
    }
}
