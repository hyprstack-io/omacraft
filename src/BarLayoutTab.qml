import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "BarStyle.js" as S

// Where the bar sits and what's on it. Arrange: the screen edge, then the
// three lanes, with widgets dragged between them or in from the shelf, and
// the picked one's settings beside them. Presets: whole arrangements from
// omabar16, JaKooLit and HANCORE, each drawn as the bar it makes.
Item {
    id: tab
    property var page

    property string view: startTab === "presets" ? "presets" : "arrange"     // arrange | presets
    property string presetGroup: "All"
    function showArrange() { view = "arrange"; }

    readonly property var lanes: ["left", "center", "right"]

    // --- dragging: one floating chip, dropped on a lane ---
    property var drag: null             // { fromLane, fromIndex, newId, glyph, name }
    property string dropLane: ""
    property int dropIndex: -1
    function startDrag(payload) { drag = payload; }
    function moveDrag(scenePoint) {
        const p = tab.mapFromItem(null, scenePoint.x, scenePoint.y);
        ghost.x = p.x - ghost.width / 2;
        ghost.y = p.y - ghost.height / 2;
    }
    function endDrag() {
        if (drag && dropLane !== "") {
            if (drag.newId) bar.addWidget(drag.newId, dropLane, dropIndex);
            else bar.moveWidget(drag.fromLane, drag.fromIndex, dropLane, dropIndex);
            if (!drag.newId) page.clearSelection();
        }
        drag = null;
        dropLane = "";
        dropIndex = -1;
    }

    // Widgets not on the bar yet, and those that can go on more than once.
    readonly property var onBar: lanes.reduce((all, l) => all.concat((bar.layout[l] || []).map(e => e.id)), [])
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
                text: tab.view === "arrange" ? "Drag widgets between lanes or in from the shelf; click one (here or on the stage) for its settings."
                                             : "Applying a layout moves widgets; their own settings and other plugins' widgets stay."
                color: theme.textDim
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        // ================= Arrange =================
        RowLayout {
            visible: tab.view === "arrange"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // --- where on the screen ---
                Card {
                    Layout.fillWidth: true
                    implicitHeight: edgeRow.implicitHeight + 24
                    RowLayout {
                        id: edgeRow
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 18

                        EdgePicker {
                            current: bar.position
                            onPicked: edge => bar.setPosition(edge)
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            SwitchRow {
                                label: "Transparent"
                                hint: "The wallpaper shows through the bar; segments keep their colours."
                                checked: bar.transparent
                                onToggled: on => bar.setTransparent(on)
                            }
                            SliderRow {
                                label: "Float"; from: 0; to: 24; stepSize: 1; decimals: 0; suffix: " px"
                                value: bar.style.float || 0
                                onMoved: v => bar.setStyle("float", Math.round(v))
                            }
                            SliderRow {
                                label: "Edge padding"; from: 0; to: 32; stepSize: 1; decimals: 0; suffix: " px"
                                value: bar.style.edge || 0
                                onMoved: v => bar.setStyle("edge", Math.round(v))
                            }
                        }
                    }
                }

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
                            readonly property bool target: tab.drag !== null && tab.dropLane === modelData
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
                                    interactive: tab.drag === null
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
                                                readonly property bool dragging: tab.drag !== null && !tab.drag.newId && tab.drag.fromLane === laneBox.modelData && tab.drag.fromIndex === index
                                                width: laneColumn.width
                                                height: 42
                                                // Where a drop would land.
                                                Rectangle {
                                                    visible: laneBox.target && tab.dropIndex === chipSlot.index
                                                    width: parent.width; height: 2; y: -3
                                                    color: theme.accent
                                                }
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 8
                                                    opacity: chipSlot.dragging ? 0.35 : 1
                                                    readonly property color tone: Qt.color(theme.accent)
                                                    color: chipSlot.picked ? Qt.rgba(tone.r, tone.g, tone.b, 0.14) : chipHover.hovered ? theme.hover : theme.inset
                                                    border.color: chipSlot.picked ? theme.accent : theme.border
                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 6
                                                        anchors.rightMargin: 4
                                                        spacing: 6
                                                        Label { text: "\u{f01dd}"; color: theme.textFaint; font.pixelSize: 12 }
                                                        Rectangle {
                                                            width: 26; height: 26; radius: 6
                                                            color: theme.sunken
                                                            Label {
                                                                anchors.centerIn: parent
                                                                text: chipSlot.modelData.icon || tab.page.glyphFor(chipSlot.modelData.id)
                                                                color: S.isHex(chipSlot.modelData.color) ? chipSlot.modelData.color : theme.accent
                                                                font.family: chipSlot.modelData.iconFont || "JetBrainsMono Nerd Font"
                                                                font.pixelSize: 14
                                                            }
                                                        }
                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 0
                                                            Label {
                                                                Layout.fillWidth: true
                                                                text: chipSlot.modelData.id === "omacraft.folders" ? (chipSlot.modelData.name || "Folder") : tab.page.widgetName(chipSlot.modelData.id)
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
                                                            text: "\u{f0156}"
                                                            implicitWidth: 28; implicitHeight: 28
                                                            font.pixelSize: 13
                                                            focusPolicy: Qt.NoFocus
                                                            onClicked: { bar.removeWidget(laneBox.modelData, chipSlot.index); tab.page.clearSelection(); }
                                                            ToolTip.visible: hovered
                                                            ToolTip.text: "Take off the bar"
                                                        }
                                                    }
                                                    HoverHandler { id: chipHover; cursorShape: tab.drag ? Qt.ClosedHandCursor : Qt.PointingHandCursor }
                                                    TapHandler { onTapped: tab.page.select(laneBox.modelData, chipSlot.index) }
                                                    DragHandler {
                                                        target: null
                                                        dragThreshold: 6
                                                        // The lane's scrolling mustn't take a drag over.
                                                        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                                                        onActiveChanged: {
                                                            if (active) tab.moveDrag(centroid.scenePosition);
                                                            if (active) tab.startDrag({ fromLane: laneBox.modelData, fromIndex: chipSlot.index, newId: "",
                                                                                        glyph: chipSlot.modelData.icon || tab.page.glyphFor(chipSlot.modelData.id),
                                                                                        name: tab.page.widgetName(chipSlot.modelData.id) });
                                                            else tab.endDrag();
                                                        }
                                                        onCentroidChanged: if (active) tab.moveDrag(centroid.scenePosition)
                                                    }
                                                }
                                            }
                                        }
                                        Rectangle {
                                            visible: laneBox.target && tab.dropIndex >= laneBox.entries.length
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
                                onEntered: tab.dropLane = laneBox.modelData
                                onExited: if (tab.dropLane === laneBox.modelData) { tab.dropLane = ""; tab.dropIndex = -1; }
                                onPositionChanged: drag => {
                                    const y = laneColumn.mapFromItem(this, drag.x, drag.y).y;
                                    tab.dropIndex = Math.max(0, Math.min(laneBox.entries.length, Math.round(y / 46)));
                                }
                            }
                        }
                    }
                }
            }

            // --- right: the picked widget, or the shelf ---
            Card {
                Layout.preferredWidth: 330
                Layout.fillHeight: true
                BarInspector {
                    visible: tab.page.selEntry !== null
                    anchors.fill: parent
                    anchors.margins: 12
                    page: tab.page
                }
                ColumnLayout {
                    visible: tab.page.selEntry === null
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    SectionLabel { text: "Widgets to add · " + tab.shelf.length }
                    TextField { id: shelfSearch; Layout.fillWidth: true; placeholderText: "Search widgets" }
                    ListView {
                        id: shelfList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: tab.drag === null
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
                            radius: 8
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
                            ToolTip.visible: shelfHover.hovered && shelfItem.modelData.description !== "" && !tab.drag
                            ToolTip.delay: 900
                            ToolTip.text: shelfItem.modelData.description
                            HoverHandler { id: shelfHover; cursorShape: Qt.OpenHandCursor }
                            DragHandler {
                                target: null
                                dragThreshold: 6
                                grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                                onActiveChanged: {
                                    if (active) tab.moveDrag(centroid.scenePosition);
                                    if (active) tab.startDrag({ fromLane: "", fromIndex: -1, newId: shelfItem.modelData.id,
                                                                glyph: tab.page.glyphFor(shelfItem.modelData.id), name: shelfItem.modelData.name });
                                    else tab.endDrag();
                                }
                                onCentroidChanged: if (active) tab.moveDrag(centroid.scenePosition)
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: bar.widgets.length === 0
                        text: "Reading the installed widgets…"
                        color: theme.textDim
                        font.pixelSize: 11
                    }
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
                TextField { id: presetSearch; Layout.preferredWidth: 200; placeholderText: "Search layouts" }
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

    // The chip under the pointer while dragging.
    Rectangle {
        id: ghost
        visible: tab.drag !== null
        width: ghostRow.implicitWidth + 20
        height: 34
        radius: 8
        z: 100
        color: theme.raised
        border.color: theme.accent
        opacity: 0.95
        Drag.active: tab.drag !== null
        Drag.keys: ["barwidget"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Row {
            id: ghostRow
            anchors.centerIn: parent
            spacing: 8
            Label { text: tab.drag ? tab.drag.glyph : ""; color: theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
            Label { text: tab.drag ? tab.drag.name : ""; color: theme.text; font.pixelSize: 12 }
        }
    }
}
