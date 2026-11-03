import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "LockDefaults.js" as Defaults

// A monitor showing the real scene at full size, scaled down, so what's here is
// what locks. The block drags around it and snaps to the nine points; states and
// transitions play on it without touching the live lock.
Item {
    id: stage

    property var settings: Defaults.clean({})
    property string target: "lock"
    property string pictureFile: ""
    property string mode: "idle"            // idle, typing or wrong
    property alias leaving: scene.leaving

    signal movedBlock(real x, real y)

    readonly property real screenWidth: Math.max(1, width - 16)
    readonly property real screenHeight: screenWidth * 9 / 16
    readonly property real zoom: Math.min(screenWidth, (height - 16) * 16 / 9) / 1920
    readonly property var snaps: [15, 50, 85]

    function play() {
        if (settings.lockIn === "none" && settings.unlockOut === "none") {
            flash.restart();
            return;
        }
        reel.restart();
    }
    function snapped(value) {
        for (const point of snaps)
            if (Math.abs(value - point) < 3) return point;
        return value;
    }

    // The monitor: the accent's gradient around it, as the desktop's windows have.
    Rectangle {
        id: monitor
        anchors.centerIn: parent
        width: 1920 * stage.zoom + 8
        height: 1080 * stage.zoom + 8
        radius: 8
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: theme.accent }
            GradientStop { position: 1; color: Qt.darker(theme.accent, 1.8) }
        }

        Item {
            anchors.fill: parent
            anchors.margins: 4
            clip: true

            LockScene {
                id: scene
                objectName: "lockStageScene"
                width: 1920
                height: 1080
                scale: stage.zoom
                transformOrigin: Item.TopLeft
                settings: {
                    if (!grip.pressed) return stage.settings;
                    const moved = Object.assign({}, stage.settings);
                    moved.blockX = grip.dragX;
                    moved.blockY = grip.dragY;
                    return moved;
                }
                theme: lockLogon.themeColors
                backgroundFile: stage.pictureFile
                userName: "skll"
                hostName: "omarchy"
                inputEnabled: false
                pictureScale: Math.max(0.35, stage.zoom)
                failureMessage: stage.mode === "wrong" ? "Wrong password" : ""
                passwordText: stage.mode === "typing" ? "omacraft" : ""
            }

            // Thirds lines while dragging, to aim for.
            Repeater {
                model: grip.pressed ? stage.snaps : []
                delegate: Item {
                    required property var modelData
                    anchors.fill: parent
                    Rectangle { x: parent.width * modelData / 100; width: 1; height: parent.height; color: theme.accent; opacity: grip.dragX === modelData ? 0.9 : 0.25 }
                    Rectangle { y: parent.height * modelData / 100; height: 1; width: parent.width; color: theme.accent; opacity: grip.dragY === modelData ? 0.9 : 0.25 }
                }
            }

            MouseArea {
                id: grip
                objectName: "lockStageGrip"
                anchors.fill: parent
                property real dragX: stage.settings.blockX
                property real dragY: stage.settings.blockY
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                function follow(mouse) {
                    dragX = stage.snapped(Math.round(Math.max(0, Math.min(100, mouse.x / width * 100))));
                    dragY = stage.snapped(Math.round(Math.max(0, Math.min(100, mouse.y / height * 100))));
                }
                onPressed: mouse => follow(mouse)
                onPositionChanged: mouse => { if (pressed) follow(mouse); }
                onReleased: stage.movedBlock(dragX, dragY)
            }

            Rectangle {
                id: flashFrame
                anchors.fill: parent
                color: "transparent"
                border.color: theme.accent
                border.width: 2
                opacity: 0
                NumberAnimation on opacity { id: flash; running: false; from: 1; to: 0; duration: 500 }
            }
        }
    }

    // In, a beat on the screen, out, and back: the whole life of the lock.
    SequentialAnimation {
        id: reel
        ScriptAction { script: { scene.leaving = false; scene.replayIn(); } }
        PauseAnimation { duration: stage.settings.lockInMs + 700 }
        ScriptAction { script: scene.leaving = true }
        PauseAnimation { duration: stage.settings.unlockMs + 500 }
        ScriptAction { script: scene.leaving = false }
    }
}
