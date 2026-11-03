import QtQuick
import QtQuick.Controls
import QtQuick.Window

// Cursors & Icons' stage: a strip of desktop with a file manager in the icon
// theme and a cursor at its real size, gliding over it. It points, hovers a
// folder (hand), types in a field (text), presses Apply (progress), grabs the
// title bar (move) and the corner (resize), so each shape is seen in use.
// A new icon theme washes over the folders; a new cursor pops in with a ring.
Stage {
    id: stage

    property string iconTheme
    property string cursorTheme
    property int cursorSize: 24
    property bool playing: true

    windows: false
    caption: (previewing ? "Previewing  " : "In use  ") + iconTheme + "  ·  " + cursorTheme + "  " + cursorSize + "px"

    readonly property var icons: iconTheme === "" ? [] : cursorIcons.iconSamples(iconTheme)
    readonly property var cursors: {
        const out = {};
        const list = cursorTheme === "" ? [] : cursorIcons.cursorSamples(cursorTheme, Math.round(cursorSize * Screen.devicePixelRatio));
        for (const sample of list) out[sample.role] = sample;
        return out;
    }
    readonly property color ink: tc.foreground || "#c0caf5"
    // What a file manager would call each one.
    readonly property var names: ({
        "folder": "Projects", "folder-download": "Downloads", "folder-pictures": "Pictures",
        "text-x-generic": "notes.txt", "image-x-generic": "wall.png", "audio-x-generic": "song.flac",
        "utilities-terminal": "Terminal", "web-browser": "Browser", "preferences-system": "Settings",
        "accessories-text-editor": "Editor", "user-home": "Home", "user-trash": "Trash"
    })
    readonly property color paneColor: Qt.darker(backColor, 1.08)

    // --- the icons wash in when the theme changes ---
    property int wave: 0
    onIconThemeChanged: wave++
    onCursorThemeChanged: { pop.restart(); ripple.burst(); }
    onCursorSizeChanged: pop.restart()

    // A window with the house's gradient edge.
    component Pane: Rectangle {
        id: pane
        property string title
        default property alias body: paneBody.data
        radius: 10
        color: stage.paneColor
        // The gradient edge: a gradient a little bigger, under the pane.
        Rectangle {
            z: -1
            anchors.fill: parent
            anchors.margins: -2
            radius: parent.radius + 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: stage.accentColor }
                GradientStop { position: 1; color: stage.glowColor }
            }
            opacity: 0.85
        }
        Item {
            id: titleBar
            objectName: "titleBar"
            width: parent.width; height: 26
            Row {
                x: 10; anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Repeater {
                    model: 3
                    Rectangle { width: 7; height: 7; radius: 4; color: Qt.rgba(stage.ink.r, stage.ink.g, stage.ink.b, 0.25 + index * 0.12) }
                }
            }
            Text {
                anchors.centerIn: parent
                text: pane.title
                color: Qt.rgba(stage.ink.r, stage.ink.g, stage.ink.b, 0.7)
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
            }
        }
        Item { id: paneBody; anchors.fill: parent; anchors.topMargin: 26 }
        property alias bar: titleBar
    }

    // --- the file manager ---
    Pane {
        id: files
        title: "Files — ~/Projects"
        x: 22
        y: 16
        width: Math.min(stage.width * 0.52, 560)
        height: stage.height - 46

        Row {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 10

            // Sidebar: the places, in the theme's small icons.
            Column {
                width: 112
                spacing: 4
                Repeater {
                    model: [{ role: "user-home", name: "Home" }, { role: "folder-download", name: "Downloads" },
                            { role: "folder-pictures", name: "Pictures" }, { role: "user-trash", name: "Trash" }]
                    Rectangle {
                        required property var modelData
                        required property int index
                        width: 112; height: 22; radius: 5
                        color: index === 0 ? Qt.rgba(stage.accentColor.r, stage.accentColor.g, stage.accentColor.b, 0.18) : "transparent"
                        Row {
                            x: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Image {
                                width: 16; height: 16
                                sourceSize: Qt.size(32, 32)
                                source: (stage.icons.find(s => s.role === modelData.role) || {}).source || ""
                                asynchronous: true
                            }
                            Text { text: modelData.name; color: stage.ink; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            // The grid of files and folders, in the big icons.
            Grid {
                id: grid
                columns: Math.max(3, Math.floor((files.width - 140) / 68))
                spacing: 6
                Repeater {
                    id: iconRepeater
                    model: stage.icons.filter(s => s.role !== "user-home" && s.role !== "user-trash").slice(0, grid.columns * 2)
                    Item {
                        id: iconCell
                        required property var modelData
                        required property int index
                        readonly property bool hot: stage.hot === iconCell
                        width: 62; height: 62
                        Rectangle {
                            anchors.fill: parent
                            radius: 7
                            color: iconCell.hot ? Qt.rgba(stage.accentColor.r, stage.accentColor.g, stage.accentColor.b, 0.22) : "transparent"
                            border.color: iconCell.hot ? Qt.rgba(stage.accentColor.r, stage.accentColor.g, stage.accentColor.b, 0.6) : "transparent"
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                        Image {
                            id: iconImage
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 4
                            width: 36; height: 36
                            sourceSize: Qt.size(72, 72)
                            source: iconCell.modelData.source
                            asynchronous: true
                            scale: iconCell.hot ? 1.14 : 1
                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                            // The wash: each icon drops in a beat after the one before.
                            SequentialAnimation {
                                id: washIn
                                PropertyAction { target: iconImage; property: "opacity"; value: 0 }
                                PauseAnimation { duration: iconCell.index * 45 }
                                ParallelAnimation {
                                    NumberAnimation { target: iconImage; property: "opacity"; to: 1; duration: 260 }
                                    NumberAnimation { target: iconImage; property: "y"; from: -10; to: 4; duration: 420; easing.type: Easing.OutBack }
                                    RotationAnimation { target: iconImage; from: -12; to: 0; duration: 420; easing.type: Easing.OutBack }
                                }
                            }
                            Connections {
                                target: stage
                                function onWaveChanged() { washIn.restart(); }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            width: parent.width - 4
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: stage.names[iconCell.modelData.role] || iconCell.modelData.role
                            color: Qt.rgba(stage.ink.r, stage.ink.g, stage.ink.b, 0.75)
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: stage.icons.length === 0
            text: "No icons to show"
            color: Qt.rgba(stage.ink.r, stage.ink.g, stage.ink.b, 0.5)
        }
    }

    // --- a settings window: a field, a button, a corner to drag ---
    Pane {
        id: settings
        title: "Settings"
        x: files.x + files.width + 26
        y: 30
        width: Math.max(180, Math.min(stage.width - x - 24, 300)) + stretch
        height: 138
        property real stretch: 0

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10
            Rectangle {
                id: field
                width: parent.width; height: 26; radius: 5
                color: Qt.rgba(stage.ink.r, stage.ink.g, stage.ink.b, 0.08)
                border.color: stage.hot === field ? stage.accentColor : Qt.rgba(stage.ink.r, stage.ink.g, stage.ink.b, 0.2)
                Text {
                    id: typed
                    x: 8; anchors.verticalCenter: parent.verticalCenter
                    text: "omacraft".substring(0, stage.typedLength)
                    color: stage.ink
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }
                Rectangle {
                    x: typed.x + typed.implicitWidth + 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1.5; height: 14
                    color: stage.accentColor
                    visible: stage.hot === field
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: stage.hot === field
                        NumberAnimation { to: 0; duration: 380 }
                        NumberAnimation { to: 1; duration: 380 }
                    }
                }
            }
            Rectangle {
                id: applyButton
                width: 96; height: 26; radius: 6
                color: stage.hot === applyButton ? Qt.lighter(stage.accentColor, 1.15) : stage.accentColor
                Text { anchors.centerIn: parent; text: "Apply"; color: stage.backColor; font.pixelSize: 11; font.weight: Font.DemiBold }
                scale: stage.pressed && stage.hot === applyButton ? 0.94 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
            }
            Rectangle {
                width: parent.width; height: 4; radius: 2
                color: Qt.rgba(stage.ink.r, stage.ink.g, stage.ink.b, 0.12)
                Rectangle {
                    width: parent.width * stage.progress
                    height: parent.height; radius: 2
                    color: stage.accentColor
                }
            }
        }
        // The grip the resize cursor takes hold of.
        Item { id: grip; anchors.right: parent.right; anchors.bottom: parent.bottom; width: 14; height: 14 }
    }

    // --- the tour ---
    property Item hot: null
    property bool pressed: false
    property int typedLength: 0
    property real progress: 0
    property string role: "pointer"
    property int step: -1

    // Where the cursor goes, what it becomes, and for how long.
    readonly property var tour: [
        { at: () => files, dx: 0.5, dy: 0.62, role: "pointer", dwell: 700 },
        { at: () => iconRepeater.itemAt(1), dx: 0.5, dy: 0.45, role: "hand", dwell: 1100 },
        { at: () => iconRepeater.itemAt(4), dx: 0.5, dy: 0.45, role: "hand", dwell: 900 },
        { at: () => field, dx: 0.4, dy: 0.5, role: "text", dwell: 1500, typing: true },
        { at: () => applyButton, dx: 0.5, dy: 0.55, role: "hand", dwell: 300, press: true },
        { at: () => applyButton, dx: 0.5, dy: 0.55, role: "progress", dwell: 1700, working: true },
        { at: () => files.bar, dx: 0.62, dy: 0.5, role: "move", dwell: 1100, drift: true },
        { at: () => grip, dx: 0.5, dy: 0.5, role: "resize", dwell: 1200, stretch: true },
        { at: () => settings, dx: 0.35, dy: 0.8, role: "wait", dwell: 1500 },
        { at: () => files, dx: 0.82, dy: 0.86, role: "help", dwell: 900 }
    ]

    function next() {
        step = (step + 1) % tour.length;
        const stop = tour[step];
        const target = stop.at();
        if (!target) { next(); return; }
        const point = target.mapToItem(stage, target.width * stop.dx, target.height * stop.dy);
        hot = null;
        glideX.to = point.x;
        glideY.to = point.y;
        glide.restart();
    }
    function arrive() {
        const stop = tour[step];
        const target = stop.at();
        role = cursors[stop.role] ? stop.role : "pointer";
        hot = (stop.role === "hand" || stop.typing || stop.press || stop.working) ? target : null;
        if (stop.press) { pressed = true; ripple.burst(); }
        if (stop.typing) { typedLength = 0; typing.restart(); }
        if (stop.working) { progress = 0; working.restart(); }
        if (stop.drift) drift.restart();
        if (stop.stretch) stretchAnim.restart();
        dwell.interval = stop.dwell;
        dwell.restart();
    }

    Timer {
        id: dwell
        onTriggered: { stage.pressed = false; if (stage.playing) stage.next(); }
    }
    ParallelAnimation {
        id: glide
        NumberAnimation { id: glideX; target: pointer; property: "px"; duration: 620; easing.type: Easing.InOutCubic }
        NumberAnimation { id: glideY; target: pointer; property: "py"; duration: 620; easing.type: Easing.InOutQuad }
        onFinished: stage.arrive()
    }
    NumberAnimation { id: typing; target: stage; property: "typedLength"; from: 0; to: 8; duration: 1100 }
    NumberAnimation { id: working; target: stage; property: "progress"; from: 0; to: 1; duration: 1600; easing.type: Easing.InOutSine }
    SequentialAnimation {
        id: drift
        NumberAnimation { target: files; property: "x"; to: 34; duration: 500; easing.type: Easing.InOutSine }
        NumberAnimation { target: files; property: "x"; to: 22; duration: 500; easing.type: Easing.InOutSine }
    }
    SequentialAnimation {
        id: stretchAnim
        NumberAnimation { target: settings; property: "stretch"; to: 22; duration: 550; easing.type: Easing.InOutSine }
        NumberAnimation { target: settings; property: "stretch"; to: 0; duration: 550; easing.type: Easing.InOutSine }
    }

    // While the page is out of sight the tour waits where it is.
    onPlayingChanged: if (playing && !dwell.running && !glide.running) next()
    Component.onCompleted: {
        pointer.px = stage.width * 0.5;
        pointer.py = stage.height * 0.5;
        if (playing) Qt.callLater(next);
    }

    // --- the cursor itself, at the size it'll be on screen ---
    Item {
        id: pointer
        property real px: 0
        property real py: 0
        z: 20
        width: stage.cursorSize
        height: stage.cursorSize
        // Arrows point from their corner; the rest are held by the middle.
        readonly property bool corner: stage.role === "pointer" || stage.role === "hand" || stage.role === "help" || stage.role === "progress"
        x: px - (corner ? width * 0.12 : width / 2)
        y: py - (corner ? height * 0.06 : height / 2)

        CursorSprite {
            id: sprite
            anchors.fill: parent
            sample: stage.cursors[stage.role] || stage.cursors.pointer || null
            playing: stage.playing
            transformOrigin: Item.TopLeft
            SequentialAnimation {
                id: pop
                NumberAnimation { target: sprite; property: "scale"; from: 0.35; to: 1; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            }
        }
        // No pictures (a theme that isn't readable): a plain arrow stands in.
        Text {
            visible: !sprite.sample
            text: "\u{f01bf}"
            color: stage.ink
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: stage.cursorSize
        }
    }

    // A ring that spreads from the cursor on a click and on a new cursor.
    Rectangle {
        id: ripple
        z: 19
        property real size: 0
        function burst() {
            x = Qt.binding(() => pointer.px - size / 2);
            y = Qt.binding(() => pointer.py - size / 2);
            spread.restart();
        }
        width: size; height: size; radius: size / 2
        color: "transparent"
        border.width: 2
        border.color: stage.accentColor
        opacity: 0
        ParallelAnimation {
            id: spread
            NumberAnimation { target: ripple; property: "size"; from: 4; to: 64; duration: 520; easing.type: Easing.OutCubic }
            NumberAnimation { target: ripple; property: "opacity"; from: 0.9; to: 0; duration: 520; easing.type: Easing.InQuad }
        }
    }
}
