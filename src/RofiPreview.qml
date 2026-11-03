import QtQuick
import QtQuick.Controls
import "RofiFx.js" as Fx

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
    // Icons are always drawn in the Nerd Font, as the popups draw them.
    readonly property string glyphFont: "JetBrainsMono Nerd Font"
    // rofi's font size is in points.
    readonly property real text_: Math.max(7, (look.fontSize || 12) * 1.333 * s)
    function alpha(c, a) { const q = Qt.color(c || "#000"); return Qt.rgba(q.r, q.g, q.b, a); }
    readonly property color panelBg: alpha(pal.bg, look.opacity !== undefined ? look.opacity : 0.94)

    // The popup's motion, from the same RofiFx.js the overlay runs: its
    // entrance replays when a setting changes, or on replay().
    readonly property var fxSource: kind === "power" ? power : kind === "menu" ? menu : ({})
    readonly property string enterStyle: kind === "notify" ? ({ slide: "slide", fade: "fade", pop: "zoom", drop: "drop", flip: "flip" })[notify.enter || "slide"] || "none"
                                                           : kind === "power" || kind === "menu" ? fxSource.enter || (kind === "power" ? "cascade" : "fade") : "none"
    readonly property string hoverStyle: fxSource.hover || "hyde"
    readonly property string backdrop: fxSource.backdrop || "dim"
    readonly property real fxSpeed: kind === "notify" ? (notify.duration || 200) / 200 : fxSource.speed || 1
    readonly property int fxCount: kind === "power" ? Math.max(1, (power.buttons || []).filter(b => b.enabled !== false).length)
                                                     : kind === "menu" ? Math.max(1, (menu.items || []).length) : 3
    property real clock: 1
    property real beat: 0
    function replay() {
        entrance.stop();
        clock = enterStyle === "none" ? 1 : 0;
        if (enterStyle !== "none") entrance.start();
    }
    onEnterStyleChanged: Qt.callLater(replay)
    onFxSpeedChanged: Qt.callLater(replay)
    onKindChanged: Qt.callLater(replay)
    NumberAnimation {
        id: entrance
        target: stage; property: "clock"; from: 0; to: 1
        duration: Math.max(1, Fx.duration(stage.enterStyle, stage.fxSpeed, stage.fxCount))
    }
    SequentialAnimation on beat {
        running: stage.visible
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: 620; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: 620; easing.type: Easing.InOutSine }
    }
    // The halo a lit card can have.
    component Halo: Repeater {
        property real glow: 0
        property color tone
        property real corner: 0
        model: glow > 0 ? [10, 7, 4] : []
        Rectangle {
            required property int modelData
            anchors.fill: parent
            anchors.margins: -modelData
            z: -1
            radius: corner + modelData
            color: tone
            opacity: glow * 0.14
        }
    }

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
        visible: stage.kind === "power" && style !== "wlogout"
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

        FxBackdrop {
            anchors.fill: parent
            visible: powerView.dim > 0.001
            style: stage.backdrop
            dim: powerView.dim
            running: stage.visible && powerView.visible
            accent: stage.pal.accent || "#7aa2f7"
            second: stage.pal.urgent || "#f7768e"
        }

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
                        // HyDE's hover, as the popups plugin draws it: the
                        // active card swells a tenth each way and rounds off
                        // on an overshooting curve, and snaps back after.
                        property real t: 0
                        NumberAnimation {
                            id: pswell
                            target: pbutton; property: "t"; from: 0; to: 1
                            duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.55, 0.0, 0.28, 1.682, 1, 1]
                        }
                        onOnChanged: { pswell.stop(); if (on) pswell.start(); else t = 0 }
                        z: on ? 2 : 0
                        readonly property var fx: Fx.hover(stage.hoverStyle, t, stage.beat)
                        readonly property var enter: Fx.enter(stage.enterStyle, stage.clock, index, powerView.count, Math.max(width, 30), powerView.columns)
                        readonly property bool lit: on && !fx.outline
                        readonly property real swell: t * fx.swell
                        opacity: enter.opacity
                        rotation: enter.rotation + fx.rotation
                        transform: [
                            Translate { x: pbutton.enter.x; y: pbutton.enter.y + pbutton.fx.y * stage.s * 2 },
                            Rotation { origin.x: pbutton.width / 2; origin.y: pbutton.height / 2; axis { x: 0; y: 1; z: 0 } angle: pbutton.enter.flip }
                        ]
                        scale: enter.scale * fx.scale * (1 + (powerView.style === "list" ? 0.04 : 0.2) * swell)
                        radius: powerView.style === "pill" ? width / 2
                              : powerView.style === "list" ? stage.radius_ * (0.6 + 0.4 * swell)
                              : stage.radius_ * (1 + 2.57 * swell)
                        color: lit ? stage.pal.accent : powerView.style === "list" ? "transparent" : stage.pal.alt
                        border.width: on && fx.outline ? Math.max(1, stage.border_) : 0
                        border.color: stage.pal.accent || "transparent"
                        Halo { glow: pbutton.fx.glow; tone: stage.pal.accent || "#7aa2f7"; corner: pbutton.radius }

                        Column {
                            visible: powerView.style !== "list"
                            anchors.centerIn: parent
                            spacing: 4 * stage.s
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: pbutton.modelData.glyph
                                color: pbutton.lit ? stage.pal.accentFg : pbutton.on ? stage.pal.accent : stage.pal.fg
                                font.family: stage.glyphFont
                                font.pixelSize: Math.max(8, powerView.glyph)
                            }
                            Label {
                                visible: powerView.labels
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: pbutton.modelData.label
                                color: pbutton.lit ? stage.pal.accentFg : pbutton.on ? stage.pal.accent : stage.pal.fg
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
                                color: pbutton.lit ? stage.pal.accentFg : pbutton.on ? stage.pal.accent : stage.pal.fg
                                font.family: stage.glyphFont
                                font.pixelSize: Math.max(8, powerView.glyph)
                            }
                            Label {
                                visible: powerView.labels
                                anchors.verticalCenter: parent.verticalCenter
                                text: pbutton.modelData.label
                                color: pbutton.lit ? stage.pal.accentFg : pbutton.on ? stage.pal.accent : stage.pal.fg
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

    // ---------------------------------------------------------- wlogout
    // HyDE's wlogout style 1 as wlogout draws it: one bar of tall cards
    // across the screen, margins of 28% of its height (23% under the
    // pointer). Hovering a card swells its icon from 20% to 40% of its width,
    // rounds its corners and stretches it, on the same overshooting curve;
    // leaving snaps it back, as GTK does with the transition on :hover only.
    Item {
        id: wlogoutView
        anchors.fill: parent
        visible: stage.kind === "power" && (stage.power.style || "row") === "wlogout"
        readonly property var buttons: (stage.power.buttons || []).filter(b => b.enabled !== false)
        readonly property real mgn: height * 0.28
        readonly property real hvr: height * 0.23
        readonly property real cardWidth: (width - 2 * mgn) / Math.max(1, buttons.length)
        readonly property real iconScale: (stage.power.glyphSize || 44) / 44
        readonly property real ends: (stage.look.radius !== undefined ? stage.look.radius : 14) * 80 / 14 * stage.s
        readonly property real active: (stage.look.radius !== undefined ? stage.look.radius : 14) * 50 / 14 * stage.s
        readonly property bool labels: stage.power.labels !== false
        property int hovered: -1
        // wlogout opens with the first button focused.
        property int focused: 0

        FxBackdrop {
            anchors.fill: parent
            style: stage.backdrop
            dim: stage.power.dim !== undefined ? stage.power.dim : 0.55
            running: stage.visible && wlogoutView.visible
            accent: stage.pal.accent || "#7aa2f7"
            second: stage.pal.urgent || "#f7768e"
        }

        Repeater {
            model: wlogoutView.buttons
            Rectangle {
                id: card
                required property var modelData
                required property int index
                readonly property bool hot: wlogoutView.hovered === index
                readonly property bool first: index === 0
                readonly property bool last: index === wlogoutView.buttons.length - 1
                // 0 at rest, 1 hovered: everything below follows it. It
                // overshoots past 1 on the way, which is the bounce.
                property real t: 0
                NumberAnimation {
                    id: swell
                    target: card; property: "t"; from: 0; to: 1
                    duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.55, 0.0, 0.28, 1.682, 1, 1]
                }
                onHotChanged: { swell.stop(); if (hot) swell.start(); else t = 0 }
                readonly property var enter: Fx.enter(stage.enterStyle, stage.clock, index, wlogoutView.buttons.length, width, wlogoutView.buttons.length)
                opacity: enter.opacity
                scale: enter.scale
                rotation: enter.rotation
                transform: [
                    Translate { x: card.enter.x; y: card.enter.y },
                    Rotation { origin.x: card.width / 2; origin.y: card.height / 2; axis { x: 0; y: 1; z: 0 } angle: card.enter.flip }
                ]
                readonly property real margin: wlogoutView.mgn + (wlogoutView.hvr - wlogoutView.mgn) * t
                x: wlogoutView.mgn + index * wlogoutView.cardWidth
                y: margin
                width: wlogoutView.cardWidth
                height: wlogoutView.height - 2 * margin
                z: hot ? 1 : 0
                // The bar's ends are rounded; a hovered card rounds all over.
                topLeftRadius: (first ? wlogoutView.ends : 0) * (1 - t) + wlogoutView.active * t
                bottomLeftRadius: topLeftRadius
                topRightRadius: (last ? wlogoutView.ends : 0) * (1 - t) + wlogoutView.active * t
                bottomRightRadius: topRightRadius
                color: hot ? stage.pal.accent : wlogoutView.focused === index ? stage.pal.alt : stage.panelBg

                Label {
                    anchors.centerIn: parent
                    text: card.modelData.glyph
                    color: card.hot ? stage.pal.accentFg : stage.pal.fg
                    font.family: stage.glyphFont
                    // 20% of the card's width at rest, 30% focused, 40% hovered.
                    font.pixelSize: Math.max(6, card.width * wlogoutView.iconScale
                                                * ((wlogoutView.focused === card.index ? 0.3 : 0.2) + (0.4 - (wlogoutView.focused === card.index ? 0.3 : 0.2)) * card.t))
                }
                Label {
                    visible: wlogoutView.labels
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: height * 0.8
                    text: card.modelData.label
                    color: card.hot ? stage.pal.accentFg : stage.pal.fg
                    font.family: stage.font_
                    font.pixelSize: Math.max(6, stage.height * 0.02)
                }
                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) wlogoutView.hovered = card.index
                        else if (wlogoutView.hovered === card.index) wlogoutView.hovered = -1
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
        id: cell
        property string glyph
        property string label
        property bool on: false
        property bool vertical: false
        property real glyphScale: 1
        // Where the popup's entrance has it.
        property var enter: ({ opacity: 1, scale: 1, x: 0, y: 0, rotation: 0, flip: 0 })
        readonly property var fx: Fx.hover(stage.hoverStyle, t, stage.beat)
        readonly property bool lit: on && !fx.outline
        readonly property real swell: t * fx.swell
        signal hoveredIn()
        // HyDE's hover, as on the power cards.
        property real t: 0
        NumberAnimation {
            id: cswell
            target: cell; property: "t"; from: 0; to: 1
            duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.55, 0.0, 0.28, 1.682, 1, 1]
        }
        onOnChanged: { cswell.stop(); if (on) cswell.start(); else t = 0 }
        z: on ? 2 : 0
        opacity: enter.opacity
        rotation: enter.rotation + fx.rotation
        transform: [
            Translate { x: cell.enter.x; y: cell.enter.y + cell.fx.y * stage.s * 2 },
            Rotation { origin.x: cell.width / 2; origin.y: cell.height / 2; axis { x: 0; y: 1; z: 0 } angle: cell.enter.flip }
        ]
        scale: enter.scale * fx.scale * (1 + (vertical ? 0.18 : 0.04) * swell)
        radius: stage.radius_ * (vertical ? 0.8 + 1.4 * swell : 0.6 + 0.4 * swell)
        color: lit ? stage.pal.accent : vertical ? stage.pal.alt : "transparent"
        border.width: on && fx.outline ? Math.max(1, stage.border_) : 0
        border.color: stage.pal.accent || "transparent"
        HoverHandler { onHoveredChanged: if (hovered) cell.hoveredIn() }
        Halo { glow: cell.fx.glow; tone: stage.pal.accent || "#7aa2f7"; corner: cell.radius }
        Column {
            visible: parent.vertical
            anchors.centerIn: parent
            spacing: 3 * stage.s
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: glyph; color: lit ? stage.pal.accentFg : on ? stage.pal.accent : stage.pal.fg; font.family: stage.glyphFont; font.pixelSize: stage.text_ * 2 * glyphScale }
            Label { anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(implicitWidth, parent.parent.width - 6); elide: Text.ElideRight; text: label; color: lit ? stage.pal.accentFg : on ? stage.pal.accent : stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ * (glyphScale < 1 ? 1 : 0.8) }
        }
        Row {
            visible: !parent.vertical
            anchors.verticalCenter: parent.verticalCenter
            x: 12 * stage.s
            spacing: 10 * stage.s
            Label { text: glyph; color: lit ? stage.pal.accentFg : on ? stage.pal.accent : stage.pal.fg; font.family: stage.glyphFont; font.pixelSize: stage.text_ * 1.2 }
            Label { text: label; color: lit ? stage.pal.accentFg : on ? stage.pal.accent : stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ }
        }
    }

    Panel {
        id: menuView
        visible: stage.kind === "menu"
        property int selected: 0
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
                    on: index === menuView.selected
                    enter: Fx.enter(stage.enterStyle, stage.clock, index, menuView.items.length, Math.max(width, 30), menuView.columns)
                    onHoveredIn: menuView.selected = index
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
            property int order: 0
            readonly property var enter: Fx.enter(stage.enterStyle, stage.clock, order, 3, 90 * stage.s, 1)
            readonly property bool alarm: urgency === "critical"
            readonly property string alarmStyle: alarm ? stage.notify.critical || "none" : "none"
            property bool hot: false
            width: notifyView.toastWidth
            height: Math.max(notifyView.icon, textCol.implicitHeight) + 20 * stage.s
            radius: stage.radius_
            color: stage.panelBg
            opacity: enter.opacity * (urgency === "low" ? 0.85 : 1)
            scale: enter.scale * (alarmStyle === "pulse" ? 1 + 0.018 * stage.beat : 1) * (hot && stage.notify.hover === "lift" ? 1.02 : 1)
            transform: [
                Translate {
                    x: (notifyView.side === "right" ? -1 : 1) * parent.enter.x
                       + (parent.alarmStyle === "shake" ? Math.sin(stage.beat * Math.PI * 6) * 3 * stage.s * 2 : 0)
                    y: parent.enter.y - (parent.hot && stage.notify.hover === "lift" ? 3 : 0)
                },
                Rotation { origin.x: notifyView.toastWidth / 2; axis { x: 1; y: 0; z: 0 } angle: parent.enter.flip }
            ]
            border.color: urgency === "critical" ? stage.pal.urgent : stage.alpha(stage.pal.fg, 0.1)
            border.width: Math.max(1, stage.border_ / 2)
            HoverHandler { onHoveredChanged: parent.hot = hovered }
            Halo {
                glow: parent.alarmStyle === "glow" ? stage.beat : parent.hot && stage.notify.hover === "glow" ? 0.8 : 0
                tone: parent.alarm ? stage.pal.urgent || "#f7768e" : stage.pal.accent || "#7aa2f7"
                corner: parent.radius
            }
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
            Toast { order: 1; summary: "Low urgency"; body: "A quiet note that fades sooner."; urgency: "low" }
            Toast { order: 2; summary: "Critical"; body: "These stay until dismissed."; urgency: "critical" }
        }

        // The control centre, swaync-client -t.
        Rectangle {
            visible: stage.showCenter
            readonly property real w: (stage.notify.centerWidth || 460) * stage.s
            clip: true
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
                    // swaync puts the list at the bottom when it isn't placed.
                    model: notifyView.widgets.indexOf("notifications") >= 0 ? notifyView.widgets : notifyView.widgets.concat(["notifications"])
                    Loader {
                        required property string modelData
                        readonly property string kind: modelData.split("#")[0]
                        // An installed widget's swaync settings; {} for the built-in ones.
                        readonly property var settings: ((stage.notify.customWidgets || {})[modelData] || {}).config || ({})
                        width: parent.width
                        sourceComponent: kind === "title" ? titleWidget : kind === "dnd" ? dndWidget
                                       : kind === "notifications" ? listWidget : kind === "mpris" ? mprisWidget
                                       : kind === "buttons-grid" ? buttonsWidget : kind === "label" ? labelWidget
                                       : kind === "menubar" ? menubarWidget : kind === "inhibitors" ? inhibitorsWidget : sliderWidget
                        property string widget: kind
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
                    Label { x: 10 * stage.s; anchors.verticalCenter: parent.verticalCenter; text: parent.parent.settings.label || (parent.parent.widget === "volume" ? "󰕾" : "󰃟"); color: stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ * 1.2 }
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
                            model: (parent.parent.parent.settings.actions || [{ label: "󰐥" }, { label: "󰜉" }, { label: "󰌾" }, { label: "󰖩" }, { label: "󰂯" }]).map(a => a.label).slice(0, 8)
                            Rectangle {
                                required property string modelData
                                required property int index
                                width: Math.max(stage.text_ * 2.4, buttonText.implicitWidth + 10 * stage.s); height: stage.text_ * 2; radius: stage.radius_ * 0.6
                                color: index === 3 ? stage.pal.accent : stage.pal.bg
                                Label { id: buttonText; anchors.centerIn: parent; text: modelData; color: index === 3 ? stage.pal.accentFg : stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ * 1.1 }
                            }
                        }
                    }
                }
            }
            Component {
                id: labelWidget
                Item {
                    implicitHeight: stage.text_ * 1.9
                    Label { anchors.centerIn: parent; textFormat: Text.PlainText; text: parent.parent.settings.text || "Label"; color: stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ * 1.1 }
                }
            }
            Component {
                id: inhibitorsWidget
                Item {
                    height: stage.text_ * 2
                    Label { anchors.verticalCenter: parent.verticalCenter; x: 8 * stage.s; text: "Inhibitors"; color: stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ }
                }
            }
            Component {
                id: menubarWidget
                Rectangle {
                    height: stage.text_ * 2.4; radius: stage.radius_; color: stage.pal.alt
                    readonly property var settings: parent.settings
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 8 * stage.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6 * stage.s
                        Repeater {
                            model: {
                                const out = [], all = parent.parent.settings || {};
                                for (const key in all) {
                                    if (key.indexOf("menu") === 0) out.push(all[key].label || "Menu");
                                    else (all[key].actions || []).forEach(a => out.push(a.label));
                                }
                                return out.slice(0, 7);
                            }
                            Label { required property string modelData; text: modelData; color: stage.pal.fg; font.family: stage.font_; font.pixelSize: stage.text_ * 1.1 }
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
