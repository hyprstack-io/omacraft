import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Shown in place of a page whose plugin isn't installed, with the way to
// install it right there.
Card {
    id: card
    property string pluginId
    property string what
    readonly property var info: plugins.plugins.find(p => p.id === pluginId) || ({})

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + 48

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 520)
        spacing: 12
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: (card.info.name || card.pluginId) + " isn't installed"
            color: theme.text
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: theme.textMuted
            text: card.info.canInstall
                  ? card.what + " Install it to use this page."
                  : card.what + " Its code wasn't found at " + (card.info.source || "any known place")
                    + ". Set where it lives on the Plugins page."
        }
        AccentButton {
            Layout.alignment: Qt.AlignHCenter
            visible: card.info.canInstall === true
            enabled: !plugins.busy
            text: "Install " + (card.info.name || card.pluginId)
            onClicked: plugins.install(card.pluginId)
        }
    }
}
