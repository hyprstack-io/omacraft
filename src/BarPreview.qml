import QtQuick
import "BarStyle.js" as S

// A faithful, scaled sketch of omabar16 for a config: the live stage at the
// top of the Main Bar page, and every theme, look, colour and layout tile. Along
// the left or right edge it draws the bar as a rail, as omabar16 does.
Item {
    id: mb

    property var cfg: ({ layout: { left: [], center: [], right: [] }, style: {}, centerAnchor: "" })
    property var themeColors: ({})
    // Draw along the edge cfg.position names (a rail for left and right).
    property bool followEdge: false
    property bool interactive: false
    property bool labels: true
    property string selectedKey: ""     // "lane:index"
    property int segH: 22
    property int fontPx: 11
    // Grow the bar with its thickness setting (the stage), or keep segH (tiles).
    property bool trueSize: false
    signal segmentClicked(string lane, int index)
    signal backgroundClicked()

    // Widgets dragged along the bar itself. The page follows the drag and
    // asks dropTarget() where it would land; dropLane/dropIndex draw the gap.
    property bool draggable: false
    property string draggingKey: ""     // "lane:index", dimmed while it moves
    property string dropLane: ""
    property int dropIndex: -1
    signal dragStarted(string lane, int index, point scenePos)
    signal dragMoved(point scenePos)
    signal dragEnded()

    readonly property var style: cfg && cfg.style ? cfg.style : ({})
    readonly property var res: S.resolve(style, themeColors)
    readonly property bool vertical: followEdge && (cfg.position === "left" || cfg.position === "right")
    readonly property string kind: vertical && (style.shape || "none") !== "none" ? "block" : (style.shape || "none")
    readonly property int gap: style.gap === undefined ? 1 : style.gap
    readonly property int inset: style.inset === undefined ? 0 : style.inset
    readonly property int floatPx: kind === "none" || style.float === undefined ? 0 : style.float
    readonly property int edge: style.edge === undefined ? (kind === "none" ? 8 : 0) : style.edge
    readonly property int sh: trueSize ? Math.max(14, (style.size || 26) - 2 * inset - 4) : segH
    readonly property int barH: sh + 2 * inset + 6
    readonly property real segAlpha: style.segmentOpacity === undefined ? 1 : Math.max(0.1, style.segmentOpacity)
    readonly property real natural: vertical ? 1 : leftRow.width + centerRow.width + rightRow.width + edge * 2 + 48
    readonly property real fit: vertical ? 1 : Math.min(1, mb.width / Math.max(1, natural))
    readonly property string textFont: typeof style.fontFamily === "string" && style.fontFamily !== "" ? style.fontFamily : "JetBrainsMono Nerd Font"
    readonly property string iconFont: typeof style.iconFont === "string" && style.iconFont !== "" ? style.iconFont : "JetBrainsMono Nerd Font"

    implicitHeight: vertical ? 200 : (barH + 2 * floatPx) * fit
    implicitWidth: vertical ? barH + 2 * floatPx : 400

    function lane(name) { return S.lane(cfg, name); }
    function anchorIndex() {
        const l = lane("center");
        for (let i = 0; i < l.length; i++) if (l[i].id === cfg.centerAnchor) return i;
        return -1;
    }
    function modeFor(region, index) {
        if (kind !== "arrow") return "right";
        if (region === "right") return "left";
        if (region === "center") {
            const a = anchorIndex();
            if (a < 0) return "right";
            return index < a ? "left" : (index === a ? "both" : "right");
        }
        return "right";
    }
    function labelFor(entry) {
        if (!labels) return "";
        switch (entry.id) {
        case "omarchy.clock": return S.clockSample(entry.format || "dddd HH:mm");
        case "omarchy.active-window": return "Firefox";
        case "omarchy.media": return "Now playing";
        case "omarchy.weather": return "18°";
        case "omacraft.folders": return entry.showLabel ? (entry.name || "Apps") : "";
        }
        return "";
    }
    function glyphOf(entry) {
        if (entry.id === "omarchy.spacer") return "";
        if (entry.icon) return entry.icon;
        if (entry.id === "omarchy.clock" && labels) return "";
        if (entry.id === "omarchy.workspaces") return labels ? "1 2 3 4" : "\u{f0570}";
        return bar.glyphs ? bar.glyphFor(entry.id) : "";
    }
    // --- where a drop lands ---
    readonly property var laneOrder: ["left", "center", "right"]
    function laneBox(name) {
        return vertical ? railLanes.itemAt(laneOrder.indexOf(name)) : ({ left: leftRow, center: centerRow, right: rightRow })[name];
    }
    function laneItems(name) {
        const box = laneBox(name);
        if (!box) return [];
        const out = [];
        for (let i = 0; i < box.children.length; i++) {
            const c = box.children[i];
            if (c.laneIndex !== undefined) out.push(c);
        }
        return out.sort((a, b) => a.laneIndex - b.laneIndex);
    }
    // Start and end of an item along the bar, in the bar's own coordinates.
    function span(item) {
        const host = vertical ? rail : canvas;
        const a = item.mapToItem(host, 0, 0), b = item.mapToItem(host, item.width, item.height);
        return vertical ? { start: a.y, end: b.y } : { start: a.x, end: b.x };
    }
    // {lane, index, at} for a point in the window, or null when it's off the bar.
    function dropTarget(scenePos) {
        if (!visible) return null;
        const local = mb.mapFromItem(null, scenePos.x, scenePos.y);
        if (local.x < -16 || local.y < -24 || local.x > width + 16 || local.y > height + 24) return null;
        const host = vertical ? rail : canvas;
        const p = host.mapFromItem(null, scenePos.x, scenePos.y);
        const pos = vertical ? p.y : p.x;
        const ext = laneOrder.map(l => span(laneBox(l)));
        const b1 = (ext[0].end + ext[1].start) / 2, b2 = (ext[1].end + ext[2].start) / 2;
        const lane = pos < b1 ? "left" : pos < b2 ? "center" : "right";
        const items = laneItems(lane);
        let index = 0;
        for (const it of items) {
            const sp = span(it);
            if ((sp.start + sp.end) / 2 < pos) index++;
        }
        const ext2 = ext[laneOrder.indexOf(lane)];
        const at = index < items.length ? span(items[index]).start : (items.length ? span(items[items.length - 1]).end : ext2.start);
        return { lane: lane, index: index, at: at };
    }
    readonly property real dropAt: {
        if (dropLane === "") return -1;
        const items = laneItems(dropLane);
        if (dropIndex < items.length) return span(items[dropIndex]).start;
        return items.length ? span(items[items.length - 1]).end : span(laneBox(dropLane)).start;
    }

    function fillFor(region, idx, count, id) {
        if (kind === "none") return "transparent";
        const c = Qt.color(S.segmentFill(res, S.segmentBase(res, region, idx, count, id), false));
        return Qt.rgba(c.r, c.g, c.b, segAlpha);
    }
    function textFor(entry) {
        if (S.isHex(entry.color)) return entry.color;
        return kind === "none" || kind === "underline" ? res.barText : res.text;
    }

    component Seg: BarSegment {
        property var entry: ({ id: "" })
        property int idx: 0
        property string region: ""
        property int count: 0
        readonly property int laneIndex: idx

        kind: mb.kind
        h: mb.sh
        fontPx: mb.fontPx
        blockRadius: mb.style.radius === undefined ? 0 : Math.round(mb.style.radius * mb.sh / 30)
        fontFamily: entry.font || mb.textFont
        glyphFont: entry.iconFont || mb.iconFont
        gap: mb.gap
        pad: mb.style.pad === undefined ? 3 : mb.style.pad
        depthFactor: mb.style.depth === undefined ? 0.42 : mb.style.depth
        mode: mb.modeFor(region, idx)
        flatEdge: mb.style.flatEnds !== false && ((region === "left" && idx === 0) || (region === "right" && idx === count - 1))
        outline: mb.style.outline || 0
        outlineColor: S.isHex(mb.style.outlineColor) ? mb.style.outlineColor : Qt.darker(mb.res.bg, 1.6)
        glyph: mb.glyphOf(entry)
        label: mb.labelFor(entry)
        fixedWidth: entry.id === "omarchy.spacer" ? Math.max(4, (entry.size || 12) * mb.sh / 26) : 0
        itemOpacity: entry.opacity === undefined ? 1 : Math.max(0.1, entry.opacity)
        fill: mb.fillFor(region, idx, count, entry.id)
        textColor: mb.textFor(entry)
        interactive: mb.interactive
        selected: mb.interactive && mb.selectedKey === region + ":" + idx
        opacity: mb.draggingKey === region + ":" + idx ? 0.3 : itemOpacity
        onClicked: mb.segmentClicked(region, idx)
        DragHandler {
            target: null
            enabled: mb.draggable
            dragThreshold: 5
            cursorShape: Qt.ClosedHandCursor
            onActiveChanged: active ? mb.dragStarted(parent.region, parent.idx, centroid.scenePosition) : mb.dragEnded()
            onCentroidChanged: if (active) mb.dragMoved(centroid.scenePosition)
        }
    }

    // --- along the top or bottom ---
    Item {
        id: canvas
        visible: !mb.vertical
        width: mb.width / mb.fit
        height: mb.barH + 2 * mb.floatPx
        scale: mb.fit
        transformOrigin: Item.TopLeft

        Rectangle {
            x: mb.floatPx
            y: mb.floatPx
            width: parent.width - 2 * mb.floatPx
            height: mb.barH
            radius: mb.floatPx > 0 ? Math.min(height / 2, (mb.style.radius || 0)) : 0
            readonly property color base: Qt.color(mb.res.bg)
            color: mb.floatPx > 0 || mb.cfg.transparent ? "transparent"
                 : Qt.rgba(base.r, base.g, base.b, mb.style.barOpacity === undefined ? 1 : mb.style.barOpacity)
            TapHandler { enabled: mb.interactive; onTapped: mb.backgroundClicked() }
        }
        Row {
            id: leftRow
            x: mb.floatPx + mb.edge
            y: mb.floatPx + Math.round((mb.barH - mb.sh) / 2)
            Repeater {
                model: mb.lane("left")
                Seg { required property var modelData; required property int index; entry: modelData; idx: index; region: "left"; count: mb.lane("left").length }
            }
        }
        Row {
            id: centerRow
            anchors.horizontalCenter: parent.horizontalCenter
            y: mb.floatPx + Math.round((mb.barH - mb.sh) / 2)
            Repeater {
                model: mb.lane("center")
                Seg { required property var modelData; required property int index; entry: modelData; idx: index; region: "center"; count: mb.lane("center").length }
            }
        }
        Row {
            id: rightRow
            anchors.right: parent.right
            anchors.rightMargin: mb.floatPx + mb.edge
            y: mb.floatPx + Math.round((mb.barH - mb.sh) / 2)
            Repeater {
                model: mb.lane("right")
                Seg { required property var modelData; required property int index; entry: modelData; idx: index; region: "right"; count: mb.lane("right").length }
            }
        }
        // Where a dragged widget would go.
        Rectangle {
            visible: mb.dropLane !== "" && !mb.vertical
            x: mb.dropAt - 2
            y: mb.floatPx - 3
            width: 3
            height: mb.barH + 6
            radius: 1.5
            color: theme.accent
        }
    }

    // --- down the left or right: a rail of tiles, glyphs only ---
    Rectangle {
        id: rail
        visible: mb.vertical
        x: mb.floatPx
        y: mb.floatPx
        width: mb.barH
        height: mb.height - 2 * mb.floatPx
        radius: mb.floatPx > 0 ? Math.min(width / 2, (mb.style.radius || 0)) : 0
        readonly property color base: Qt.color(mb.res.bg)
        color: mb.cfg.transparent ? "transparent" : Qt.rgba(base.r, base.g, base.b, mb.style.barOpacity === undefined ? 1 : mb.style.barOpacity)
        readonly property int tile: mb.sh
        readonly property int count: mb.lane("left").length + mb.lane("center").length + mb.lane("right").length
        readonly property real railScale: Math.min(1, (height - 2 * Math.max(4, mb.edge)) / Math.max(1, count * (tile + Math.max(1, mb.gap)) + 24))
        TapHandler { enabled: mb.interactive; onTapped: mb.backgroundClicked() }

        Repeater {
            id: railLanes
            model: ["left", "center", "right"]
            delegate: Column {
                id: railLane
                required property string modelData
                readonly property var entries: mb.lane(modelData)
                spacing: Math.max(1, mb.gap)
                scale: rail.railScale
                transformOrigin: modelData === "left" ? Item.Top : modelData === "right" ? Item.Bottom : Item.Center
                anchors.horizontalCenter: parent.horizontalCenter
                y: modelData === "left" ? Math.max(4, mb.edge)
                 : modelData === "right" ? rail.height - height - Math.max(4, mb.edge)
                 : (rail.height - height) / 2
                Repeater {
                    model: railLane.entries
                    delegate: Rectangle {
                        id: tileItem
                        required property var modelData
                        required property int index
                        readonly property int laneIndex: index
                        width: rail.tile
                        height: modelData.id === "omarchy.spacer" ? Math.max(4, (modelData.size || 12) * rail.tile / 26)
                              : modelData.id === "omarchy.workspaces" ? rail.tile * 2 : rail.tile
                        radius: mb.kind === "none" ? 4 : Math.min(width / 2, (mb.style.radius === undefined ? 4 : mb.style.radius) * mb.sh / 30)
                        color: mb.fillFor(railLane.modelData, index, railLane.entries.length, modelData.id)
                        opacity: mb.draggingKey === railLane.modelData + ":" + index ? 0.3 : modelData.opacity === undefined ? 1 : Math.max(0.1, modelData.opacity)
                        border.width: mb.interactive && mb.selectedKey === railLane.modelData + ":" + index ? 2 : 0
                        border.color: theme.accent
                        Text {
                            anchors.centerIn: parent
                            text: tileItem.modelData.id === "omarchy.clock" ? S.clockSample("HH\nmm")
                                : tileItem.modelData.id === "omarchy.workspaces" ? "1\n2\n3"
                                : mb.glyphOf(tileItem.modelData)
                            horizontalAlignment: Text.AlignHCenter
                            color: mb.textFor(tileItem.modelData)
                            font.family: tileItem.modelData.id === "omarchy.clock" ? mb.textFont : (tileItem.modelData.iconFont || mb.iconFont)
                            font.pixelSize: tileItem.modelData.id === "omarchy.clock" ? Math.round(mb.fontPx * 0.9) : Math.round(mb.fontPx * 1.1)
                            lineHeight: 0.85
                        }
                        HoverHandler { enabled: mb.interactive; cursorShape: Qt.PointingHandCursor }
                        TapHandler { enabled: mb.interactive; onTapped: mb.segmentClicked(railLane.modelData, tileItem.index) }
                        DragHandler {
                            target: null
                            enabled: mb.draggable
                            dragThreshold: 5
                            cursorShape: Qt.ClosedHandCursor
                            onActiveChanged: active ? mb.dragStarted(railLane.modelData, tileItem.index, centroid.scenePosition) : mb.dragEnded()
                            onCentroidChanged: if (active) mb.dragMoved(centroid.scenePosition)
                        }
                    }
                }
            }
        }
        Rectangle {
            visible: mb.dropLane !== "" && mb.vertical
            x: -3
            y: mb.dropAt - 2
            width: parent.width + 6
            height: 3
            radius: 1.5
            color: theme.accent
        }
    }
}
