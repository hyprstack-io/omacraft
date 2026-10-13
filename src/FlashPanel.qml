import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Writes an ISO to a removable drive. Nothing is written until the user has
// picked a drive and typed its name, because this erases the whole drive.
Rectangle {
    id: panel
    color: "#cc000000"

    property color accent
    property color accentForeground
    property string selectedPath: ""
    readonly property var selected: {
        for (const drive of iso.drives)
            if (drive.path === selectedPath)
                return drive;
        return null;
    }
    readonly property bool flashing: iso.state === "flashing"
    readonly property bool canWrite: selected !== null && selected.blocker === "" && iso.flashIso !== ""
                                     && confirmField.text.trim() === selected.name && !iso.busy

    signal closeRequested()
    signal cancelRequested()

    // Never picks a drive on its own: erasing one should always start with the
    // user choosing it. This only drops a choice that has disappeared.
    function forgetMissingDrive() {
        for (const drive of iso.drives) {
            if (drive.path === selectedPath)
                return;
        }
        selectedPath = "";
        confirmField.text = "";
    }

    function move(step) {
        const drives = iso.drives;
        if (drives.length === 0)
            return;
        let index = drives.findIndex(d => d.path === selectedPath);
        index = index < 0 ? (step > 0 ? 0 : drives.length - 1) : Math.max(0, Math.min(drives.length - 1, index + step));
        selectedPath = drives[index].path;
        confirmField.text = "";
    }

    function write() {
        if (canWrite)
            iso.flash(selected.path, confirmField.text);
    }

    onVisibleChanged: {
        if (visible) {
            confirmField.text = "";
            selectedPath = "";
            iso.openFlash();
        }
    }

    Connections {
        target: iso
        function onFlashChanged() { panel.forgetMissingDrive(); }
        function onFlashFinished(ok) { if (ok) confirmField.text = ""; }
    }

    Shortcut { sequence: "Up"; context: Qt.ApplicationShortcut; enabled: panel.visible && !panel.flashing; onActivated: panel.move(-1) }
    Shortcut { sequence: "Down"; context: Qt.ApplicationShortcut; enabled: panel.visible && !panel.flashing; onActivated: panel.move(1) }
    Shortcut { sequence: "R"; context: Qt.ApplicationShortcut; enabled: panel.visible && !panel.flashing && !confirmField.activeFocus; onActivated: iso.refreshDrives() }
    Shortcut { sequence: "C"; context: Qt.ApplicationShortcut; enabled: panel.visible && !panel.flashing && !confirmField.activeFocus; onActivated: iso.chooseFlashIso() }
    Shortcut { sequence: "Tab"; context: Qt.ApplicationShortcut; enabled: panel.visible && !panel.flashing && panel.selected !== null && panel.selected.blocker === "" && iso.flashIso !== ""; onActivated: confirmField.forceActiveFocus() }

    MouseArea { anchors.fill: parent; onClicked: if (!panel.flashing) panel.closeRequested() }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 680)
        height: Math.min(parent.height - 48, body.implicitHeight + 48)
        radius: 12
        color: "#18181b"
        border.color: "#2a2a30"

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "Write to a USB drive"
                    color: "white"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                KeyCap { text: "Esc" }
            }

            // The image to write.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: isoRow.implicitHeight + 20
                radius: 8
                color: "#111113"
                border.color: "#26262b"

                RowLayout {
                    id: isoRow
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            Layout.fillWidth: true
                            text: iso.flashIso === "" ? "No ISO chosen" : iso.flashIso.split("/").pop()
                            color: iso.flashIso === "" ? "#8a8a93" : "white"
                            font.family: "monospace"
                            font.pixelSize: 13
                            elide: Text.ElideMiddle
                        }
                        Label {
                            visible: iso.flashIso !== ""
                            Layout.fillWidth: true
                            text: iso.flashIsoSize + " · " + iso.flashIso
                            color: "#74747d"
                            font.pixelSize: 11
                            elide: Text.ElideMiddle
                        }
                    }
                    Button {
                        text: "Choose ISO…"
                        flat: true
                        focusPolicy: Qt.NoFocus
                        enabled: !panel.flashing
                        onClicked: iso.chooseFlashIso()
                    }
                    KeyCap { text: "C" }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "REMOVABLE DRIVES"
                    color: "#8a8a93"
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                Label { text: "↑ ↓ to choose"; color: "#74747d"; font.pixelSize: 11 }
                Button {
                    text: "Refresh"
                    flat: true
                    focusPolicy: Qt.NoFocus
                    enabled: !panel.flashing
                    onClicked: iso.refreshDrives()
                }
                KeyCap { text: "R" }
            }

            Label {
                visible: iso.drives.length > 0 && iso.flashIso === ""
                Layout.fillWidth: true
                text: "Choose an ISO first, then a drive."
                color: "#8a8a93"
            }

            Label {
                visible: iso.drives.length === 0
                Layout.fillWidth: true
                text: "No removable drives found. Plug in a USB stick and press R."
                color: "#8a8a93"
                wrapMode: Text.WordWrap
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: iso.drives
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool chosen: modelData.path === panel.selectedPath
                        readonly property bool usable: modelData.blocker === ""
                        Layout.fillWidth: true
                        implicitHeight: driveRow.implicitHeight + 18
                        radius: 8
                        color: chosen ? Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.10) : "#111113"
                        border.color: chosen ? panel.accent : "#26262b"
                        opacity: usable ? 1 : 0.55

                        RowLayout {
                            id: driveRow
                            anchors.fill: parent
                            anchors.margins: 9
                            anchors.leftMargin: 12
                            spacing: 12
                            Label {
                                text: modelData.name
                                color: chosen ? panel.accent : "white"
                                font.family: "monospace"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                Layout.preferredWidth: 64
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.model + "  ·  " + modelData.size + (modelData.transport ? "  ·  " + modelData.transport : "")
                                    color: "white"
                                    elide: Text.ElideRight
                                }
                                Label {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: modelData.blocker !== "" ? modelData.blocker
                                          : modelData.mountpoints !== "" ? "Mounted at " + modelData.mountpoints + ", unmounted before writing" : ""
                                    color: modelData.blocker !== "" ? "#ff8a8a" : "#8a8a93"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !panel.flashing
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { panel.selectedPath = modelData.path; confirmField.text = ""; }
                        }
                    }
                }
            }

            // The confirmation: the drive's name, typed.
            ColumnLayout {
                Layout.fillWidth: true
                visible: panel.selected !== null && panel.selected.blocker === "" && !panel.flashing
                         && iso.flashIso !== ""
                spacing: 8

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    color: "#ffb4b4"
                    text: panel.selected ? "Everything on <b>" + panel.selected.model + "</b> (" + panel.selected.name + ", "
                                           + panel.selected.size + ") will be erased." : ""
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    TextField {
                        id: confirmField
                        Layout.fillWidth: true
                        placeholderText: panel.selected ? "Type " + panel.selected.name + " to confirm" : ""
                        font.family: "monospace"
                        onAccepted: panel.write()
                    }
                    KeyCap { text: "Tab" }
                    Button {
                        text: "Erase and write"
                        focusPolicy: Qt.NoFocus
                        enabled: panel.canWrite
                        Material.background: "#c94a4a"
                        Material.foreground: "white"
                        onClicked: panel.write()
                    }
                }
            }

            // Progress while writing.
            ColumnLayout {
                Layout.fillWidth: true
                visible: panel.flashing
                spacing: 8
                ProgressBar {
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: iso.progress
                    indeterminate: iso.progress <= 0
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        text: iso.cancelling ? "Stopping…" : iso.stage
                        color: "white"
                    }
                    Label { text: iso.elapsed; color: "#8a8a93"; font.family: "monospace" }
                    Button {
                        text: "Stop"
                        flat: true
                        focusPolicy: Qt.NoFocus
                        enabled: !iso.cancelling
                        onClicked: panel.cancelRequested()
                    }
                    KeyCap { text: "Esc" }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
