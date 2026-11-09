import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// OmaCraft's landing page: every plugin it houses as a module with a power
// switch. A plugin that's on runs from OmaCraft, not from an icon of its own
// on the bar; the inspector beside the grid holds the rest (where its code
// is, removing it, what it keeps on the bar).
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    property int selected: 0
    property string removing: ""
    readonly property var list: plugins.plugins
    readonly property var current: list[selected] || ({})
    readonly property bool dialogOpen: removeConfirm.visible
    readonly property int columns: Math.max(1, Math.floor((grid.width + grid.columnSpacing) / 290))
    readonly property bool wide: scroll.availableWidth > 940
    readonly property var onBar: list.filter(p => p.installed && p.barIcons > 0)
    readonly property int running: list.filter(p => p.enabled).length
    readonly property int installedCount: list.filter(p => p.installed).length
    readonly property var shortcuts: [
        { keys: "← → ↑ ↓", action: "Choose a plugin" },
        { keys: "Space", action: "Switch it on or off" },
        { keys: "I", action: "Install it" },
        { keys: "Del", action: "Remove it from the shell (its files are kept)" },
        { keys: "Enter", action: "Open its page" },
        { keys: "B", action: "Move every plugin's bar icon into OmaCraft" },
        { keys: "F5", action: "Check the shell again" },
        { keys: "Ctrl R", action: "Restart the shell" }
    ]

    function handleEscape() {
        if (removeConfirm.visible) {
            removeConfirm.visible = false;
            return true;
        }
        if (plugins.error !== "" || plugins.notice !== "") {
            plugins.dismissMessages();
            return true;
        }
        return false;
    }
    function acceptDialog() {
        removeConfirm.visible = false;
        plugins.remove(page.removing);
    }
    function askRemove(id) {
        page.removing = id;
        removeConfirm.visible = true;
    }
    function home(path) {
        return String(path || "").replace(/^\/home\/[^/]+/, "~");
    }
    function toggle(p) {
        if (!plugins.busy && p.installed)
            plugins.setEnabled(p.id, !p.enabled);
    }
    function step(by) {
        page.selected = Math.max(0, Math.min(list.length - 1, page.selected + by));
    }
    // What a plugin leaves on the bar on purpose, said where it's switched.
    function keeps(p) {
        if (p.id === "omacraft.folders") return "Its folder trays stay on the bar. Make them under Main Bar › Folders.";
        if (p.id === "omacraft.studio") return "Its launcher button stays on the bar: it's your Omarchy menu.";
        if (p.isBar) return "This one is the bar itself, so on means it's the bar you see.";
        return "";
    }

    readonly property bool keys: active && keysFree && !dialogOpen
    Shortcut { sequence: "Left"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.step(-1) }
    Shortcut { sequence: "Right"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.step(1) }
    Shortcut { sequence: "Up"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.step(-page.columns) }
    Shortcut { sequence: "Down"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.step(page.columns) }
    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; enabled: page.keys && !plugins.busy && page.current.installed === true; onActivated: page.toggle(page.current) }
    Shortcut { sequence: "I"; context: Qt.ApplicationShortcut; enabled: page.keys && !plugins.busy && page.current.canInstall === true; onActivated: plugins.install(page.current.id) }
    Shortcut { sequences: ["Delete", "X"]; context: Qt.ApplicationShortcut; enabled: page.keys && !plugins.busy && page.current.installed === true; onActivated: page.askRemove(page.current.id) }
    Shortcut { sequence: "B"; context: Qt.ApplicationShortcut; enabled: page.keys && !plugins.busy && page.onBar.length > 0; onActivated: plugins.takeIconsOffBar() }
    Shortcut { sequences: ["Return", "Enter"]; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.openPage(page.current.page) }
    Shortcut { sequence: "F5"; context: Qt.ApplicationShortcut; enabled: page.active; onActivated: plugins.refresh() }

    readonly property color tone: Qt.color(theme.accent)

    onActiveChanged: if (active && wallpaper.available) wallpaper.refresh()

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: scroll.availableWidth
            spacing: 0

            // --- hero: the name, what this is, and how things stand ---
            Item {
                Layout.fillWidth: true
                implicitHeight: hero.implicitHeight + 56

                // A faint grid behind the title, like graph paper on a CRT.
                Canvas {
                    anchors.fill: parent
                    opacity: 0.5
                    readonly property color line: theme.border
                    onLineChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = line;
                        ctx.lineWidth = 1;
                        for (let x = (width % 24) / 2; x < width; x += 24) {
                            ctx.beginPath(); ctx.moveTo(x + 0.5, 0); ctx.lineTo(x + 0.5, height); ctx.stroke();
                        }
                        for (let y = 0; y < height; y += 24) {
                            ctx.beginPath(); ctx.moveTo(0, y + 0.5); ctx.lineTo(width, y + 0.5); ctx.stroke();
                        }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(page.tone.r, page.tone.g, page.tone.b, 0.07) }
                        GradientStop { position: 1; color: theme.window }
                    }
                }

                ColumnLayout {
                    id: hero
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 30
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    spacing: 14

                    IntroTitle {
                        Layout.fillWidth: true
                        running: page.active
                    }

                    // The tagline types itself out under the art.
                    Label {
                        id: tagline
                        Layout.alignment: Qt.AlignHCenter
                        readonly property string full: "Omarchy UI/UX Tweakz Suite"
                        property int shown: 0
                        property bool caret: true
                        text: "› " + full.substring(0, shown) + (caret ? "▌" : " ")
                        color: theme.textMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        Timer {
                            interval: 38
                            repeat: true
                            running: page.active && tagline.shown < tagline.full.length
                            onTriggered: tagline.shown++
                        }
                        Timer {
                            interval: 530
                            repeat: true
                            running: page.active
                            onTriggered: tagline.caret = !tagline.caret
                        }
                    }

                    // Counters, read like a status line.
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 22
                        Repeater {
                            model: [
                                { n: page.running, what: "running" },
                                { n: page.installedCount - page.running, what: "off" },
                                { n: page.list.length - page.installedCount, what: "not installed" },
                                { n: page.onBar.length, what: "on the bar" }
                            ]
                            delegate: RowLayout {
                                required property var modelData
                                spacing: 6
                                Label {
                                    text: modelData.n
                                    color: modelData.what === "running" ? theme.accent : theme.text
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                }
                                Label { text: modelData.what; color: theme.textDim; font.pixelSize: 12 }
                            }
                        }
                        Rectangle { width: 1; height: 18; color: theme.border }
                        RowLayout {
                            spacing: 7
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: plugins.shellRunning ? theme.success : theme.danger
                                SequentialAnimation on opacity {
                                    running: page.active && plugins.shellRunning
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                                }
                            }
                            Label {
                                text: plugins.shellRunning ? "shell answering" : "shell not answering"
                                color: theme.textDim
                                font.pixelSize: 12
                            }
                        }
                    }
                }

                // Working: a light runs along the hero's foot.
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: theme.border
                    Rectangle {
                        id: runner
                        visible: plugins.busy
                        width: parent.width * 0.25
                        height: 2
                        y: -0.5
                        color: theme.accent
                        NumberAnimation on x {
                            running: plugins.busy
                            loops: Animation.Infinite
                            from: -runner.width
                            to: runner.parent.width
                            duration: 1100
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 20
                spacing: 14

                MessageBar {
                    error: plugins.error
                    notice: plugins.notice
                    onDismissed: plugins.dismissMessages()
                }
                MessageBar {
                    error: plugins.shellRunning ? ""
                           : plugins.shellInstalled ? "The Omarchy shell isn't answering. Switches still save, and take hold when it starts (omarchy-restart-shell)."
                           : "OmaCraft's plugins run in the Omarchy 4 shell, which isn't on this system, so they won't load. Run omacraft-doctor in a terminal to see what's missing."
                }

                // Plugins that still have an icon of their own on the bar.
                Rectangle {
                    Layout.fillWidth: true
                    visible: page.onBar.length > 0
                    implicitHeight: barRow.implicitHeight + 22
                    radius: 10
                    color: theme.warningFill
                    border.color: theme.warningBorder
                    RowLayout {
                        id: barRow
                        anchors.fill: parent
                        anchors.margins: 11
                        anchors.leftMargin: 16
                        spacing: 12
                        Label { text: "\u{f0570}"; color: theme.warningText; font.pixelSize: 18 }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: theme.warningText
                            text: page.onBar.map(p => p.name).join(", ")
                                  + (page.onBar.length === 1 ? " still has its own icon" : " still have their own icons")
                                  + " on the bar. Everything they do is here in OmaCraft."
                        }
                        AccentButton {
                            text: "Move into OmaCraft"
                            enabled: !plugins.busy
                            onClicked: plugins.takeIconsOffBar()
                        }
                    }
                }

                // Side by side when there's room; otherwise the inspector
                // follows the modules.
                GridLayout {
                    Layout.fillWidth: true
                    columns: page.wide ? 2 : 1
                    columnSpacing: 16
                    rowSpacing: 16

                    // --- the modules ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "MODULES"
                                color: theme.textFaint
                                font.pixelSize: 11
                                font.letterSpacing: 2
                                font.weight: Font.DemiBold
                            }
                            Item { Layout.fillWidth: true }
                            Button { text: "Check again"; flat: true; focusPolicy: Qt.NoFocus; enabled: !plugins.busy; onClicked: plugins.refresh() }
                            Button { text: "Restart shell"; visible: plugins.shellInstalled; flat: true; focusPolicy: Qt.NoFocus; enabled: !plugins.busy; onClicked: plugins.restartShell() }
                        }

                        GridLayout {
                            id: grid
                            Layout.fillWidth: true
                            columns: page.columns
                            columnSpacing: 12
                            rowSpacing: 12

                            Repeater {
                                model: page.list
                                delegate: ModuleTile {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    info: modelData
                                    chosen: page.selected === index
                                    busy: plugins.busy
                                    onPicked: page.selected = index
                                    onSwitched: page.toggle(modelData)
                                    onInstall: plugins.install(modelData.id)
                                    onOpen: page.openPage(modelData.page)
                                }
                            }
                        }

                        Label {
                            Layout.topMargin: 14
                            text: "BUILT IN"
                            color: theme.textFaint
                            font.pixelSize: 11
                            font.letterSpacing: 2
                            font.weight: Font.DemiBold
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 10
                            Repeater {
                                model: [
                                    { page: "iso", name: "ISOma Builder", glyph: "\u{f0a4f}", what: "Arch ISOs with archiso, written to USB" },
                                    { page: "saver", name: "Screensaver", glyph: "\u{f1104}", what: "The Omarchy screensaver's art and effects" },
                                    { page: "lights", name: "Keyboard Lighting", glyph: "\u{f030c}", what: "Per-key lighting for the Alienware x15" }
                                ].filter(item => item.page !== "lights" || alienwareKeys)
                                delegate: Rectangle {
                                    id: builtIn
                                    required property var modelData
                                    width: builtInRow.implicitWidth + 28
                                    height: 46
                                    radius: 10
                                    color: builtInHover.hovered ? theme.hover : theme.card
                                    border.color: theme.border
                                    RowLayout {
                                        id: builtInRow
                                        anchors.centerIn: parent
                                        spacing: 10
                                        Label { text: builtIn.modelData.glyph; color: theme.accent; font.pixelSize: 17 }
                                        ColumnLayout {
                                            spacing: 0
                                            Label { text: builtIn.modelData.name; color: theme.text; font.weight: Font.DemiBold; font.pixelSize: 13 }
                                            Label { text: builtIn.modelData.what; color: theme.textDim; font.pixelSize: 11 }
                                        }
                                        Label { text: "›"; color: theme.textDim; font.pixelSize: 16 }
                                    }
                                    HoverHandler { id: builtInHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: page.openPage(builtIn.modelData.page) }
                                }
                            }
                        }
                    }

                    // --- the inspector: the chosen module in full ---
                    Card {
                        id: inspector
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 320
                        Layout.fillWidth: !page.wide
                        visible: page.current.id !== undefined
                        implicitHeight: detail.implicitHeight + 36
                        readonly property var p: page.current

                        ColumnLayout {
                            id: detail
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 12

                            RowLayout {
                                spacing: 12
                                Rectangle {
                                    width: 46; height: 46; radius: 12
                                    color: Qt.rgba(page.tone.r, page.tone.g, page.tone.b, inspector.p.enabled ? 0.18 : 0.06)
                                    border.color: inspector.p.enabled ? theme.accent : theme.border
                                    Label {
                                        anchors.centerIn: parent
                                        text: inspector.p.glyph || ""
                                        color: inspector.p.enabled ? theme.accent : theme.textMuted
                                        font.pixelSize: 22
                                    }
                                }
                                ColumnLayout {
                                    spacing: 2
                                    Label { text: inspector.p.name || ""; color: theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                                    Label {
                                        text: (inspector.p.id || "") + (inspector.p.version ? "  v" + inspector.p.version : "")
                                        color: theme.textFaint
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            StatePill {
                                text: inspector.p.state || ""
                                on: inspector.p.enabled === true
                                warn: inspector.p.state === "Broken link" || inspector.p.state === "Not found by the shell"
                                      || (inspector.p.duplicates || []).length > 0 || inspector.p.barIcons > 0
                            }

                            Label {
                                Layout.fillWidth: true
                                text: inspector.p.summary || ""
                                color: theme.textSoft
                                wrapMode: Text.WordWrap
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: page.keeps(inspector.p)
                                color: theme.textDim
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                            Label { text: "CODE"; color: theme.textFaint; font.pixelSize: 10; font.letterSpacing: 2 }
                            Label {
                                Layout.fillWidth: true
                                color: theme.textDim
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                wrapMode: Text.WrapAnywhere
                                text: inspector.p.linked && inspector.p.installed
                                      ? "Linked from " + page.home(inspector.p.linkTarget)
                                      : inspector.p.installed ? "Installed in " + page.home(inspector.p.dir)
                                      : inspector.p.stashed ? "Set aside in " + page.home(inspector.p.dir) + ", ready to install again"
                                      : inspector.p.sourceExists ? "Code in " + page.home(inspector.p.source)
                                      : "Code not found" + (inspector.p.source ? " at " + page.home(inspector.p.source) : "")
                            }
                            TextField {
                                Layout.fillWidth: true
                                text: page.home(inspector.p.source)
                                placeholderText: "~/Projects/my-plugin (a folder with manifest.json)"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                onEditingFinished: if (text !== page.home(inspector.p.source)) plugins.setSource(inspector.p.id, text)
                            }
                            Label {
                                text: inspector.p.sourceExists ? "A plugin is there." : "No manifest.json there."
                                color: inspector.p.sourceExists ? theme.accent : theme.danger
                                font.pixelSize: 11
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                spacing: 8
                                AccentButton {
                                    text: "Open page"
                                    onClicked: page.openPage(inspector.p.page)
                                }
                                AccentButton {
                                    visible: !inspector.p.installed
                                    enabled: inspector.p.canInstall === true && !plugins.busy
                                    text: "Install"
                                    onClicked: plugins.install(inspector.p.id)
                                }
                                Item { Layout.fillWidth: true }
                                Button {
                                    visible: inspector.p.installed === true
                                    enabled: !plugins.busy
                                    text: "Remove"
                                    flat: true
                                    focusPolicy: Qt.NoFocus
                                    Material.foreground: theme.danger
                                    onClicked: page.askRemove(inspector.p.id)
                                }
                            }
                        }
                    }
                }

                // --- the wallpaper's colour scheme, the same card as
                // Wallpapers › Colours, so either page sets it ---
                Label {
                    Layout.topMargin: 14
                    text: "COLOUR SCHEME"
                    color: theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 2
                    font.weight: Font.DemiBold
                }
                PaletteCard {
                    Layout.fillWidth: true
                    visible: wallpaper.available
                }
                Label {
                    Layout.fillWidth: true
                    visible: !wallpaper.available
                    text: "The colour scheme comes from Hyprskin, inside the Studio plugin. Install Studio above to set it here."
                    color: theme.textDim
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                // --- the tab OmaCraft folds into when minimised ---
                Label {
                    Layout.topMargin: 14
                    text: "EDGE TAB"
                    color: theme.textFaint
                    font.pixelSize: 11
                    font.letterSpacing: 2
                    font.weight: Font.DemiBold
                }
                Card {
                    Layout.fillWidth: true
                    implicitHeight: tabColumn.implicitHeight + 32
                    ColumnLayout {
                        id: tabColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                Layout.fillWidth: true
                                text: edgeTab.supported
                                      ? "Where the tab sits and how it looks when OmaCraft is minimised. You can still drag it round the edge; it stays where it's left."
                                      : "The edge tab needs a Wayland compositor with layer shell, so it isn't shown here. These are kept for when it is."
                                color: theme.textDim
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                            Button { text: "Reset"; flat: true; focusPolicy: Qt.NoFocus; onClicked: edgeTab.reset() }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Label { Layout.preferredWidth: 120; text: "Edge"; color: theme.textSoft }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    model: [{ value: "top", label: "Top" }, { value: "bottom", label: "Bottom" }, { value: "left", label: "Left" }, { value: "right", label: "Right" }]
                                    Chip {
                                        required property var modelData
                                        text: modelData.label
                                        chosen: edgeTab.edge === modelData.value
                                        onClicked: edgeTab.setOption("edge", modelData.value)
                                    }
                                }
                            }
                        }
                        SliderRow {
                            label: "Position"
                            from: 0; to: 100; stepSize: 1; decimals: 0; suffix: "%"
                            value: Math.round(edgeTab.offset * 100)
                            onMoved: v => edgeTab.setOption("offset", v / 100)
                        }
                        SliderRow {
                            label: "Tab length"
                            from: 60; to: 400; stepSize: 5; decimals: 0; suffix: " px"
                            value: edgeTab.length
                            onMoved: v => edgeTab.setOption("length", Math.round(v))
                        }
                        SliderRow {
                            label: "Tab width"
                            from: 24; to: 90; stepSize: 1; decimals: 0; suffix: " px"
                            value: edgeTab.thickness
                            onMoved: v => edgeTab.setOption("thickness", Math.round(v))
                        }
                        SliderRow {
                            label: "Tab opacity"
                            from: 20; to: 100; stepSize: 5; decimals: 0; suffix: "%"
                            value: Math.round(edgeTab.opacity * 100)
                            onMoved: v => edgeTab.setOption("opacity", v / 100)
                        }
                        SwitchRow {
                            label: "Show the icon"
                            hint: "The accent square with OmaCraft's mark."
                            checked: edgeTab.showIcon
                            onToggled: on => edgeTab.setOption("showIcon", on)
                        }
                        SwitchRow {
                            label: "Show the title"
                            hint: "Turned to read along the side edges; cut short when the tab is too short for it."
                            checked: edgeTab.showTitle
                            onToggled: on => edgeTab.setOption("showTitle", on)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            enabled: edgeTab.showTitle
                            Label { Layout.preferredWidth: 120; text: "Title"; color: theme.textSoft }
                            TextField {
                                Layout.fillWidth: true
                                text: edgeTab.title
                                placeholderText: "OmaCraft"
                                onEditingFinished: if (text !== edgeTab.title) edgeTab.setOption("title", text)
                            }
                        }

                        // Ten seconds of the real tab, to judge changes by.
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 10
                            AccentButton {
                                text: win.previewLeft > 0 ? "Hide the tab" : "Show the tab for " + win.previewSeconds + " seconds"
                                enabled: edgeTab.supported
                                onClicked: win.previewLeft > 0 ? win.endEdgePreview() : win.previewEdgeTab()
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: win.previewLeft > 0
                                text: "Hiding in " + win.previewLeft + "s. Changes above show on it as you make them."
                                color: theme.textDim
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }

    Confirm {
        id: removeConfirm
        readonly property var target: plugins.plugins.find(p => p.id === page.removing) || ({})
        heading: "Remove " + (target.name || page.removing) + " from the shell?"
        body: target.isBar && target.enabled
              ? "The bar goes back to Omarchy's built-in one first. " + (target.linked ? "The link is removed; the code stays where it is." : "Its folder is set aside in ~/.local/share/omacraft/stash, so Install brings it back.")
              : (target.linked ? "It's switched off, then its link is removed. The code stays where it is." : "It's switched off, then its folder is set aside in ~/.local/share/omacraft/stash, so Install brings it back.")
        action: "Remove"
        keepText: "Keep it"
        onAccepted: page.acceptDialog()
        onRejected: visible = false
    }
}
