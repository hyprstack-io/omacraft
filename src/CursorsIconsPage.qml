import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window

// Cursors & Icons: every icon and cursor theme in the search path, a stage
// that shows the chosen pair in use, and the choice of who picks them: you,
// the Omarchy theme, or you with the colour following the wallpaper. Themes
// come in from an archive or a folder (or dropped on the page) and go out to
// OmaCraft's stash, never deleted.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    property string tab: startTab === "cursors" ? "cursors" : "icons"
    property string filter: "all"
    property string removing: ""
    readonly property bool dialogOpen: removing !== ""
    readonly property var shortcuts: [
        { keys: "I / C", action: "Icons and Cursors tabs" },
        { keys: "/", action: "Search the themes" },
        { keys: "Ctrl O", action: "Import an archive (or drop one on the page)" },
        { keys: "Ctrl Shift O", action: "Import a folder" },
        { keys: "Ctrl Z", action: "Undo the last change" },
        { keys: "Hover a tile", action: "Preview it on the stage" }
    ]

    // A tile under the mouse previews on the stage, a beat after it's reached.
    property string hoverIcons: ""
    property string hoverCursor: ""
    property string pendingIcons: ""
    property string pendingCursor: ""
    Timer {
        id: hoverDelay
        interval: 260
        onTriggered: { page.hoverIcons = page.pendingIcons; page.hoverCursor = page.pendingCursor; }
    }
    function hoverTile(kind, id) {
        pendingIcons = kind === "icons" ? id : "";
        pendingCursor = kind === "cursors" ? id : "";
        if (id === "") { hoverDelay.stop(); hoverIcons = ""; hoverCursor = ""; }
        else hoverDelay.restart();
    }

    function handleEscape() {
        if (removing !== "") { removing = ""; return true; }
        if (cursorIcons.error !== "" || cursorIcons.notice !== "") { cursorIcons.dismissMessages(); return true; }
        if (search.text !== "") { search.text = ""; return true; }
        return false;
    }
    function acceptDialog() {
        if (removing !== "") { cursorIcons.remove(removing); removing = ""; }
    }

    Shortcut { sequence: "I"; enabled: page.active && page.keysFree; onActivated: page.tab = "icons" }
    Shortcut { sequence: "C"; enabled: page.active && page.keysFree; onActivated: page.tab = "cursors" }
    Shortcut { sequence: "/"; enabled: page.active && page.keysFree; onActivated: search.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+O"; enabled: page.active && !cursorIcons.busy; onActivated: cursorIcons.chooseArchive() }
    Shortcut { sequence: "Ctrl+Shift+O"; enabled: page.active && !cursorIcons.busy; onActivated: cursorIcons.chooseFolder() }
    Shortcut { sequence: "Ctrl+Z"; enabled: page.active && cursorIcons.canUndo; onActivated: cursorIcons.undo() }

    readonly property var themes: {
        const list = tab === "icons" ? cursorIcons.iconThemes : cursorIcons.cursorThemes;
        const needle = search.text.toLowerCase();
        return list.filter(t => (filter === "all" || (filter === "mine") === t.user)
                             && (needle === "" || t.name.toLowerCase().indexOf(needle) >= 0 || t.id.toLowerCase().indexOf(needle) >= 0));
    }
    // The theme each tab marks as in use: the pick, which may wear a tint.
    readonly property string iconInUse: cursorIcons.iconTheme
    readonly property string cursorInUse: cursorIcons.cursorMode === "follow" && cursorIcons.cursorPick !== "" ? cursorIcons.cursorPick : cursorIcons.cursorTheme
    readonly property var tintKeys: ["accent", "foreground", "blue", "cyan", "green", "yellow", "orange", "red", "magenta",
                                     "bright_blue", "bright_cyan", "bright_magenta"]

    // A colour from the theme to tint with, as a round swatch.
    component Swatch: Rectangle {
        id: swatch
        property string key
        readonly property bool chosen: cursorIcons.tintKey === key
        width: 24; height: 24; radius: 12
        color: cursorIcons.themeColors[key] || "transparent"
        border.width: chosen ? 2 : 1
        border.color: chosen ? theme.text : theme.border
        scale: swatchHover.hovered ? 1.15 : chosen ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        Rectangle {
            anchors.centerIn: parent
            visible: swatch.chosen
            width: 8; height: 8; radius: 4
            readonly property color under: Qt.color(swatch.color)
            color: under.r * 0.299 + under.g * 0.587 + under.b * 0.114 > 0.6 ? "#111111" : "#ffffff"
            opacity: 0.9
        }
        HoverHandler { id: swatchHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: cursorIcons.setTintKey(swatch.key) }
        ToolTip.visible: swatchHover.hovered
        ToolTip.text: swatch.key.replace("_", " ") + "  " + swatch.color
    }

    // A tag on a tile.
    component Badge: Rectangle {
        property string text
        property bool strong: false
        readonly property color tone: Qt.color(theme.accent)
        implicitWidth: badgeLabel.implicitWidth + 12
        implicitHeight: 18
        radius: 9
        color: strong ? theme.accent : Qt.rgba(tone.r, tone.g, tone.b, 0.12)
        Label {
            id: badgeLabel
            anchors.centerIn: parent
            text: parent.text
            color: parent.strong ? theme.accentForeground : theme.textSoft
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }

    // Drop an archive or a folder anywhere on the page.
    DropArea {
        id: drop
        anchors.fill: parent
        z: 50
        keys: ["text/uri-list"]
        onDropped: drag => {
            for (const url of drag.urls) cursorIcons.importFrom(url.toString());
            drag.accept();
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            visible: drop.containsDrag
            radius: 14
            color: Qt.rgba(0, 0, 0, 0.55)
            border.width: 2
            border.color: theme.accent
            SequentialAnimation on border.width {
                running: drop.containsDrag
                loops: Animation.Infinite
                NumberAnimation { to: 5; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 2; duration: 500; easing.type: Easing.InOutSine }
            }
            Column {
                anchors.centerIn: parent
                spacing: 8
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\u{f0552}"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 54
                    color: theme.accent
                    SequentialAnimation on y {
                        running: drop.containsDrag
                        loops: Animation.Infinite
                        NumberAnimation { from: 0; to: 10; duration: 520; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 10; to: 0; duration: 520; easing.type: Easing.InOutSine }
                    }
                }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Drop to import"; color: "white"; font.pixelSize: 18; font.weight: Font.DemiBold }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Icon or cursor themes: a folder, .tar.gz, .tar.xz, .tar.zst or .zip"; color: "#d0d0d0" }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        PageHeader {
            title: "Cursors & Icons"
            subtitle: page.tab === "icons" ? "The icons apps, the launcher and file managers draw, and their colour."
                                           : "The pointer, its size, and a tint taken from the theme."
            glyph: "\u{f01bf}"
            Segmented {
                objectName: "cursorIconsTabs"
                model: [{ id: "icons", name: "Icons" }, { id: "cursors", name: "Cursors" }]
                current: page.tab
                onPicked: id => page.tab = id
            }
        }

        MessageBar {
            error: cursorIcons.error
            notice: cursorIcons.notice
            onDismissed: cursorIcons.dismissMessages()
        }

        CursorStage {
            objectName: "cursorStage"
            Layout.fillWidth: true
            Layout.preferredHeight: 236
            iconTheme: page.hoverIcons !== "" ? page.hoverIcons : cursorIcons.iconTheme
            cursorTheme: page.hoverCursor !== "" ? page.hoverCursor : cursorIcons.cursorTheme
            cursorSize: cursorIcons.cursorSize
            previewing: page.hoverIcons !== "" || page.hoverCursor !== ""
            playing: page.active && Window.window !== null && Window.window.visible
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // --- the themes ---
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    SearchBox {
                        id: search
                        Layout.preferredWidth: 240
                        placeholderText: page.tab === "icons" ? "Search icon themes" : "Search cursor themes"
                    }
                    Chip { text: "All"; chosen: page.filter === "all"; onClicked: page.filter = "all" }
                    Chip { text: "Imported"; chosen: page.filter === "mine"; onClicked: page.filter = "mine" }
                    Chip { text: "System"; chosen: page.filter === "system"; onClicked: page.filter = "system" }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: page.themes.length + (page.themes.length === 1 ? " theme" : " themes")
                        color: theme.textFaint
                        font.pixelSize: 11
                    }
                }

                GridView {
                    id: grid
                    objectName: "themeGrid"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    readonly property int columns: Math.max(1, Math.floor(width / 300))
                    cellWidth: Math.floor(width / columns)
                    cellHeight: page.tab === "icons" ? 118 : 112
                    model: page.themes
                    ScrollBar.vertical: ScrollBar {}

                    // Tiles settle in one after another when the list changes.
                    add: Transition { NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 200 } }
                    displaced: Transition { NumberAnimation { properties: "x,y"; duration: 240; easing.type: Easing.OutCubic } }

                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            id: tile
                            objectName: "themeTile-" + cell.modelData.id
                            anchors.fill: parent
                            anchors.margins: 5
                            readonly property bool icons: page.tab === "icons"
                            readonly property bool inUse: icons ? page.iconInUse === cell.modelData.id : page.cursorInUse === cell.modelData.id
                            readonly property color tone: Qt.color(theme.accent)
                            radius: 10
                            color: tileHover.hovered ? theme.hover : theme.card
                            border.width: inUse ? 2 : 1
                            border.color: inUse ? theme.accent : tileHover.hovered ? theme.borderStrong : theme.border
                            Behavior on color { ColorAnimation { duration: 140 } }

                            // Enter: rise and fade, a little after the tile before.
                            opacity: 0
                            transform: Translate { id: lift; y: 14 }
                            Component.onCompleted: enter.start()
                            SequentialAnimation {
                                id: enter
                                PauseAnimation { duration: Math.min(cell.index, 14) * 28 }
                                ParallelAnimation {
                                    NumberAnimation { target: tile; property: "opacity"; to: 1; duration: 260 }
                                    NumberAnimation { target: lift; property: "y"; to: 0; duration: 380; easing.type: Easing.OutCubic }
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                anchors.leftMargin: 12
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Rectangle {
                                        visible: tile.icons && (cell.modelData.swatch || "") !== ""
                                        width: 10; height: 10; radius: 5
                                        color: cell.modelData.swatch || "transparent"
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: cell.modelData.name
                                        color: theme.text
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Badge { visible: tile.inUse; text: "In use"; strong: true }
                                    Badge { visible: cell.modelData.user; text: "Imported" }
                                    Badge { visible: tile.icons && cell.modelData.tintable === true; text: "Tintable" }
                                    Badge { visible: !tile.icons && cell.modelData.hyprcursor === true; text: "Hyprcursor" }
                                }

                                // Icons: a row of the theme's own, lifting in a wave on hover.
                                Row {
                                    visible: tile.icons
                                    Layout.fillWidth: true
                                    spacing: 8
                                    clip: true
                                    Repeater {
                                        model: tile.icons ? cursorIcons.iconSamples(cell.modelData.id).slice(0, Math.max(1, Math.floor((tile.width - 24) / 44))) : []
                                        Image {
                                            required property var modelData
                                            required property int index
                                            width: 36; height: 36
                                            sourceSize: Qt.size(Math.round(36 * Screen.devicePixelRatio), Math.round(36 * Screen.devicePixelRatio))
                                            source: modelData.source
                                            asynchronous: true
                                            smooth: true
                                            y: tileHover.hovered ? -4 : 0
                                            Behavior on y {
                                                SequentialAnimation {
                                                    PauseAnimation { duration: index * 30 }
                                                    NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Cursors: the shapes on a checkered board, spinners spinning on hover.
                                Rectangle {
                                    visible: !tile.icons
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    radius: 7
                                    color: theme.inset
                                    clip: true
                                    Grid {
                                        anchors.fill: parent
                                        columns: Math.ceil(width / 12)
                                        opacity: 0.35
                                        Repeater {
                                            model: tile.icons ? 0 : Math.ceil(parent.width / 12) * 4
                                            Rectangle {
                                                required property int index
                                                readonly property int cols: Math.ceil(parent.width / 12)
                                                width: 12; height: 12
                                                color: (Math.floor(index / cols) + index % cols) % 2 === 0 ? theme.sunken : "transparent"
                                            }
                                        }
                                    }
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: 10
                                        spacing: 14
                                        Repeater {
                                            model: tile.icons ? [] : cursorIcons.cursorSamples(cell.modelData.id, Math.round(32 * Screen.devicePixelRatio))
                                                                     .filter(s => ["pointer", "hand", "text", "wait", "progress", "move", "resize"].indexOf(s.role) >= 0)
                                                                     .slice(0, Math.max(1, Math.floor((tile.width - 30) / 46)))
                                            CursorSprite {
                                                required property var modelData
                                                required property int index
                                                width: 32; height: 32
                                                sample: modelData
                                                playing: tileHover.hovered || tile.inUse
                                                scale: tileHover.hovered ? 1.1 : 1
                                                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                            }
                                        }
                                    }
                                    Label {
                                        anchors.centerIn: parent
                                        visible: cursorIcons.cursorSamples(cell.modelData.id, 32).length === 0
                                        text: "No preview"
                                        color: theme.textFaint
                                        font.pixelSize: 11
                                    }
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: cell.modelData.id + (cell.modelData.user ? "  ·  ~/.local/share/icons" : "")
                                    color: theme.textFaint
                                    font.family: "monospace"
                                    font.pixelSize: 10
                                    elide: Text.ElideMiddle
                                }
                            }

                            // Remove: imported themes only, never the one in use.
                            Rectangle {
                                visible: cell.modelData.user && tileHover.hovered && !tile.inUse
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                width: 24; height: 24; radius: 6
                                color: trashHover.hovered ? theme.dangerFill : "transparent"
                                Label {
                                    anchors.centerIn: parent
                                    text: "\u{f0a7a}"
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: trashHover.hovered ? theme.danger : theme.textMuted
                                }
                                HoverHandler { id: trashHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: page.removing = cell.modelData.id }
                                ToolTip.visible: trashHover.hovered
                                ToolTip.text: "Put it away in OmaCraft's stash"
                            }

                            // Picking: a ring spreads from where it was clicked.
                            Rectangle {
                                id: burst
                                property real size: 0
                                width: size; height: size; radius: size / 2
                                color: Qt.rgba(tile.tone.r, tile.tone.g, tile.tone.b, 0.25)
                                opacity: 0
                                ParallelAnimation {
                                    id: burstAnim
                                    NumberAnimation { target: burst; property: "size"; from: 0; to: tile.width * 2.2; duration: 560; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: burst; property: "opacity"; from: 1; to: 0; duration: 560; easing.type: Easing.InQuad }
                                }
                                x: cx - size / 2
                                y: cy - size / 2
                                property real cx: 0
                                property real cy: 0
                            }
                            layer.enabled: burstAnim.running
                            clip: true

                            HoverHandler {
                                id: tileHover
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: page.hoverTile(hovered ? page.tab : "", hovered ? cell.modelData.id : "")
                            }
                            TapHandler {
                                onTapped: point => {
                                    burst.cx = point.position.x;
                                    burst.cy = point.position.y;
                                    burstAnim.restart();
                                    if (tile.icons) cursorIcons.useIcons(cell.modelData.id);
                                    else cursorIcons.useCursor(cell.modelData.id);
                                }
                            }
                        }
                    }

                    // Nothing to show: say why, and how to get some.
                    Column {
                        anchors.centerIn: parent
                        visible: grid.count === 0
                        spacing: 8
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: search.text !== "" ? "\u{f0349}" : "\u{f0552}"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 36
                            color: theme.textFaint
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: search.text !== "" ? "No theme matches “" + search.text + "”"
                                : page.filter === "mine" ? "Nothing imported yet" : "No themes found"
                            color: theme.textMuted
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: search.text === ""
                            text: "Import an archive or a folder, or drop one on the page."
                            color: theme.textFaint
                            font.pixelSize: 11
                        }
                    }
                }
            }

            // --- the settings beside it ---
            Card {
                Layout.preferredWidth: 310
                Layout.fillHeight: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 14
                    contentHeight: side.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: side
                        width: parent.width
                        spacing: 10

                        SectionLabel { text: "Import" }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            AccentButton {
                                objectName: "importArchive"
                                Layout.fillWidth: true
                                text: cursorIcons.busy ? "Unpacking…" : "Archive…"
                                enabled: !cursorIcons.busy
                                onClicked: cursorIcons.chooseArchive()
                            }
                            Button {
                                Layout.fillWidth: true
                                text: "Folder…"
                                flat: true
                                focusPolicy: Qt.NoFocus
                                enabled: !cursorIcons.busy
                                onClicked: cursorIcons.chooseFolder()
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: "Packs from gnome-look, the AUR or GitHub. They go in ~/.local/share/icons, just for you."
                            color: theme.textMuted
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                        Button {
                            text: "Open the themes folder"
                            flat: true
                            focusPolicy: Qt.NoFocus
                            onClicked: cursorIcons.openFolder()
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

                        // --- icons ---
                        ColumnLayout {
                            visible: page.tab === "icons"
                            Layout.fillWidth: true
                            spacing: 8
                            SectionLabel { text: "Who picks the icons" }
                            Segmented {
                                objectName: "iconMode"
                                model: [{ id: "omarchy", name: "Omarchy" }, { id: "fixed", name: "My pick" }, { id: "follow", name: "Follow theme" }]
                                current: cursorIcons.iconMode
                                onPicked: id => cursorIcons.setIconMode(id)
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: theme.textMuted
                                font.pixelSize: 11
                                text: cursorIcons.iconMode === "omarchy" ? "Each Omarchy theme brings its own icons, and they change with it. Picking a tile switches to My pick."
                                    : cursorIcons.iconMode === "fixed" ? "Your pick stays, whatever theme you switch to."
                                    : "Your pick's family, in the colour nearest the theme's. Themes marked Tintable come in several colours (Yaru-blue, Yaru-red…)."
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "In use"; color: theme.textMuted; font.pixelSize: 11 }
                                Label {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignRight
                                    text: cursorIcons.iconTheme
                                    color: theme.accent
                                    font.family: "monospace"
                                    elide: Text.ElideLeft
                                }
                            }
                        }

                        // --- cursors ---
                        ColumnLayout {
                            visible: page.tab === "cursors"
                            Layout.fillWidth: true
                            spacing: 8
                            SectionLabel { text: "Colour" }
                            Segmented {
                                objectName: "cursorMode"
                                model: [{ id: "fixed", name: "As designed" }, { id: "follow", name: "Tint to theme" }]
                                current: cursorIcons.cursorMode
                                onPicked: id => cursorIcons.setCursorMode(id)
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: theme.textMuted
                                font.pixelSize: 11
                                text: cursorIcons.cursorMode === "follow"
                                    ? "A copy of " + (cursorIcons.cursorPick || "your cursor") + " painted in the colour below, repainted whenever the theme or wallpaper changes. The outline keeps its own colour."
                                    : "The cursor's own colours. Tint to theme repaints it from the wallpaper."
                            }

                            SectionLabel { text: "Size"; Layout.topMargin: 4 }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    model: [24, 32, 40, 48, 64, 96]
                                    Chip {
                                        required property int modelData
                                        text: modelData + ""
                                        chosen: cursorIcons.cursorSize === modelData
                                        onClicked: cursorIcons.setCursorSize(modelData)
                                    }
                                }
                            }
                            SliderRow {
                                Layout.fillWidth: true
                                label: "Custom"
                                from: 16; to: 128; stepSize: 2
                                decimals: 0
                                suffix: " px"
                                value: cursorIcons.cursorSize
                                onMoved: value => cursorIcons.setCursorSize(Math.round(value))
                            }
                        }

                        // --- the theme colour, for both ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: page.tab === "icons" ? cursorIcons.iconMode === "follow" : cursorIcons.cursorMode === "follow"
                            SectionLabel { text: "Theme colour"; Layout.topMargin: 4 }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 8
                                Repeater {
                                    model: page.tintKeys.filter(k => cursorIcons.themeColors[k] !== undefined)
                                    Swatch { required property string modelData; key: modelData }
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: theme.textFaint
                                font.pixelSize: 11
                                text: "Taken from the current Omarchy theme, so a new wallpaper or theme brings a new colour."
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
                        RowLayout {
                            Layout.fillWidth: true
                            Button {
                                text: "Undo"
                                flat: true
                                focusPolicy: Qt.NoFocus
                                enabled: cursorIcons.canUndo
                                onClicked: cursorIcons.undo()
                            }
                            Item { Layout.fillWidth: true }
                            Button {
                                objectName: "restoreDefaults"
                                text: "Omarchy defaults"
                                flat: true
                                focusPolicy: Qt.NoFocus
                                onClicked: cursorIcons.restoreDefaults()
                            }
                        }
                    }
                }
            }
        }
    }

    Confirm {
        visible: page.removing !== ""
        heading: "Put away " + page.removing + "?"
        body: "It moves to ~/.local/share/omacraft/stash/icons, where you can get it back. Nothing is deleted."
        action: "Put away"
        onAccepted: page.acceptDialog()
        onRejected: page.removing = ""
    }
}
