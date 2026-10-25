import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "BarStyle.js" as S

// Where the bar sits and what's on it. Arrange: a slim strip for the edge
// and spacing, then the three lanes, with widgets dragged between them, onto
// the stage, in from the shelf, or out to the hidden tray (off the bar, its
// plugin and settings kept). The picked one's settings take the side panel.
// Presets: whole arrangements from omabar16, JaKooLit and HANCORE, each
// drawn as the bar it makes.
Item {
    id: tab
    property var page

    property string view: startTab === "presets" ? "presets" : "arrange"     // arrange | presets
    property string side: startTab === "hidden" ? "hidden" : "add"           // add | hidden
    property string presetGroup: "All"
    function showArrange() { view = "arrange"; }

    readonly property var lanes: ["left", "center", "right"]
    readonly property bool dragging: page.drag !== null

    // Widgets not on the bar (or hidden) yet, and those that can go on more than once.
    readonly property var onBar: lanes.reduce((all, l) => all.concat((bar.layout[l] || []).map(e => e.id)), [])
                                      .concat(bar.hidden.map(h => h.entry.id))
    readonly property var shelf: bar.widgets.filter(w => (w.multiple || onBar.indexOf(w.id) < 0)
                                                    && (shelfSearch.text === "" || (w.name + " " + w.id + " " + w.category).toLowerCase().indexOf(shelfSearch.text.toLowerCase()) >= 0))
                                     .sort((a, b) => a.category.localeCompare(b.category) || a.name.localeCompare(b.name))

    function detail(entry) {
        if (entry.id === "omarchy.clock") return S.clockSample(entry.format || "dddd HH:mm");
        if (entry.id === "omarchy.spacer") return (entry.size || 12) + " px";
        if (entry.id === "omacraft.folders") return (entry.apps || []).length + " apps";
        const bits = [];
        if (entry.icon) bits.push("own icon");
        if (entry.color) bits.push("own colour");
        if (entry.opacity !== undefined) bits.push(Math.round(entry.opacity * 100) + "%");
        return bits.join(" · ");
    }

    // A widget's glyph in a small well, in its own colour.
    component Glyph: Rectangle {
        property var entry: ({ id: "" })
        width: 28; height: 28; radius: 7
        color: theme.sunken
        Label {
            anchors.centerIn: parent
            text: parent.entry.icon || tab.page.glyphFor(parent.entry.id)
            color: S.isHex(parent.entry.color) ? parent.entry.color : theme.accent
            font.family: parent.entry.iconFont || "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }
    }
    // A small labelled slider for the placement strip.
    component MiniSlider: RowLayout {
        property string label
        property real from: 0
        property real to: 24
        property real value: 0
        signal moved(real value)
        spacing: 8
        Label { text: parent.label; color: theme.textSoft; font.pixelSize: 12 }
        Slider {
            Layout.preferredWidth: 120
            from: parent.from; to: parent.to; stepSize: 1
            value: parent.value
            focusPolicy: Qt.NoFocus
            onMoved: parent.moved(Math.round(value))
        }
        Label { text: Math.round(parent.value) + " px"; color: theme.accent; font.family: "monospace"; font.pixelSize: 11; Layout.preferredWidth: 38 }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Segmented {
                model: [{ id: "arrange", name: "Arrange" }, { id: "presets", name: "Preset layouts" }]
                current: tab.view
                onPicked: id => tab.view = id
            }
            Label {
                Layout.leftMargin: 8
                Layout.fillWidth: true
                text: tab.view === "arrange" ? "Drag widgets along the stage, between lanes, or to Hidden to keep them off the bar. Click one for its settings."
                                             : "Applying a layout moves widgets; their own settings, hidden ones and other plugins' widgets stay."
                color: theme.textDim
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        // ================= Arrange =================
        // --- where on the screen, in one strip ---
        Card {
            visible: tab.view === "arrange"
            Layout.fillWidth: true
            implicitHeight: 52
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 14
                Label { text: "EDGE"; color: theme.textFaint; font.pixelSize: 10; font.letterSpacing: 1.2; font.weight: Font.DemiBold }
                Segmented {
                    model: [{ id: "top", name: "\u{f005d}  Top" }, { id: "bottom", name: "\u{f0045}  Bottom" },
                            { id: "left", name: "\u{f004d}  Left" }, { id: "right", name: "\u{f0054}  Right" }]
                    current: bar.position
                    onPicked: id => bar.setPosition(id)
                }
                Rectangle { width: 1; Layout.preferredHeight: 26; color: theme.border }
                Switch {
                    checked: bar.transparent
                    focusPolicy: Qt.NoFocus
                    onToggled: bar.setTransparent(checked)
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: "The wallpaper shows through the bar; segments keep their colours."
                }
                Label { text: "Transparent"; color: theme.textSoft; font.pixelSize: 12; Layout.leftMargin: -10 }
                Item { Layout.fillWidth: true }
                MiniSlider { label: "Float"; to: 24; value: bar.style.float || 0; onMoved: v => bar.setStyle("float", v) }
                MiniSlider { label: "Padding"; to: 32; value: bar.style.edge || 0; onMoved: v => bar.setStyle("edge", v) }
            }
        }

        RowLayout {
            visible: tab.view === "arrange"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // --- the three lanes ---
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10
                Repeater {
                    model: tab.lanes
                    delegate: Rectangle {
                        id: laneBox
                        required property string modelData
                        readonly property var entries: bar.layout[modelData] || []
                        readonly property bool target: tab.dragging && tab.page.dropOn === "lanes" && tab.page.dropLane === modelData
                        readonly property color tone: Qt.color(theme.accent)
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: target ? Qt.rgba(tone.r, tone.g, tone.b, 0.07) : theme.card
                        border.color: target ? theme.accent : theme.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6
                            RowLayout {
                                Layout.fillWidth: true
                                SectionLabel { text: tab.page.laneNames[laneBox.modelData] + " · " + laneBox.entries.length }
                                Item { Layout.fillWidth: true }
                                Label {
                                    visible: laneBox.modelData === "center" && bar.centerAnchor !== ""
                                    text: "\u{f0031} " + tab.page.widgetName(bar.centerAnchor)
                                    color: theme.textFaint
                                    font.pixelSize: 10
                                    ToolTip.visible: anchorHover.hovered
                                    ToolTip.text: "Sits dead centre; the rest of the lane flows out from it"
                                    HoverHandler { id: anchorHover }
                                }
                            }
                            Flickable {
                                id: laneFlick
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                contentHeight: laneColumn.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds
                                interactive: !tab.dragging
                                ScrollBar.vertical: ScrollBar {}
                                Column {
                                    id: laneColumn
                                    width: laneFlick.width
                                    spacing: 4
                                    Repeater {
                                        model: laneBox.entries
                                        delegate: Item {
                                            id: chipSlot
                                            required property var modelData
                                            required property int index
                                            readonly property bool picked: tab.page.selKey === laneBox.modelData + ":" + index
                                            readonly property bool moving: tab.dragging && tab.page.drag.fromLane === laneBox.modelData && tab.page.drag.fromIndex === index
                                            width: laneColumn.width
                                            height: 44
                                            // Where a drop would land.
                                            Rectangle {
                                                visible: laneBox.target && tab.page.dropIndex === chipSlot.index
                                                width: parent.width; height: 2; y: -3
                                                color: theme.accent
                                            }
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 9
                                                opacity: chipSlot.moving ? 0.35 : 1
                                                readonly property color tone: Qt.color(theme.accent)
                                                color: chipSlot.picked ? Qt.rgba(tone.r, tone.g, tone.b, 0.14) : chipHover.hovered ? theme.hover : theme.inset
                                                border.color: chipSlot.picked ? theme.accent : theme.border
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 6
                                                    anchors.rightMargin: 4
                                                    spacing: 7
                                                    Label { text: "\u{f01dd}"; color: theme.textFaint; font.pixelSize: 12 }
                                                    Glyph { entry: chipSlot.modelData }
                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 0
                                                        Label {
                                                            Layout.fillWidth: true
                                                            text: tab.page.entryName(chipSlot.modelData)
                                                            color: theme.text
                                                            font.pixelSize: 12
                                                            elide: Text.ElideRight
                                                        }
                                                        Label {
                                                            visible: text !== ""
                                                            Layout.fillWidth: true
                                                            text: tab.detail(chipSlot.modelData)
                                                            color: theme.textDim
                                                            font.pixelSize: 10
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                    // Always laid out, shown on hover: a button that
                                                    // appears in place can't land under the pointer.
                                                    ToolButton {
                                                        opacity: chipHover.hovered || chipSlot.picked ? 1 : 0
                                                        enabled: opacity > 0
                                                        text: "\u{f0209}"
                                                        implicitWidth: 26; implicitHeight: 28
                                                        font.pixelSize: 13
                                                        focusPolicy: Qt.NoFocus
                                                        onClicked: tab.page.hide(laneBox.modelData, chipSlot.index)
                                                        ToolTip.visible: hovered
                                                        ToolTip.text: "Hide from the bar (H); it stays installed"
                                                    }
                                                    ToolButton {
                                                        opacity: chipHover.hovered || chipSlot.picked ? 1 : 0
                                                        enabled: opacity > 0
                                                        text: "\u{f0156}"
                                                        implicitWidth: 26; implicitHeight: 28
                                                        font.pixelSize: 13
                                                        focusPolicy: Qt.NoFocus
                                                        onClicked: { bar.removeWidget(laneBox.modelData, chipSlot.index); tab.page.clearSelection(); }
                                                        ToolTip.visible: hovered
                                                        ToolTip.text: "Take off the bar"
                                                    }
                                                }
                                                HoverHandler { id: chipHover; cursorShape: tab.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
                                                TapHandler { onTapped: tab.page.select(laneBox.modelData, chipSlot.index) }
                                                DragHandler {
                                                    target: null
                                                    dragThreshold: 6
                                                    // The lane's scrolling mustn't take a drag over.
                                                    grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                                                    onActiveChanged: {
                                                        if (active)
                                                            tab.page.startDrag({ fromLane: laneBox.modelData, fromIndex: chipSlot.index,
                                                                                 glyph: chipSlot.modelData.icon || tab.page.glyphFor(chipSlot.modelData.id),
                                                                                 name: tab.page.entryName(chipSlot.modelData) }, centroid.scenePosition);
                                                        else tab.page.endDrag();
                                                    }
                                                    onCentroidChanged: if (active) tab.page.moveDrag(centroid.scenePosition)
                                                }
                                            }
                                        }
                                    }
                                    Rectangle {
                                        visible: laneBox.target && tab.page.dropIndex >= laneBox.entries.length
                                        width: parent.width; height: 2
                                        color: theme.accent
                                    }
                                    Label {
                                        visible: laneBox.entries.length === 0
                                        width: parent.width
                                        topPadding: 18
                                        horizontalAlignment: Text.AlignHCenter
                                        text: "Empty. Drag a widget here."
                                        color: theme.textFaint
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }
                        // The whole lane takes drops; the slot follows the pointer.
                        DropArea {
                            anchors.fill: parent
                            keys: ["barwidget"]
                            onEntered: { tab.page.dropOn = "lanes"; tab.page.dropLane = laneBox.modelData; }
                            onExited: if (tab.page.dropOn === "lanes" && tab.page.dropLane === laneBox.modelData) tab.page.clearDrop()
                            onPositionChanged: drag => {
                                const y = laneColumn.mapFromItem(this, drag.x, drag.y).y;
                                tab.page.dropOn = "lanes";
                                tab.page.dropLane = laneBox.modelData;
                                tab.page.dropIndex = Math.max(0, Math.min(laneBox.entries.length, Math.round(y / 48)));
                            }
                        }
                    }
                }
            }

            // --- right: the picked widget, or the shelf and the hidden tray ---
            Card {
                id: sidePanel
                Layout.preferredWidth: 330
                Layout.fillHeight: true
                readonly property bool hideTarget: tab.dragging && tab.page.drag.fromLane !== ""
                border.color: hideTarget && tab.page.dropOn === "hidden" ? theme.accent : theme.border

                BarInspector {
                    visible: tab.page.selEntry !== null && !sidePanel.hideTarget
                    anchors.fill: parent
                    anchors.margins: 12
                    page: tab.page
                }
                ColumnLayout {
                    visible: tab.page.selEntry === null && !sidePanel.hideTarget
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Segmented {
                        Layout.fillWidth: true
                        model: [{ id: "add", name: "\u{f0415}  Add · " + tab.shelf.length },
                                { id: "hidden", name: "\u{f0209}  Hidden · " + bar.hidden.length }]
                        current: tab.side
                        onPicked: id => tab.side = id
                    }

                    // --- widgets to add ---
                    SearchBox { id: shelfSearch; visible: tab.side === "add"; Layout.fillWidth: true; placeholderText: "Search widgets" }
                    ListView {
                        id: shelfList
                        visible: tab.side === "add"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: !tab.dragging
                        model: tab.shelf
                        section.property: "category"
                        section.delegate: Label {
                            required property string section
                            width: shelfList.width
                            topPadding: 6
                            bottomPadding: 2
                            text: section
                            color: theme.textFaint
                            font.pixelSize: 10
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 1
                        }
                        ScrollBar.vertical: ScrollBar {}
                        delegate: Rectangle {
                            id: shelfItem
                            required property var modelData
                            width: shelfList.width - 8
                            height: 40
                            radius: 9
                            color: shelfHover.hovered ? theme.hover : theme.inset
                            border.color: theme.border
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 4
                                spacing: 6
                                Label { text: tab.page.glyphFor(shelfItem.modelData.id); color: theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; Layout.preferredWidth: 20 }
                                Label { Layout.fillWidth: true; text: shelfItem.modelData.name; color: theme.text; font.pixelSize: 12; elide: Text.ElideRight }
                                Repeater {
                                    model: tab.lanes
                                    ToolButton {
                                        required property string modelData
                                        opacity: shelfHover.hovered ? 1 : 0
                                        enabled: opacity > 0
                                        text: tab.page.vertical ? { left: "↑", center: "•", right: "↓" }[modelData] : { left: "←", center: "•", right: "→" }[modelData]
                                        implicitWidth: 26; implicitHeight: 26
                                        focusPolicy: Qt.NoFocus
                                        onClicked: bar.addWidget(shelfItem.modelData.id, modelData, -1)
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Add to the " + tab.page.laneNames[modelData].toLowerCase()
                                    }
                                }
                            }
                            ToolTip.visible: shelfHover.hovered && shelfItem.modelData.description !== "" && !tab.dragging
                            ToolTip.delay: 900
                            ToolTip.text: shelfItem.modelData.description
                            HoverHandler { id: shelfHover; cursorShape: Qt.OpenHandCursor }
                            DragHandler {
                                target: null
                                dragThreshold: 6
                                grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                                onActiveChanged: {
                                    if (active)
                                        tab.page.startDrag({ newId: shelfItem.modelData.id, glyph: tab.page.glyphFor(shelfItem.modelData.id),
                                                             name: shelfItem.modelData.name }, centroid.scenePosition);
                                    else tab.page.endDrag();
                                }
                                onCentroidChanged: if (active) tab.page.moveDrag(centroid.scenePosition)
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: tab.side === "add" && bar.widgets.length === 0
                        text: "Reading the installed widgets…"
                        color: theme.textDim
                        font.pixelSize: 11
                    }

                    // --- hidden: off the bar, still installed ---
                    Label {
                        visible: tab.side === "hidden"
                        Layout.fillWidth: true
                        text: "Kept off the bar, with their settings. Their plugins stay on. Drag one back onto the bar or a lane, or show it where it was."
                        color: theme.textDim
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }
                    ListView {
                        id: hiddenList
                        visible: tab.side === "hidden"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: !tab.dragging
                        model: bar.hidden
                        ScrollBar.vertical: ScrollBar {}
                        delegate: Rectangle {
                            id: hiddenItem
                            required property var modelData
                            required property int index
                            width: hiddenList.width - 8
                            height: 44
                            radius: 9
                            color: hiddenHover.hovered ? theme.hover : theme.inset
                            border.color: theme.border
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 4
                                spacing: 7
                                Glyph { entry: hiddenItem.modelData.entry; opacity: 0.6 }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Label { Layout.fillWidth: true; text: tab.page.entryName(hiddenItem.modelData.entry); color: theme.textSoft; font.pixelSize: 12; elide: Text.ElideRight }
                                    Label {
                                        Layout.fillWidth: true
                                        text: "was " + (tab.page.laneNames[hiddenItem.modelData.lane] || "").toLowerCase() + ", " + (hiddenItem.modelData.index + 1)
                                        color: theme.textFaint
                                        font.pixelSize: 10
                                    }
                                }
                                Button {
                                    text: "\u{f0208}  Show"
                                    flat: true
                                    font.pixelSize: 11
                                    implicitHeight: 32
                                    focusPolicy: Qt.NoFocus
                                    onClicked: bar.showWidget(hiddenItem.index)
                                    ToolTip.visible: hovered
                                    ToolTip.delay: 500
                                    ToolTip.text: "Back on the bar where it was"
                                }
                            }
                            HoverHandler { id: hiddenHover; cursorShape: Qt.OpenHandCursor }
                            DragHandler {
                                target: null
                                dragThreshold: 6
                                grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                                onActiveChanged: {
                                    if (active)
                                        tab.page.startDrag({ hiddenIndex: hiddenItem.index,
                                                             glyph: hiddenItem.modelData.entry.icon || tab.page.glyphFor(hiddenItem.modelData.entry.id),
                                                             name: tab.page.entryName(hiddenItem.modelData.entry) }, centroid.scenePosition);
                                    else tab.page.endDrag();
                                }
                                onCentroidChanged: if (active) tab.page.moveDrag(centroid.scenePosition)
                            }
                        }
                        Label {
                            anchors.centerIn: parent
                            width: parent.width - 20
                            visible: hiddenList.count === 0
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: "Nothing hidden. Hover a widget and click \u{f0209}, or drag it here."
                            color: theme.textFaint
                            font.pixelSize: 11
                        }
                    }
                }

                // While a widget from the bar is dragged, the panel is the hidden tray.
                ColumnLayout {
                    visible: sidePanel.hideTarget
                    anchors.centerIn: parent
                    width: parent.width - 40
                    spacing: 8
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: "\u{f0209}"
                        color: tab.page.dropOn === "hidden" ? theme.accent : theme.textFaint
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 34
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Drop here to hide it from the bar. Its plugin stays on."
                        color: tab.page.dropOn === "hidden" ? theme.text : theme.textDim
                        font.pixelSize: 12
                    }
                }
                DropArea {
                    anchors.fill: parent
                    enabled: sidePanel.hideTarget
                    keys: ["barwidget"]
                    onEntered: { tab.page.dropOn = "hidden"; tab.page.dropLane = ""; tab.page.dropIndex = -1; }
                    onExited: if (tab.page.dropOn === "hidden") tab.page.clearDrop()
                }
            }
        }

        // ================= Presets =================
        ColumnLayout {
            visible: tab.view === "presets"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: ["All", "Originals", "Side rails", "JaKooLit", "HANCORE"].filter(g => g === "All" || bar.layouts.some(l => l.group === g))
                    Chip {
                        required property string modelData
                        text: modelData
                        chosen: tab.presetGroup === modelData
                        onClicked: tab.presetGroup = modelData
                    }
                }
                Item { Layout.fillWidth: true }
                SearchBox { id: presetSearch; placeholderText: "Search layouts" }
            }
            GridView {
                id: presetGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                readonly property int columns: Math.max(1, Math.floor(width / 330))
                cellWidth: Math.floor(width / columns)
                cellHeight: 112
                ScrollBar.vertical: ScrollBar {}
                model: bar.layouts.filter(l => (tab.presetGroup === "All" || l.group === tab.presetGroup)
                                          && (presetSearch.text === "" || (l.label + " " + (l.desc || "")).toLowerCase().indexOf(presetSearch.text.toLowerCase()) >= 0))
                delegate: Item {
                    id: presetCell
                    required property var modelData
                    width: presetGrid.cellWidth
                    height: presetGrid.cellHeight
                    BarTile {
                        anchors.fill: parent
                        anchors.margins: 5
                        title: presetCell.modelData.label
                        tag: (presetCell.modelData.position ? presetCell.modelData.position + " · " : "") + presetCell.modelData.counts
                        subtitle: presetCell.modelData.desc || ""
                        chosen: bar.currentLayout === presetCell.modelData.id
                        labels: true
                        cfg: ({ position: "top", layout: presetCell.modelData.layout, centerAnchor: presetCell.modelData.anchor || "", style: bar.style })
                        onPreviewWanted: on => on ? tab.page.preview(presetCell.modelData.label, null, presetCell.modelData)
                                                  : tab.page.endPreview(presetCell.modelData.label)
                        onPicked: { tab.page.endPreview(presetCell.modelData.label); tab.page.clearSelection(); bar.applyLayout(presetCell.modelData.id); }
                    }
                }
            }
        }
    }
}
