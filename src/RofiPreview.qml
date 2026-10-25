import QtQuick
import QtQuick.Controls

// A screen with one of ROFIoma's popups drawn on it as rofi (or swaync) will
// draw it: the same sizes, colours, corners and layout, scaled down from a
// 1920 pixel wide screen. Hovering a power button selects it, as the arrow
// keys would.
Rectangle {
    id: stage
    // power, menu, symbols, keybinds or notify.
    property string kind: "power"
    property var pal: ({})
    property var look: ({})
    property var power: ({})
    property var menu: ({})
    property var symbols: ({})
    property var notify: ({})
    property var sample: []
    property bool showCenter: false

    readonly property real s: width / 1920
    readonly property real radius_: (look.radius !== undefined ? look.radius : 14) * s
    readonly property real border_: Math.max(1, (look.border !== undefined ? look.border : 2) * s)
    readonly property string font_: look.font || "JetBrainsMono Nerd Font"
    // rofi's font size is in points.
    readonly property real text_: Math.max(7, (look.fontSize || 12) * 1.333 * s)
    function alpha(c, a) { const q = Qt.color(c || "#000"); return Qt.rgba(q.r, q.g, q.b, a); }
    readonly property color panelBg: alpha(pal.bg, look.opacity !== undefined ? look.opacity : 0.94)

    implicitHeight: width * 0.5625
    radius: 10
    clip: true
    border.color: theme.border
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.darker(stage.pal.accent || theme.accent, 3.2) }
        GradientStop { position: 0.55; color: Qt.darker(stage.pal.bg || theme.window, 1.2) }
        GradientStop { position: 1; color: Qt.darker(stage.pal.urgent || theme.danger, 4) }
    }

    // A couple of windows, so the popup reads as over a desktop.
    Repeater {
        model: [{ x: 0.04, y: 0.07, w: 0.44, h: 0.86 }, { x: 0.5, y: 0.07, w: 0.46, h: 0.4 }, { x: 0.5, y: 0.5, w: 0.46, h: 0.43 }]
        Rectangle {
            required property var modelData
            x: stage.width * modelData.x; y: stage.height * modelData.y
            width: stage.width * modelData.w; height: stage.height * modelData.h
            radius: 6
            color: stage.alpha(stage.pal.bg, 0.55)
            border.color: stage.alpha(stage.pal.fg, 0.08)
            Column {
                x: 10; y: 10; spacing: 5
                Repeater {
                    model: 4
                    Rectangle { required property int index; width: (parent.parent.width - 20) * (0.8 - index * 0.15); height: 4; radius: 2; color: stage.alpha(stage.pal.fg, 0.08) }
                }
            }
        }
    }

    // ---------------------------------------------------------- power
    Item {
        id: powerView
        anchors.fill: parent
        visible: stage.kind === "power"
        readonly property string style: stage.power.style || "row"
        readonly property var buttons: (stage.power.buttons || []).filter(b => b.enabled !== false)
        readonly property int count: Math.max(1, buttons.length)
        readonly property real dim: style === "list" ? 0 : (stage.power.dim !== undefined ? stage.power.dim : 0.55)
        readonly property int columns: style === "grid" ? Math.min(3, count) : style === "list" ? 1 : count
        readonly property real size: (stage.power.size || 150) * stage.s
        readonly property real cell: style === "pill" ? size * 0.5 : size
        readonly property real cellHeight: style === "row" ? size * 1.15 : cell
        readonly property real gap: (stage.power.spacing !== undefined ? stage.power.spacing : 14) * stage.s
        readonly property real glyph: (stage.power.glyphSize || 44) * 1.333 * stage.s * (style === "pill" ? 0.6 : style === "list" ? 0.45 : 1)
        readonly property bool labels: stage.power.labels !== false && style !== "pill"
        property int selected: 0

        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, powerView.dim); visible: powerView.dim > 0.001 }

        Rectangle {
            anchors.centerIn: parent
            readonly property bool panel: powerView.dim <= 0.001
            width: powerContent.width + 36 * stage.s * 2
            height: powerContent.height + 36 * stage.s * 2
            radius: stage.radius_
            color: panel ? stage.panelBg : "transparent"
            border.color: panel ? stage.pal.accent : "transparent"
            border.width: stage.border_

            Grid {
                id: powerContent
                anchors.centerIn: parent
                columns: powerView.columns
                spacing: powerView.style === "list" ? 2 * stage.s : powerView.gap
                Repeater {
                    model: powerView.buttons
                    Rectangle {
                        id: pbutton
                        required property var modelData
                        required property int index
                        readonly property bool on: powerView.selected === index
                        width: powerView.style === "list" ? 320 * stage.s : powerView.cell
                        height: powerView.style === "list" ? Math.max(row.implicitHeight, 20 * stage.s) + 20 * stage.s : powerView.cellHeight
                        radius: powerView.style === "pill" ? width / 2
                              : powerView.style === "list" ? stage.radius_ * 0.6
                              : on ? stage.radius_ * 1.8 : stage.radius_
                        color: on ? stage.pal.accent : powerView.style === "list" ? "transparent" : stage.pal.alt
                        Behavior on radius { NumberAnimation { duration: 140 } }
                        Behavior on color { ColorAnimation { duration: 110 } }

                        Column {
                            visible: powerView.style !== "list"
                            anchors.centerIn: parent
                            spacing: 4 * stage.s
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: pbutton.modelData.glyph
                                color: pbutton.on ? stage.pal.accentFg : stage.pal.fg
                                font.family: stage.font_
                                font.pixelSize: Math.max(8, powerView.glyph)
                            }
                            Label {
                                visible: powerView.labels
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: pbutton.modelData.label
                                color: pbutton.on ? stage.pal.accentFg : stage.pal.fg
                                font.family: stage.font_
                                font.pixelSize: stage.text_
                            }
                        }
                        Row {
                            id: row
                            visible: powerView.style === "list"
                            anchors.verticalCenter: parent.verticalCenter
                            x: 14 * stage.s
                            spacing: 12 * stage.s
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: pbutton.modelData.glyph
                                color: pbutton.on ? stage.pal.accentFg : stage.pal.fg
                                font.family: stage.font_
                                font.pixelSize: Math.max(8, powerView.glyph)
                            }
                            Label {
                                visible: powerView.labels
                                anchors.verticalCenter: parent.verticalCenter
                                text: pbutton.modelData.label
                                color: pbutton.on ? stage.pal.accentFg : stage.pal.fg
                                font.family: stage.font_
                                font.pixelSize: stage.text_
                            }
                        }
                        HoverHandler { onHoveredChanged: if (hovered) powerView.selected = pbutton.index }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------- popups
    // The panel every other rofi popup sits in: a search line, then rows.
    component Panel: Rectangle {
        property real panelWidth: 420
        default property alias content: inner.data
        anchors.centerIn: parent
        width: panelWidth * stage.s
        height: inner.implicitHeight + 36 * stage.s
        radius: stage.radius_
        color: stage.panelBg
        border.color: stage.pal.accent
        border.width: stage.border_
        Column {
            id: inner
            x: 18 * stage.s
            y: 18 * stage.s
            width: parent.width - 36 * stage.s
            spacing: 12 * stage.s
        }
    }
    component SearchLine: Rectangle {
        property string prompt
        width: parent.width
        height: stage.text_ + 20 * stage.s
        radius: stage.radius_ * 0.6
        color: stage.pal.alt
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 14 * stage.s
            spacing: 10 * stage.s
            Label { text: prompt; color: stage.pal.accent; font.family: stage.font_; font.pixelSize: stage.text_ }
            Label { text: "Search…"; color: stage.pal.muted; font.family: stage.font_; font.pixelSize: stage.text_ }
        }
    }
    component Cell: Rectangle {
        property string glyph
        property string label
        property bool on: false
        property bool vertical: false
        property real glyphScale: 1
        radius: stage.radius_ * (vertical ? 0.8 : 0.6)
        color: on ? stage.pal.accent : vertical ? stage.pal.alt : "transparent"
        Column {
            visible: parent.vertical
            anchors.centerIn: parent
            spacing: 3 * stage.s
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: glyph; color: on ? stage.pal.accentFg : stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ * 2 * glyphScale }
            Label { anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(implicitWidth, parent.parent.width - 6); elide: Text.ElideRight; text: label; color: on ? stage.pal.accentFg : stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ * (glyphScale < 1 ? 1 : 0.8) }
        }
        Row {
            visible: !parent.vertical
            anchors.verticalCenter: parent.verticalCenter
            x: 12 * stage.s
            spacing: 10 * stage.s
            Label { text: glyph; color: on ? stage.pal.accentFg : stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ * 1.2 }
            Label { text: label; color: on ? stage.pal.accentFg : stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ }
        }
    }

    Panel {
        id: menuView
        visible: stage.kind === "menu"
        readonly property string layout: stage.menu.layout || "list"
        readonly property var items: stage.menu.items || []
        readonly property int columns: layout === "grid" ? Math.max(1, stage.menu.columns || 3) : layout === "row" ? Math.max(1, items.length) : 1
        panelWidth: stage.menu.width || 420
        SearchLine { visible: stage.menu.search !== false; prompt: stage.menu.prompt || stage.menu.name || "" }
        Grid {
            width: parent.width
            columns: menuView.columns
            spacing: 8 * stage.s
            Repeater {
                model: menuView.items.slice(0, menuView.layout === "list" ? 10 : 30)
                Cell {
                    required property var modelData
                    required property int index
                    width: (parent.width - (menuView.columns - 1) * 8 * stage.s) / menuView.columns
                    height: menuView.layout === "list" ? stage.text_ * 1.4 + 18 * stage.s : stage.text_ * 3.2 + 32 * stage.s
                    vertical: menuView.layout !== "list"
                    glyph: modelData.glyph || ""
                    label: modelData.label || ""
                    on: index === 0
                }
            }
        }
    }

    Panel {
        id: symbolsView
        visible: stage.kind === "symbols"
        readonly property bool grid: (stage.symbols.layout || "grid") === "grid"
        readonly property int columns: grid ? Math.max(3, Math.min(14, stage.symbols.columns || 8)) : 1
        panelWidth: stage.symbols.width || 720
        SearchLine { prompt: "󰞅 Emoji" }
        Grid {
            width: parent.width
            columns: symbolsView.columns
            spacing: 6 * stage.s
            Repeater {
                model: stage.sample.slice(0, symbolsView.grid ? symbolsView.columns * 5 : 12)
                Cell {
                    required property var modelData
                    required property int index
                    width: (parent.width - (symbolsView.columns - 1) * 6 * stage.s) / symbolsView.columns
                    height: symbolsView.grid ? stage.text_ * 3.6 + 20 * stage.s : stage.text_ * 1.3 + 12 * stage.s
                    vertical: symbolsView.grid
                    glyphScale: symbolsView.grid ? 1.1 : 1
                    glyph: modelData.symbol || ""
                    label: symbolsView.grid ? (modelData.name || "") : (modelData.name || "") + "   " + (modelData.set || "")
                    on: index === 0
                }
            }
        }
    }

    Panel {
        id: keysView
        visible: stage.kind === "keybinds"
        panelWidth: 860
        SearchLine { prompt: "󰌌 Keys" }
        Column {
            width: parent.width
            spacing: 2 * stage.s
            Repeater {
                model: (stage.sample.length ? stage.sample : [
                    { keys: "SUPER + RETURN", description: "Terminal" },
                    { keys: "SUPER + SPACE", description: "Launcher" },
                    { keys: "SUPER + W", description: "Close window" },
                    { keys: "SUPER + ESCAPE", description: "System menu" }
                ]).slice(0, 14)
                Rectangle {
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: stage.text_ + 12 * stage.s
                    radius: stage.radius_ * 0.5
                    color: index === 0 ? stage.pal.accent : index % 2 ? stage.pal.alt : "transparent"
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12 * stage.s
                        Label {
                            width: stage.text_ * 0.62 * 31
                            text: modelData.keys || ""
                            elide: Text.ElideRight
                            color: index === 0 ? stage.pal.accentFg : stage.pal.accent
                            font.family: "monospace"
                            font.pixelSize: stage.text_
                        }
                        Label {
                            text: modelData.description || ""
                            color: index === 0 ? stage.pal.accentFg : stage.pal.fg
                            font.family: stage.font_
                            font.pixelSize: stage.text_
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------- swaync
    Item {
        id: notifyView
        anchors.fill: parent
        visible: stage.kind === "notify"
        readonly property string position: stage.notify.position || "top-right"
        readonly property bool atTop: position.indexOf("top") === 0
        readonly property string side: position.split("-")[1] || "right"
        readonly property real margin: (stage.notify.margin !== undefined ? stage.notify.margin : 12) * stage.s
        readonly property real toastWidth: (stage.notify.width || 380) * stage.s
        readonly property real icon: (stage.notify.iconSize || 48) * stage.s
        readonly property bool edge: stage.notify.accentEdge !== false
        readonly property var widgets: stage.notify.widgets || []

        function xFor(w) { return side === "left" ? margin : side === "center" ? (stage.width - w) / 2 : stage.width - w - margin; }

        component Toast: Rectangle {
            property string summary
            property string body
            property string urgency: "normal"
            width: notifyView.toastWidth
            height: Math.max(notifyView.icon, textCol.implicitHeight) + 20 * stage.s
            radius: stage.radius_
            color: stage.panelBg
            opacity: urgency === "low" ? 0.85 : 1
            border.color: urgency === "critical" ? stage.pal.urgent : stage.alpha(stage.pal.fg, 0.1)
            border.width: Math.max(1, stage.border_ / 2)
            Rectangle {
                visible: notifyView.edge || urgency === "critical"
                width: Math.max(3, stage.border_ * 2); height: parent.height - parent.radius * 1.2
                anchors.verticalCenter: parent.verticalCenter
                x: 0
                radius: width / 2
                color: urgency === "critical" ? stage.pal.urgent : stage.pal.accent
            }
            Rectangle {
                id: iconBox
                x: 12 * stage.s; anchors.verticalCenter: parent.verticalCenter
                width: notifyView.icon; height: width; radius: width * 0.22
                color: stage.alpha(stage.pal.accent, 0.18)
                Label { anchors.centerIn: parent; text: urgency === "critical" ? "󰀪" : "󰂚"; color: urgency === "critical" ? stage.pal.urgent : stage.pal.accent; font.family: stage.font_; font.pixelSize: parent.width * 0.5 }
            }
            Column {
                id: textCol
                anchors.left: iconBox.right; anchors.leftMargin: 10 * stage.s
                anchors.right: parent.right; anchors.rightMargin: 12 * stage.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Label { width: parent.width; text: summary; elide: Text.ElideRight; color: stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ * 1.08; font.weight: Font.Bold }
                Label { width: parent.width; text: body; elide: Text.ElideRight; color: stage.alpha(stage.pal.fg, 0.82); font.family: stage.font_; font.pixelSize: stage.text_ }
            }
        }

        Column {
            id: toasts
            visible: !stage.showCenter
            x: notifyView.xFor(width)
            y: notifyView.atTop ? notifyView.margin : stage.height - height - notifyView.margin
            width: notifyView.toastWidth
            spacing: 6 * stage.s
            Toast { summary: "ROFIoma"; body: "This is how your notifications look now." }
            Toast { summary: "Low urgency"; body: "A quiet note that fades sooner."; urgency: "low" }
            Toast { summary: "Critical"; body: "These stay until dismissed."; urgency: "critical" }
        }

        // The control centre, swaync-client -t.
        Rectangle {
            visible: stage.showCenter
            readonly property real w: (stage.notify.centerWidth || 460) * stage.s
            x: notifyView.side === "left" ? notifyView.margin : notifyView.side === "center" ? (stage.width - w) / 2 : stage.width - w - notifyView.margin
            y: notifyView.margin
            width: w
            height: stage.height - 2 * notifyView.margin
            radius: stage.radius_
            color: stage.panelBg
            border.color: stage.pal.accent
            border.width: stage.border_
            Column {
                x: 8 * stage.s; y: 8 * stage.s
                width: parent.width - 16 * stage.s
                spacing: 8 * stage.s
                Repeater {
                    model: notifyView.widgets
                    Loader {
                        required property string modelData
                        width: parent.width
                        sourceComponent: modelData === "title" ? titleWidget : modelData === "dnd" ? dndWidget
                                       : modelData === "notifications" ? listWidget : modelData === "mpris" ? mprisWidget
                                       : modelData === "buttons-grid" ? buttonsWidget : sliderWidget
                        property string widget: modelData
                    }
                }
            }
            Component {
                id: titleWidget
                Item {
                    height: stage.text_ * 2
                    Label { anchors.verticalCenter: parent.verticalCenter; x: 8 * stage.s; text: "Notifications"; color: stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ * 1.4 }
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 8 * stage.s; anchors.verticalCenter: parent.verticalCenter
                        width: clear.implicitWidth + 24 * stage.s; height: stage.text_ * 1.6; radius: stage.radius_ * 0.6; color: stage.pal.alt
                        Label { id: clear; anchors.centerIn: parent; text: "Clear all"; color: stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ }
                    }
                }
            }
            Component {
                id: dndWidget
                Item {
                    height: stage.text_ * 2
                    Label { anchors.verticalCenter: parent.verticalCenter; x: 8 * stage.s; text: "Do Not Disturb"; color: stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ }
                    Rectangle {
                        anchors.right: parent.right; anchors.rightMargin: 8 * stage.s; anchors.verticalCenter: parent.verticalCenter
                        width: stage.text_ * 2.6; height: stage.text_ * 1.4; radius: height / 2; color: stage.pal.alt
                        Rectangle { x: 2; anchors.verticalCenter: parent.verticalCenter; width: parent.height - 4; height: width; radius: width / 2; color: stage.pal.fg }
                    }
                }
            }
            Component {
                id: mprisWidget
                Rectangle {
                    height: 72 * stage.s + 16 * stage.s; radius: stage.radius_; color: stage.pal.alt
                    Rectangle { x: 8 * stage.s; anchors.verticalCenter: parent.verticalCenter; width: 72 * stage.s; height: width; radius: 10 * stage.s; color: stage.alpha(stage.pal.accent, 0.35) }
                    Column {
                        x: 88 * stage.s; anchors.verticalCenter: parent.verticalCenter
                        Label { text: "Now playing"; color: stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_; font.weight: Font.Bold }
                        Label { text: "󰒮  󰐊  󰒭"; color: stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ * 1.2 }
                    }
                }
            }
            Component {
                id: sliderWidget
                Rectangle {
                    height: stage.text_ * 2.4; radius: stage.radius_; color: stage.pal.alt
                    Label { x: 10 * stage.s; anchors.verticalCenter: parent.verticalCenter; text: parent.parent.widget === "volume" ? "󰕾" : "󰃟"; color: stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ * 1.2 }
                    Rectangle {
                        x: 40 * stage.s; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 54 * stage.s; height: 4; radius: 2; color: stage.alpha(stage.pal.fg, 0.15)
                        Rectangle { width: parent.width * 0.6; height: parent.height; radius: 2; color: stage.pal.accent }
                    }
                }
            }
            Component {
                id: buttonsWidget
                Rectangle {
                    height: stage.text_ * 3; radius: stage.radius_; color: stage.pal.alt
                    Row {
                        anchors.centerIn: parent; spacing: 6 * stage.s
                        Repeater {
                            model: ["󰐥", "󰜉", "󰌾", "󰖩", "󰂯"]
                            Rectangle {
                                required property string modelData
                                required property int index
                                width: stage.text_ * 2.4; height: stage.text_ * 2; radius: stage.radius_ * 0.6
                                color: index === 3 ? stage.pal.accent : stage.pal.bg
                                Label { anchors.centerIn: parent; text: modelData; color: index === 3 ? stage.pal.accentFg : stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ * 1.1 }
                            }
                        }
                    }
                }
            }
            Component {
                id: listWidget
                Column {
                    spacing: 6 * stage.s
                    Repeater {
                        model: [["ROFIoma", "This is how your notifications look now."], ["Updates", "12 packages can be updated."]]
                        Rectangle {
                            required property var modelData
                            width: parent.width; height: stage.text_ * 3.4; radius: stage.radius_; color: stage.pal.alt
                            Column {
                                x: 12 * stage.s; anchors.verticalCenter: parent.verticalCenter
                                Label { text: modelData[0]; color: stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_; font.weight: Font.Bold }
                                Label { text: modelData[1]; color: stage.alpha(stage.pal.fg, 0.82); font.family: stage.font_; font.pixelSize: stage.text_ * 0.92 }
                            }
                        }
                    }
                }
            }
        }
    }
}
