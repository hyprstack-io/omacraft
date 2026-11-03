import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "LockDefaults.js" as Defaults

// The designer, shared by the lock and login tabs: the stage and looks on the
// left, every setting on the right. target says which look it edits.
RowLayout {
    id: design

    property string target: "lock"
    readonly property bool isLock: target === "lock"
    readonly property var look: isLock ? lockLogon.lockLook : lockLogon.loginLook
    readonly property var s: Defaults.clean(look)
    property string section: "layout"
    readonly property var stage: stageView

    // The picture the stage shows: a folder's first file stands in for the lot.
    readonly property string pictureFile: s.bgMode === "folder"
        ? (lockLogon.folderImages.length > 0 ? String(lockLogon.folderImages[0]) : lockLogon.wallpaper)
        : s.bgMode === "image" && s.bgImage !== "" ? s.bgImage : lockLogon.wallpaper

    function put(key, value) { lockLogon.set(target, key, value); }
    function play() { stageView.play(); }

    spacing: 14

    // A theme-following colour, or one of your own.
    component ColourRow: RowLayout {
        id: colourRow
        property string label
        property string key
        readonly property string value: design.s[key]
        Layout.fillWidth: true
        spacing: 8
        Label { Layout.fillWidth: true; text: colourRow.label; color: theme.textSoft; elide: Text.ElideRight }
        Label {
            text: colourRow.value === "" ? "theme" : colourRow.value
            color: theme.textDim
            font.family: "monospace"
            font.pixelSize: 11
        }
        ToolButton {
            visible: colourRow.value !== ""
            implicitWidth: 26; implicitHeight: 26
            text: "\u{f0156}"
            focusPolicy: Qt.NoFocus
            onClicked: design.put(colourRow.key, "")
            ToolTip.visible: hovered
            ToolTip.text: "Back to the theme"
        }
        ColorButton {
            value: colourRow.value
            title: colourRow.label
            onPicked: hex => design.put(colourRow.key, hex)
        }
    }
    // A row of worded choices for one setting.
    component ChoiceRow: ColumnLayout {
        id: choiceRow
        property string label
        property string key
        property var options: []     // [{ id, name }]
        Layout.fillWidth: true
        spacing: 4
        Label { text: choiceRow.label; color: theme.textSoft; visible: choiceRow.label !== "" }
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: choiceRow.options
                Chip {
                    required property var modelData
                    text: modelData.name
                    chosen: design.s[choiceRow.key] === modelData.id
                    onClicked: design.put(choiceRow.key, modelData.id)
                }
            }
        }
    }
    component TextRow: RowLayout {
        id: textRow
        property string label
        property string key
        property string placeholder
        Layout.fillWidth: true
        spacing: 8
        Label { Layout.preferredWidth: 78; text: textRow.label; color: theme.textSoft; elide: Text.ElideRight }
        TextField {
            Layout.fillWidth: true
            text: design.s[textRow.key]
            placeholderText: textRow.placeholder
            onEditingFinished: if (text !== design.s[textRow.key]) design.put(textRow.key, text)
        }
    }
    component ToggleRow: SwitchRow {
        id: toggleRow
        property string key
        checked: design.s[key]
        onToggled: on => design.put(key, on)
    }
    component FileRow: RowLayout {
        id: fileRow
        property string label
        property string key
        property bool folder: false
        Layout.fillWidth: true
        spacing: 8
        Label { Layout.preferredWidth: 78; text: fileRow.label; color: theme.textSoft }
        Label {
            Layout.fillWidth: true
            text: design.s[fileRow.key] === "" ? "None chosen" : design.s[fileRow.key].split("/").pop()
            color: design.s[fileRow.key] === "" ? theme.textDim : theme.text
            elide: Text.ElideMiddle
        }
        Button {
            text: "Choose…"
            flat: true
            focusPolicy: Qt.NoFocus
            onClicked: fileRow.folder ? lockLogon.chooseFolder(design.target, fileRow.key) : lockLogon.choosePicture(design.target, fileRow.key)
        }
    }

    // --- the stage and the ready-made looks ---
    ColumnLayout {
        id: stageColumn
        // Takes what the inspector leaves, whatever its contents would like.
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        Layout.minimumWidth: 280
        spacing: 10

        LockStage {
            id: stageView
            objectName: design.target + "Stage"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 200
            settings: design.s
            target: design.target
            pictureFile: design.pictureFile
            onMovedBlock: (x, y) => lockLogon.setMany(design.target, { blockX: x, blockY: y })
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Segmented {
                model: [{ id: "idle", name: "Waiting" }, { id: "typing", name: "Typing" }, { id: "wrong", name: "Wrong" }]
                current: stageView.mode
                onPicked: id => stageView.mode = id
            }
            Item { Layout.fillWidth: true }
            Label { visible: stageColumn.width > 560; text: "Drag on the screen to move the block"; color: theme.textDim; font.pixelSize: 11 }
            Button { text: "▶ Play  (P)"; flat: true; focusPolicy: Qt.NoFocus; onClicked: stageView.play() }
        }

        ListView {
            id: looks
            objectName: design.target + "Looks"
            Layout.fillWidth: true
            Layout.preferredHeight: 118
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: Defaults.presets
            delegate: Rectangle {
                id: tile
                required property var modelData
                width: 172
                height: 118
                radius: 8
                color: tileHover.hovered ? theme.hover : theme.card
                border.color: tileHover.hovered ? theme.accent : theme.border

                Item {
                    x: 6; y: 6
                    width: 160; height: 90
                    clip: true
                    LockScene {
                        width: 1920; height: 1080
                        scale: 160 / 1920
                        transformOrigin: Item.TopLeft
                        settings: Defaults.clean(tile.modelData.values)
                        theme: lockLogon.themeColors
                        backgroundFile: lockLogon.wallpaper
                        userName: "skll"
                        hostName: "omarchy"
                        inputEnabled: false
                        thumbnail: true
                        pictureScale: 0.1
                    }
                }
                Label {
                    x: 8; y: 97
                    width: parent.width - 16
                    text: tile.modelData.name
                    color: theme.text
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: lockLogon.replace(design.target, tile.modelData.values) }
                ToolTip.visible: tileHover.hovered
                ToolTip.delay: 400
                ToolTip.text: tile.modelData.note
            }
        }
    }

    // --- the inspector ---
    Card {
        Layout.preferredWidth: Math.min(360, design.width * 0.46)
        Layout.minimumWidth: 270
        Layout.fillHeight: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Segmented {
                Layout.alignment: Qt.AlignHCenter
                model: [{ id: "layout", name: "Layout" }, { id: "colour", name: "Colour" }, { id: "picture", name: "Picture" }, { id: "motion", name: "Motion" }]
                current: design.section
                onPicked: id => design.section = id
            }

            ScrollView {
                id: scroller
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    width: scroller.availableWidth - 8
                    spacing: 10

                    // --- layout ---
                    ColumnLayout {
                        visible: design.section === "layout"
                        Layout.fillWidth: true
                        spacing: 10

                        SectionLabel { text: "Block" }
                        ChoiceRow {
                            label: "Text lines up"
                            key: "align"
                            options: [{ id: "left", name: "Left" }, { id: "center", name: "Centre" }, { id: "right", name: "Right" }]
                        }
                        SliderRow { label: "Across"; from: 0; to: 100; stepSize: 1; decimals: 0; suffix: "%"; value: design.s.blockX; onMoved: v => design.put("blockX", v) }
                        SliderRow { label: "Down"; from: 0; to: 100; stepSize: 1; decimals: 0; suffix: "%"; value: design.s.blockY; onMoved: v => design.put("blockY", v) }
                        SliderRow { label: "Spacing"; from: 0; to: 80; stepSize: 1; decimals: 0; value: design.s.gap; onMoved: v => design.put("gap", v) }

                        SectionLabel { text: "Backing panel" }
                        ChoiceRow {
                            key: "panel"
                            options: [{ id: "none", name: "None" }, { id: "card", name: "Card" }, { id: "left", name: "Left" }, { id: "right", name: "Right" }, { id: "bottom", name: "Bottom" }]
                        }
                        SliderRow { visible: design.s.panel !== "none"; label: "Size"; from: 15; to: 70; stepSize: 1; decimals: 0; suffix: "%"; value: design.s.panelSize; onMoved: v => design.put("panelSize", v) }
                        SliderRow { visible: design.s.panel === "card"; label: "Corners"; from: 0; to: 48; stepSize: 1; decimals: 0; value: design.s.panelRadius; onMoved: v => design.put("panelRadius", v) }

                        SectionLabel { text: "Password field" }
                        ChoiceRow {
                            key: "fieldStyle"
                            options: [{ id: "box", name: "Box" }, { id: "pill", name: "Pill" }, { id: "line", name: "Line" }]
                        }
                        SliderRow { label: "Width"; from: 180; to: 900; stepSize: 5; decimals: 0; value: design.s.fieldWidth; onMoved: v => design.put("fieldWidth", v) }
                        SliderRow { label: "Height"; from: 36; to: 120; stepSize: 1; decimals: 0; value: design.s.fieldHeight; onMoved: v => design.put("fieldHeight", v) }
                        SliderRow { visible: design.s.fieldStyle === "box"; label: "Corners"; from: 0; to: 60; stepSize: 1; decimals: 0; value: design.s.fieldRadius; onMoved: v => design.put("fieldRadius", v) }
                        SliderRow { label: "Border"; from: 0; to: 10; stepSize: 1; decimals: 0; value: design.s.borderWidth; onMoved: v => design.put("borderWidth", v) }
                        ChoiceRow {
                            label: "Password dots"
                            key: "dotGlyph"
                            options: ["●", "•", "*", "■", "✦", "█"].map(g => ({ id: g, name: g }))
                        }
                        TextRow { label: "Prompt"; key: "placeholder"; placeholder: "Enter password" }

                        SectionLabel { text: "Clock" }
                        ToggleRow { label: "Show the clock"; key: "showClock" }
                        ColumnLayout {
                            visible: design.s.showClock
                            Layout.fillWidth: true
                            spacing: 8
                            ToggleRow { label: "24-hour"; key: "clock24h" }
                            ToggleRow { label: "Seconds"; key: "clockSeconds" }
                            SliderRow { label: "Size"; from: 24; to: 260; stepSize: 2; decimals: 0; value: design.s.clockSize; onMoved: v => design.put("clockSize", v) }
                            ChoiceRow { key: "clockWeight"; options: [{ id: "light", name: "Light" }, { id: "normal", name: "Regular" }, { id: "bold", name: "Bold" }] }
                        }
                        ToggleRow { label: "Show the date"; key: "showDate" }
                        ColumnLayout {
                            visible: design.s.showDate
                            Layout.fillWidth: true
                            spacing: 8
                            TextRow { label: "Format"; key: "dateFormat"; placeholder: "dddd d MMMM" }
                            SliderRow { label: "Size"; from: 10; to: 64; stepSize: 1; decimals: 0; value: design.s.dateSize; onMoved: v => design.put("dateSize", v) }
                        }

                        SectionLabel { text: "You" }
                        ToggleRow { label: "Greeting"; hint: "{user} and {host} fill themselves in."; key: "showGreeting" }
                        ColumnLayout {
                            visible: design.s.showGreeting
                            Layout.fillWidth: true
                            spacing: 8
                            TextRow { label: "Words"; key: "greeting"; placeholder: "{user}" }
                            SliderRow { label: "Size"; from: 10; to: 64; stepSize: 1; decimals: 0; value: design.s.greetingSize; onMoved: v => design.put("greetingSize", v) }
                        }
                        ToggleRow { label: "Avatar"; key: "showAvatar" }
                        ColumnLayout {
                            visible: design.s.showAvatar
                            Layout.fillWidth: true
                            spacing: 8
                            FileRow { label: "Picture"; key: "avatar" }
                            SliderRow { label: "Size"; from: 32; to: 240; stepSize: 2; decimals: 0; value: design.s.avatarSize; onMoved: v => design.put("avatarSize", v) }
                            ChoiceRow { key: "avatarShape"; options: [{ id: "circle", name: "Circle" }, { id: "squircle", name: "Soft square" }, { id: "square", name: "Square" }] }
                        }
                        ToggleRow { label: "A note"; hint: "A line under the field: whose laptop, who to call."; key: "showNote" }
                        TextRow { visible: design.s.showNote; label: "Words"; key: "note"; placeholder: "If found, call…" }
                        FontField {
                            label: "Font"
                            value: design.s.fontFamily
                            placeholder: "JetBrainsMono Nerd Font"
                            onPicked: family => design.put("fontFamily", family)
                        }
                    }

                    // --- colour and opacity ---
                    ColumnLayout {
                        visible: design.section === "colour"
                        Layout.fillWidth: true
                        spacing: 10

                        SectionLabel { text: "Colours" }
                        ColourRow { label: "Field fill"; key: "colorSurface" }
                        ColourRow { label: "Border"; key: "colorBorder" }
                        ColourRow { label: "Border's far end"; key: "colorBorder2" }
                        ToggleRow { label: "Blend the two border colours"; key: "borderGradient" }
                        ColourRow { label: "Text"; key: "colorText" }
                        ColourRow { label: "Clock"; key: "colorClock" }
                        ColourRow { label: "Wrong password"; key: "colorError" }
                        ColourRow { label: "Panel"; key: "colorPanel" }
                        ColourRow { label: "Dimming"; key: "colorDim" }

                        SectionLabel { text: "Opacity" }
                        SliderRow { label: "Field"; from: 0; to: 1; stepSize: 0.01; value: design.s.fieldOpacity; onMoved: v => design.put("fieldOpacity", v) }
                        SliderRow { label: "Panel"; from: 0; to: 1; stepSize: 0.01; value: design.s.panelOpacity; onMoved: v => design.put("panelOpacity", v) }
                        SliderRow { label: "Clock"; from: 0.1; to: 1; stepSize: 0.01; value: design.s.clockOpacity; onMoved: v => design.put("clockOpacity", v) }
                        SliderRow { label: "Dimming"; from: 0; to: 1; stepSize: 0.01; value: design.s.dim; onMoved: v => design.put("dim", v) }
                    }

                    // --- the picture ---
                    ColumnLayout {
                        visible: design.section === "picture"
                        Layout.fillWidth: true
                        spacing: 10

                        SectionLabel { text: "Behind it all" }
                        ChoiceRow {
                            key: "bgMode"
                            options: design.isLock
                                ? [{ id: "wallpaper", name: "Wallpaper" }, { id: "image", name: "Picture" }, { id: "folder", name: "Random from folder" }, { id: "solid", name: "Solid" }, { id: "gradient", name: "Gradient" }]
                                : [{ id: "wallpaper", name: "Today's wallpaper" }, { id: "image", name: "Picture" }, { id: "solid", name: "Solid" }, { id: "gradient", name: "Gradient" }]
                        }
                        FileRow { visible: design.s.bgMode === "image"; label: "Picture"; key: "bgImage" }
                        FileRow { visible: design.s.bgMode === "folder"; label: "Folder"; key: "bgFolder"; folder: true }
                        Label {
                            visible: design.s.bgMode === "folder"
                            Layout.fillWidth: true
                            text: lockLogon.folderImages.length + " pictures. Each lock picks one."
                            color: theme.textDim
                            font.pixelSize: 11
                        }
                        ColourRow { visible: design.s.bgMode === "solid" || design.s.bgMode === "gradient"; label: "Colour"; key: "bgColor" }
                        ColourRow { visible: design.s.bgMode === "gradient"; label: "Second colour"; key: "bgColor2" }
                        SliderRow { visible: design.s.bgMode === "gradient"; label: "Direction"; from: 0; to: 359; stepSize: 45; decimals: 0; suffix: "°"; value: design.s.bgAngle; onMoved: v => design.put("bgAngle", v) }

                        ColumnLayout {
                            visible: design.s.bgMode !== "solid" && design.s.bgMode !== "gradient"
                            Layout.fillWidth: true
                            spacing: 10
                            ChoiceRow {
                                label: "Fit"
                                key: "bgFit"
                                options: [{ id: "crop", name: "Fill" }, { id: "fit", name: "Fit" }, { id: "stretch", name: "Stretch" }, { id: "center", name: "Centre" }, { id: "tile", name: "Tile" }]
                            }
                            SectionLabel { text: "Treatment" }
                            SliderRow { label: "Blur"; from: 0; to: 1; stepSize: 0.01; value: design.s.blur; onMoved: v => design.put("blur", v) }
                            SliderRow { label: "Brightness"; from: -1; to: 1; stepSize: 0.01; value: design.s.brightness; onMoved: v => design.put("brightness", v) }
                            SliderRow { label: "Contrast"; from: -1; to: 1; stepSize: 0.01; value: design.s.contrast; onMoved: v => design.put("contrast", v) }
                            SliderRow { label: "Saturation"; from: -1; to: 1; stepSize: 0.01; value: design.s.saturation; onMoved: v => design.put("saturation", v) }
                        }
                    }

                    // --- motion ---
                    ColumnLayout {
                        visible: design.section === "motion"
                        Layout.fillWidth: true
                        spacing: 10

                        readonly property var moves: [{ id: "none", name: "None" }, { id: "fade", name: "Fade" }, { id: "rise", name: "Rise" }, { id: "zoom", name: "Zoom" }, { id: "focus", name: "Focus" }, { id: "curtain", name: "Curtain" }]

                        SectionLabel { text: design.isLock ? "Locking" : "Arriving" }
                        ChoiceRow { key: "lockIn"; options: parent.moves }
                        SliderRow { label: "Time"; from: 100; to: 1500; stepSize: 10; decimals: 0; suffix: " ms"; value: design.s.lockInMs; onMoved: v => design.put("lockInMs", v) }

                        SectionLabel { visible: design.isLock; text: "Unlocking" }
                        ChoiceRow { visible: design.isLock; key: "unlockOut"; options: parent.moves }
                        SliderRow { visible: design.isLock; label: "Time"; from: 100; to: 800; stepSize: 10; decimals: 0; suffix: " ms"; value: design.s.unlockMs; onMoved: v => design.put("unlockMs", v) }

                        SectionLabel { text: "While it waits" }
                        ToggleRow { label: "Shake on a wrong password"; key: "shake" }
                        ToggleRow { label: "Slow drift over the picture"; hint: "A very slow zoom. Uses a little power."; key: "drift" }
                        ToggleRow { label: "Breathing border"; key: "pulse" }

                        SectionLabel { visible: !design.isLock; text: "Login extras" }
                        ToggleRow { visible: !design.isLock; label: "Session picker"; key: "showSession" }
                        ToggleRow { visible: !design.isLock; label: "Restart and power buttons"; key: "showPower" }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: "Undo"
                    flat: true
                    focusPolicy: Qt.NoFocus
                    enabled: design.isLock ? lockLogon.canUndoLock : lockLogon.canUndoLogin
                    onClicked: lockLogon.undo(design.target)
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "Reset"
                    flat: true
                    focusPolicy: Qt.NoFocus
                    onClicked: lockLogon.replace(design.target, {})
                }
            }
        }
    }
}
