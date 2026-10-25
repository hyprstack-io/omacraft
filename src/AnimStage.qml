import QtQuick
import QtQuick.Shapes

// A preset played on a little desktop, from what it writes for Hyprland:
// a window opens (windowsIn), the workspace switches away and back
// (workspaces), and the window closes (windowsOut), each with the preset's
// duration, curve and style, at the chosen speed, inside the window border
// (spinning when it does).
Item {
    id: st

    property var motion: ({})
    property var curves: ({})
    property real speed: 1
    property bool animated: true
    property string windowStyle: "preset"
    property string workspaceStyle: "preset"
    property var borderColors: []
    property bool borderLoop: false
    property int borderSeconds: 6
    // Which parts play: the window opening and closing, the workspace switch.
    property bool windows: true
    property bool workspaces: true
    property bool playing: true
    property bool compact: false

    // Hyprland's own curves, and Omarchy's, for presets that name them.
    readonly property var builtins: ({
        "linear": { type: "bezier", points: [[0, 0], [1, 1]] },
        "default": { type: "bezier", points: [[0.05, 0.9], [0.1, 1.05]] },
        "almostLinear": { type: "bezier", points: [[0.5, 0.5], [0.75, 1]] },
        "easeOutQuint": { type: "bezier", points: [[0.23, 1], [0.32, 1]] },
        "easeInOutCubic": { type: "bezier", points: [[0.65, 0.05], [0.36, 1]] },
        "quick": { type: "bezier", points: [[0.15, 0], [0.1, 1]] }
    })

    // What one part of the preset does: on, how long, which curve, which style.
    function spec(name, fallback, override) {
        const m = motion || {};
        let v = m[name];
        if (v === undefined && fallback) v = m[fallback];
        if (v === undefined) v = m.global;
        if (!animated || v === false) return { on: false, ms: 0, curve: "linear", style: "" };
        if (!v || typeof v.length !== "number") return { on: true, ms: Math.round(400 / speed), curve: "default", style: override !== "preset" ? override : "" };
        return { on: true, ms: Math.max(30, Math.round(Number(v[0]) * 100 / Math.max(0.1, speed))), curve: String(v[1] || "default"),
                 style: override && override !== "preset" ? override : String(v[2] || "") };
    }
    function curve(name) { return curves[name] || builtins[name] || builtins["default"]; }
    function easingType(name) {
        const c = curve(name);
        return c.type === "spring" ? Easing.OutBack : Easing.BezierSpline;
    }
    function bezier(name) {
        const c = curve(name);
        const p = c.type === "bezier" && c.points ? c.points : [[0.25, 0.1], [0.25, 1]];
        return [p[0][0], p[0][1], p[1][0], p[1][1], 1, 1];
    }
    function overshoot(name) {
        const c = curve(name);
        return c.type === "spring" ? Math.max(0.4, Math.min(3, 26 / Math.max(4, Number(c.dampening) || 14))) : 1.70158;
    }

    readonly property var inSpec: spec("windowsIn", "windows", windowStyle)
    readonly property var outSpec: { const s = spec("windowsOut", "windows", windowStyle); if (s.style === "") s.style = inSpec.style; return s; }
    readonly property var fadeInSpec: spec("fadeIn", "fade", "preset")
    readonly property var fadeOutSpec: spec("fadeOut", "fade", "preset")
    readonly property var wsSpec: spec("workspaces", "", workspaceStyle)
    readonly property real gap: compact ? 5 : 10

    onMotionChanged: if (loop.running) loop.restart()
    onWindowStyleChanged: if (loop.running) loop.restart()
    onWorkspaceStyleChanged: if (loop.running) loop.restart()

    // Where the opening window is: t 0 gone → 1 there; f its opacity.
    property real t: 1
    property real f: 1
    property string bStyle: inSpec.style
    // Which workspace: 0 the first, 1 the second.
    property real w: 0

    function percent(style, fallback) {
        const m = /(\d+)%/.exec(style);
        return m ? Number(m[1]) / 100 : fallback;
    }

    SequentialAnimation {
        id: loop
        running: st.playing && st.visible && st.width > 0
        loops: Animation.Infinite
        onRunningChanged: if (!running) { st.t = 1; st.f = 1; st.w = 0; }
        ScriptAction { script: { st.t = st.windows ? 0 : 1; st.f = st.windows ? 0 : 1; st.w = 0; st.bStyle = st.inSpec.style; } }
        PauseAnimation { duration: st.compact ? 250 : 450 }
        ParallelAnimation {
            NumberAnimation {
                target: st; property: "t"; from: st.windows ? 0 : 1; to: 1; duration: st.windows ? st.inSpec.ms : 0
                easing.type: st.easingType(st.inSpec.curve); easing.bezierCurve: st.bezier(st.inSpec.curve); easing.overshoot: st.overshoot(st.inSpec.curve)
            }
            NumberAnimation {
                target: st; property: "f"; from: st.windows ? 0 : 1; to: 1; duration: st.windows ? Math.max(st.fadeInSpec.ms, 1) : 0
                easing.type: st.easingType(st.fadeInSpec.curve); easing.bezierCurve: st.bezier(st.fadeInSpec.curve)
            }
        }
        PauseAnimation { duration: st.compact ? 700 : 1000 }
        NumberAnimation {
            target: st; property: "w"; from: 0; to: st.workspaces ? 1 : 0; duration: st.workspaces ? st.wsSpec.ms : 0
            easing.type: st.easingType(st.wsSpec.curve); easing.bezierCurve: st.bezier(st.wsSpec.curve); easing.overshoot: st.overshoot(st.wsSpec.curve)
        }
        PauseAnimation { duration: st.workspaces ? 900 : 0 }
        NumberAnimation {
            target: st; property: "w"; from: st.workspaces ? 1 : 0; to: 0; duration: st.workspaces ? st.wsSpec.ms : 0
            easing.type: st.easingType(st.wsSpec.curve); easing.bezierCurve: st.bezier(st.wsSpec.curve); easing.overshoot: st.overshoot(st.wsSpec.curve)
        }
        PauseAnimation { duration: st.workspaces ? 600 : 0 }
        ScriptAction { script: st.bStyle = st.outSpec.style }
        ParallelAnimation {
            NumberAnimation {
                target: st; property: "t"; from: 1; to: st.windows ? 0 : 1; duration: st.windows ? st.outSpec.ms : 0
                easing.type: st.easingType(st.outSpec.curve); easing.bezierCurve: st.bezier(st.outSpec.curve); easing.overshoot: st.overshoot(st.outSpec.curve)
            }
            NumberAnimation {
                target: st; property: "f"; from: 1; to: st.windows ? 0 : 1; duration: st.windows ? Math.max(st.fadeOutSpec.ms, 1) : 0
                easing.type: st.easingType(st.fadeOutSpec.curve); easing.bezierCurve: st.bezier(st.fadeOutSpec.curve)
            }
        }
        PauseAnimation { duration: st.windows ? (st.compact ? 500 : 800) : 0 }
    }

    // One window: a title strip, a few lines, and its border.
    component Win: Item {
        id: win
        property bool focused: false
        property color body: Qt.rgba(0.08, 0.09, 0.12, 0.88)
        Rectangle {
            id: frame
            anchors.fill: parent
            radius: st.compact ? 5 : 8
            color: "transparent"
            border.width: win.focused ? 0 : 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            clip: true
            // The border: the colour run, turning when the border spins.
            Shape {
                visible: win.focused
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillGradient: ConicalGradient {
                        centerX: frame.width / 2
                        centerY: frame.height / 2
                        angle: spin.angle
                        GradientStop { position: 0; color: st.borderStop(0) }
                        GradientStop { position: 0.33; color: st.borderStop(1) }
                        GradientStop { position: 0.66; color: st.borderStop(2) }
                        GradientStop { position: 1; color: st.borderStop(0) }
                    }
                    PathRectangle { width: frame.width; height: frame.height; radius: frame.radius }
                }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: win.focused ? (st.compact ? 1.5 : 2) : 0
                radius: frame.radius - 1
                color: win.body
                Column {
                    x: st.compact ? 6 : 10
                    y: st.compact ? 5 : 9
                    spacing: st.compact ? 3 : 6
                    Row {
                        spacing: 3
                        Repeater { model: 3; Rectangle { width: st.compact ? 3 : 5; height: width; radius: width / 2; color: Qt.rgba(1, 1, 1, 0.25) } }
                    }
                    Repeater {
                        model: st.compact ? 2 : 4
                        Rectangle {
                            required property int index
                            width: (win.width - (st.compact ? 14 : 24)) * [0.8, 0.55, 0.7, 0.4][index]
                            height: st.compact ? 3 : 5
                            radius: 2
                            color: Qt.rgba(1, 1, 1, index === 0 ? 0.22 : 0.12)
                        }
                    }
                }
            }
        }
    }

    function borderStop(i) {
        const list = borderColors || [];
        if (list.length === 0) return i === 1 ? Qt.lighter(theme.accent, 1.3) : theme.accent;
        return list[Math.min(list.length - 1, Math.floor(i * (list.length - 1) / 2))];
    }
    QtObject {
        id: spin
        property real angle: 0
    }
    NumberAnimation {
        target: spin; property: "angle"; from: 0; to: 360
        duration: Math.max(1, st.borderSeconds) * 1000
        loops: Animation.Infinite
        running: st.borderLoop && st.playing && st.visible && (st.borderColors || []).length > 0
    }

    // --- the two workspaces ---
    Item {
        id: viewport
        anchors.fill: parent
        clip: true
        // Drawn into its own layer, so a window sliding or springing past the
        // edge is cut off there whatever the renderer does with clipping.
        layer.enabled: true
        readonly property string ws: st.wsSpec.style || "slide"
        readonly property bool vertical: ws.indexOf("vert") >= 0
        readonly property bool fades: ws.indexOf("fade") >= 0
        readonly property bool slides: ws.indexOf("slide") >= 0
        readonly property real reach: (vertical ? height : width) * (fades && slides ? st.percent(ws, 0.2) : 1)

        // The first: an open window, and the one that comes and goes.
        Item {
            width: viewport.width
            height: viewport.height
            x: viewport.slides && !viewport.vertical ? -st.w * viewport.reach : 0
            y: viewport.slides && viewport.vertical ? -st.w * viewport.reach : 0
            opacity: viewport.fades || !viewport.slides ? 1 - st.w : 1
            Win {
                x: st.gap
                y: st.gap
                width: (parent.width - 3 * st.gap) / 2
                height: parent.height - 2 * st.gap
            }
            Win {
                id: winB
                focused: true
                readonly property real baseX: (parent.width + st.gap) / 2
                readonly property real baseW: (parent.width - 3 * st.gap) / 2
                readonly property string style: st.bStyle
                readonly property bool popin: style.indexOf("popin") === 0
                readonly property bool gnomed: style === "gnomed"
                readonly property bool slide: style.indexOf("slide") === 0
                readonly property string dir: slide ? (style.split(" ")[1] || "right") : ""
                width: baseW
                height: parent.height - 2 * st.gap
                x: baseX + (dir === "right" ? (1 - st.t) * (parent.width - baseX) : dir === "left" ? -(1 - st.t) * (baseX + baseW) : 0)
                y: st.gap + (dir === "bottom" ? (1 - st.t) * parent.height : dir === "top" ? -(1 - st.t) * parent.height : 0)
                // Every opening window fades in too (fadeIn), whatever its style.
                opacity: st.windows ? st.f : 1
                transform: Scale {
                    origin.x: winB.width / 2
                    origin.y: winB.gnomed ? winB.height : winB.height / 2
                    xScale: winB.popin ? st.percent(winB.style, 0.85) + (1 - st.percent(winB.style, 0.85)) * st.t : winB.gnomed ? 0.3 + 0.7 * st.t : 1
                    yScale: winB.popin ? st.percent(winB.style, 0.85) + (1 - st.percent(winB.style, 0.85)) * st.t : winB.gnomed ? Math.max(0.01, st.t) : 1
                }
            }
        }
        // The second: one wide window.
        Item {
            width: viewport.width
            height: viewport.height
            x: viewport.slides && !viewport.vertical ? (1 - st.w) * viewport.reach : 0
            y: viewport.slides && viewport.vertical ? (1 - st.w) * viewport.reach : 0
            opacity: viewport.fades || !viewport.slides ? st.w : (st.w > 0 ? 1 : 0)
            Win {
                x: st.gap * 3
                y: st.gap
                width: parent.width - 6 * st.gap
                height: parent.height - 2 * st.gap
                body: Qt.rgba(0.1, 0.08, 0.14, 0.9)
            }
        }
    }
}
