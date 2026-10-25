import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Everything for the keyboard lights: the live keyboard, the designs,
// animations and paint canvas, the colours (or the theme's), and the
// lighting service that puts it on the keys. AlienFlare's window and
// OmaCraft's Alienflare page both show this, so they work the same way.
Item {
    id: view

    // Whether this is on screen; the preview only animates while it is.
    property bool active: true
    // Whether single-key shortcuts may fire (no field has the keyboard).
    property bool keysFree: true

    readonly property bool keys: active && keysFree
    readonly property var shortcuts: [
        { keys: "Space", action: "Turn the lights on or off" },
        { keys: "D / A / P", action: "Designs, animations, or paint key by key" },
        { keys: "← / →", action: "Previous / next design or animation" },
        { keys: "T", action: "Light the keys in the wallpaper's colours" },
        { keys: "[ / ]", action: "Slower / faster animation" },
        { keys: "- / =", action: "Dimmer / brighter" },
        { keys: "F / C", action: "Paint: fill every key / clear the canvas" },
        { keys: "B", action: "Copy what's showing onto the canvas" },
        { keys: "Right-click", action: "Paint: erase a key" },
        { keys: "Ctrl Z", action: "Undo (Ctrl Shift Z redo)" }
    ]

    function handleEscape() {
        if (lights.error !== "" || lights.notice !== "") {
            lights.dismissMessages();
            return true;
        }
        return false;
    }

    onActiveChanged: lights.previewing = active
    Component.onCompleted: lights.previewing = active

    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; enabled: view.keys; onActivated: lights.toggle() }
    Shortcut { sequence: "D"; context: Qt.ApplicationShortcut; enabled: view.keys; onActivated: lights.setMode("pattern") }
    Shortcut { sequence: "A"; context: Qt.ApplicationShortcut; enabled: view.keys; onActivated: lights.setMode("animation") }
    Shortcut { sequence: "P"; context: Qt.ApplicationShortcut; enabled: view.keys; onActivated: lights.setMode("paint") }
    Shortcut { sequence: "Left"; context: Qt.ApplicationShortcut; enabled: view.keys && lights.mode !== "paint"; onActivated: lights.step(-1) }
    Shortcut { sequence: "Right"; context: Qt.ApplicationShortcut; enabled: view.keys && lights.mode !== "paint"; onActivated: lights.step(1) }
    Shortcut { sequence: "T"; context: Qt.ApplicationShortcut; enabled: view.keys; onActivated: lights.setFollowTheme(!lights.followTheme) }
    Shortcut { sequence: "["; context: Qt.ApplicationShortcut; enabled: view.keys; onActivated: lights.setSpeed(lights.speed - 0.25) }
    Shortcut { sequence: "]"; context: Qt.ApplicationShortcut; enabled: view.keys; onActivated: lights.setSpeed(lights.speed + 0.25) }
    Shortcut { sequence: "-"; context: Qt.ApplicationShortcut; enabled: view.keys; onActivated: lights.setBrightness(lights.brightness - 10) }
    Shortcut { sequences: ["=", "+"]; context: Qt.ApplicationShortcut; enabled: view.keys; onActivated: lights.setBrightness(lights.brightness + 10) }
    Shortcut { sequence: "F"; context: Qt.ApplicationShortcut; enabled: view.keys && lights.mode === "paint"; onActivated: lights.fillAll() }
    Shortcut { sequence: "C"; context: Qt.ApplicationShortcut; enabled: view.keys && lights.mode === "paint"; onActivated: lights.clearPaint() }
    Shortcut { sequence: "B"; context: Qt.ApplicationShortcut; enabled: view.keys; onActivated: lights.bakeToPaint() }
    Shortcut { sequence: "Ctrl+Z"; context: Qt.ApplicationShortcut; enabled: view.active; onActivated: lights.undo() }
    Shortcut { sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]; context: Qt.ApplicationShortcut; enabled: view.active; onActivated: lights.redo() }

    readonly property var quickColors: ["#ff1e1e", "#ff7a00", "#ffd60a", "#38ff6a", "#00e5ff", "#0050ff", "#7a00ff", "#ff2bd6", "#ffffff"]

    RowLayout {
        anchors.fill: parent
        spacing: 16

        // --- the keyboard and what it shows ---
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            MessageBar {
                error: lights.error
                notice: lights.notice
                onDismissed: lights.dismissMessages()
            }

            // The lighting service: nothing reaches the keys without it.
            Rectangle {
                Layout.fillWidth: true
                visible: !lights.driverRunning || lights.driverError !== "" || lights.alienfxThemeSync
                implicitHeight: serviceColumn.implicitHeight + 18
                radius: 8
                color: !lights.driverRunning || lights.driverError !== "" ? theme.dangerFill : theme.warningFill
                border.color: !lights.driverRunning || lights.driverError !== "" ? theme.dangerBorder : theme.warningBorder

                ColumnLayout {
                    id: serviceColumn
                    anchors.fill: parent
                    anchors.margins: 9
                    anchors.leftMargin: 14
                    spacing: 6

                    RowLayout {
                        visible: !lights.driverRunning
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: theme.dangerText
                            text: "The lighting service isn't running, so the keyboard won't change. It is what paints the keys, runs the animations and follows the theme, even with this window closed."
                        }
                        Button {
                            text: lights.driverBusy ? "Starting…" : "Start the service"
                            enabled: !lights.driverBusy
                            highlighted: true
                            focusPolicy: Qt.NoFocus
                            onClicked: lights.startDriver()
                        }
                    }
                    Label {
                        visible: lights.driverRunning && lights.driverError !== ""
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: theme.dangerText
                        text: lights.driverError
                    }
                    RowLayout {
                        visible: lights.alienfxThemeSync
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: theme.warningText
                            text: "The AlienFX plugin's ThemeSync is on, so it repaints the keyboard after every theme switch too. AlienFlare paints over it a moment later; turning it off stops the flicker."
                        }
                        Button {
                            text: "Turn off AlienFX ThemeSync"
                            flat: true
                            focusPolicy: Qt.NoFocus
                            onClicked: lights.disableAlienfxThemeSync()
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(width * 6 / 15 + 32, view.height * 0.48)

                KeyboardView {
                    anchors.fill: parent
                    anchors.margins: 16
                    interactive: lights.mode === "paint"
                    opacity: lights.on ? 1 : 0.5
                }
                Label {
                    visible: !lights.on
                    anchors.centerIn: parent
                    text: "Lights off  ·  Space turns them on"
                    color: theme.text
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    style: Text.Outline
                    styleColor: theme.window
                }
            }

            // What fills the keys.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Chip { text: "Designs"; chosen: lights.mode === "pattern"; onClicked: lights.setMode("pattern") }
                KeyCap { text: "D" }
                Chip { text: "Animations"; chosen: lights.mode === "animation"; onClicked: lights.setMode("animation") }
                KeyCap { text: "A" }
                Chip { text: "Paint"; chosen: lights.mode === "paint"; onClicked: lights.setMode("paint") }
                KeyCap { text: "P" }
                Item { Layout.fillWidth: true }
                Label {
                    visible: lights.mode !== "paint"
                    text: "← → to step through"
                    color: theme.textFaint
                    font.pixelSize: 11
                }
            }

            // Designs and animations, as tiles.
            ScrollView {
                id: tiles
                visible: lights.mode !== "paint"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth

                GridLayout {
                    width: tiles.availableWidth
                    columns: Math.max(2, Math.floor(tiles.availableWidth / 190))
                    columnSpacing: 10
                    rowSpacing: 10

                    Repeater {
                        model: lights.mode === "animation" ? lights.animations : lights.patterns
                        delegate: PresetTile {
                            required property var modelData
                            Layout.fillWidth: true
                            mode: lights.mode
                            preset: modelData
                            chosen: (lights.mode === "animation" ? lights.animation : lights.pattern) === modelData.id
                            onPicked: lights.mode === "animation" ? lights.chooseAnimation(modelData.id) : lights.choosePattern(modelData.id)
                        }
                    }
                }
            }

            // The paint tools.
            Card {
                visible: lights.mode === "paint"
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    SectionLabel { text: "Brush" }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: theme.textDim
                        font.pixelSize: 12
                        text: "Click or drag over keys to paint them; right-click to erase. The four colour slots follow the wallpaper when theme colours are chosen, so keys painted with them change with the wallpaper. A colour of its own stays put."
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: 4
                            delegate: Rectangle {
                                id: slotBrush
                                required property int index
                                readonly property string value: "@" + index
                                readonly property bool chosen: lights.brush === value
                                width: slotRow.implicitWidth + 20
                                height: 34
                                radius: 8
                                color: chosen ? theme.hover : theme.inset
                                border.color: chosen ? theme.accent : theme.border
                                border.width: chosen ? 2 : 1
                                Row {
                                    id: slotRow
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Rectangle {
                                        width: 18; height: 18; radius: 5
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: lights.colors[slotBrush.index] || "#000000"
                                        border.color: theme.borderStrong
                                    }
                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: lights.slotNames[slotBrush.index]
                                        color: theme.textSoft
                                        font.pixelSize: 12
                                    }
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: lights.setBrush(slotBrush.value) }
                            }
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: view.quickColors
                            delegate: Rectangle {
                                required property string modelData
                                width: 30; height: 30; radius: 7
                                color: modelData
                                border.color: lights.brush === modelData ? theme.text : theme.border
                                border.width: lights.brush === modelData ? 2 : 1
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: lights.setBrush(parent.modelData) }
                            }
                        }
                        ColorButton {
                            value: lights.brush.startsWith("#") ? lights.brush : ""
                            title: "Brush colour"
                            implicitHeight: 30
                            onPicked: hex => lights.setBrush(hex)
                        }
                    }
                    RowLayout {
                        spacing: 8
                        Button { text: "Fill every key"; flat: true; focusPolicy: Qt.NoFocus; onClicked: lights.fillAll() }
                        KeyCap { text: "F" }
                        Button { text: "Clear"; flat: true; focusPolicy: Qt.NoFocus; onClicked: lights.clearPaint() }
                        KeyCap { text: "C" }
                        Item { Layout.fillWidth: true }
                        Label { text: lights.paintedCount + " keys painted"; color: theme.textFaint; font.pixelSize: 11 }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }

        // --- colours and settings ---
        ScrollView {
            id: side
            Layout.preferredWidth: 330
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: side.availableWidth
                spacing: 12

                Card {
                    Layout.fillWidth: true
                    implicitHeight: lightsColumn.implicitHeight + 32

                    ColumnLayout {
                        id: lightsColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            SwitchRow {
                                label: "Lights on"
                                hint: lights.on ? "Showing on the keyboard" : "Every key dark"
                                checked: lights.on
                                onToggled: on => lights.setOn(on)
                            }
                            KeyCap { text: "Space" }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            SwitchRow {
                                label: "Theme colours"
                                hint: "Light the keys only in colours found in the active wallpaper, so they change with every wallpaper switch"
                                checked: lights.followTheme
                                onToggled: on => lights.setFollowTheme(on)
                            }
                            KeyCap { text: "T" }
                        }

                        SectionLabel { text: "Colours"; Layout.topMargin: 6 }
                        Repeater {
                            model: 4
                            delegate: RowLayout {
                                id: slotRow2
                                required property int index
                                Layout.fillWidth: true
                                spacing: 10
                                visible: lights.slotNames[index] !== "—"
                                Rectangle {
                                    width: 26; height: 26; radius: 6
                                    color: lights.colors[slotRow2.index] || "#000000"
                                    border.color: theme.borderStrong
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: lights.slotNames[slotRow2.index]
                                    color: theme.textSoft
                                    elide: Text.ElideRight
                                }
                                Label {
                                    text: lights.colors[slotRow2.index] || ""
                                    color: theme.textFaint
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                }
                                ColorButton {
                                    value: lights.colors[slotRow2.index] || ""
                                    title: lights.slotNames[slotRow2.index]
                                    onPicked: hex => lights.setSlotColor(slotRow2.index, hex)
                                }
                            }
                        }
                        Label {
                            visible: lights.slotNames.every(n => n === "—")
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: lights.followTheme ? "Travels round the wallpaper's colours." : "Travels round the whole colour wheel. Choose theme colours to travel round the wallpaper's instead."
                            color: theme.textDim
                            font.pixelSize: 11
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                Layout.fillWidth: true
                                text: lights.followTheme ? "From the wallpaper. Pick a colour to set your own." : "Your own colours."
                                color: theme.textDim
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                            Button {
                                visible: lights.mode !== "paint"
                                text: "Original colours"
                                flat: true
                                focusPolicy: Qt.NoFocus
                                onClicked: lights.resetColors()
                            }
                        }

                        ColumnLayout {
                            visible: (lights.mode === "pattern" && lights.pattern === "word") || (lights.mode === "animation" && lights.animation === "typist")
                            Layout.fillWidth: true
                            spacing: 4
                            SectionLabel { text: "Word" }
                            TextField {
                                Layout.fillWidth: true
                                text: lights.word
                                placeholderText: "Letters to light"
                                maximumLength: 32
                                onTextEdited: lights.setWord(text)
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    implicitHeight: tuneColumn.implicitHeight + 32

                    ColumnLayout {
                        id: tuneColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 6

                        SectionLabel { text: "Tune" }
                        SliderRow {
                            label: "Brightness"
                            from: 0; to: 100; stepSize: 5
                            value: lights.brightness
                            decimals: 0
                            suffix: "%"
                            onMoved: v => lights.setBrightness(Math.round(v))
                        }
                        SliderRow {
                            label: "Vividness"
                            from: 0; to: 100; stepSize: 5
                            value: lights.vivid
                            decimals: 0
                            suffix: "%"
                            onMoved: v => lights.setVivid(Math.round(v))
                        }
                        SliderRow {
                            visible: lights.mode === "animation"
                            label: "Speed"
                            from: 0.25; to: 3; stepSize: 0.25
                            value: lights.speed
                            decimals: 2
                            suffix: "×"
                            onMoved: v => lights.setSpeed(v)
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "Vividness deepens pale theme colours, which otherwise read as white on the keys."
                            color: theme.textDim
                            font.pixelSize: 11
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    implicitHeight: chassisColumn.implicitHeight + 32

                    ColumnLayout {
                        id: chassisColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        SectionLabel { text: "Lid logo, power button and ring" }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: [
                                    { id: "primary", name: "First colour" },
                                    { id: "secondary", name: "Second colour" },
                                    { id: "keyboard", name: "Match the keys" },
                                    { id: "off", name: "Off" },
                                    { id: "leave", name: "Leave alone" }
                                ]
                                delegate: Chip {
                                    required property var modelData
                                    text: modelData.name
                                    chosen: lights.chassis === modelData.id
                                    onClicked: lights.setChassis(modelData.id)
                                }
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "Set through alienwarectl. They hold one colour, so animations show them the first colour, or the keys' average."
                            color: theme.textDim
                            font.pixelSize: 11
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    implicitHeight: serviceInfo.implicitHeight + 32

                    ColumnLayout {
                        id: serviceInfo
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        SectionLabel { text: "Lighting service" }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: lights.driverRunning ? (lights.driverError === "" ? theme.success : theme.danger) : theme.textFaint
                            }
                            Label {
                                Layout.fillWidth: true
                                text: !lights.driverRunning ? "Not running"
                                      : lights.driverKeyboard !== "" ? "Running, writing through " + lights.driverKeyboard
                                      : "Running, no keyboard found"
                                color: theme.textSoft
                                wrapMode: Text.WordWrap
                            }
                        }
                        Button {
                            text: lights.driverRunning ? "Stop the service" : "Start the service"
                            enabled: !lights.driverBusy
                            flat: true
                            focusPolicy: Qt.NoFocus
                            onClicked: lights.driverRunning ? lights.stopDriver() : lights.startDriver()
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "alienflare.service runs at login and keeps the scene on the keys. Stopping it leaves the keys as they are."
                            color: theme.textDim
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
