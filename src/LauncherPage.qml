import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// HyprLAUNCH, the launcher in the Studio plugin: its layouts, colour schemes
// and how it moves. Every pick is written to launcher-style.json, which the
// launcher follows straight away.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property bool dialogOpen: false
    readonly property var shortcuts: [
        { keys: "L / Shift L", action: "Next / previous layout" },
        { keys: "C / Shift C", action: "Next / previous colour scheme" },
        { keys: "T / Shift T", action: "Next / previous transition" },
        { keys: "R", action: "Surprise me: a random layout and scheme" },
        { keys: "O", action: "Open the launcher to see it" }
    ]

    function handleEscape() {
        if (launcher.error !== "" || launcher.notice !== "") {
            launcher.dismissMessages();
            return true;
        }
        return false;
    }
    function acceptDialog() {}

    function find(list, id) {
        for (let i = 0; i < list.length; i++)
            if (list[i].id === id)
                return list[i];
        return list.length ? list[0] : ({});
    }
    function cycle(list, id, step) {
        if (!list.length)
            return "";
        let i = 0;
        for (; i < list.length; i++)
            if (list[i].id === id)
                break;
        if (i >= list.length)
            i = 0;
        return list[(i + step + list.length) % list.length].id;
    }

    // A scheme as plain colours; "omarchy" stands for the live theme.
    function colorsOf(id) {
        const s = find(launcher.schemes, id);
        if (s.id && s.id !== "omarchy")
            return s;
        return { bg: theme.inset, alt: theme.card, fg: theme.textSoft, sel: theme.accent, active: theme.accent, urgent: "#f7768e" };
    }
    readonly property var current: colorsOf(launcher.scheme)
    readonly property var transitionDef: find(launcher.transitions, launcher.transition)

    readonly property bool keys: active && keysFree && launcher.available
    Shortcut { sequence: "L"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: launcher.setLayout(page.cycle(launcher.layouts, launcher.layout, 1)) }
    Shortcut { sequence: "Shift+L"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: launcher.setLayout(page.cycle(launcher.layouts, launcher.layout, -1)) }
    Shortcut { sequence: "C"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: launcher.setScheme(page.cycle(launcher.schemes, launcher.scheme, 1)) }
    Shortcut { sequence: "Shift+C"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: launcher.setScheme(page.cycle(launcher.schemes, launcher.scheme, -1)) }
    Shortcut { sequence: "T"; context: Qt.ApplicationShortcut; enabled: page.keys && launcher.transitions.length > 0; onActivated: launcher.setTransition(page.cycle(launcher.transitions, launcher.transition, 1)) }
    Shortcut { sequence: "Shift+T"; context: Qt.ApplicationShortcut; enabled: page.keys && launcher.transitions.length > 0; onActivated: launcher.setTransition(page.cycle(launcher.transitions, launcher.transition, -1)) }
    Shortcut { sequence: "R"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: launcher.randomize() }
    Shortcut { sequence: "O"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: launcher.preview() }

    onActiveChanged: if (active) launcher.reload()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        PageHeader {
            title: "HyprLAUNCH"
            subtitle: "The launcher's layouts, colours and motion, saved to ~/.config/omarchy/launcher-style.json"
            glyph: "\u{f003b}"
            Button { text: "Surprise me"; flat: true; focusPolicy: Qt.NoFocus; visible: launcher.available; onClicked: launcher.randomize() }
            KeyCap { text: "R"; visible: launcher.available }
            AccentButton { text: "Open launcher"; visible: launcher.available; onClicked: launcher.preview() }
            KeyCap { text: "O"; visible: launcher.available }
        }

        NotInstalled {
            visible: !launcher.available
            pluginId: "omacraft.studio"
            what: "HyprLAUNCH is the launcher inside the Studio plugin."
        }

        MessageBar {
            error: launcher.error
            notice: launcher.notice
            onDismissed: launcher.dismissMessages()
        }

        ScrollView {
            id: scroll
            visible: launcher.available
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: scroll.availableWidth
                spacing: 14

                // ---- Motion
                Card {
                    Layout.fillWidth: true
                    implicitHeight: motion.implicitHeight + 32
                    ColumnLayout {
                        id: motion
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            SectionLabel { text: "Transition" }
                            Label {
                                Layout.fillWidth: true
                                text: page.transitionDef.description || ""
                                color: theme.textMuted
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            KeyCap { text: "T" }
                        }
                        Label {
                            visible: launcher.transitions.length === 0
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: theme.warning
                            text: "This copy of the Studio plugin has no transitions yet. Update it, then restart the shell."
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: Math.max(3, Math.floor(width / 150))
                            rowSpacing: 8
                            columnSpacing: 8
                            Repeater {
                                model: launcher.transitions
                                delegate: Rectangle {
                                    id: ttile
                                    required property var modelData
                                    readonly property bool chosen: launcher.transition === modelData.id
                                    readonly property color tone: Qt.color(theme.accent)
                                    Layout.fillWidth: true
                                    implicitHeight: 92
                                    radius: 9
                                    color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.14) : thover.hovered ? theme.hover : theme.inset
                                    border.color: chosen ? theme.accent : theme.border
                                    border.width: chosen ? 2 : 1

                                    // A small launcher card playing this transition.
                                    TransitionDemo {
                                        id: demo
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 8
                                        height: 50
                                        def: ttile.modelData
                                        colors: page.current
                                        layoutBase: page.find(launcher.layouts, launcher.layout).base || launcher.layout
                                    }
                                    Label {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 8
                                        text: (ttile.modelData.icon ? ttile.modelData.icon + "  " : "") + ttile.modelData.name
                                        color: ttile.chosen ? theme.accent : theme.text
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }
                                    HoverHandler {
                                        id: thover
                                        cursorShape: Qt.PointingHandCursor
                                        onHoveredChanged: if (hovered) demo.play()
                                    }
                                    TapHandler {
                                        onTapped: {
                                            launcher.setTransition(ttile.modelData.id);
                                            demo.play();
                                        }
                                    }
                                }
                            }
                        }
                        SliderRow {
                            label: "Speed"
                            from: 0.25
                            to: 3
                            stepSize: 0.05
                            value: launcher.speed
                            suffix: "×"
                            onMoved: value => launcher.setSpeed(value)
                        }
                        SwitchRow {
                            label: "Glide between layouts"
                            hint: "Switching layout while the launcher is open (Ctrl+L, or a pick here) moves the card to its new place and fades the content across."
                            checked: launcher.animateLayouts
                            onToggled: on => launcher.setAnimateLayouts(on)
                        }
                        SwitchRow {
                            label: "Blend colour schemes"
                            hint: "Switching colours while it is open (Ctrl+T, or a pick here) blends from the old scheme to the new one."
                            checked: launcher.animateColors
                            onToggled: on => launcher.setAnimateColors(on)
                        }
                    }
                }

                // ---- Layouts
                Card {
                    Layout.fillWidth: true
                    implicitHeight: layoutColumn.implicitHeight + 32
                    ColumnLayout {
                        id: layoutColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        RowLayout {
                            SectionLabel { text: "Layout" }
                            Item { Layout.fillWidth: true }
                            KeyCap { text: "L" }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: Math.max(2, Math.floor(width / 190))
                            rowSpacing: 10
                            columnSpacing: 10
                            Repeater {
                                model: launcher.layouts
                                delegate: Rectangle {
                                    id: ltile
                                    required property var modelData
                                    readonly property bool chosen: launcher.layout === modelData.id
                                    readonly property color tone: Qt.color(theme.accent)
                                    Layout.fillWidth: true
                                    implicitHeight: 148
                                    radius: 9
                                    color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.14) : lhover.hovered ? theme.hover : theme.inset
                                    border.color: chosen ? theme.accent : theme.border
                                    border.width: chosen ? 2 : 1
                                    LayoutSketch {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 9
                                        height: 86
                                        def: ltile.modelData
                                        colors: page.current
                                    }
                                    ColumnLayout {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 9
                                        spacing: 1
                                        Label {
                                            Layout.fillWidth: true
                                            text: ltile.modelData.icon + "  " + ltile.modelData.name
                                            color: ltile.chosen ? theme.accent : theme.text
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            text: ltile.modelData.description || ""
                                            color: theme.textMuted
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }
                                    HoverHandler { id: lhover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: launcher.setLayout(ltile.modelData.id) }
                                }
                            }
                        }
                    }
                }

                // ---- Colours
                Card {
                    Layout.fillWidth: true
                    implicitHeight: schemeColumn.implicitHeight + 32
                    ColumnLayout {
                        id: schemeColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        RowLayout {
                            SectionLabel { text: "Colours" }
                            Item { Layout.fillWidth: true }
                            KeyCap { text: "C" }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: Math.max(2, Math.floor(width / 170))
                            rowSpacing: 10
                            columnSpacing: 10
                            Repeater {
                                model: launcher.schemes
                                delegate: Rectangle {
                                    id: stile
                                    required property var modelData
                                    readonly property var c: page.colorsOf(modelData.id)
                                    readonly property bool chosen: launcher.scheme === modelData.id
                                    Layout.fillWidth: true
                                    implicitHeight: 74
                                    radius: 9
                                    color: c.bg
                                    border.color: chosen ? theme.accent : shover.hovered ? c.sel : theme.border
                                    border.width: chosen ? 2 : 1
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Label { text: stile.modelData.name; color: stile.c.fg; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                                            Label { visible: stile.chosen; text: "✓"; color: stile.c.sel }
                                        }
                                        // A selected row, as the launcher draws it.
                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 16
                                            radius: 4
                                            color: stile.c.sel
                                            Row {
                                                anchors.right: parent.right
                                                anchors.rightMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 3
                                                Repeater {
                                                    model: [stile.c.alt, stile.c.active, stile.c.urgent, stile.c.fg]
                                                    Rectangle { required property var modelData; width: 8; height: 8; radius: 4; color: modelData; border.color: Qt.rgba(0, 0, 0, 0.3) }
                                                }
                                            }
                                        }
                                    }
                                    HoverHandler { id: shover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: launcher.setScheme(stile.modelData.id) }
                                }
                            }
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: theme.textFaint
                    font.pixelSize: 11
                    text: "Inside the launcher, Ctrl+L and Ctrl+T cycle layouts and colours (Shift goes back). "
                          + "From a terminal: omarchy-launcher-style layout|scheme|transition|speed|morph."
                }
            }
        }
    }

    // A screen with the launcher's card where the layout puts it.
    component LayoutSketch: Rectangle {
        id: sk
        property var def: ({})
        property var colors: ({})
        readonly property string base: def.base || def.id || "classic"
        radius: 6
        color: theme.sunken
        border.color: theme.hover
        clip: true

        readonly property var rect: {
            const w = width, h = height, g = 5;
            const d = sk.def;
            const right = d.side === "right";
            switch (base) {
            case "sidebar":
                if (d.floating)
                    return { x: right ? w - w * 0.3 - 8 : 8, y: h * 0.12, w: w * 0.3, h: h * 0.76 };
                return { x: right ? w - w * 0.32 - g : g, y: g, w: w * 0.32, h: h - 2 * g };
            case "spotlight": {
                const cw = w * Math.min(0.85, (d.width || 700) / 1100);
                const top = d.top === "center" ? (h - h * 0.4) / 2 : h * (Number(d.top) || 0.16);
                return { x: (w - cw) / 2, y: top, w: cw, h: h * 0.4 };
            }
            case "split":
                return { x: w * 0.12, y: h * 0.16, w: w * 0.76, h: h * 0.68 };
            case "launchpad":
                return { x: 0, y: 0, w: w, h: h };
            case "grid": {
                const cw = w * Math.min(0.9, (d.width || 860) / 1300);
                return { x: (w - cw) / 2, y: h * 0.14, w: cw, h: h * 0.72 };
            }
            case "dock":
                return { x: w * 0.2, y: d.edge === "top" ? 7 : h - h * 0.26 - 7, w: w * 0.6, h: h * 0.26 };
            case "topbar":
                return { x: g, y: d.edge === "bottom" ? h - 12 - g : g, w: w - 2 * g, h: 12 };
            }
            return { x: (w - w * 0.3) / 2, y: h * 0.18, w: w * 0.3, h: h * 0.64 };
        }

        Rectangle {
            x: sk.rect.x; y: sk.rect.y; width: sk.rect.w; height: sk.rect.h
            radius: sk.base === "launchpad" ? 0 : 4
            color: sk.base === "launchpad" ? Qt.rgba(Qt.color(sk.colors.bg).r, Qt.color(sk.colors.bg).g, Qt.color(sk.colors.bg).b, 0.75) : sk.colors.bg
            border.color: sk.colors.sel
            border.width: sk.base === "launchpad" ? 0 : 1

            // Rows for list layouts, dots for grids and docks.
            Column {
                visible: ["sidebar", "spotlight", "split", "classic"].indexOf(sk.base) >= 0
                x: 4; y: 4
                width: (sk.base === "split" ? parent.width * 0.5 : parent.width) - 8
                spacing: 2
                Repeater {
                    model: Math.max(1, Math.min(6, Math.floor((parent.parent.height - 8) / 7)))
                    Rectangle { required property int index; width: parent.width; height: 5; radius: 2; color: index === 0 ? sk.colors.sel : sk.colors.alt }
                }
            }
            Rectangle {
                visible: sk.base === "split"
                x: parent.width * 0.55; y: 4; width: parent.width * 0.45 - 4; height: parent.height - 8; radius: 3
                color: sk.colors.alt
            }
            Grid {
                visible: ["grid", "launchpad", "dock"].indexOf(sk.base) >= 0
                anchors.centerIn: parent
                columns: sk.base === "dock" ? 6 : (sk.base === "launchpad" ? 7 : 5)
                spacing: 4
                Repeater {
                    model: sk.base === "dock" ? 6 : (sk.base === "launchpad" ? 21 : 10)
                    Rectangle { required property int index; width: 7; height: 7; radius: 2; color: index === 0 ? sk.colors.sel : sk.colors.alt }
                }
            }
            Rectangle {
                visible: sk.base === "topbar"
                x: 3; y: 3; width: parent.width * 0.25; height: parent.height - 6; radius: 2
                color: sk.colors.sel
            }
        }
    }

    // A tiny launcher card replaying a transition's entrance, from the same
    // numbers the launcher uses (start scale, offset, angle, easing, time).
    component TransitionDemo: Rectangle {
        id: td
        property var def: ({})
        property var colors: ({})
        property string layoutBase: "classic"
        property real p: 1
        radius: 5
        color: theme.sunken
        border.color: theme.hover
        clip: true

        // "Layout's own" stands for the current layout's entrance.
        readonly property var eff: {
            if (def.id !== "auto")
                return def;
            switch (layoutBase) {
            case "sidebar": return { x: -0.3, ms: 190, ease: "OutCubic" };
            case "dock": return { y: 0.3, ms: 190, ease: "OutCubic" };
            case "topbar": return { y: -0.3, ms: 190, ease: "OutCubic" };
            case "classic": return { ms: 1, ease: "Linear" };
            }
            return { scale: 0.965, ms: 190, ease: "OutCubic" };
        }
        readonly property var easings: ({ OutCubic: Easing.OutCubic, OutBack: Easing.OutBack, OutBounce: Easing.OutBounce, Linear: Easing.Linear })

        function play() { anim.restart(); }

        NumberAnimation {
            id: anim
            target: td
            property: "p"
            from: 0
            to: 1
            duration: Math.max(1, (td.eff.ms || 200) / Math.max(0.25, launcher.speed)) * 1.6
            easing.type: td.easings[td.eff.ease] || Easing.OutCubic
        }

        Rectangle {
            id: mini
            readonly property real gap: 1 - td.p
            anchors.centerIn: parent
            width: parent.width * 0.42
            height: parent.height * 0.66
            radius: 4
            color: td.colors.bg || theme.inset
            border.color: td.colors.sel || theme.accent
            opacity: td.eff.ms === 1 ? 1 : Math.max(0, Math.min(1, td.p * 1.6))
            Column {
                x: 4; y: 4; width: parent.width - 8; spacing: 2
                Repeater {
                    model: 3
                    Rectangle { required property int index; width: parent.width; height: 5; radius: 2; color: index === 0 ? (td.colors.sel || theme.accent) : (td.colors.alt || "#222") }
                }
            }
            transform: [
                Translate {
                    x: mini.gap * (td.eff.x || 0) * (mini.width + 40)
                    y: mini.gap * (td.eff.y || 0) * (mini.height + 30)
                },
                Scale {
                    readonly property real from: td.eff.scale !== undefined ? td.eff.scale : 1
                    readonly property real fromY: td.eff.yScale !== undefined ? td.eff.yScale : from
                    origin.x: mini.width / 2
                    origin.y: mini.height / 2
                    xScale: from + (1 - from) * td.p
                    yScale: fromY + (1 - fromY) * td.p
                },
                Rotation {
                    readonly property string around: td.eff.axis || "z"
                    origin.x: mini.width / 2
                    origin.y: around === "x" ? 0 : mini.height / 2
                    axis { x: around === "x" ? 1 : 0; y: around === "y" ? 1 : 0; z: around === "z" ? 1 : 0 }
                    angle: (td.eff.angle || 0) * mini.gap
                }
            ]
        }
    }
}
