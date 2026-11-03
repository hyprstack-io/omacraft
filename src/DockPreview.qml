import QtQuick
import QtQuick.Controls

// Side Dock drawn from its settings, the way the shell plugin draws it: the
// body in its shape, colour, opacity and border, down a side or across the
// bottom; the agents button, the dock items as tiles in their shape (plates
// shown on hover, always, or as outlines); magnification under the pointer,
// growing out past the dock's open side; and, when open, the agents panel
// beside it (above a bottom dock).
Item {
    id: dk

    property var s: ({})
    property var items: []
    property var agents: []
    property bool interactive: false
    property bool panelOpen: false
    property int selectedIndex: -1
    // Fit the dock into this height, or width when it runs across the
    // bottom (0: natural size).
    property real fitHeight: 0
    property real fitWidth: 0
    signal itemClicked(int index)

    readonly property var dockColors: ({ midnight: "#11111b", ink: "#000000", slate: "#1e293b", ocean: "#0b3954",
                                         forest: "#12372a", plum: "#2d1b3d", wine: "#3b0d1a", amber: "#3a2800",
                                         frost: "#dfe9f5", paper: "#f2efe9" })
    readonly property var accentColors: ({ red: "#f7768e", orange: "#ff9e64", yellow: "#e0af68", green: "#9ece6a",
                                           teal: "#73daca", cyan: "#7dcfff", blue: "#7aa2f7", purple: "#bb9af7",
                                           pink: "#ff79c6", white: "#ffffff" })
    function pick(value, named, fallback) {
        const v = String(value || "theme");
        if (v.startsWith("#")) return v;
        return named[v] || fallback;
    }
    readonly property color tint: pick(s.dockColor, dockColors, bar.themeColors.background || "#1a1b26")
    readonly property color accent: pick(s.accentColor, accentColors, theme.accent)
    readonly property bool light: (0.299 * tint.r + 0.587 * tint.g + 0.114 * tint.b) > 0.6
    readonly property color ink: light ? "#1d1f24" : "#e6e6e6"
    readonly property color line: light ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.12)
    readonly property bool onRight: (s.position || "right") === "right"
    readonly property bool horizontal: s.position === "bottom"
    readonly property int size: s.iconSize || 28
    readonly property int slot: size + 10
    readonly property real magMax: s.magnify ? Math.max(1.1, Math.min(2.4, s.magnifyScale || 1.7)) : 1
    readonly property int magRange: Math.max(1, Math.min(4, s.magnifyRange || 2))
    readonly property real dockWidth: size + 16
    // The dock's length along its edge.
    readonly property real naturalHeight: (horizontal ? column.implicitWidth : column.implicitHeight) + 12
    readonly property real fit: {
        const room = horizontal ? fitWidth : fitHeight;
        return room > 0 ? Math.min(1, room / Math.max(1, naturalHeight)) : 1;
    }
    // How far the panel reaches out: its width beside a side dock, its
    // height above a bottom one.
    readonly property real panelWidth: horizontal ? Math.max(90, Math.min(150, (s.width || 520) * 0.24))
                                                  : Math.max(160, Math.min(320, (s.width || 520) * 0.42))
    readonly property real depth: dockWidth + (panelOpen ? panelWidth + 10 : 0)

    implicitWidth: (horizontal ? naturalHeight : depth) * fit
    implicitHeight: (horizontal ? depth : naturalHeight) * fit

    // Where the pointer is along the dock, for magnifying.
    property real pointerY: -1
    function magnify(centre) {
        if (!s.magnify || pointerY < 0) return 1;
        const reach = magRange * slot;
        const d = Math.abs(centre - pointerY);
        if (d >= reach) return 1;
        return 1 + (magMax - 1) * (0.5 + 0.5 * Math.cos(Math.PI * d / reach));
    }

    Item {
        id: canvas
        width: dk.horizontal ? dk.naturalHeight : dk.depth
        height: dk.horizontal ? dk.depth : dk.naturalHeight
        scale: dk.fit
        transformOrigin: dk.horizontal ? Item.BottomLeft : dk.onRight ? Item.TopRight : Item.TopLeft
        x: dk.onRight ? dk.width - width : 0
        y: dk.horizontal ? dk.height - height : 0

        // --- the agents panel, opened beside (or above) the dock ---
        Rectangle {
            visible: dk.panelOpen
            x: dk.horizontal || dk.onRight ? 0 : dk.dockWidth + 10
            width: dk.horizontal ? parent.width : dk.panelWidth
            height: dk.horizontal ? dk.panelWidth : parent.height
            radius: 14
            color: Qt.rgba(dk.tint.r, dk.tint.g, dk.tint.b, (dk.s.opacity || 0.94))
            border.width: (dk.s.dockBorder || "subtle") === "none" ? 0 : 1
            border.color: dk.s.dockBorder === "accent" ? Qt.rgba(dk.accent.r, dk.accent.g, dk.accent.b, 0.75) : dk.line
            Row {
                x: 10; y: 10
                spacing: 6
                Repeater {
                    model: dk.agents.filter(a => a.shown !== false)
                    Rectangle {
                        required property var modelData
                        required property int index
                        width: tabRow.implicitWidth + 16
                        height: 26
                        radius: 7
                        color: index === 0 ? Qt.rgba(dk.accent.r, dk.accent.g, dk.accent.b, 0.22) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: index === 0 ? dk.accent : "transparent"
                        Row {
                            id: tabRow
                            anchors.centerIn: parent
                            spacing: 5
                            Image { width: 14; height: 14; source: modelData.iconUrl || ""; sourceSize: Qt.size(28, 28); anchors.verticalCenter: parent.verticalCenter }
                            Label { text: modelData.name; color: dk.ink; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
            // A terminal's worth of lines.
            Column {
                x: 12; y: 46
                spacing: 7
                Repeater {
                    model: 9
                    Rectangle {
                        required property int index
                        visible: 46 + index * 11 < parent.parent.height - 8
                        width: (parent.parent.width - 24) * [0.5, 0.8, 0.65, 0.3, 0.75, 0.55, 0.85, 0.4, 0.6][index]
                        height: 4
                        radius: 2
                        color: index === 0 ? dk.accent : Qt.rgba(dk.ink.r, dk.ink.g, dk.ink.b, 0.22)
                    }
                }
            }
        }

        // --- the dock ---
        Item {
            id: dockBox
            x: dk.onRight ? parent.width - dk.dockWidth : 0
            y: dk.horizontal ? parent.height - dk.dockWidth : 0
            width: dk.horizontal ? parent.width : dk.dockWidth
            height: dk.horizontal ? dk.dockWidth : parent.height

            Rectangle {
                readonly property string shape: dk.s.dockShape || "rounded"
                readonly property real thick: Math.min(width, height)
                readonly property real r: shape === "pill" ? thick / 2 : shape === "soft" ? 8 : shape === "square" ? 0 : Math.min(18, thick / 2)
                readonly property bool edge: shape === "edge"
                readonly property bool onLeft: !dk.onRight && !dk.horizontal
                anchors.fill: parent
                radius: edge ? 0 : r
                // "edge" rounds only the side facing the desktop.
                topLeftRadius: edge ? (onLeft ? 0 : 16) : r
                bottomLeftRadius: edge ? (dk.onRight ? 16 : 0) : r
                topRightRadius: edge ? (dk.onRight ? 0 : 16) : r
                bottomRightRadius: edge ? (onLeft ? 16 : 0) : r
                color: Qt.rgba(dk.tint.r, dk.tint.g, dk.tint.b, dk.s.opacity === undefined ? 0.94 : dk.s.opacity)
                border.width: (dk.s.dockBorder || "subtle") === "none" ? 0 : 1
                border.color: dk.s.dockBorder === "accent" ? Qt.rgba(dk.accent.r, dk.accent.g, dk.accent.b, 0.75) : dk.line
            }

            // A column down a side dock, a row across a bottom one.
            Grid {
                id: column
                x: dk.horizontal ? 6 : (parent.width - width) / 2
                y: dk.horizontal ? (parent.height - height) / 2 : 6
                columns: dk.horizontal ? 1000 : 1
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter
                spacing: 0

                Glyph { glyph: dk.horizontal ? "\u{f0143}" : dk.onRight ? "\u{f0141}" : "\u{f0142}"; highlighted: dk.panelOpen }
                Item { width: 4; height: 4 }
                Rectangle { width: dk.horizontal ? 1 : dk.size; height: dk.horizontal ? dk.size : 1; color: dk.line }
                Item { width: 4; height: 4 }
                Repeater {
                    model: dk.items
                    delegate: Loader {
                        id: itemLoader
                        required property var modelData
                        required property int index
                        // A magnified tile draws over its neighbours.
                        z: item ? item.z : 0
                        sourceComponent: modelData.type === "spacer" ? spacerItem : modelData.type === "divider" ? dividerItem : tileItem
                        Component { id: spacerItem; Item { width: dk.horizontal ? dk.size / 2 : dk.size; height: dk.horizontal ? dk.size : dk.size / 2 } }
                        Component {
                            id: dividerItem
                            Item {
                                width: dk.horizontal ? 9 : dk.size
                                height: dk.horizontal ? dk.size : 9
                                Rectangle { anchors.centerIn: parent; width: dk.horizontal ? 1 : dk.size * 0.7; height: dk.horizontal ? dk.size * 0.7 : 1; color: dk.line }
                            }
                        }
                        Component {
                            id: tileItem
                            Glyph {
                                entry: itemLoader.modelData
                                glyph: itemLoader.modelData.type === "cmd" ? (itemLoader.modelData.glyph || "›") : ""
                                icon: itemLoader.modelData.type === "app" ? (itemLoader.modelData.icon || "") : ""
                                selected: dk.selectedIndex === itemLoader.index
                                onClicked: dk.itemClicked(itemLoader.index)
                            }
                        }
                    }
                }
                Item { width: 4; height: 4 }
                Rectangle { width: dk.horizontal ? 1 : dk.size; height: dk.horizontal ? dk.size : 1; color: dk.line }
                Item { width: 4; height: 4 }
                Glyph { glyph: "\u{f0493}" }
            }

            HoverHandler {
                enabled: dk.interactive
                onPointChanged: dk.pointerY = hovered ? (dk.horizontal ? point.position.x : point.position.y) : -1
                onHoveredChanged: if (!hovered) dk.pointerY = -1
            }
        }
    }

    // One tile: an app's icon or a glyph, in the icon shape, magnified.
    component Glyph: Item {
        id: g
        property var entry: null
        property string glyph: ""
        property string icon: ""
        property bool highlighted: false
        property bool selected: false
        signal clicked()
        readonly property var mid: g.mapToItem(dockBox, width / 2, height / 2)
        readonly property real mag: dk.magnify(dk.horizontal ? mid.x : mid.y)
        // Grow from the screen-edge side, out past the dock's open side.
        readonly property int origin: dk.horizontal ? Item.Bottom : dk.onRight ? Item.Right : Item.Left
        width: dk.slot
        height: dk.slot
        readonly property string shape: dk.s.iconShape || "rounded"
        readonly property string plate: dk.s.iconPlate || "hover"
        z: g.mag > 1.01 ? g.mag : 0
        // The tile's drawing, scaled as one from the screen-edge side.
        Item {
            anchors.fill: parent
            scale: g.mag
            transformOrigin: g.origin
            Rectangle {
                id: plateRect
                anchors.centerIn: parent
                width: dk.size + 6
                height: dk.size + 6
                rotation: g.shape === "diamond" ? 45 : 0
                radius: g.shape === "circle" ? width / 2 : g.shape === "squircle" ? width * 0.32 : g.shape === "square" ? 3 : g.shape === "diamond" ? 4 : 8
                readonly property bool show: g.highlighted || g.selected || g.plate === "always" || (g.plate === "hover" && tileHover.hovered) || g.plate === "outline"
                color: !show || g.plate === "outline" ? "transparent"
                     : g.highlighted ? Qt.rgba(dk.accent.r, dk.accent.g, dk.accent.b, 0.25) : Qt.rgba(dk.ink.r, dk.ink.g, dk.ink.b, 0.1)
                border.width: g.selected ? 2 : g.plate === "outline" ? 1 : 0
                border.color: g.selected ? theme.accent : Qt.rgba(dk.ink.r, dk.ink.g, dk.ink.b, 0.35)
            }
            Image {
                visible: g.icon !== ""
                anchors.centerIn: parent
                width: dk.size; height: dk.size
                source: g.icon !== "" ? "image://icon/" + g.icon : ""
                sourceSize: Qt.size(dk.size * 2, dk.size * 2)
                opacity: g.entry && g.entry.missing ? 0.35 : 1
            }
            Label {
                visible: g.icon === ""
                anchors.centerIn: parent
                text: g.glyph
                color: g.highlighted ? dk.accent : dk.ink
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Math.round(dk.size * 0.62)
            }
        }
        HoverHandler { id: tileHover; enabled: dk.interactive; cursorShape: g.entry ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: dk.interactive && g.entry !== null; onTapped: g.clicked() }
        ToolTip.visible: dk.interactive && tileHover.hovered && g.entry !== null
        ToolTip.text: g.entry ? (g.entry.label || "") : ""
    }
}
