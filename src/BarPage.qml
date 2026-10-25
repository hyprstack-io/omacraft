import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "BarStyle.js" as S

// omabar16, edited right here: themes, looks and colours to mix, the
// widgets and where they sit (or hidden, kept for later), every style key,
// and the folder trays. Each change goes to the live bar at once
// (shell.json, which the bar follows), with OmaCraft's own undo. The stage
// at the top is the bar as it is, or as it would be while a tile is
// hovered, and its widgets can be dragged along it.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property bool dialogOpen: themesTab.dialogOpen
    // `omacraft bar folders` opens on the folder trays.
    // `omacraft bar looks|colours|widgets|hidden|presets|style` open there too.
    property int tab: startTab === "folders" ? 3 : ["layout", "presets", "widgets", "hidden"].indexOf(startTab) >= 0 ? 1 : startTab === "style" ? 2 : 0
    readonly property bool ready: bar.available && bar.inUse

    // A tile being hovered: its style or layout, shown on the stage.
    property var previewStyle: null
    property var previewLayout: null
    property string previewName: ""
    function preview(name, style, layout) {
        previewName = name;
        previewStyle = style || null;
        previewLayout = layout || null;
    }
    function endPreview(name) {
        if (previewName !== name) return;
        previewName = "";
        previewStyle = null;
        previewLayout = null;
    }

    // Names and glyphs, read through the lists they come from, so bindings
    // fill in when the installed widgets (or the presets) arrive.
    function widgetName(id) { return bar.widgets.length >= 0 ? bar.widgetName(id) : id; }
    function glyphFor(id) { return bar.glyphs ? bar.glyphFor(id) : ""; }
    function entryName(entry) { return entry.id === "omacraft.folders" ? (entry.name || "Folder") : widgetName(entry.id); }

    // The widget picked on the stage or in the lanes, as lane and index.
    property string selLane: ""
    property int selIndex: -1
    readonly property var selEntry: selLane !== "" ? (bar.layout[selLane] || [])[selIndex] || null : null
    readonly property string selKey: selEntry ? selLane + ":" + selIndex : ""
    function select(lane, index) {
        selLane = lane;
        selIndex = index;
    }
    function clearSelection() {
        selLane = "";
        selIndex = -1;
    }
    function hide(lane, index) {
        bar.hideWidget(lane, index);
        clearSelection();
    }

    // --- dragging: one chip under the pointer, from the stage, a lane, the
    // shelf or the hidden tray, dropped on the stage, a lane or the tray ---
    property var drag: null             // { fromLane, fromIndex, newId, hiddenIndex, glyph, name }
    property string dropOn: ""          // stage | lanes | hidden
    property string dropLane: ""
    property int dropIndex: -1
    function startDrag(payload, scenePos) {
        drag = Object.assign({ fromLane: "", fromIndex: -1, newId: "", hiddenIndex: -1 }, payload);
        moveDrag(scenePos);
    }
    function moveDrag(scenePos) {
        const p = page.mapFromItem(null, scenePos.x, scenePos.y);
        ghost.x = p.x - ghost.width / 2;
        ghost.y = p.y - ghost.height / 2;
        const t = stageBar.dropTarget(scenePos);
        if (t) {
            dropOn = "stage";
            dropLane = t.lane;
            dropIndex = t.index;
        } else if (dropOn === "stage") {
            clearDrop();
        }
    }
    function clearDrop() {
        dropOn = "";
        dropLane = "";
        dropIndex = -1;
    }
    function endDrag() {
        const d = drag;
        if (d && dropOn === "hidden") {
            if (d.fromLane !== "") hide(d.fromLane, d.fromIndex);
        } else if (d && dropLane !== "") {
            if (d.hiddenIndex >= 0) bar.showWidget(d.hiddenIndex, dropLane, dropIndex);
            else if (d.newId) bar.addWidget(d.newId, dropLane, dropIndex);
            else {
                bar.moveWidget(d.fromLane, d.fromIndex, dropLane, dropIndex);
                clearSelection();
            }
        }
        drag = null;
        clearDrop();
    }

    readonly property var stageCfg: {
        const c = S.clone(bar.config) || {};
        if (previewStyle) c.style = previewStyle;
        if (previewLayout) {
            c.layout = previewLayout.layout;
            c.centerAnchor = previewLayout.anchor || "";
            if (previewLayout.position) c.position = previewLayout.position;
        }
        return c;
    }
    readonly property var vertical: bar.position === "left" || bar.position === "right"
    readonly property var laneNames: vertical ? { left: "Top", center: "Middle", right: "Bottom" }
                                              : { left: "Left", center: "Centre", right: "Right" }

    readonly property var shortcuts: [
        { keys: "T / W / S / F", action: "Themes, Widgets, Style, Folders" },
        { keys: "Ctrl Z", action: "Undo (Ctrl Shift Z redo)" },
        { keys: "R", action: "Shuffle: a random look in random colours" },
        { keys: "H", action: "Hide the picked widget (it stays installed)" },
        { keys: "Delete", action: "Take the picked widget off the bar" }
    ]

    function handleEscape() {
        if (themesTab.closeDialogs()) return true;
        if (drag) {
            drag = null;
            clearDrop();
            return true;
        }
        if (selKey !== "") {
            clearSelection();
            return true;
        }
        if (bar.error !== "" || bar.notice !== "") {
            bar.dismissMessages();
            return true;
        }
        return false;
    }
    function acceptDialog() { themesTab.acceptDialog(); }

    onActiveChanged: if (active) { bar.reload(); bar.refreshWidgets(); }

    readonly property bool keys: active && keysFree && bar.available
    Shortcut { sequence: "T"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 0 }
    Shortcut { sequences: ["W", "L", "M"]; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 1 }
    Shortcut { sequence: "S"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 2 }
    Shortcut { sequence: "F"; context: Qt.ApplicationShortcut; enabled: page.active && page.keysFree; onActivated: page.tab = 3 }
    Shortcut { sequence: "R"; context: Qt.ApplicationShortcut; enabled: page.keys && page.ready; onActivated: themesTab.shuffle() }
    Shortcut { sequence: "Ctrl+Z"; context: Qt.ApplicationShortcut; enabled: page.keys && page.ready; onActivated: bar.undo() }
    Shortcut { sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]; context: Qt.ApplicationShortcut; enabled: page.keys && page.ready; onActivated: bar.redo() }
    Shortcut {
        sequence: "H"
        context: Qt.ApplicationShortcut
        enabled: page.keys && page.ready && page.selKey !== ""
        onActivated: page.hide(page.selLane, page.selIndex)
    }
    Shortcut {
        sequences: ["Delete", "Backspace"]
        context: Qt.ApplicationShortcut
        enabled: page.keys && page.ready && page.selKey !== ""
        onActivated: { bar.removeWidget(page.selLane, page.selIndex); page.clearSelection(); }
    }

    // A round icon button for the header and the stage.
    component IconButton: ToolButton {
        property string tip
        implicitWidth: 38
        implicitHeight: 38
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        focusPolicy: Qt.NoFocus
        ToolTip.visible: hovered && tip !== ""
        ToolTip.delay: 400
        ToolTip.text: tip
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        PageHeader {
            title: "Main Bar"
            subtitle: "omabar16, edited here and applied to the live bar as you go"
            glyph: "\u{f0570}"
            IconButton { text: "\u{f054c}"; tip: "Undo (Ctrl Z)"; enabled: page.ready && bar.canUndo; onClicked: bar.undo() }
            IconButton { text: "\u{f044e}"; tip: "Redo (Ctrl Shift Z)"; enabled: page.ready && bar.canRedo; onClicked: bar.redo() }
            Button {
                text: "Revert"
                flat: true
                focusPolicy: Qt.NoFocus
                enabled: page.ready && bar.edited
                onClicked: bar.revert()
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Back to the bar as it was when OmaCraft opened"
            }
        }

        NotInstalled {
            visible: !bar.available
            pluginId: "omabar16"
            what: "The bar is the omabar16 plugin; OmaCraft edits it."
        }

        MessageBar {
            error: bar.error
            notice: bar.notice
            onDismissed: bar.dismissMessages()
        }

        // Installed but another bar is showing.
        Rectangle {
            visible: bar.available && !bar.inUse
            Layout.fillWidth: true
            implicitHeight: useRow.implicitHeight + 20
            radius: 8
            color: theme.warningFill
            border.color: theme.warningBorder
            RowLayout {
                id: useRow
                anchors.fill: parent
                anchors.margins: 10
                anchors.leftMargin: 14
                Label {
                    Layout.fillWidth: true
                    text: "Your bar is " + bar.barId + ", not omabar16, so changes here wouldn't show. Use omabar16 to edit it."
                    color: theme.warningText
                    wrapMode: Text.WordWrap
                }
                AccentButton {
                    text: "Use omabar16"
                    onClicked: bar.useAsBar()
                }
            }
        }

        // --- the stage: a strip of desktop with the bar on its edge ---
        Stage {
            id: stage
            visible: bar.available
            Layout.fillWidth: true
            Layout.preferredHeight: page.vertical || (page.previewLayout && (page.previewLayout.position === "left" || page.previewLayout.position === "right")) ? 300 : 150
            opacity: page.ready ? 1 : 0.55
            previewing: page.previewName !== "" || page.dropOn === "stage"
            edge: page.stageCfg.position || "top"
            edgeSize: edge === "left" || edge === "right" ? stageBar.width * zoom + 40 : stageBar.height * zoom + 4
            captionRight: edge === "right" ? stageBar.width * zoom + 10 : 10
            captionBottom: edge === "bottom" ? stageBar.height * zoom + 8 : 8
            caption: page.previewName !== "" ? "Preview · " + page.previewName + " · click to apply"
                   : page.drag ? "Drop on the bar to place it"
                   : [bar.currentTheme !== "" ? (bar.themes.find(t => t.id === bar.currentTheme) || {}).label : "Custom look",
                      bar.currentLayout !== "" ? (bar.layouts.find(l => l.id === bar.currentLayout) || {}).label + " layout" : "your layout",
                      bar.position + " edge",
                      bar.hidden.length > 0 ? bar.hidden.length + " hidden" : "",
                      "drag widgets to move them"].filter(t => t !== "").join(" · ")

            // Drawn a little larger than life, so a thin bar still reads.
            readonly property real zoom: edge === "left" || edge === "right" ? 1 : 1.4
            BarPreview {
                id: stageBar
                cfg: page.stageCfg
                themeColors: bar.themeColors
                followEdge: true
                trueSize: true
                interactive: page.ready && page.previewName === ""
                draggable: interactive
                draggingKey: page.drag && page.drag.fromLane !== "" ? page.drag.fromLane + ":" + page.drag.fromIndex : ""
                dropLane: page.dropOn === "stage" ? page.dropLane : ""
                dropIndex: page.dropIndex
                selectedKey: page.selKey
                fontPx: 12
                scale: stage.zoom
                transformOrigin: stage.edge === "right" ? Item.TopRight : stage.edge === "bottom" ? Item.BottomLeft : Item.TopLeft
                x: stage.edge === "right" ? stage.width - width - 1 : 1
                y: stage.edge === "bottom" ? stage.height - height - 1 : 1
                width: vertical ? implicitWidth : (stage.width - 2) / stage.zoom
                height: vertical ? (stage.height - 2) / stage.zoom : implicitHeight
                onSegmentClicked: (lane, index) => {
                    page.select(lane, index);
                    page.tab = 1;
                    layoutTab.showArrange();
                }
                onBackgroundClicked: page.clearSelection()
                onDragStarted: (lane, index, pos) => {
                    const e = (bar.layout[lane] || [])[index] || { id: "" };
                    page.startDrag({ fromLane: lane, fromIndex: index, glyph: e.icon || page.glyphFor(e.id), name: page.entryName(e) }, pos);
                }
                onDragMoved: pos => page.moveDrag(pos)
                onDragEnded: page.endDrag()
            }

            // The picked widget's quick actions, where it was picked.
            Row {
                visible: page.selEntry !== null && page.ready && !page.drag
                anchors.left: stage.edge === "left" ? undefined : parent.left
                anchors.right: stage.edge === "left" ? parent.right : undefined
                anchors.bottom: parent.bottom
                anchors.margins: 10
                anchors.bottomMargin: stage.edge === "bottom" ? stage.edgeSize + 6 : 10
                spacing: 6
                Rectangle {
                    height: 30
                    width: pickRow.implicitWidth + 20
                    radius: 15
                    color: Qt.rgba(0, 0, 0, 0.55)
                    border.color: theme.accent
                    Row {
                        id: pickRow
                        anchors.centerIn: parent
                        spacing: 10
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.selEntry ? page.entryName(page.selEntry) : ""
                            color: "#eeeeee"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u{f0209}  Hide"
                            color: hideHover.hovered ? theme.accent : "#cccccc"
                            font.pixelSize: 11
                            HoverHandler { id: hideHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: page.hide(page.selLane, page.selIndex) }
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u{f0156}  Remove"
                            color: removeHover.hovered ? theme.accent : "#cccccc"
                            font.pixelSize: 11
                            HoverHandler { id: removeHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: { bar.removeWidget(page.selLane, page.selIndex); page.clearSelection(); } }
                        }
                    }
                }
            }
        }

        TabBar {
            Layout.fillWidth: true
            currentIndex: page.tab
            onCurrentIndexChanged: page.tab = currentIndex
            background: null
            Repeater {
                model: ["Themes", "Widgets", "Style", "Folders"]
                TabButton {
                    required property string modelData
                    required property int index
                    text: modelData + (index === 1 && bar.hidden.length > 0 ? " · " + bar.hidden.length + " hidden" : "")
                    focusPolicy: Qt.NoFocus
                    width: implicitWidth + 24
                }
            }
        }

        StackLayout {
            // Folders work on any bar; the other tabs need omabar16.
            visible: bar.available || page.tab === 3
            enabled: page.ready || page.tab === 3
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: page.tab

            BarThemesTab { id: themesTab; page: page }
            BarLayoutTab { id: layoutTab; page: page }
            BarStyleTab { page: page }
            FoldersPanel {}
        }
    }

    // The widget under the pointer while dragging; lanes and the hidden
    // tray take it through Drag, the stage through dropTarget().
    Rectangle {
        id: ghost
        visible: page.drag !== null
        width: ghostRow.implicitWidth + 22
        height: 36
        radius: 10
        z: 100
        color: theme.raised
        border.color: page.dropOn === "hidden" ? theme.textMuted : theme.accent
        border.width: 1.5
        opacity: 0.96
        Drag.active: page.drag !== null
        Drag.keys: ["barwidget"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Row {
            id: ghostRow
            anchors.centerIn: parent
            spacing: 8
            Label {
                text: page.dropOn === "hidden" ? "\u{f0209}" : page.drag ? page.drag.glyph : ""
                color: theme.accent
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
            }
            Label {
                text: page.drag ? (page.dropOn === "hidden" ? "Hide " + page.drag.name : page.drag.name) : ""
                color: theme.text
                font.pixelSize: 12
            }
        }
    }
}
