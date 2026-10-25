import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Burn My Windows: effects when windows open and close, after the GNOME
// extension. Each tile runs the plugin's own shader on a little window, so
// what you see here is what the shell plays. Every pick is written to
// burn-my-windows.json, which the shell follows straight away.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    // Which list the tiles edit: windows closing or opening.
    property string side: "close"

    readonly property bool dialogOpen: false
    readonly property var shortcuts: [
        { keys: "C / O", action: "Edit the effects for closing / opening windows" },
        { keys: "P", action: "Play the picked effect on this window" },
        { keys: "R", action: "Any effect, picked at random each time" },
        { keys: "E", action: "Turn all window effects on or off" }
    ]

    function handleEscape() {
        if (burn.error !== "" || burn.notice !== "") {
            burn.dismissMessages();
            return true;
        }
        return false;
    }
    function acceptDialog() {}

    readonly property var chosen: side === "open" ? burn.openEffects : burn.closeEffects
    readonly property bool anyEffect: chosen.indexOf("random") !== -1
    function firstChosen() {
        for (let i = 0; i < chosen.length; i++)
            if (chosen[i] !== "random")
                return chosen[i];
        return burn.effects.length ? burn.effects[Math.floor(Math.random() * burn.effects.length)].id : "";
    }

    readonly property var swatches: ["#ff7a1a", "#ff3b5c", "#ffd60a", "#38ff6a", "#5ef1ff", "#6fa8ff", "#c08bff", "#ffffff"]

    readonly property bool keys: active && keysFree && burn.available
    Shortcut { sequence: "C"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.side = "close" }
    Shortcut { sequence: "O"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.side = "open" }
    Shortcut { sequence: "P"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: burn.preview(page.firstChosen(), page.side === "open" ? "open" : "both") }
    Shortcut { sequence: "R"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: burn.toggleEffect(page.side, "random") }
    Shortcut { sequence: "E"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: burn.setEnabled(!burn.enabled) }

    onActiveChanged: if (active) burn.reload()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        PageHeader {
            title: "Burn My Windows"
            subtitle: "Burn My Windows for Omarchy, saved to ~/.config/omarchy/burn-my-windows.json"
            glyph: "\u{f0238}"
            Switch {
                visible: burn.available
                checked: burn.enabled
                focusPolicy: Qt.NoFocus
                onToggled: burn.setEnabled(checked)
            }
            KeyCap { text: "E"; visible: burn.available }
            AccentButton {
                text: "Play on this window"
                visible: burn.available
                onClicked: burn.preview(page.firstChosen(), page.side === "open" ? "open" : "both")
            }
            KeyCap { text: "P"; visible: burn.available }
        }

        NotInstalled {
            visible: !burn.available
            pluginId: "omacraft.burn"
            what: "Window effects come from the Burn My Windows shell plugin."
        }

        MessageBar {
            error: burn.error
            notice: burn.notice
            onDismissed: burn.dismissMessages()
        }

        ScrollView {
            id: scroll
            visible: burn.available
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: scroll.availableWidth
                spacing: 14
                opacity: burn.enabled ? 1 : 0.55

                // ---- Effects
                Card {
                    Layout.fillWidth: true
                    implicitHeight: effectColumn.implicitHeight + 32
                    ColumnLayout {
                        id: effectColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Chip { text: "\u{f05ad}  Closing"; chosen: page.side === "close"; onClicked: page.side = "close" }
                            KeyCap { text: "C" }
                            Chip { text: "\u{f0415}  Opening"; chosen: page.side === "open"; onClicked: page.side = "open" }
                            KeyCap { text: "O" }
                            Item { Layout.fillWidth: true }
                            Chip {
                                text: "\u{f049d}  Any effect"
                                chosen: page.anyEffect
                                onClicked: burn.toggleEffect(page.side, "random")
                            }
                            KeyCap { text: "R" }
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: theme.textMuted
                            font.pixelSize: 12
                            text: (page.anyEffect ? "Every effect is in play: each "
                                                  : "Pick one or more; each ")
                                  + (page.side === "open" ? "window that opens" : "window that closes")
                                  + " gets one at random. Hover a tile to watch it, double-click to play it on this window."
                                  + (page.side === "open" ? " Opening runs each effect backwards, so the window comes together." : "")
                        }

                        SwitchRow {
                            label: page.side === "open" ? "Effects when windows open" : "Effects when windows close"
                            hint: page.side === "open"
                                  ? "New windows on a visible workspace are hidden for a moment and drawn in by the effect."
                                  : "Windows closed with SUPER+W or SUPER+Q (see Keys below). Others close the usual way."
                            checked: page.side === "open" ? burn.openEnabled : burn.closeEnabled
                            onToggled: on => burn.setSideEnabled(page.side, on)
                        }
                        SliderRow {
                            label: "Speed"
                            from: 0.25
                            to: 3
                            stepSize: 0.05
                            value: page.side === "open" ? burn.openSpeed : burn.closeSpeed
                            suffix: "×"
                            onMoved: value => burn.setSpeed(page.side, value)
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: Math.max(3, Math.floor(width / 160))
                            rowSpacing: 10
                            columnSpacing: 10
                            Repeater {
                                model: burn.effects
                                delegate: Rectangle {
                                    id: tile
                                    required property var modelData
                                    readonly property bool picked: page.anyEffect || page.chosen.indexOf(modelData.id) !== -1
                                    readonly property color tone: Qt.color(theme.accent)
                                    Layout.fillWidth: true
                                    implicitHeight: 168
                                    radius: 9
                                    color: picked ? Qt.rgba(tone.r, tone.g, tone.b, 0.12) : hover.hovered ? theme.hover : theme.inset
                                    border.color: picked ? theme.accent : theme.border
                                    border.width: picked && !page.anyEffect ? 2 : 1

                                    EffectPreview {
                                        id: preview
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 8
                                        height: 104
                                        def: tile.modelData
                                        running: hover.hovered
                                        reverse: page.side === "open"
                                    }
                                    ColumnLayout {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 9
                                        spacing: 1
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Label {
                                                Layout.fillWidth: true
                                                text: tile.modelData.name
                                                color: tile.picked ? theme.accent : theme.text
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                            }
                                            Label {
                                                visible: tile.modelData.source === "omacraft"
                                                text: "new"
                                                color: theme.textMuted
                                                font.pixelSize: 9
                                            }
                                            Label { visible: tile.picked && !page.anyEffect; text: "✓"; color: theme.accent }
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            text: tile.modelData.description || ""
                                            color: theme.textMuted
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                    }
                                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        onTapped: burn.toggleEffect(page.side, tile.modelData.id)
                                        onDoubleTapped: burn.preview(tile.modelData.id, page.side === "open" ? "open" : "both")
                                    }
                                    ToolTip.visible: hover.hovered
                                    ToolTip.delay: 900
                                    ToolTip.text: tile.modelData.description + (tile.modelData.source === "omacraft"
                                                  ? " (OmaCraft's own)" : " (from Burn My Windows)")
                                }
                            }
                        }
                    }
                }

                // ---- Look
                Card {
                    Layout.fillWidth: true
                    implicitHeight: lookColumn.implicitHeight + 32
                    ColumnLayout {
                        id: lookColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        SectionLabel { text: "Look" }
                        SliderRow {
                            label: "Intensity"
                            from: 0.25
                            to: 2.5
                            stepSize: 0.05
                            value: burn.intensity
                            suffix: "×"
                            onMoved: value => burn.setIntensity(value)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Label { Layout.preferredWidth: 120; text: "Colour"; color: theme.textSoft }
                            Chip { text: "Each effect's own"; chosen: burn.color === "effect"; onClicked: burn.setColor("effect") }
                            Chip { text: "Theme accent"; chosen: burn.color === "theme"; onClicked: burn.setColor("theme") }
                            Repeater {
                                model: page.swatches
                                delegate: Rectangle {
                                    required property string modelData
                                    readonly property bool picked: burn.color.toLowerCase() === modelData
                                    width: 24; height: 24; radius: 12
                                    color: modelData
                                    border.color: picked ? theme.text : theme.border
                                    border.width: picked ? 2 : 1
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: burn.setColor(modelData) }
                                }
                            }
                            ColorButton {
                                value: burn.color
                                title: "Effect colour"
                                border.width: isHex && page.swatches.indexOf(burn.color.toLowerCase()) < 0 ? 2 : 1
                                border.color: border.width > 1 ? theme.accent : theme.border
                                onPicked: hex => burn.setColor(hex)
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                // ---- Which windows
                Card {
                    Layout.fillWidth: true
                    implicitHeight: whichColumn.implicitHeight + 32
                    ColumnLayout {
                        id: whichColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        SectionLabel { text: "Which windows" }
                        SwitchRow {
                            label: "Leave floating windows alone"
                            hint: "Dialogs, pickers and popups appear and go without an effect."
                            checked: burn.skipFloating
                            onToggled: on => burn.setSkipFloating(on)
                        }
                        SwitchRow {
                            label: "Leave fullscreen windows alone"
                            hint: "Games and videos keep closing instantly."
                            checked: burn.skipFullscreen
                            onToggled: on => burn.setSkipFullscreen(on)
                        }
                        Label { text: "Never for these window classes"; color: theme.textSoft }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: burn.exclude
                                delegate: Chip {
                                    required property string modelData
                                    text: modelData + "  ×"
                                    onClicked: burn.removeExclude(modelData)
                                }
                            }
                            Label {
                                visible: burn.exclude.length === 0
                                text: "None"
                                color: theme.textFaint
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            TextField {
                                id: classField
                                Layout.fillWidth: true
                                placeholderText: "Window class, as hyprctl clients shows it (e.g. org.gnome.Calculator)"
                                onAccepted: { burn.addExclude(text); text = ""; }
                            }
                            Button {
                                text: "Add"
                                flat: true
                                focusPolicy: Qt.NoFocus
                                enabled: classField.text.trim() !== ""
                                onClicked: { burn.addExclude(classField.text); classField.text = ""; }
                            }
                        }
                    }
                }

                // ---- Keys
                Card {
                    Layout.fillWidth: true
                    implicitHeight: keysColumn.implicitHeight + 32
                    ColumnLayout {
                        id: keysColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        SectionLabel { text: "Keys" }
                        SwitchRow {
                            label: "SUPER+W and SUPER+Q close with effects"
                            hint: "A closing effect needs the window's last frame before it goes, so closing goes through "
                                  + "the shell. Writes ~/.config/hypr/burn_my_windows.lua. If the shell is down, the keys "
                                  + "still close windows, just without an effect."
                            checked: burn.keysInstalled
                            onToggled: on => burn.setKeys(on)
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: theme.textFaint
                    font.pixelSize: 11
                    text: "27 effects after Burn My Windows by Simon Schneegans, plus ASCII and Warp Speed of OmaCraft's own. "
                          + "From a terminal: omarchy-burn list | preview EFFECT | close effects ID... | open speed N."
                }
            }
        }
    }

    // A little window drawn by the effect's own shader. Rests on a frame
    // that shows what the effect does, and plays through while hovered.
    component EffectPreview: Rectangle {
        id: ep
        property var def: ({})
        property bool running: false
        property bool reverse: false
        property real progress: 0.3
        property real time: 0.6
        radius: 6
        color: theme.dark ? theme.sunken : theme.borderStrong
        border.color: theme.border
        clip: true

        readonly property real winW: Math.min(width * 0.46, height * 0.62)
        readonly property real winH: winW * 0.78
        readonly property real padPx: Math.ceil((Number(def.pad) || 0) * Math.max(winW, winH) * 0.6 + 3)

        // The window: a title bar and a few lines in the theme's colours.
        Rectangle {
            id: fake
            width: ep.winW
            height: ep.winH
            visible: false
            // Lighter than the backdrop on a dark theme, whiter on a light one.
            color: theme.dark ? theme.hover : theme.window
            Rectangle { width: parent.width; height: 9; color: theme.border }
            Rectangle { x: 4; y: 2.5; width: 4; height: 4; radius: 2; color: theme.accent }
            Column {
                x: 6; y: 15; spacing: 4
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        width: [0.7, 0.5, 0.82, 0.38, 0.6][index] * (ep.winW - 12)
                        height: 4
                        radius: 2
                        color: index === 0 ? theme.accent : theme.borderStrong
                    }
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 6
                width: parent.width * 0.32
                height: parent.height * 0.34
                radius: 3
                color: Qt.rgba(Qt.color(theme.accent).r, Qt.color(theme.accent).g, Qt.color(theme.accent).b, 0.5)
            }
        }
        ShaderEffectSource {
            id: snapshot
            sourceItem: fake
            hideSource: true
            live: true
            visible: false
            textureSize: Qt.size(fake.width * 2, fake.height * 2)
        }

        ShaderEffect {
            width: ep.winW + 2 * ep.padPx
            height: ep.winH + 2 * ep.padPx
            anchors.centerIn: parent
            fragmentShader: burn.shaderDir !== "" && ep.def.id ? "file://" + burn.shaderDir + "/" + ep.def.id + ".frag.qsb" : ""
            property var source: snapshot
            property real progress: ep.reverse ? 1 - ep.progress : ep.progress
            property real time: ep.time
            property real seed: 0.37
            property real opening: ep.reverse ? 1 : 0
            property real intensity: burn.intensity
            property real border: 1
            property point size: Qt.point(width, height)
            property point pad: Qt.point(ep.padPx, ep.padPx)
            property point origin: Qt.point(0.62, 0.45)
            property color color: burn.color === "theme" ? theme.accent : burn.color === "effect" ? (ep.def.color || "white") : burn.color
            property color color2: burn.color === "effect" ? (ep.def.color2 || "white") : Qt.lighter(color, 1.5)
            property color borderColor: theme.accent
        }

        SequentialAnimation {
            running: ep.running
            loops: Animation.Infinite
            onStopped: { ep.progress = 0.3; ep.time = 0.6; }
            NumberAnimation {
                target: ep
                property: "progress"
                from: 0
                to: 1
                duration: Math.max(300, (Number(ep.def.duration) || 1000) / Math.max(0.25, ep.reverse ? burn.openSpeed : burn.closeSpeed))
            }
            PauseAnimation { duration: 450 }
        }
        FrameAnimation {
            running: ep.running
            onTriggered: ep.time += frameTime
        }
    }
}
