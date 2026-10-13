import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// hyprbuildz, the ISO builder, as one of OMAcraft's pages. Its keys work
// while the page is showing; the window asks before quitting mid-build.
Item {
    id: win

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property color accent: theme.accent
    readonly property color accentForeground: theme.accentForeground
    readonly property color surface: "#151518"
    readonly property color line: "#26262b"

    property bool flashVisible: false
    property bool editorVisible: false
    property bool cancelConfirmVisible: false

    readonly property bool dialogOpen: cancelConfirmVisible
    readonly property bool overlayOpen: flashVisible || editorVisible || dialogOpen
    // Letter shortcuts stand down while a text field has the keyboard.
    readonly property bool typing: Window.activeFocusItem !== null && Window.activeFocusItem.cursorPosition !== undefined
    readonly property bool keysFreeHere: active && keysFree && !overlayOpen
    readonly property var shortcuts: [
        { keys: "Space", action: "Build the ISO" },
        { keys: "Esc", action: "Cancel the build, leave a field, close" },
        { keys: "P", action: "Switch the profile: installer, minimal, this desktop" },
        { keys: "N / H", action: "Edit the ISO name / hostname" },
        { keys: "E", action: "Edit the extra packages" },
        { keys: "O", action: "Add a folder to include (Shift O removes all)" },
        { keys: "T", action: "Edit configuration files (Ctrl S saves)" },
        { keys: "M", action: "Toggle Omarchy setup" },
        { keys: "W", action: "This desktop: include passwords" },
        { keys: "D", action: "Choose where the ISO is saved" },
        { keys: "F", action: "Write an ISO to a USB drive" },
        { keys: "↑ ↓  R  C", action: "In the USB panel: drive, refresh, ISO" },
        { keys: "I", action: "Install archiso, when it's missing" },
        { keys: "Ctrl Z", action: "Undo (Ctrl Shift Z redo)" }
    ]

    // Text fields save when they lose focus, so take it before anything reads
    // the config.
    function commitFields() {
        keySink.forceActiveFocus();
    }

    function build() {
        commitFields();
        iso.build();
    }

    function home(path) {
        return path.replace(/^\/home\/[^/]+/, "~");
    }

    function handleEscape() {
        if (!active)
            return false;
        if (win.cancelConfirmVisible)
            win.cancelConfirmVisible = false;
        else if (win.editorVisible)
            editorPanel.handleEscape();
        else if (win.typing)
            win.commitFields();
        else if (iso.busy && !iso.cancelling && iso.state !== "installing")
            win.cancelConfirmVisible = true;
        else if (win.flashVisible)
            win.flashVisible = false;
        else if (iso.error !== "" || iso.notice !== "")
            iso.dismissMessages();
        else
            return false;
        return true;
    }

    function acceptDialog() {
        win.cancelConfirmVisible = false;
        iso.cancel();
    }

    // --- keys ---
    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing && !iso.busy; onActivated: win.build() }
    Shortcut { sequence: "Ctrl+Z"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing; onActivated: iso.undo() }
    Shortcut { sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing; onActivated: iso.redo() }
    Shortcut { sequence: "P"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing; onActivated: iso.profile = ({ releng: "baseline", baseline: "replica", replica: "releng" })[iso.profile] }
    Shortcut { sequence: "N"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing; onActivated: isoNameField.forceActiveFocus() }
    Shortcut { sequence: "H"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing; onActivated: hostnameField.forceActiveFocus() }
    Shortcut { sequence: "E"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing; onActivated: packagesArea.forceActiveFocus() }
    Shortcut { sequence: "O"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing && iso.profile !== "replica"; onActivated: iso.chooseOverlay() }
    Shortcut { sequence: "Shift+O"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing && iso.profile !== "replica"; onActivated: iso.clearOverlays() }
    Shortcut { sequence: "T"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing && iso.profile !== "replica"; onActivated: win.editorVisible = true }
    Shortcut { sequence: "M"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing && iso.profile !== "replica"; onActivated: iso.omarchySetup = !iso.omarchySetup }
    Shortcut { sequence: "W"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing && iso.profile === "replica"; onActivated: iso.replicaSecrets = !iso.replicaSecrets }
    Shortcut { sequence: "D"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing; onActivated: iso.chooseOutput() }
    Shortcut { sequence: "F"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing && !iso.busy; onActivated: win.flashVisible = true }
    Shortcut { sequence: "I"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing && iso.archisoMissing && !iso.busy; onActivated: iso.installArchiso() }

    Connections {
        target: iso
        function onLogAppended(line) {
            logModel.append({ line: line });
            if (logModel.count > 4000)
                logModel.remove(0, 1000);
        }
        function onLogCleared() { logModel.clear(); }
    }

    ListModel { id: logModel }

    // Holds the keyboard when no field does, so letter shortcuts work.
    Item { id: keySink; focus: true }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PageHeader {
            Layout.margins: 20
            Layout.bottomMargin: 12
            title: "ISO Builder"
            subtitle: "hyprbuildz: custom Arch Linux ISOs, built with archiso"
            glyph: "\u{f0a4f}"
            Label {
                visible: iso.canUndo || iso.canRedo
                text: "Ctrl Z undo · Ctrl Shift Z redo"
                color: "#5f5f68"
                font.pixelSize: 11
            }
        }

        // --- what's wrong, or what just happened ---
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.bottomMargin: 12
            visible: message.text !== ""
            implicitHeight: messageRow.implicitHeight + 20
            radius: 8
            readonly property bool bad: iso.error !== "" || (iso.notice === "" && iso.missing !== "")
            color: bad ? "#2a1416" : Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.10)
            border.color: bad ? "#6b2a2f" : Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.45)

            RowLayout {
                id: messageRow
                anchors.fill: parent
                anchors.margins: 10
                anchors.leftMargin: 14
                spacing: 12
                Label {
                    id: message
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: parent.parent.bad ? "#ffb4b4" : "white"
                    text: iso.error !== "" ? iso.error : iso.notice !== "" ? iso.notice : iso.missing
                }
                Button {
                    visible: iso.archisoMissing && iso.error === "" && iso.notice === ""
                    text: "Install archiso"
                    focusPolicy: Qt.NoFocus
                    enabled: !iso.busy
                    Material.background: win.accent
                    Material.foreground: win.accentForeground
                    onClicked: iso.installArchiso()
                }
                KeyCap { visible: iso.archisoMissing && iso.error === "" && iso.notice === ""; text: "I" }
                KeyCap { visible: iso.error !== "" || iso.notice !== ""; text: "Esc" }
            }
        }

        // Side by side when there's room; stacked in a narrow tile, since
        // Hyprland's tiling ignores the minimum size.
        GridLayout {
            id: panes
            readonly property bool wide: win.width >= 960
            columns: wide ? 2 : 1
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.bottomMargin: 20
            rowSpacing: 16
            columnSpacing: 16

            // --- the ISO's settings ---
            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: !panes.wide
                Layout.preferredWidth: panes.wide ? 440 : -1
                Layout.preferredHeight: panes.wide ? -1 : 1
                radius: 12
                color: win.surface
                border.color: win.line

                ScrollView {
                    id: formScroll
                    anchors.fill: parent
                    anchors.margins: 1
                    contentWidth: availableWidth
                    clip: true

                    ColumnLayout {
                        width: formScroll.availableWidth
                        spacing: 22

                        Item { implicitHeight: 2 }

                        Field {
                            Layout.leftMargin: 20; Layout.rightMargin: 20
                            label: "Base profile"
                            key: "P"
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Repeater {
                                    model: [
                                        { id: "releng", name: "Live installer", detail: "The official Arch ISO, with archinstall." },
                                        { id: "baseline", name: "Minimal", detail: "A bare live system to build on." },
                                        { id: "replica", name: "This desktop", detail: "Boots into a copy of this desktop." }
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool chosen: iso.profile === modelData.id
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 1
                                        implicitHeight: profileText.implicitHeight + 22
                                        radius: 8
                                        color: chosen ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.10) : "#111113"
                                        border.color: chosen ? win.accent : win.line
                                        ColumnLayout {
                                            id: profileText
                                            anchors.fill: parent
                                            anchors.margins: 11
                                            spacing: 3
                                            Label {
                                                text: modelData.name
                                                color: chosen ? win.accent : "white"
                                                font.weight: Font.DemiBold
                                            }
                                            Label {
                                                Layout.fillWidth: true
                                                text: modelData.detail
                                                color: "#8a8a93"
                                                font.pixelSize: 11
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: iso.profile = modelData.id
                                        }
                                    }
                                }
                            }
                        }

                        Field {
                            Layout.leftMargin: 20; Layout.rightMargin: 20
                            visible: iso.profile === "replica"
                            label: "What comes along"
                            hint: "The live ISO signs in as you and starts your desktop. Changes made while it runs last until it shuts down."

                            Label {
                                visible: iso.desktopError !== ""
                                Layout.fillWidth: true
                                text: iso.desktopError
                                color: "#ff8a8a"
                                wrapMode: Text.WordWrap
                            }

                            Repeater {
                                model: iso.desktopError !== "" ? [] : [
                                    iso.nativeCount + " packages from your repositories, and the " + iso.desktopKernel + " kernel",
                                    iso.foreignPackages.length === 0 ? "" :
                                        iso.foreignPackages.length + " AUR packages, rebuilt from what's installed: " + iso.foreignPackages.join(", "),
                                    "Your changed and added system settings in /etc, and /usr/local",
                                    iso.desktopUser + ", signed in automatically, with "
                                        + (iso.sizing ? "…" : iso.homeSize) + " from your home folder"
                                ].filter(line => line !== "")
                                delegate: RowLayout {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Label { text: "•"; color: win.accent; Layout.alignment: Qt.AlignTop }
                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData
                                        color: "#d6d6da"
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                implicitHeight: groups.implicitHeight + 16
                                radius: 8
                                color: "#111113"
                                border.color: win.line
                                ColumnLayout {
                                    id: groups
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4
                                    HomeGroup {
                                        kind: "settings"
                                        title: "Settings"
                                        detail: "Your desktop, theme, shell, and apps' configuration."
                                    }
                                    HomeGroup {
                                        kind: "secret"
                                        title: "Sign-ins and secrets"
                                        detail: "Browser profiles, keys, tokens, and history. Anyone with the drive can read them."
                                    }
                                    HomeGroup {
                                        kind: "personal"
                                        title: "Personal folders"
                                        detail: "Documents, pictures, projects."
                                    }
                                    HomeGroup {
                                        kind: "cache"
                                        title: "Caches and toolchains"
                                        detail: "Rebuilt or re-downloaded as needed."
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        Label { text: "Include passwords"; color: "white" }
                                        KeyCap { text: "W" }
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: iso.replicaSecrets
                                              ? "Your login password, Wi-Fi networks, and SSH and VPN keys are on the ISO."
                                              : "Left out: the live user has no password and sudo doesn't ask; Wi-Fi is set up again."
                                        color: "#74747d"
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                    }
                                }
                                Switch {
                                    checked: iso.replicaSecrets
                                    focusPolicy: Qt.NoFocus
                                    onToggled: iso.replicaSecrets = checked
                                }
                            }
                        }

                        RowLayout {
                            Layout.leftMargin: 20; Layout.rightMargin: 20
                            Layout.fillWidth: true
                            spacing: 14
                            Field {
                                label: "ISO name"
                                key: "N"
                                TextField {
                                    id: isoNameField
                                    Layout.fillWidth: true
                                    text: iso.isoName
                                    font.family: "monospace"
                                    onEditingFinished: iso.isoName = text
                                }
                            }
                            Field {
                                label: "Hostname"
                                key: "H"
                                TextField {
                                    id: hostnameField
                                    Layout.fillWidth: true
                                    text: iso.hostname
                                    font.family: "monospace"
                                    onEditingFinished: iso.hostname = text
                                }
                            }
                        }

                        Field {
                            Layout.leftMargin: 20; Layout.rightMargin: 20
                            label: "Extra packages"
                            key: "E"
                            hint: "From your enabled repositories, separated by spaces or lines. # starts a comment. Esc when done."
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 130
                                radius: 8
                                color: "#111113"
                                border.color: packagesArea.activeFocus ? win.accent : win.line
                                ScrollView {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    TextArea {
                                        id: packagesArea
                                        text: iso.packages
                                        placeholderText: "git neovim btop\nnetworkmanager"
                                        font.family: "monospace"
                                        font.pixelSize: 13
                                        wrapMode: TextEdit.Wrap
                                        background: null
                                        onActiveFocusChanged: if (!activeFocus && text !== iso.packages) iso.packages = text
                                    }
                                }
                            }
                        }

                        Field {
                            Layout.leftMargin: 20; Layout.rightMargin: 20
                            visible: iso.profile !== "replica"
                            label: "Folders to include"
                            key: "O"
                            hint: "Each folder's contents go into the live system at the path beside it. / merges into the root, so <i>folder</i>/etc/issue becomes /etc/issue. Shift O removes them all."
                            Label {
                                visible: iso.overlays.length === 0
                                text: "None"
                                color: "#74747d"
                                font.family: "monospace"
                            }
                            Repeater {
                                model: iso.overlays
                                delegate: ColumnLayout {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label {
                                            Layout.fillWidth: true
                                            text: win.home(modelData.source)
                                            color: modelData.exists ? "white" : "#ff8a8a"
                                            font.family: "monospace"
                                            elide: Text.ElideMiddle
                                            ToolTip.visible: !modelData.exists && missingHover.hovered
                                            ToolTip.text: "This folder doesn't exist any more."
                                            HoverHandler { id: missingHover }
                                        }
                                        Button {
                                            text: "Remove"
                                            flat: true
                                            focusPolicy: Qt.NoFocus
                                            onClicked: iso.removeOverlay(index)
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Label { text: "goes to"; color: "#74747d"; font.pixelSize: 12 }
                                        TextField {
                                            Layout.fillWidth: true
                                            text: modelData.target
                                            font.family: "monospace"
                                            font.pixelSize: 12
                                            onEditingFinished: if (text !== modelData.target) iso.setOverlayTarget(index, text)
                                        }
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                Button {
                                    text: "Add folder…"
                                    flat: true
                                    focusPolicy: Qt.NoFocus
                                    onClicked: iso.chooseOverlay()
                                }
                            }
                        }

                        Field {
                            Layout.leftMargin: 20; Layout.rightMargin: 20
                            visible: iso.profile !== "replica"
                            label: "Configuration files"
                            key: "T"
                            hint: "Change any file on the live system, or the profile's own (pacman.conf, boot menus), in an editor with syntax colouring. These win over the folders above."
                            Label {
                                visible: iso.editedFiles.length === 0
                                text: "None edited"
                                color: "#74747d"
                                font.family: "monospace"
                            }
                            Repeater {
                                model: iso.editedFiles
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: "white"
                                        font.family: "monospace"
                                        elide: Text.ElideMiddle
                                    }
                                    Label {
                                        text: modelData.lines + (modelData.lines === 1 ? " line" : " lines")
                                        color: "#74747d"
                                        font.pixelSize: 12
                                    }
                                    Button {
                                        text: "Edit"
                                        flat: true
                                        focusPolicy: Qt.NoFocus
                                        onClicked: { win.editorVisible = true; editorPanel.openFile(modelData.path); }
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                Button {
                                    text: "Edit a file…"
                                    flat: true
                                    focusPolicy: Qt.NoFocus
                                    onClicked: win.editorVisible = true
                                }
                            }
                        }

                        Field {
                            Layout.leftMargin: 20; Layout.rightMargin: 20
                            visible: iso.profile !== "replica"
                            label: "Omarchy"
                            key: "M"
                            hint: "Adds an <b>omarchy-setup</b> command to the live ISO. It runs archinstall, then sets the Omarchy installer to start when the new user first logs in."
                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    Layout.fillWidth: true
                                    text: "Set up Omarchy after installing Arch"
                                    color: "white"
                                }
                                Switch {
                                    checked: iso.omarchySetup
                                    focusPolicy: Qt.NoFocus
                                    onToggled: iso.omarchySetup = checked
                                }
                            }
                        }

                        OptionsSection {
                            Layout.fillWidth: true
                            accent: win.accent
                            line: win.line
                        }

                        Field {
                            Layout.leftMargin: 20; Layout.rightMargin: 20
                            label: "Save ISO in"
                            key: "D"
                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    Layout.fillWidth: true
                                    text: win.home(iso.outputDir)
                                    color: "white"
                                    font.family: "monospace"
                                    elide: Text.ElideMiddle
                                }
                                Button {
                                    text: "Choose…"
                                    flat: true
                                    focusPolicy: Qt.NoFocus
                                    onClicked: iso.chooseOutput()
                                }
                            }
                        }

                        Item { implicitHeight: 6 }
                    }
                }
            }

            // --- building ---
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: panes.wide ? -1 : 1
                radius: 12
                color: win.surface
                border.color: win.line

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        // The main action: build, or cancel while building.
                        Rectangle {
                            id: buildButton
                            readonly property bool building: iso.state === "building" || iso.state === "checking" || iso.state === "measuring"
                            Layout.preferredWidth: 200
                            implicitHeight: 48
                            radius: 10
                            opacity: (iso.busy && !building) || iso.cancelling ? 0.5 : 1
                            color: building ? "#2a2a30" : buildHover.hovered ? Qt.lighter(win.accent, 1.08) : win.accent
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 10
                                Label {
                                    text: iso.cancelling ? "Cancelling…" : buildButton.building ? "Cancel build" : "Build ISO"
                                    color: buildButton.building ? "white" : win.accentForeground
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                }
                                KeyCap {
                                    text: buildButton.building ? "Esc" : "Space"
                                    tint: buildButton.building ? "#c8c8cf" : win.accentForeground
                                }
                            }
                            HoverHandler { id: buildHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    if (buildButton.building) {
                                        if (!iso.cancelling)
                                            win.cancelConfirmVisible = true;
                                    } else if (!iso.busy) {
                                        win.build();
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                Layout.fillWidth: true
                                text: ({ releng: "Live installer", baseline: "Minimal", replica: "This desktop" })[iso.profile]
                                color: "white"
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Label {
                                Layout.fillWidth: true
                                text: iso.profile === "replica"
                                      ? [(iso.nativeCount + iso.foreignPackages.length + iso.packageCount) + " packages",
                                         iso.sizing ? "measuring home…" : iso.homeSize + " from home",
                                         iso.replicaSecrets ? "with passwords" : "no passwords"].join(" · ")
                                      : [iso.packageCount === 0 ? "no extra packages"
                                          : iso.packageCount + " extra package" + (iso.packageCount === 1 ? "" : "s"),
                                       iso.overlays.length === 0 ? ""
                                           : iso.overlays.length + " folder" + (iso.overlays.length === 1 ? "" : "s"),
                                       iso.editedFiles.length === 0 ? ""
                                           : iso.editedFiles.length + " edited file" + (iso.editedFiles.length === 1 ? "" : "s"),
                                       iso.timezone,
                                       iso.omarchySetup ? "Omarchy setup" : ""].filter(s => s !== "").join(" · ")
                                color: "#8a8a93"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }

                        Label {
                            visible: iso.busy
                            text: iso.elapsed
                            color: "#8a8a93"
                            font.family: "monospace"
                            font.pixelSize: 14
                        }
                    }

                    // How far along: the stage, a bar, the percentage, and a
                    // rough estimate of what's left once there's enough to go on.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: iso.busy || iso.stage !== ""
                        readonly property bool indeterminate: iso.busy && iso.progress <= 0.01

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Label {
                                Layout.fillWidth: true
                                text: iso.cancelling ? "Stopping and cleaning up…" : iso.stage
                                color: "white"
                                elide: Text.ElideRight
                            }
                            Label {
                                visible: iso.remaining !== ""
                                text: iso.remaining
                                color: "#8a8a93"
                                font.pixelSize: 12
                            }
                            Label {
                                visible: !parent.parent.indeterminate
                                text: Math.round(iso.progress * 100) + "%"
                                color: win.accent
                                font.family: "monospace"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            id: track
                            Layout.fillWidth: true
                            implicitHeight: 10
                            radius: 5
                            color: "#0b0b0d"
                            border.color: win.line
                            clip: true

                            Rectangle {
                                visible: !parent.parent.indeterminate
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(radius * 2, parent.width * Math.min(1, iso.progress))
                                radius: 5
                                color: iso.cancelling ? "#6b6b74" : win.accent
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }

                            // Waiting for the password or pacman's check: a sweep.
                            Rectangle {
                                id: sweep
                                visible: parent.parent.indeterminate
                                width: parent.width * 0.25
                                height: parent.height
                                radius: 5
                                color: win.accent
                                opacity: 0.7
                                SequentialAnimation on x {
                                    running: sweep.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { from: -sweep.width; to: track.width; duration: 1400; easing.type: Easing.InOutQuad }
                                }
                            }
                        }
                    }

                    // The finished ISO, ready to write to a drive.
                    Rectangle {
                        Layout.fillWidth: true
                        visible: iso.builtIso !== "" && !iso.busy
                        implicitHeight: resultRow.implicitHeight + 20
                        radius: 8
                        color: "#111113"
                        border.color: win.line
                        RowLayout {
                            id: resultRow
                            anchors.fill: parent
                            anchors.margins: 10
                            anchors.leftMargin: 14
                            spacing: 10
                            Label {
                                Layout.fillWidth: true
                                text: win.home(iso.builtIso)
                                color: "white"
                                font.family: "monospace"
                                elide: Text.ElideMiddle
                            }
                            Button {
                                text: "Write to USB…"
                                flat: true
                                focusPolicy: Qt.NoFocus
                                onClicked: win.flashVisible = true
                            }
                            KeyCap { text: "F" }
                        }
                    }

                    // mkarchiso's output, as it comes.
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: "#0b0b0d"
                        border.color: win.line
                        clip: true

                        ListView {
                            id: logView
                            anchors.fill: parent
                            anchors.margins: 10
                            clip: true
                            model: logModel
                            boundsBehavior: Flickable.StopAtBounds
                            property bool following: true
                            onMovementEnded: following = atYEnd
                            onCountChanged: if (following) Qt.callLater(positionViewAtEnd)
                            ScrollBar.vertical: ScrollBar {}
                            delegate: Text {
                                required property string line
                                width: logView.width - 12
                                text: line
                                color: line.indexOf("ERROR") >= 0 || line.indexOf("error:") >= 0 ? "#ff8a8a"
                                     : line.indexOf("hyprbuildz:") === 0 ? win.accent
                                     : line.indexOf("WARNING") >= 0 ? "#e6c06a" : "#a9a9b2"
                                font.family: "monospace"
                                font.pixelSize: 11
                                wrapMode: Text.WrapAnywhere
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            width: parent.width - 40
                            visible: logModel.count === 0 && parent.height > implicitHeight + 24
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: iso.profile === "replica"
                                  ? "The build log appears here.\nA copy of this desktop installs every package you have, so it downloads several gigabytes and can take an hour.\nIt asks for your password once, to run mkarchiso as root."
                                  : "The build log appears here.\nA build downloads around a gigabyte and takes 10–30 minutes.\nIt asks for your password once, to run mkarchiso as root."
                            color: "#5f5f68"
                            lineHeight: 1.3
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Label { text: "Have an ISO already?"; color: "#74747d"; font.pixelSize: 12 }
                        Label {
                            text: "Write it to a USB drive"
                            color: win.accent
                            font.pixelSize: 12
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !iso.busy
                                onClicked: win.flashVisible = true
                            }
                        }
                        KeyCap { text: "F" }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }

    FlashPanel {
        anchors.fill: parent
        visible: win.flashVisible
        accent: win.accent
        accentForeground: win.accentForeground
        onCloseRequested: win.flashVisible = false
        onCancelRequested: win.cancelConfirmVisible = true
    }

    EditorPanel {
        id: editorPanel
        anchors.fill: parent
        visible: win.editorVisible
        accent: win.accent
        accentForeground: win.accentForeground
        line: win.line
        onCloseRequested: { win.editorVisible = false; win.commitFields(); }
    }

    Confirm {
        visible: win.cancelConfirmVisible
        heading: iso.state === "flashing" ? "Stop writing?" : "Cancel the build?"
        body: iso.state === "flashing" ? "The drive will be left partly written and won't boot until you write it again."
                                           : "The build so far is thrown away. Downloaded packages stay in pacman's cache, so the next build is quicker."
        action: iso.state === "flashing" ? "Stop" : "Cancel build"
        onAccepted: { win.cancelConfirmVisible = false; iso.cancel(); }
        onRejected: win.cancelConfirmVisible = false
    }
}
