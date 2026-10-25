import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// The live system's locale, services, and how the ISO boots and is packed.
ColumnLayout {
    id: section

    property color accent
    property color line
    readonly property bool replica: iso.profile === "replica"

    spacing: 22

    // A text field that offers matching entries from a list while typing.
    component SuggestField: TextField {
        id: field
        property var options: []
        readonly property bool known: text === "" || options.length === 0 || options.indexOf(text) >= 0
        readonly property var matches: {
            if (!activeFocus || text.length < 1)
                return [];
            const needle = text.toLowerCase();
            const found = [];
            for (const option of options) {
                if (option.toLowerCase().indexOf(needle) >= 0 && option !== text) {
                    found.push(option);
                    if (found.length >= 8)
                        break;
                }
            }
            return found;
        }
        signal commit(string value)

        Layout.fillWidth: true
        font.family: "monospace"
        color: known ? theme.text : theme.danger
        onEditingFinished: commit(text)
        Keys.onDownPressed: if (suggestions.count > 0) suggestions.currentIndex = Math.min(suggestions.count - 1, suggestions.currentIndex + 1)
        Keys.onUpPressed: if (suggestions.count > 0) suggestions.currentIndex = Math.max(0, suggestions.currentIndex - 1)
        Keys.onReturnPressed: event => {
            if (popup.visible && suggestions.currentIndex >= 0)
                text = field.matches[suggestions.currentIndex];
            event.accepted = false;
        }

        Popup {
            id: popup
            y: field.height
            width: field.width
            padding: 4
            visible: field.matches.length > 0
            closePolicy: Popup.NoAutoClose
            background: Rectangle { color: theme.raised; radius: 6; border.color: section.line }
            contentItem: ListView {
                id: suggestions
                implicitHeight: contentHeight
                model: field.matches
                currentIndex: -1
                onModelChanged: currentIndex = -1
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    width: ListView.view.width
                    height: 26
                    radius: 4
                    color: index === suggestions.currentIndex || hover.hovered ? theme.borderStrong : "transparent"
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        text: modelData
                        font.family: "monospace"
                        color: theme.textSoft
                    }
                    HoverHandler { id: hover }
                    TapHandler {
                        onTapped: {
                            field.text = modelData;
                            field.commit(modelData);
                        }
                    }
                }
            }
        }
    }

    Field {
        Layout.leftMargin: 20; Layout.rightMargin: 20
        visible: !section.replica
        label: "Time zone and keyboard"
        hint: "Empty keeps the profile's own: UTC and the us layout. The keyboard layout is the console's (loadkeys)."
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            SuggestField {
                text: iso.timezone
                placeholderText: text === "" ? "UTC" : ""
                options: iso.timezones
                onCommit: value => iso.timezone = value
            }
            SuggestField {
                Layout.preferredWidth: 110
                Layout.fillWidth: false
                text: iso.keymap
                placeholderText: text === "" ? "us" : ""
                options: iso.keymaps
                onCommit: value => iso.keymap = value
            }
        }
        Label {
            text: "Use this machine's"
            color: section.accent
            font.pixelSize: 12
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { iso.useHostTimezone(); iso.useHostKeymap(); }
            }
        }
    }

    Field {
        Layout.leftMargin: 20; Layout.rightMargin: 20
        visible: !section.replica
        label: "Services to start"
        hint: "systemd units enabled on the live system, like <b>sshd</b> or <b>NetworkManager</b>. Their packages have to be on the ISO."
        TextField {
            Layout.fillWidth: true
            text: iso.services
            placeholderText: text === "" ? "sshd" : ""
            font.family: "monospace"
            onEditingFinished: iso.services = text
        }
    }

    Field {
        Layout.leftMargin: 20; Layout.rightMargin: 20
        label: "Boot options"
        hint: "Added to every boot entry. <b>copytoram</b> runs it all from memory so the drive can come out; <b>nomodeset</b> helps with stubborn graphics."
        TextField {
            Layout.fillWidth: true
            text: iso.kernelParams
            placeholderText: text === "" ? "copytoram" : ""
            font.family: "monospace"
            onEditingFinished: iso.kernelParams = text
        }
    }

    Field {
        Layout.leftMargin: 20; Layout.rightMargin: 20
        label: "Compression"
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [
                    { id: "default", name: "Profile's", detail: section.replica ? "zstd: balanced." : "As archiso ships it." },
                    { id: "fast", name: "Faster build", detail: "LZ4: a bigger ISO, much sooner." },
                    { id: "small", name: "Smallest ISO", detail: "xz (LZMA): about a tenth smaller than zstd, slowest to build." }
                ]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool chosen: iso.compression === modelData.id
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    implicitHeight: compressionText.implicitHeight + 18
                    radius: 8
                    color: chosen ? Qt.rgba(section.accent.r, section.accent.g, section.accent.b, 0.10) : theme.inset
                    border.color: chosen ? section.accent : section.line
                    ColumnLayout {
                        id: compressionText
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 2
                        Label {
                            text: modelData.name
                            color: chosen ? section.accent : theme.text
                            font.weight: Font.DemiBold
                            font.pixelSize: 13
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.detail
                            color: theme.textMuted
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: iso.compression = modelData.id
                    }
                }
            }
        }
    }
}
