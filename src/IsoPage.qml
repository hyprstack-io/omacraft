import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// HyprBUILDZ: hyprbuildz, the ISO builder. The stage is the build itself,
// step by step from the profile to the USB drive, with the Build button and
// its progress; each step opens the tab that sets it. Its keys work while
// the page is showing; the window asks before quitting mid-build.
Item {
    id: win

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property color accent: theme.accent
    readonly property color accentForeground: theme.accentForeground
    readonly property color line: theme.border

    property int tab: startTab === "contents" ? 1 : startTab === "options" ? 2 : startTab === "log" ? 3 : 0
    property bool flashVisible: false
    property bool editorVisible: false
    property bool cancelConfirmVisible: false

    readonly property bool dialogOpen: cancelConfirmVisible
    readonly property bool overlayOpen: flashVisible || editorVisible || dialogOpen
    // Letter shortcuts stand down while a text field has the keyboard.
    readonly property bool typing: Window.activeFocusItem !== null && Window.activeFocusItem.cursorPosition !== undefined
    readonly property bool keysFreeHere: active && keysFree && !overlayOpen
    readonly property bool building: iso.state === "building" || iso.state === "checking" || iso.state === "measuring"
    readonly property var profiles: [
        { id: "releng", name: "Live installer", glyph: "\u{f08c7}", detail: "The official Arch ISO, with archinstall.", art: ["archinstall", "pacstrap", "grub"] },
        { id: "baseline", name: "Minimal", glyph: "\u{f0a4f}", detail: "A bare live system to build on.", art: ["bash", "pacman", "systemd"] },
        { id: "replica", name: "This desktop", glyph: "\u{f0379}", detail: "Boots into a copy of this desktop.", art: ["your apps", "your theme", "your home"] }
    ]
    readonly property var profileInfo: profiles.find(p => p.id === iso.profile) || profiles[0]
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
    function commitFields() { keySink.forceActiveFocus(); }
    function build() {
        commitFields();
        iso.build();
        tab = 3;
    }
    function home(path) { return path.replace(/^\/home\/[^/]+/, "~"); }
    // Opens a tab, then puts the keyboard in one of its fields.
    function focusOn(index, field) {
        tab = index;
        Qt.callLater(() => field.forceActiveFocus());
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
    Shortcut { sequence: "P"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing; onActivated: { win.tab = 0; iso.profile = ({ releng: "baseline", baseline: "replica", replica: "releng" })[iso.profile]; } }
    Shortcut { sequence: "N"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing; onActivated: win.focusOn(1, isoNameField) }
    Shortcut { sequence: "H"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing; onActivated: win.focusOn(1, hostnameField) }
    Shortcut { sequence: "E"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing; onActivated: win.focusOn(1, packagesArea) }
    Shortcut { sequence: "O"; context: Qt.ApplicationShortcut; enabled: win.keysFreeHere && !win.typing && iso.profile !== "replica"; onActivated: { win.tab = 1; iso.chooseOverlay(); } }
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
        anchors.margins: 20
        spacing: 12

        PageHeader {
            title: "HyprBUILDZ"
            subtitle: "hyprbuildz: custom Arch Linux ISOs, built with archiso and written to USB"
            glyph: "\u{f0a4f}"
            Button { text: "Undo"; flat: true; focusPolicy: Qt.NoFocus; enabled: iso.canUndo; onClicked: iso.undo() }
            Button { text: "Redo"; flat: true; focusPolicy: Qt.NoFocus; enabled: iso.canRedo; onClicked: iso.redo() }
            Button { text: "Write to USB…"; flat: true; focusPolicy: Qt.NoFocus; enabled: !iso.busy; onClicked: win.flashVisible = true }
        }

        // --- what's wrong, or what just happened ---
        Rectangle {
            Layout.fillWidth: true
            visible: message.text !== ""
            implicitHeight: messageRow.implicitHeight + 20
            radius: 8
            readonly property bool bad: iso.error !== "" || (iso.notice === "" && iso.missing !== "")
            color: bad ? theme.dangerFill : Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.10)
            border.color: bad ? theme.dangerBorder : Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.45)
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
                    color: parent.parent.bad ? theme.dangerText : theme.text
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

        // --- the stage: the build, step by step ---
        Stage {
            id: stage
            Layout.fillWidth: true
            Layout.preferredHeight: 196
            windows: false
            previewing: iso.busy
            caption: iso.busy ? (iso.cancelling ? "Stopping and cleaning up…" : iso.stage || "Working…")
                   : iso.builtIso !== "" ? "Built " + win.home(iso.builtIso).split("/").pop() + " · F writes it to USB"
                   : win.profileInfo.name + " · saved in " + win.home(iso.outputDir)

            readonly property var steps: [
                { name: win.profileInfo.name, label: "Profile", glyph: win.profileInfo.glyph, tab: 0,
                  detail: iso.profile === "replica" ? iso.desktopUser + "'s desktop" : win.profileInfo.detail },
                { name: iso.profile === "replica" ? (iso.nativeCount + iso.foreignPackages.length + iso.packageCount) + " packages"
                                                  : iso.packageCount === 0 ? "No extras" : iso.packageCount + " extra",
                  label: "Packages", glyph: "\u{f03d7}", tab: 1,
                  detail: iso.profile === "replica" ? iso.desktopKernel + " kernel" : "from your repositories" },
                { name: iso.profile === "replica" ? (iso.sizing ? "measuring…" : iso.homeSize)
                                                  : (iso.overlays.length + iso.editedFiles.length) === 0 ? "None" : iso.overlays.length + " folders · " + iso.editedFiles.length + " files",
                  label: iso.profile === "replica" ? "Home" : "Files", glyph: "\u{f024b}", tab: 1,
                  detail: iso.profile === "replica" ? (iso.replicaSecrets ? "with passwords" : "no passwords") : (iso.omarchySetup ? "+ Omarchy setup" : "your additions") },
                { name: iso.timezone || "UTC", label: "Options", glyph: "\u{f0493}", tab: 2,
                  detail: [iso.keymap, iso.compression].filter(x => x).join(" · ") },
                { name: iso.isoName + ".iso", label: "ISO", glyph: "\u{f02ca}", tab: 3,
                  detail: iso.builtIso !== "" && !iso.busy ? "ready" : iso.busy ? Math.round(iso.progress * 100) + "%" : win.home(iso.outputDir) },
                { name: "USB drive", label: "Write", glyph: "\u{f0553}", tab: -1,
                  detail: iso.state === "flashing" ? "writing…" : "F to write" }
            ]

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                anchors.bottomMargin: 40
                spacing: 14

                // The steps, joined by arrows; the one being built glows.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4
                    Repeater {
                        model: stage.steps
                        delegate: RowLayout {
                            id: stepRow
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            Layout.minimumWidth: 0
                            spacing: 4
                            Rectangle {
                                id: stepCard
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1
                                Layout.minimumWidth: 0
                                radius: 10
                                readonly property bool live: win.building && stepRow.index === 4 || iso.state === "flashing" && stepRow.index === 5
                                readonly property bool done: iso.builtIso !== "" && !iso.busy && stepRow.index <= 4
                                color: live ? Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.28)
                                     : stepHover.hovered ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(0, 0, 0, 0.38)
                                border.color: live || done ? win.accent : Qt.rgba(1, 1, 1, 0.1)
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 3
                                    RowLayout {
                                        Label { text: stepRow.modelData.glyph; color: win.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
                                        Label { text: stepRow.modelData.label.toUpperCase(); color: "#aaaaaa"; font.pixelSize: 9; font.letterSpacing: 1.2; Layout.fillWidth: true; elide: Text.ElideRight }
                                        Label { visible: stepCard.done; text: "\u{f012c}"; color: win.accent; font.pixelSize: 12 }
                                    }
                                    Item { Layout.fillHeight: true }
                                    Label { Layout.fillWidth: true; text: stepRow.modelData.name; color: "#f0f0f0"; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                    Label { Layout.fillWidth: true; text: stepRow.modelData.detail || ""; color: "#b8b8b8"; font.pixelSize: 10; elide: Text.ElideRight }
                                }
                                HoverHandler { id: stepHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        if (stepRow.modelData.tab >= 0) win.tab = stepRow.modelData.tab;
                                        else if (!iso.busy) win.flashVisible = true;
                                    }
                                }
                            }
                            Label {
                                visible: stepRow.index < stage.steps.length - 1
                                text: "\u{f0142}"
                                color: Qt.rgba(1, 1, 1, 0.35)
                                font.pixelSize: 14
                            }
                        }
                    }
                }

                // The main action: build, or cancel while building.
                Rectangle {
                    id: buildButton
                    Layout.preferredWidth: 170
                    Layout.fillHeight: true
                    radius: 12
                    opacity: (iso.busy && !win.building) || iso.cancelling ? 0.5 : 1
                    color: win.building ? Qt.rgba(0, 0, 0, 0.45) : buildHover.hovered ? Qt.lighter(win.accent, 1.08) : win.accent
                    border.color: win.building ? win.accent : "transparent"
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: iso.cancelling ? "Cancelling…" : win.building ? "Cancel build" : "Build ISO"
                            color: win.building ? "#f0f0f0" : win.accentForeground
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            visible: iso.busy
                            text: iso.elapsed + (iso.remaining !== "" ? " · " + iso.remaining : "")
                            color: "#dddddd"
                            font.family: "monospace"
                            font.pixelSize: 11
                        }
                        KeyCap {
                            Layout.alignment: Qt.AlignHCenter
                            text: win.building ? "Esc" : "Space"
                            tint: win.building ? "#dddddd" : win.accentForeground
                        }
                    }
                    HoverHandler { id: buildHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (win.building) {
                                if (!iso.cancelling)
                                    win.cancelConfirmVisible = true;
                            } else if (!iso.busy) {
                                win.build();
                            }
                        }
                    }
                }
            }

            // How far along, across the bottom of the stage.
            Rectangle {
                id: track
                visible: iso.busy || iso.stage !== ""
                readonly property bool indeterminate: iso.busy && iso.progress <= 0.01
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 14
                anchors.bottomMargin: 15
                width: parent.width * 0.55
                height: 8
                radius: 4
                color: Qt.rgba(0, 0, 0, 0.4)
                clip: true
                Rectangle {
                    visible: !track.indeterminate
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(radius * 2, parent.width * Math.min(1, iso.progress))
                    radius: 4
                    color: iso.cancelling ? "#888888" : win.accent
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                }
                // Waiting for the password or pacman's check: a sweep.
                Rectangle {
                    id: sweep
                    visible: track.indeterminate
                    width: parent.width * 0.25
                    height: parent.height
                    radius: 4
                    color: win.accent
                    opacity: 0.7
                    SequentialAnimation on x {
                        running: sweep.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: -sweep.width; to: track.width; duration: 1400; easing.type: Easing.InOutQuad }
                    }
                }
            }
            Label {
                visible: track.visible && !track.indeterminate
                anchors.left: track.right
                anchors.leftMargin: 8
                anchors.verticalCenter: track.verticalCenter
                text: Math.round(iso.progress * 100) + "%"
                color: win.accent
                font.family: "monospace"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }

        TabBar {
            Layout.fillWidth: true
            currentIndex: win.tab
            onCurrentIndexChanged: win.tab = currentIndex
            background: null
            Repeater {
                model: ["Profile", "Contents", "Options", "Build log" + (logModel.count > 0 ? " · " + logModel.count : "")]
                TabButton {
                    required property string modelData
                    text: modelData
                    focusPolicy: Qt.NoFocus
                    width: implicitWidth + 24
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: win.tab

            // ================= Profile =================
            ScrollView {
                id: profileScroll
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    width: profileScroll.availableWidth
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "What the ISO starts from"; color: theme.textDim; font.pixelSize: 11; Layout.fillWidth: true }
                        KeyCap { text: "P" }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Repeater {
                            model: win.profiles
                            delegate: Rectangle {
                                id: profileTile
                                required property var modelData
                                readonly property bool chosen: iso.profile === modelData.id
                                readonly property color tone: Qt.color(theme.accent)
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: 176
                                radius: 12
                                color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.12) : profileHover.hovered ? theme.hover : theme.inset
                                border.color: chosen ? theme.accent : profileHover.hovered ? theme.borderStrong : theme.border
                                border.width: chosen ? 2 : 1
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8
                                    // A little picture of what boots: a screen with its layers.
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 84
                                        radius: 8
                                        color: theme.sunken
                                        Label {
                                            x: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: profileTile.modelData.glyph
                                            color: profileTile.chosen ? theme.accent : theme.textMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 40
                                        }
                                        Column {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4
                                            Repeater {
                                                model: profileTile.modelData.art
                                                Rectangle {
                                                    required property string modelData
                                                    required property int index
                                                    width: 110 - index * 8
                                                    height: 18
                                                    radius: 4
                                                    anchors.right: parent.right
                                                    color: Qt.rgba(profileTile.tone.r, profileTile.tone.g, profileTile.tone.b, profileTile.chosen ? 0.35 - index * 0.08 : 0.14)
                                                    Label { anchors.centerIn: parent; text: modelData; color: theme.text; font.pixelSize: 10; font.family: "monospace" }
                                                }
                                            }
                                        }
                                    }
                                    Label { text: profileTile.modelData.name; color: profileTile.chosen ? theme.accent : theme.text; font.weight: Font.DemiBold; font.pixelSize: 14 }
                                    Label { Layout.fillWidth: true; text: profileTile.modelData.detail; color: theme.textMuted; font.pixelSize: 11; wrapMode: Text.WordWrap }
                                }
                                HoverHandler { id: profileHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: iso.profile = profileTile.modelData.id }
                            }
                        }
                    }

                    // This desktop: what comes along.
                    Card {
                        visible: iso.profile === "replica"
                        Layout.fillWidth: true
                        implicitHeight: replicaCol.implicitHeight + 28
                        ColumnLayout {
                            id: replicaCol
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8
                            SectionLabel { text: "What comes along" }
                            Label {
                                Layout.fillWidth: true
                                text: "The live ISO signs in as you and starts your desktop. Changes made while it runs last until it shuts down."
                                color: theme.textDim
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                            Label {
                                visible: iso.desktopError !== ""
                                Layout.fillWidth: true
                                text: iso.desktopError
                                color: theme.danger
                                wrapMode: Text.WordWrap
                            }
                            Repeater {
                                model: iso.desktopError !== "" ? [] : [
                                    iso.nativeCount + " packages from your repositories, and the " + iso.desktopKernel + " kernel",
                                    iso.foreignPackages.length === 0 ? "" :
                                        iso.foreignPackages.length + " AUR packages, rebuilt from what's installed: " + iso.foreignPackages.join(", "),
                                    "Your changed and added system settings in /etc, and /usr/local",
                                    iso.desktopUser + ", signed in automatically, with " + (iso.sizing ? "…" : iso.homeSize) + " from your home folder"
                                ].filter(line => line !== "")
                                delegate: RowLayout {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Label { text: "•"; color: win.accent; Layout.alignment: Qt.AlignTop }
                                    Label { Layout.fillWidth: true; text: modelData; color: theme.textSoft; wrapMode: Text.WordWrap }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                implicitHeight: groups.implicitHeight + 16
                                radius: 8
                                color: theme.inset
                                border.color: win.line
                                ColumnLayout {
                                    id: groups
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4
                                    HomeGroup { kind: "settings"; title: "Settings"; detail: "Your desktop, theme, shell, and apps' configuration." }
                                    HomeGroup { kind: "secret"; title: "Sign-ins and secrets"; detail: "Browser profiles, keys, tokens, and history. Anyone with the drive can read them." }
                                    HomeGroup { kind: "personal"; title: "Personal folders"; detail: "Documents, pictures, projects." }
                                    HomeGroup { kind: "cache"; title: "Caches and toolchains"; detail: "Rebuilt or re-downloaded as needed." }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        Label { text: "Include passwords"; color: theme.text }
                                        KeyCap { text: "W" }
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: iso.replicaSecrets
                                              ? "Your login password, Wi-Fi networks, and SSH and VPN keys are on the ISO."
                                              : "Left out: the live user has no password and sudo doesn't ask; Wi-Fi is set up again."
                                        color: theme.textDim
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
                    }

                    // The others: Omarchy on top.
                    Card {
                        visible: iso.profile !== "replica"
                        Layout.fillWidth: true
                        implicitHeight: omarchyRow.implicitHeight + 28
                        RowLayout {
                            id: omarchyRow
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12
                            Label { text: "\u{f08c7}"; color: win.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                RowLayout {
                                    Label { text: "Set up Omarchy after installing Arch"; color: theme.text }
                                    KeyCap { text: "M" }
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: "Adds an <b>omarchy-setup</b> command to the live ISO. It runs archinstall, then sets the Omarchy installer to start when the new user first logs in."
                                    color: theme.textDim
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                }
                            }
                            Switch {
                                checked: iso.omarchySetup
                                focusPolicy: Qt.NoFocus
                                onToggled: iso.omarchySetup = checked
                            }
                        }
                    }
                    Item { implicitHeight: 4 }
                }
            }

            // ================= Contents =================
            ScrollView {
                id: contentScroll
                contentWidth: availableWidth
                clip: true
                GridLayout {
                    width: contentScroll.availableWidth
                    columns: width > 940 ? 2 : 1
                    columnSpacing: 14
                    rowSpacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 14
                        Card {
                            Layout.fillWidth: true
                            implicitHeight: identity.implicitHeight + 28
                            RowLayout {
                                id: identity
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 14
                                Field {
                                    label: "ISO name"
                                    key: "N"
                                    TextField { id: isoNameField; Layout.fillWidth: true; text: iso.isoName; font.family: "monospace"; onEditingFinished: iso.isoName = text }
                                }
                                Field {
                                    label: "Hostname"
                                    key: "H"
                                    TextField { id: hostnameField; Layout.fillWidth: true; text: iso.hostname; font.family: "monospace"; onEditingFinished: iso.hostname = text }
                                }
                            }
                        }
                        Card {
                            Layout.fillWidth: true
                            implicitHeight: packagesField.implicitHeight + 28
                            Field {
                                id: packagesField
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                label: "Extra packages · " + iso.packageCount
                                key: "E"
                                hint: "From your enabled repositories, separated by spaces or lines. # starts a comment. Esc when done."
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 170
                                    radius: 8
                                    color: theme.inset
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
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 14
                        Card {
                            visible: iso.profile !== "replica"
                            Layout.fillWidth: true
                            implicitHeight: foldersField.implicitHeight + 28
                            Field {
                                id: foldersField
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                label: "Folders to include"
                                key: "O"
                                hint: "Each folder's contents go into the live system at the path beside it. / merges into the root, so <i>folder</i>/etc/issue becomes /etc/issue. Shift O removes them all."
                                Label { visible: iso.overlays.length === 0; text: "None"; color: theme.textDim; font.family: "monospace" }
                                Repeater {
                                    model: iso.overlays
                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        implicitHeight: overlayCol.implicitHeight + 16
                                        radius: 8
                                        color: theme.inset
                                        border.color: win.line
                                        ColumnLayout {
                                            id: overlayCol
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 2
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Label { text: "\u{f024b}"; color: win.accent; font.family: "JetBrainsMono Nerd Font" }
                                                Label {
                                                    Layout.fillWidth: true
                                                    text: win.home(modelData.source)
                                                    color: modelData.exists ? theme.text : theme.danger
                                                    font.family: "monospace"
                                                    elide: Text.ElideMiddle
                                                    ToolTip.visible: !modelData.exists && missingHover.hovered
                                                    ToolTip.text: "This folder doesn't exist any more."
                                                    HoverHandler { id: missingHover }
                                                }
                                                ToolButton { text: "\u{f0156}"; focusPolicy: Qt.NoFocus; onClicked: iso.removeOverlay(index); ToolTip.visible: hovered; ToolTip.text: "Remove" }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8
                                                Label { text: "goes to"; color: theme.textDim; font.pixelSize: 12 }
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
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Item { Layout.fillWidth: true }
                                    Button { text: "Add folder…"; flat: true; focusPolicy: Qt.NoFocus; onClicked: iso.chooseOverlay() }
                                }
                            }
                        }
                        Card {
                            visible: iso.profile !== "replica"
                            Layout.fillWidth: true
                            implicitHeight: filesField.implicitHeight + 28
                            Field {
                                id: filesField
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                label: "Configuration files"
                                key: "T"
                                hint: "Change any file on the live system, or the profile's own (pacman.conf, boot menus), in an editor with syntax colouring. These win over the folders."
                                Label { visible: iso.editedFiles.length === 0; text: "None edited"; color: theme.textDim; font.family: "monospace" }
                                Repeater {
                                    model: iso.editedFiles
                                    delegate: RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Label { text: "\u{f0219}"; color: win.accent; font.family: "JetBrainsMono Nerd Font" }
                                        Label { Layout.fillWidth: true; text: modelData.name; color: theme.text; font.family: "monospace"; elide: Text.ElideMiddle }
                                        Label { text: modelData.lines + (modelData.lines === 1 ? " line" : " lines"); color: theme.textDim; font.pixelSize: 12 }
                                        Button { text: "Edit"; flat: true; focusPolicy: Qt.NoFocus; onClicked: { win.editorVisible = true; editorPanel.openFile(modelData.path); } }
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Item { Layout.fillWidth: true }
                                    Button { text: "Edit a file…"; flat: true; focusPolicy: Qt.NoFocus; onClicked: win.editorVisible = true }
                                }
                            }
                        }
                        Card {
                            visible: iso.profile === "replica"
                            Layout.fillWidth: true
                            implicitHeight: replicaNote.implicitHeight + 28
                            Label {
                                id: replicaNote
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                text: "A copy of this desktop takes your system as it is, so there are no folders or files to add here. Extra packages still go on top."
                                color: theme.textMuted
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            // ================= Options =================
            ScrollView {
                id: optionsScroll
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    width: optionsScroll.availableWidth
                    spacing: 14
                    Card {
                        Layout.fillWidth: true
                        implicitHeight: saveRow.implicitHeight + 28
                        Field {
                            id: saveRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            label: "Save ISO in"
                            key: "D"
                            RowLayout {
                                Layout.fillWidth: true
                                Label { Layout.fillWidth: true; text: win.home(iso.outputDir); color: theme.text; font.family: "monospace"; elide: Text.ElideMiddle }
                                Button { text: "Choose…"; flat: true; focusPolicy: Qt.NoFocus; onClicked: iso.chooseOutput() }
                            }
                        }
                    }
                    Card {
                        Layout.fillWidth: true
                        implicitHeight: options.implicitHeight + 36
                        OptionsSection {
                            id: options
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 18
                            accent: win.accent
                            line: win.line
                        }
                    }
                    Item { implicitHeight: 4 }
                }
            }

            // ================= Build log =================
            ColumnLayout {
                spacing: 10
                // The finished ISO, ready to write to a drive.
                Rectangle {
                    Layout.fillWidth: true
                    visible: iso.builtIso !== "" && !iso.busy
                    implicitHeight: resultRow.implicitHeight + 20
                    radius: 10
                    color: Qt.rgba(win.accent.r, win.accent.g, win.accent.b, 0.1)
                    border.color: win.accent
                    RowLayout {
                        id: resultRow
                        anchors.fill: parent
                        anchors.margins: 10
                        anchors.leftMargin: 14
                        spacing: 10
                        Label { text: "\u{f012c}"; color: win.accent; font.pixelSize: 16 }
                        Label { Layout.fillWidth: true; text: win.home(iso.builtIso); color: theme.text; font.family: "monospace"; elide: Text.ElideMiddle }
                        AccentButton { text: "Write to USB…"; onClicked: win.flashVisible = true }
                        KeyCap { text: "F" }
                    }
                }
                // mkarchiso's output, as it comes.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: theme.sidebar
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
                            color: line.indexOf("ERROR") >= 0 || line.indexOf("error:") >= 0 ? theme.danger
                                 : line.indexOf("hyprbuildz:") === 0 ? win.accent
                                 : line.indexOf("WARNING") >= 0 ? theme.warning : theme.textMuted
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
                        color: theme.textFaint
                        lineHeight: 1.3
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
