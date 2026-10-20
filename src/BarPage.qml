import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "BarStyle.js" as S

// omabar16, edited right here: themes, looks and colours to mix, the layout
// with its widgets and their settings, every style key, and the folder
// trays. Each change goes to the live bar at once (shell.json, which the bar
// follows), with OMAcraft's own undo. The stage at the top is the bar as it
// is, or as it would be while a tile is hovered.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property bool dialogOpen: themesTab.dialogOpen
    // `omacraft bar folders` opens on the folder trays.
    // `omacraft bar looks|colours|layout|presets|style` open there too.
    property int tab: startTab === "folders" ? 3 : startTab === "layout" || startTab === "presets" ? 1 : startTab === "style" ? 2 : 0
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
        { keys: "T / L / S / F", action: "Themes, Layout, Style, Folders" },
        { keys: "Ctrl Z", action: "Undo (Ctrl Shift Z redo)" },
        { keys: "R", action: "Shuffle: a random look in random colours" },
        { keys: "Delete", action: "Take the picked widget off the bar" }
    ]

    function handleEscape() {
        if (themesTab.closeDialogs()) return true;
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
    Shortcut { sequences: ["L", "M"]; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 1 }
    Shortcut { sequence: "S"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 2 }
    Shortcut { sequence: "F"; context: Qt.ApplicationShortcut; enabled: page.active && page.keysFree; onActivated: page.tab = 3 }
    Shortcut { sequence: "R"; context: Qt.ApplicationShortcut; enabled: page.keys && page.ready; onActivated: themesTab.shuffle() }
    Shortcut { sequence: "Ctrl+Z"; context: Qt.ApplicationShortcut; enabled: page.keys && page.ready; onActivated: bar.undo() }
    Shortcut { sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]; context: Qt.ApplicationShortcut; enabled: page.keys && page.ready; onActivated: bar.redo() }
    Shortcut {
        sequences: ["Delete", "Backspace"]
        context: Qt.ApplicationShortcut
        enabled: page.keys && page.ready && page.selKey !== ""
        onActivated: { bar.removeWidget(page.selLane, page.selIndex); page.clearSelection(); }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        PageHeader {
            title: "Bar"
            subtitle: "omabar16, edited here and applied to the live bar as you go"
            glyph: "\u{f0570}"
            Button { text: "Undo"; flat: true; focusPolicy: Qt.NoFocus; enabled: page.ready && bar.canUndo; onClicked: bar.undo() }
            Button { text: "Redo"; flat: true; focusPolicy: Qt.NoFocus; enabled: page.ready && bar.canRedo; onClicked: bar.redo() }
            Button {
                text: "Revert"
                flat: true
                focusPolicy: Qt.NoFocus
                enabled: page.ready && bar.edited
                onClicked: bar.revert()
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Back to the bar as it was when OMAcraft opened"
            }
        }

        NotInstalled {
            visible: !bar.available
            pluginId: "omabar16"
            what: "The bar is the omabar16 plugin; OMAcraft edits it."
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
            Layout.preferredHeight: page.vertical || (page.previewLayout && (page.previewLayout.position === "left" || page.previewLayout.position === "right")) ? 300 : 112
            opacity: page.ready ? 1 : 0.55
            previewing: page.previewName !== ""
            edge: page.stageCfg.position || "top"
            edgeSize: edge === "left" || edge === "right" ? stageBar.width * zoom + 40 : stageBar.height * zoom + 4
            captionRight: edge === "right" ? stageBar.width * zoom + 10 : 10
            captionBottom: edge === "bottom" ? stageBar.height * zoom + 8 : 8
            caption: page.previewName !== "" ? "Preview · " + page.previewName + " · click to apply"
                   : [bar.currentTheme !== "" ? (bar.themes.find(t => t.id === bar.currentTheme) || {}).label : "Custom look",
                      bar.currentLayout !== "" ? (bar.layouts.find(l => l.id === bar.currentLayout) || {}).label + " layout" : "your layout",
                      bar.position + " edge"].join(" · ")

            // Drawn a little larger than life, so a thin bar still reads.
            readonly property real zoom: edge === "left" || edge === "right" ? 1 : 1.4
            BarPreview {
                id: stageBar
                cfg: page.stageCfg
                themeColors: bar.themeColors
                followEdge: true
                trueSize: true
                interactive: page.ready && page.previewName === ""
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
            }
        }

        TabBar {
            Layout.fillWidth: true
            currentIndex: page.tab
            onCurrentIndexChanged: page.tab = currentIndex
            background: null
            Repeater {
                model: ["Themes", "Layout", "Style", "Folders"]
                TabButton {
                    required property string modelData
                    text: modelData
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
}
