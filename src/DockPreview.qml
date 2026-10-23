import QtQuick
import QtQuick.Controls

// Side Dock drawn from its settings, the way the shell plugin draws it: the
// body in its shape, colour, opacity and border; the agents button, the dock
// items as tiles in their shape (plates shown on hover, always, or as
// outlines); magnification under the pointer; and, when open, the agents
// panel beside it.
Item {
    id: dk

    property var s: ({})
    property var items: []
    property var agents: []
    property bool interactive: false
    property bool panelOpen: false
    property int selectedIndex: -1
    // Fit the dock into this height (0: natural size).
    property real fitHeight: 0
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
    readonly property int size: s.iconSize || 28
    readonly property int slot: size + 10
    readonly property real magMax: s.magnify ? Math.max(1.1, Math.min(2.4, s.magnifyScale || 1.7)) : 1
    readonly property int magRange: Math.max(1, Math.min(4, s.magnifyRange || 2))
    readonly property real dockWidth: size + 16
    readonly property real naturalHeight: column.implicitHeight + 12
    readonly property real fit: fitHeight > 0 ? Math.min(1, fitHeight / Math.max(1, naturalHeight)) : 1

    implicitWidth: (dockWidth + (panelOpen ? panelWidth + 10 : 0)) * fit
    implicitHeight: naturalHeight * fit
    readonly property real panelWidth: Math.max(160, Math.min(320, (s.width || 520) * 0.42))

    // Where the pointer is along the dock, for magnifying.
    property real pointerY: -1
    function magnify(centreY) {
        if (!s.magnify || pointerY < 0) return 1;
        const reach = magRange * slot;
        const d = Math.abs(centreY - pointerY);
        if (d >= reach) return 1;
        return 1 + (magMax - 1) * (0.5 + 0.5 * Math.cos(Math.PI * d / reach));
    }

    Item {
        id: canvas
        width: dk.dockWidth + (dk.panelOpen ? dk.panelWidth + 10 : 0)
        height: dk.naturalHeight
        scale: dk.fit
        transformOrigin: dk.onRight ? Item.TopRight : Item.TopLeft
        x: dk.onRight ? dk.width - width : 0

        // --- the agents panel, opened beside the dock ---
        Rectangle {
            visible: dk.panelOpen
            x: dk.onRight ? 0 : dk.dockWidth + 10
            width: dk.panelWidth
            height: parent.height
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
                        width: (dk.panelWidth - 24) * [0.5, 0.8, 0.65, 0.3, 0.75, 0.55, 0.85, 0.4, 0.6][index]
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
            width: dk.dockWidth
            height: parent.height

            Rectangle {
                readonly property string shape: dk.s.dockShape || "rounded"
                readonly property real r: shape === "pill" ? width / 2 : shape === "soft" ? 8 : shape === "square" ? 0 : Math.min(18, width / 2)
                readonly property bool edge: shape === "edge"
                anchors.fill: parent
                radius: edge ? 0 : r
                topLeftRadius: edge ? (dk.onRight ? 16 : 0) : r
                bottomLeftRadius: edge ? (dk.onRight ? 16 : 0) : r
                topRightRadius: edge ? (dk.onRight ? 0 : 16) : r
                bottomRightRadius: edge ? (dk.onRight ? 0 : 16) : r
                color: Qt.rgba(dk.tint.r, dk.tint.g, dk.tint.b, dk.s.opacity === undefined ? 0.94 : dk.s.opacity)
                border.width: (dk.s.dockBorder || "subtle") === "none" ? 0 : 1
                border.color: dk.s.dockBorder === "accent" ? Qt.rgba(dk.accent.r, dk.accent.g, dk.accent.b, 0.75) : dk.line
            }

            Column {
                id: column
                y: 6
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                Glyph { glyph: dk.onRight ? "\u{f0141}" : "\u{f0142}"; highlighted: dk.panelOpen }
                Item { width: 1; height: 4 }
                Rectangle { width: dk.size; height: 1; color: dk.line; anchors.horizontalCenter: parent.horizontalCenter }
                Item { width: 1; height: 4 }
                Repeater {
                    model: dk.items
                    delegate: Loader {
                        id: itemLoader
                        required property var modelData
                        required property int index
                        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                        sourceComponent: modelData.type === "spacer" ? spacerItem : modelData.type === "divider" ? dividerItem : tileItem
                        Component { id: spacerItem; Item { width: dk.size; height: dk.size / 2 } }
                        Component { id: dividerItem; Item { width: dk.size; height: 9; Rectangle { anchors.centerIn: parent; width: dk.size * 0.7; height: 1; color: dk.line } } }
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
                Item { width: 1; height: 4 }
                Rectangle { width: dk.size; height: 1; color: dk.line; anchors.horizontalCenter: parent.horizontalCenter }
                Item { width: 1; height: 4 }
                Glyph { glyph: "\u{f0493}" }
            }

            HoverHandler {
                enabled: dk.interactive
                onPointChanged: dk.pointerY = hovered ? point.position.y : -1
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
        readonly property real centre: y + height / 2
        readonly property real mag: dk.magnify(g.mapToItem(dockBox, 0, height / 2).y)
        width: dk.slot
        height: dk.slot
        readonly property string shape: dk.s.iconShape || "rounded"
        readonly property string plate: dk.s.iconPlate || "hover"
        Rectangle {
            id: plateRect
            anchors.centerIn: parent
            width: dk.size + 6
            height: dk.size + 6
            scale: g.mag
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
            scale: g.mag
            source: g.icon !== "" ? "image://icon/" + g.icon : ""
            sourceSize: Qt.size(dk.size * 2, dk.size * 2)
            opacity: g.entry && g.entry.missing ? 0.35 : 1
        }
        Label {
            visible: g.icon === ""
            anchors.centerIn: parent
            scale: g.mag
            text: g.glyph
            color: g.highlighted ? dk.accent : dk.ink
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.round(dk.size * 0.62)
        }
        HoverHandler { id: tileHover; enabled: dk.interactive; cursorShape: g.entry ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: dk.interactive && g.entry !== null; onTapped: g.clicked() }
        ToolTip.visible: dk.interactive && tileHover.hovered && g.entry !== null
        ToolTip.text: g.entry ? (g.entry.label || "") : ""
    }
}
