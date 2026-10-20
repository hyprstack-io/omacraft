import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win
    width: 1320
    height: 860
    minimumWidth: 900
    minimumHeight: 600
    visible: true
    title: iso.busy && iso.progress > 0.01 ? "OMAcraft — ISO " + Math.round(iso.progress * 100) + "%" : "OMAcraft"
    color: theme.window

    // Follows the Omarchy theme: light themes get a light window.
    Material.theme: theme.dark ? Material.Dark : Material.Light
    Material.accent: Qt.color(theme.accent)
    Material.background: theme.window
    Material.foreground: theme.text

    readonly property var pages: [
        { id: "plugins", name: "Plugins", glyph: "\u{f0ac6}", plugin: "", file: "PluginsPage.qml" },
        { id: "wallpaper", name: "Wallpaper", glyph: "\u{f08b9}", plugin: "omacraft.studio", file: "WallpaperPage.qml" },
        { id: "animations", name: "Animations", glyph: "\u{f0d6d}", plugin: "omacraft.animations", file: "AnimationsPage.qml" },
        { id: "effects", name: "Window FX", glyph: "\u{f0238}", plugin: "omacraft.burn", file: "BurnPage.qml" },
        { id: "dock", name: "HyprDOCKN", glyph: "\u{f06a9}", plugin: "omacraft.agentdock", file: "DockPage.qml" },
        { id: "bar", name: "Bar", glyph: "\u{f0570}", plugin: "omabar16", file: "BarPage.qml" },
        { id: "launcher", name: "HyprLAUNCH", glyph: "\u{f003b}", plugin: "omacraft.studio", file: "LauncherPage.qml" },
        { id: "ascii", name: "HyprSPLASH", glyph: "\u{f0b9e}", plugin: "omacraft.omascii", file: "AsciiPage.qml" },
        { id: "hyprcraft", name: "HyprFIGZ", glyph: "\u{f0b0b}", plugin: "omacraft.hyprcraft", file: "HyprCraftPage.qml" },
        { id: "iso", name: "HyprBUILDZ", glyph: "\u{f0a4f}", plugin: "", file: "IsoPage.qml" },
        { id: "lights", name: "HyprKEYZ", glyph: "\u{f030c}", plugin: "", file: "LightsPage.qml" }
    ]
    property int current: startPage
    property var visited: ({})

    property bool helpVisible: false
    property bool quitConfirmVisible: false
    property bool quitting: false

    // Each page as it loads, so bindings on the current page update.
    property var pageItems: []
    readonly property var page: pageItems[current] || null
    // Letter shortcuts stand down while a text field (or the web view) has
    // the keyboard, or a dialog is up.
    readonly property bool typing: activeFocusItem !== null && activeFocusItem.cursorPosition !== undefined
    readonly property bool overlayOpen: helpVisible || quitConfirmVisible
    readonly property bool webPage: page !== null && page.capturesKeys === true
    readonly property bool keysFree: !typing && !overlayOpen && !webPage

    function show(index) {
        if (index < 0 || index >= pages.length) return;
        current = index;
        // A new object, so bindings on visited see the change.
        const seen = Object.assign({}, visited);
        seen[index] = true;
        visited = seen;
        helpVisible = false;
    }
    function showPage(id) {
        for (let i = 0; i < pages.length; i++)
            if (pages[i].id === id) show(i);
    }
    function requestQuit() {
        if (iso.busy) {
            quitConfirmVisible = true;
        } else {
            quitting = true;
            Qt.quit();
        }
    }
    // The state dot beside each page: the plugin's, or none.
    function pageState(entry) {
        if (entry.plugin === "") return "";
        const info = plugins.plugins.find(p => p.id === entry.plugin) || {};
        if (!info.installed) return "missing";
        return info.enabled ? "on" : "off";
    }

    Component.onCompleted: show(current)

    onClosing: close => {
        if (iso.busy && !quitting) {
            close.accepted = false;
            quitConfirmVisible = true;
        }
    }

    // --- keys ---
    Shortcut { sequence: "?"; context: Qt.ApplicationShortcut; enabled: (win.keysFree || win.helpVisible) && !win.quitConfirmVisible; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; enabled: win.keysFree && !(win.page && win.page.dialogOpen); onActivated: win.requestQuit() }
    Shortcut { sequence: "Ctrl+Q"; context: Qt.ApplicationShortcut; onActivated: win.requestQuit() }
    Shortcut { sequence: "Ctrl+R"; context: Qt.ApplicationShortcut; enabled: !win.webPage && !win.overlayOpen; onActivated: plugins.restartShell() }
    Shortcut { sequence: "Ctrl+PgDown"; context: Qt.ApplicationShortcut; onActivated: win.show((win.current + 1) % win.pages.length) }
    Shortcut { sequence: "Ctrl+PgUp"; context: Qt.ApplicationShortcut; onActivated: win.show((win.current + win.pages.length - 1) % win.pages.length) }
    Repeater {
        model: win.pages.length
        Item {
            required property int index
            // Pages past the ninth are reached with Ctrl PgUp / PgDn.
            Shortcut { sequence: index < 9 ? "Ctrl+" + (index + 1) : ""; context: Qt.ApplicationShortcut; enabled: index < 9; onActivated: win.show(index) }
            Shortcut { sequence: index < 9 ? String(index + 1) : ""; context: Qt.ApplicationShortcut; enabled: win.keysFree && index < 9; onActivated: win.show(index) }
        }
    }

    // Esc and Enter belong to whatever is on top: the window's own dialogs,
    // then the page's.
    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        // HyprFIGZ's own dialogs close with Esc, so leave it to the web view.
        enabled: !win.webPage || win.overlayOpen
        onActivated: {
            if (win.quitConfirmVisible)
                win.quitConfirmVisible = false;
            else if (win.helpVisible)
                win.helpVisible = false;
            else if (win.page && win.page.handleEscape && win.page.handleEscape())
                return;
            else if (win.typing)
                keySink.forceActiveFocus();
        }
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        context: Qt.ApplicationShortcut
        enabled: win.quitConfirmVisible || (win.page !== null && win.page.dialogOpen === true)
        onActivated: {
            if (win.quitConfirmVisible) {
                win.quitConfirmVisible = false;
                win.quitting = true;
                iso.cancelAndQuit();
            } else {
                win.page.acceptDialog();
            }
        }
    }

    // Holds the keyboard when no field does, so letter shortcuts work.
    Item { id: keySink; focus: true }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // --- sidebar ---
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 220
            color: theme.sidebar
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: theme.border }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 4

                RowLayout {
                    Layout.bottomMargin: 18
                    Layout.topMargin: 6
                    spacing: 10
                    Rectangle {
                        width: 32; height: 32; radius: 9
                        color: theme.accent
                        Label {
                            anchors.centerIn: parent
                            text: "◆"
                            color: theme.accentForeground
                            font.pixelSize: 15
                        }
                    }
                    ColumnLayout {
                        spacing: 0
                        Label { text: "OMAcraft"; color: theme.text; font.pixelSize: 17; font.weight: Font.DemiBold }
                        Label { text: "Your Omarchy plugins"; color: theme.textDim; font.pixelSize: 11 }
                    }
                }

                Repeater {
                    model: win.pages
                    delegate: Rectangle {
                        id: nav
                        required property var modelData
                        required property int index
                        readonly property bool chosen: win.current === index
                        readonly property string pluginState: win.pageState(modelData)
                        readonly property color tone: Qt.color(theme.accent)

                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: 8
                        color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.13) : navHover.hovered ? theme.hover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10
                            Label {
                                Layout.preferredWidth: 20
                                text: nav.modelData.glyph
                                color: nav.chosen ? theme.accent : theme.textMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                            }
                            Label {
                                Layout.fillWidth: true
                                text: nav.modelData.name
                                color: nav.chosen ? theme.text : theme.textSoft
                                font.weight: nav.chosen ? Font.DemiBold : Font.Normal
                            }
                            // Whether the page's plugin is on, off, or missing.
                            Rectangle {
                                visible: nav.pluginState !== ""
                                width: 7; height: 7; radius: 4
                                color: nav.pluginState === "on" ? theme.accent : nav.pluginState === "off" ? theme.textFaint : "transparent"
                                border.color: nav.pluginState === "missing" ? theme.danger : "transparent"
                                ToolTip.visible: dotHover.hovered
                                ToolTip.text: nav.pluginState === "on" ? "Enabled in the shell" : nav.pluginState === "off" ? "Installed, not enabled" : "Not installed"
                                HoverHandler { id: dotHover }
                            }
                            Label {
                                text: nav.index < 9 ? nav.index + 1 : ""
                                color: theme.textFaint
                                font.family: "monospace"
                                font.pixelSize: 11
                            }
                        }
                        HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: win.show(nav.index) }
                    }
                }

                Item { Layout.fillHeight: true }

                Label {
                    Layout.fillWidth: true
                    visible: !plugins.shellRunning
                    text: "The shell isn't answering."
                    color: theme.danger
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
                Button {
                    Layout.fillWidth: true
                    text: "Restart shell"
                    flat: true
                    focusPolicy: Qt.NoFocus
                    enabled: !plugins.busy
                    onClicked: plugins.restartShell()
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    Label { text: "Shortcuts"; color: theme.textFaint; font.pixelSize: 11 }
                    KeyCap { text: "?" }
                    Item { Layout.fillWidth: true }
                    Label { text: "Quit"; color: theme.textFaint; font.pixelSize: 11 }
                    KeyCap { text: "Q" }
                }
            }
        }

        // --- pages ---
        // Each page loads the first time it's opened and then stays, so a
        // running build or an edit in HyprFIGZ survives switching away.
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: win.current

            Repeater {
                model: win.pages
                delegate: Loader {
                    required property var modelData
                    required property int index
                    active: win.visited[index] === true
                    source: modelData.file
                    onLoaded: {
                        item.openPage.connect(win.showPage);
                        const items = win.pageItems.slice();
                        items[index] = item;
                        win.pageItems = items;
                    }
                    Binding { target: item; property: "active"; value: win.current === index; when: item !== null }
                    Binding { target: item; property: "keysFree"; value: win.keysFree; when: item !== null }
                }
            }
        }
    }

    // --- quitting mid-build ---
    Confirm {
        visible: win.quitConfirmVisible
        heading: "Quit OMAcraft?"
        body: iso.state === "flashing" ? "A drive is being written. Quitting stops it, and the drive won't boot."
              : iso.state === "installing" ? "archiso is being installed. OMAcraft quits once pacman finishes."
              : "An ISO build is running. Quitting cancels it and cleans up first, which takes a few seconds."
        action: "Quit"
        onAccepted: { win.quitConfirmVisible = false; win.quitting = true; iso.cancelAndQuit(); }
        onRejected: win.quitConfirmVisible = false
    }

    // --- shortcuts overlay: the window's, then this page's ---
    Rectangle {
        visible: win.helpVisible
        anchors.fill: parent
        color: "#cc000000"
        z: 60

        MouseArea { anchors.fill: parent; onClicked: win.helpVisible = false }

        Rectangle {
            anchors.centerIn: parent
            width: helpColumn.width + 56
            height: helpColumn.height + 48
            radius: 12
            color: theme.raised

            Column {
                id: helpColumn
                anchors.centerIn: parent
                spacing: 9

                component HelpRow: Row {
                    required property var modelData
                    spacing: 18
                    Label {
                        width: 120
                        horizontalAlignment: Text.AlignRight
                        text: modelData.keys
                        color: theme.accent
                        font.family: "monospace"
                    }
                    Label { text: modelData.action; color: theme.textSoft }
                }

                Label {
                    text: "Keyboard shortcuts"
                    color: theme.text
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    bottomPadding: 8
                }
                Repeater {
                    model: [
                        { keys: "1 … 9", action: "Switch pages (Ctrl 1 … 9 anywhere)" },
                        { keys: "Ctrl PgUp/PgDn", action: "Previous / next page" },
                        { keys: "Ctrl R", action: "Restart the Omarchy shell" },
                        { keys: "Esc", action: "Close, dismiss, or leave a field" },
                        { keys: "Q", action: "Quit (asks first while an ISO builds)" },
                        { keys: "?", action: "Show these shortcuts" }
                    ]
                    delegate: HelpRow {}
                }
                Label {
                    visible: win.page !== null && (win.page.shortcuts || []).length > 0
                    text: win.pages[win.current].name
                    color: theme.text
                    font.weight: Font.DemiBold
                    topPadding: 10
                    bottomPadding: 4
                }
                Repeater {
                    model: win.page ? (win.page.shortcuts || []) : []
                    delegate: HelpRow {}
                }
            }
        }
    }
}
