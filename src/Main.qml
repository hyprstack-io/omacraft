import QtCore
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
    title: iso.busy && iso.progress > 0.01 ? "OmaCraft — ISO " + Math.round(iso.progress * 100) + "%" : "OmaCraft"
    color: theme.window

    // Follows the Omarchy theme: light themes get a light window.
    Material.theme: theme.dark ? Material.Dark : Material.Light
    Material.accent: Qt.color(theme.accent)
    Material.background: theme.window
    Material.foreground: theme.text

    readonly property var pages: [
        { id: "plugins", name: "Plugin Suite", glyph: "\u{f0ac6}", plugin: "", file: "PluginsPage.qml" },
        { id: "wallpaper", name: "Wallpapers", glyph: "\u{f08b9}", plugin: "omacraft.studio", file: "WallpaperPage.qml" },
        { id: "animations", name: "Window Transitions", glyph: "\u{f0d6d}", plugin: "omacraft.animations", file: "AnimationsPage.qml" },
        { id: "effects", name: "Burn My Windows", glyph: "\u{f0238}", plugin: "omacraft.burn", file: "BurnPage.qml" },
        { id: "dock", name: "Side Dock", glyph: "\u{f06a9}", plugin: "omacraft.agentdock", file: "DockPage.qml" },
        { id: "bar", name: "Main Bar", glyph: "\u{f0570}", plugin: "omabar16", file: "BarPage.qml" },
        { id: "launcher", name: "Launcher", glyph: "\u{f003b}", plugin: "omacraft.studio", file: "LauncherPage.qml" },
        { id: "rofioma", name: "ROFIoma", glyph: "\u{f1401}", plugin: "", file: "RofiomaPage.qml" },
        { id: "ascii", name: "Boot Splash", glyph: "\u{f0b9e}", plugin: "omacraft.omascii", file: "AsciiPage.qml" },
        { id: "saver", name: "Screensaver", glyph: "\u{f1104}", plugin: "", file: "ScreensaverPage.qml" },
        { id: "lock", name: "Lock & Logon", glyph: "\u{f033e}", plugin: "omacraft.lock", file: "LockLogonPage.qml" },
        { id: "cursors", name: "Cursors & Icons", glyph: "\u{f01bf}", plugin: "", file: "CursorsIconsPage.qml" },
        { id: "hyprcraft", name: "Dotfile Generator", glyph: "\u{f0b0b}", plugin: "omacraft.hyprcraft", file: "HyprCraftPage.qml" },
        { id: "iso", name: "OmaBuilds", glyph: "\u{f0a4f}", plugin: "", file: "IsoPage.qml" },
        // Off the list without an Alienware keyboard; `omacraft lights` still opens it.
        { id: "lights", name: "Alienflare", glyph: "\u{f030c}", plugin: "", file: "LightsPage.qml", hidden: !alienwareKeys },
        { id: "market", name: "Plugin Marketplace", glyph: "\u{f0003}", plugin: "", file: "PluginMarketPage.qml" },
        { id: "themes", name: "Theme Marketplace", glyph: "\u{f03d8}", plugin: "", file: "ThemeMarketPage.qml" }
    ]
    property int current: startPage
    property var visited: ({})

    property bool helpVisible: false
    property bool aboutVisible: false
    property bool navCollapsed: false
    Settings {
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/omacraft/window.ini"
        property alias navCollapsed: win.navCollapsed
    }

    // Whether a page's plugin is on, off, or missing.
    component StateDot: Rectangle {
        property string pluginState
        width: 7; height: 7; radius: 4
        color: pluginState === "on" ? theme.accent : pluginState === "off" ? theme.textFaint : "transparent"
        border.color: pluginState === "missing" ? theme.danger : "transparent"
    }

    // A small icon button for the sidebar.
    component NavButton: Rectangle {
        id: navButton
        property string glyph
        property string tip
        signal clicked()
        implicitWidth: 30
        implicitHeight: 30
        radius: 7
        opacity: enabled ? 1 : 0.4
        color: buttonHover.hovered ? theme.hover : "transparent"
        Label {
            anchors.centerIn: parent
            text: navButton.glyph
            color: buttonHover.hovered ? theme.text : theme.textMuted
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
        }
        HoverHandler { id: buttonHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: navButton.clicked() }
        ToolTip.visible: buttonHover.hovered
        ToolTip.delay: 300
        ToolTip.text: tip
    }
    property bool quitConfirmVisible: false
    property bool quitting: false

    // Each page as it loads, so bindings on the current page update.
    property var pageItems: []
    readonly property var page: pageItems[current] || null
    // Letter shortcuts stand down while a text field (or the web view) has
    // the keyboard, or a dialog is up.
    readonly property bool typing: activeFocusItem !== null && activeFocusItem.cursorPosition !== undefined
    readonly property bool overlayOpen: helpVisible || quitConfirmVisible || aboutVisible
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
    // The next page along that's on the list.
    function step(by) {
        let index = current;
        do {
            index = (index + by + pages.length) % pages.length;
        } while (pages[index].hidden);
        show(index);
    }
    function showPage(id) {
        for (let i = 0; i < pages.length; i++)
            if (pages[i].id === id) show(i);
    }
    function requestQuit() {
        if (iso.busy) {
            if (collapsed) restore("");
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

    // Closed or minimised, OmaCraft folds into a tab on the screen's edge
    // (where it was last left) rather than going away. Q and Ctrl Q, or the
    // tab's own button, quit.
    property bool collapsed: false
    function collapse() {
        if (!edgeTab.supported || collapsed) return false;
        previewLeft = 0;
        collapsed = true;
        edgeTab.attach(edgeTabWindow, win);
        edgeTabWindow.show();
        win.hide();
        return true;
    }
    // The Plugin Suite page's preview: the tab beside the open window for ten
    // seconds, following its settings as they change.
    readonly property int previewSeconds: 10
    property int previewLeft: 0
    function previewEdgeTab() {
        if (!edgeTab.supported || collapsed) return;
        previewLeft = previewSeconds;
        edgeTab.attach(edgeTabWindow, win);
        edgeTabWindow.show();
    }
    function endEdgePreview() {
        if (previewLeft === 0) return;
        previewLeft = 0;
        if (!collapsed) edgeTabWindow.hide();
    }
    Timer {
        running: win.previewLeft > 0
        interval: 1000
        repeat: true
        onTriggered: win.previewLeft > 1 ? win.previewLeft-- : win.endEdgePreview()
    }
    function restore(pageId) {
        if (pageId) showPage(pageId);
        if (!collapsed) {
            win.raise();
            win.requestActivate();
            return;
        }
        collapsed = false;
        // showNormal: this window's own show() picks a page.
        win.showNormal();
        win.raise();
        win.requestActivate();
        edgeTabWindow.hide();
    }

    onClosing: close => {
        if (quitting) return;
        if (collapse()) {
            close.accepted = false;
        } else if (iso.busy) {
            close.accepted = false;
            quitConfirmVisible = true;
        }
    }
    onVisibilityChanged: visibility => {
        if (visibility === Window.Minimized && !quitting) collapse();
    }

    EdgeTab {
        id: edgeTabWindow
        previewing: win.previewLeft > 0
        onRestoreWanted: win.previewLeft > 0 ? win.endEdgePreview() : win.restore("")
        onQuitWanted: win.requestQuit()
    }
    Connections {
        target: edgeTab
        // Launched again: the window this one already has, on that page.
        function onRestoreRequested(pageId, tabId) { win.restore(pageId); }
    }

    // --- keys ---
    Shortcut { sequence: "?"; context: Qt.ApplicationShortcut; enabled: (win.keysFree || win.helpVisible) && !win.quitConfirmVisible; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "F1"; context: Qt.ApplicationShortcut; enabled: !win.quitConfirmVisible; onActivated: { win.helpVisible = false; win.aboutVisible = !win.aboutVisible; } }
    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; enabled: win.keysFree && !(win.page && win.page.dialogOpen); onActivated: win.requestQuit() }
    Shortcut { sequence: "Ctrl+Q"; context: Qt.ApplicationShortcut; onActivated: win.requestQuit() }
    Shortcut { sequence: "Ctrl+B"; context: Qt.ApplicationShortcut; enabled: !win.webPage && !win.overlayOpen; onActivated: win.navCollapsed = !win.navCollapsed }
    Shortcut { sequence: "Ctrl+R"; context: Qt.ApplicationShortcut; enabled: !win.webPage && !win.overlayOpen; onActivated: plugins.restartShell() }
    Shortcut { sequence: "Ctrl+PgDown"; context: Qt.ApplicationShortcut; onActivated: win.step(1) }
    Shortcut { sequence: "Ctrl+PgUp"; context: Qt.ApplicationShortcut; onActivated: win.step(-1) }
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
        // Dotfile Generator's own dialogs close with Esc, so leave it to the web view.
        enabled: !win.webPage || win.overlayOpen
        onActivated: {
            if (win.quitConfirmVisible)
                win.quitConfirmVisible = false;
            else if (win.aboutVisible)
                win.aboutVisible = false;
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
        // Folds down to a rail of icons (Ctrl B, or the arrow by the logo)
        // and opens out to icon and name; it stays as it was left.
        Rectangle {
            id: sidebar
            Layout.fillHeight: true
            Layout.preferredWidth: win.navCollapsed ? 60 : 244
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            color: theme.sidebar
            clip: true
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: theme.border }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: win.navCollapsed ? 10 : 12
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 14
                    Layout.topMargin: 4
                    spacing: 10
                    AppLogo {
                        objectName: "sidebarLogo"
                        Layout.alignment: Qt.AlignHCenter
                        // Folded, the logo is what opens it out again.
                        HoverHandler { id: logoHover; enabled: win.navCollapsed; cursorShape: Qt.PointingHandCursor }
                        TapHandler { enabled: win.navCollapsed; onTapped: win.navCollapsed = false }
                        ToolTip.visible: logoHover.hovered
                        ToolTip.text: "Show the page names  (Ctrl B)"
                    }
                    ColumnLayout {
                        visible: !win.navCollapsed
                        Layout.fillWidth: true
                        spacing: 0
                        Label { text: "OmaCraft"; color: theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Label { text: "Your Omarchy plugins"; color: theme.textDim; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    NavButton {
                        visible: !win.navCollapsed
                        glyph: "\u{f0141}"
                        tip: "Fold to icons  (Ctrl B)"
                        onClicked: win.navCollapsed = true
                    }
                }

                // Scrolls when the window's too short for every page.
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: win.current
                    highlightFollowsCurrentItem: false
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    model: win.pages
                    delegate: Rectangle {
                        id: nav
                        required property var modelData
                        required property int index
                        readonly property bool chosen: win.current === index
                        readonly property string pluginState: win.pageState(modelData)
                        readonly property color tone: Qt.color(theme.accent)

                        visible: !modelData.hidden
                        width: ListView.view.width
                        height: visible ? 36 : 0
                        radius: 8
                        color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.13) : navHover.hovered ? theme.hover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: win.navCollapsed ? 0 : 10
                            anchors.rightMargin: win.navCollapsed ? 0 : 10
                            spacing: 10
                            Label {
                                Layout.preferredWidth: win.navCollapsed ? nav.width : 20
                                horizontalAlignment: win.navCollapsed ? Text.AlignHCenter : Text.AlignLeft
                                text: nav.modelData.glyph
                                color: nav.chosen ? theme.accent : theme.textMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                            }
                            Label {
                                visible: !win.navCollapsed
                                Layout.fillWidth: true
                                text: nav.modelData.name
                                color: nav.chosen ? theme.text : theme.textSoft
                                font.weight: nav.chosen ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }
                            StateDot {
                                pluginState: nav.pluginState
                                visible: !win.navCollapsed && nav.pluginState !== ""
                                ToolTip.visible: dotHover.hovered
                                ToolTip.text: nav.pluginState === "on" ? "Enabled in the shell" : nav.pluginState === "off" ? "Installed, not enabled" : "Not installed"
                                HoverHandler { id: dotHover }
                            }
                            Label {
                                visible: !win.navCollapsed
                                text: nav.index < 9 ? nav.index + 1 : ""
                                color: theme.textFaint
                                font.family: "monospace"
                                font.pixelSize: 11
                            }
                        }
                        // Folded, the dot sits on the icon's corner.
                        StateDot {
                            pluginState: nav.pluginState
                            visible: win.navCollapsed && nav.pluginState !== ""
                            x: nav.width / 2 + 7
                            y: 7
                        }
                        HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: win.show(nav.index) }
                        ToolTip.visible: win.navCollapsed && navHover.hovered
                        ToolTip.delay: 300
                        ToolTip.text: nav.modelData.name + (nav.index < 9 ? "  (" + (nav.index + 1) + ")" : "")
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: !plugins.shellRunning
                    text: win.navCollapsed ? "!" : plugins.shellInstalled ? "The shell isn't answering." : "The Omarchy shell isn't installed."
                    horizontalAlignment: win.navCollapsed ? Text.AlignHCenter : Text.AlignLeft
                    color: theme.danger
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
                Button {
                    visible: !win.navCollapsed && plugins.shellInstalled
                    Layout.fillWidth: true
                    text: "Restart shell"
                    flat: true
                    focusPolicy: Qt.NoFocus
                    enabled: !plugins.busy
                    onClicked: plugins.restartShell()
                }
                NavButton {
                    visible: win.navCollapsed && plugins.shellInstalled
                    Layout.alignment: Qt.AlignHCenter
                    glyph: "\u{f0450}"
                    tip: "Restart shell  (Ctrl R)"
                    enabled: !plugins.busy
                    onClicked: plugins.restartShell()
                }
                NavButton {
                    visible: win.navCollapsed
                    Layout.alignment: Qt.AlignHCenter
                    glyph: "\u{f02fd}"
                    tip: "About Us  (F1)"
                    onClicked: win.aboutVisible = true
                }
                NavButton {
                    visible: win.navCollapsed
                    Layout.alignment: Qt.AlignHCenter
                    glyph: "\u{f0142}"
                    tip: "Show the page names  (Ctrl B)"
                    onClicked: win.navCollapsed = false
                }
                Button {
                    objectName: "aboutButton"
                    visible: !win.navCollapsed
                    Layout.fillWidth: true
                    text: "About Us"
                    flat: true
                    focusPolicy: Qt.NoFocus
                    onClicked: win.aboutVisible = true
                }
                RowLayout {
                    visible: !win.navCollapsed
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
        // running build or an edit in Dotfile Generator survives switching away.
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
        heading: "Quit OmaCraft?"
        body: iso.state === "flashing" ? "A drive is being written. Quitting stops it, and the drive won't boot."
              : iso.state === "installing" ? "archiso is being installed. OmaCraft quits once pacman finishes."
              : "An ISO build is running. Quitting cancels it and cleans up first, which takes a few seconds."
        action: "Quit"
        onAccepted: { win.quitConfirmVisible = false; win.quitting = true; iso.cancelAndQuit(); }
        onRejected: win.quitConfirmVisible = false
    }

    AboutDialog {
        visible: win.aboutVisible
        onClosed: win.aboutVisible = false
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
                        { keys: "Ctrl B", action: "Fold the sidebar to icons, or open it out" },
                        { keys: "Ctrl R", action: "Restart the Omarchy shell" },
                        { keys: "F1", action: "About OmaCraft, credits and licences" },
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
