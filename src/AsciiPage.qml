import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Omacraft 1.0

// omascii's boot screen designer in three steps: pick the art, fine-tune it,
// then save it or apply it to the boot screen.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    // Whether a preset also switches to the TheDraw font it was made with.
    property bool presetFont: true
    signal openPage(string name)

    readonly property bool dialogOpen: false
    readonly property var c: omascii.config
    readonly property var o: omascii.options
    property string source: "figlet" // saved, figlet, tdf, ttf, image
    property int tuneTab: Math.max(0, ["text", "image", "style", "animation"].indexOf(startTab))
    property string deleting: ""
    property bool playing: false
    property int frame: 0
    property string playingEffect: ""
    readonly property var shortcuts: [
        { keys: "↑ ↓", action: "Browse fonts, using each one" },
        { keys: "Ctrl F", action: "Search the list" },
        { keys: "Ctrl P", action: "Play the intro over the art" },
        { keys: "Ctrl S", action: "Save the design to My boot screens" },
        { keys: "Ctrl Enter", action: "Apply it to the boot screen (asks for your password)" },
        { keys: "Ctrl Z", action: "Undo (Ctrl Shift Z redo)" },
        { keys: "Esc", action: "Stop the intro, clear the search" }
    ]

    function handleEscape() {
        if (page.playing) {
            stop();
            return true;
        }
        if (search.text !== "") {
            search.text = "";
            return true;
        }
        if (omascii.error !== "" || omascii.notice !== "") {
            omascii.dismissMessages();
            return true;
        }
        return false;
    }
    function acceptDialog() {}

    function useSource(name) {
        page.source = name;
        search.text = "";
        if (name === "figlet" || name === "tdf" || name === "ttf")
            omascii.fontSet = name;
        if (name === "image")
            omascii.loadImages();
    }
    function browse(step) {
        const list = omascii.fonts;
        if (list.length === 0) return;
        let i = fontList.currentIndex + step;
        i = Math.max(0, Math.min(list.length - 1, i));
        fontList.currentIndex = i;
        omascii.setOption("font", list[i].name);
    }
    function play(effect) {
        const effects = c.effects || [];
        const chosen = effect || (effects.length ? effects[0] : "");
        if (chosen === "") {
            omascii.dismissMessages();
            return;
        }
        page.playingEffect = chosen;
        page.frame = 0;
        page.playing = true;
        omascii.loadFrames(chosen);
    }
    function stop() {
        page.playing = false;
        player.stop();
    }
    function paletteHex(name) {
        if (String(name).startsWith("#")) return name;
        const hex = omascii.palette[name];
        return hex ? "#" + hex : "transparent";
    }
    function home(path) { return String(path || "").replace(/^\/home\/[^/]+/, "~"); }

    onActiveChanged: if (active && !omascii.loaded) omascii.refresh()

    Connections {
        target: omascii
        function onFramesChanged() {
            if (page.playing && omascii.frames.length > 0) {
                page.frame = 0;
                player.restart();
            } else if (page.playing && !omascii.loadingFrames) {
                page.playing = false;
            }
        }
        function onConfigChanged() {
            // The intro follows changes while it plays, as in the overlay.
            if (page.playing && !omascii.loadingFrames)
                omascii.loadFrames(page.playingEffect);
        }
    }

    Timer {
        id: player
        interval: Math.max(10, Math.round(1000 / omascii.fps))
        repeat: true
        onTriggered: {
            if (page.frame + 1 >= omascii.frames.length) {
                stop();
                page.playing = false;
                return;
            }
            page.frame++;
        }
    }

    readonly property bool keys: active && omascii.available
    readonly property bool letters: keys && keysFree
    Shortcut { sequence: "Up"; context: Qt.ApplicationShortcut; enabled: page.keys && (page.keysFree || search.activeFocus) && page.source !== "saved" && page.source !== "image"; onActivated: page.browse(-1) }
    Shortcut { sequence: "Down"; context: Qt.ApplicationShortcut; enabled: page.keys && (page.keysFree || search.activeFocus) && page.source !== "saved" && page.source !== "image"; onActivated: page.browse(1) }
    Shortcut { sequence: "Ctrl+F"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: search.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+P"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.playing ? page.stop() : page.play("") }
    Shortcut { sequence: "Ctrl+S"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: omascii.saveToLibrary(saveName.text || saveName.placeholderText) }
    Shortcut { sequences: ["Ctrl+Return", "Ctrl+Enter"]; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: omascii.applyToBoot() }
    Shortcut { sequence: "Ctrl+Z"; context: Qt.ApplicationShortcut; enabled: page.letters; onActivated: omascii.undo() }
    Shortcut { sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]; context: Qt.ApplicationShortcut; enabled: page.letters; onActivated: omascii.redo() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        PageHeader {
            title: "Boot Splash"
            subtitle: "omascii: FIGlet, TheDraw, system-font or image art for the Plymouth boot screen"
            glyph: "\u{f0b9e}"
            StatePill {
                visible: omascii.loaded || bootSplash.on
                text: bootSplash.on ? "Boot screen: HyprStack"
                    : omascii.boot.installed ? "Boot screen: omascii" : "Boot screen: " + (omascii.boot.theme || "stock")
                on: bootSplash.on || omascii.boot.installed === true
            }
            Button { text: "Undo"; flat: true; focusPolicy: Qt.NoFocus; enabled: omascii.canUndo; onClicked: omascii.undo() }
            Button { text: "Redo"; flat: true; focusPolicy: Qt.NoFocus; enabled: omascii.canRedo; onClicked: omascii.redo() }
        }

        // The HyprStack logo animation, a ready-made boot screen beside the
        // ones designed here.
        Card {
            Layout.fillWidth: true
            implicitHeight: hyprstackRow.implicitHeight + 20
            RowLayout {
                id: hyprstackRow
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                CheckBox {
                    focusPolicy: Qt.NoFocus
                    enabled: bootSplash.available && !bootSplash.switching
                    checked: bootSplash.on
                    onClicked: {
                        const wanted = checked;
                        // Stay bound to the real boot theme; it flips once the switch is done.
                        checked = Qt.binding(() => bootSplash.on);
                        bootSplash.setOn(wanted);
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label { text: "Use the HyprStack boot animation as the default boot screen"; color: theme.text }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: bootSplash.error ? theme.dangerText : theme.textFaint
                        text: bootSplash.error ? bootSplash.error
                            : !bootSplash.available ? "Not installed: it comes with the omacraft package."
                            : bootSplash.switching ? "Switching in the terminal: it asks for your password, then rebuilds the initramfs."
                            : bootSplash.on ? "The HyprStack logo plays at boot, with the disk password prompt below it. Untick to go back to " + bootSplash.previousTheme() + "."
                            : "The HyprStack logo animation, with the disk password prompt below it. Asks for your password and rebuilds the initramfs."
                    }
                }
            }
        }

        MessageBar {
            visible: !omascii.available
            error: "omascii isn't installed: its command wasn't found in the plugin or on your PATH. Install the omascii plugin on the Plugin Suite page, or run its install.sh."
        }

        MessageBar {
            error: omascii.error
            notice: omascii.notice
            onDismissed: omascii.dismissMessages()
        }

        RowLayout {
            visible: omascii.available
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // --- 1. Pick the art ---
            Card {
                Layout.preferredWidth: 330
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    SectionLabel { text: "① Pick the art" }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 5
                        Repeater {
                            model: [{ id: "saved", name: "★ Mine" }, { id: "figlet", name: "FIGlet" }, { id: "tdf", name: "TheDraw" },
                                    { id: "ttf", name: "System" }, { id: "image", name: "Image" }]
                            Chip {
                                required property var modelData
                                text: modelData.name
                                chosen: page.source === modelData.id
                                onClicked: page.useSource(modelData.id)
                            }
                        }
                    }
                    TextField {
                        id: search
                        Layout.fillWidth: true
                        visible: page.source !== "saved"
                        placeholderText: page.source === "image" ? "Image path, or filter below" : "Search " + omascii.fontTotal + " fonts"
                        onTextChanged: if (page.source !== "image") omascii.fontFilter = text
                        onAccepted: if (page.source === "image" && text.trim() !== "") omascii.setOption("image", text.trim())
                    }

                    // Fonts.
                    ListView {
                        id: fontList
                        visible: page.source === "figlet" || page.source === "tdf" || page.source === "ttf"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: omascii.fonts
                        currentIndex: -1
                        highlightMoveDuration: 0
                        ScrollBar.vertical: ScrollBar {}
                        delegate: ItemDelegate {
                            required property var modelData
                            required property int index
                            readonly property bool inUse: page.c.source !== "image" && page.c.font === modelData.name
                            width: fontList.width - 10
                            height: 34
                            focusPolicy: Qt.NoFocus
                            highlighted: inUse
                            contentItem: RowLayout {
                                spacing: 8
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: inUse ? theme.accent : theme.text
                                    elide: Text.ElideRight
                                }
                                Label { text: modelData.detail; color: theme.textFaint; font.pixelSize: 10; elide: Text.ElideRight; Layout.maximumWidth: 120 }
                            }
                            onClicked: {
                                fontList.currentIndex = index;
                                omascii.setOption("font", modelData.name);
                            }
                        }
                        Label {
                            anchors.centerIn: parent
                            width: parent.width - 20
                            visible: fontList.count === 0
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            color: theme.textDim
                            text: omascii.loadingFonts ? "Loading fonts…"
                                : page.source === "tdf" && (page.o.tdf || {}).count === 0 ? "No TheDraw fonts yet."
                                : "No fonts match."
                        }
                    }
                    Button {
                        visible: page.source === "tdf"
                        Layout.fillWidth: true
                        text: (page.o.tdf || {}).count > 0 ? "Update TheDraw fonts" : "Download TheDraw fonts (~3,500)"
                        flat: true
                        focusPolicy: Qt.NoFocus
                        onClicked: omascii.fetchTheDraw()
                    }
                    Button {
                        visible: page.source === "figlet"
                        Layout.fillWidth: true
                        text: "Download more FIGlet fonts"
                        flat: true
                        focusPolicy: Qt.NoFocus
                        onClicked: omascii.fetchMoreFonts()
                    }

                    // Images.
                    ListView {
                        id: imageList
                        visible: page.source === "image"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: omascii.images.filter(i => search.text === "" || i.path.toLowerCase().indexOf(search.text.toLowerCase()) >= 0)
                        ScrollBar.vertical: ScrollBar {}
                        delegate: ItemDelegate {
                            required property var modelData
                            readonly property bool inUse: page.c.source === "image" && page.c.image === modelData.path
                            width: imageList.width - 10
                            height: 52
                            focusPolicy: Qt.NoFocus
                            highlighted: inUse
                            contentItem: RowLayout {
                                spacing: 10
                                Image {
                                    Layout.preferredWidth: 40; Layout.preferredHeight: 40
                                    source: "file://" + modelData.path
                                    sourceSize: Qt.size(80, 80)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Label { Layout.fillWidth: true; text: modelData.name; color: inUse ? theme.accent : theme.text; elide: Text.ElideMiddle }
                                    Label { text: modelData.dir; color: theme.textFaint; font.pixelSize: 10 }
                                }
                            }
                            onClicked: omascii.setOption("image", modelData.path)
                        }
                    }

                    // My boot screens.
                    ListView {
                        id: savedList
                        visible: page.source === "saved"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: omascii.saved
                        ScrollBar.vertical: ScrollBar {}
                        delegate: Rectangle {
                            id: savedTile
                            required property var modelData
                            width: savedList.width - 10
                            height: 108
                            radius: 8
                            color: theme.inset
                            border.color: theme.border
                            clip: true
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label { Layout.fillWidth: true; text: savedTile.modelData.name; color: theme.text; elide: Text.ElideRight; font.pixelSize: 12 }
                                    Label { text: savedTile.modelData.kind; color: theme.textFaint; font.pixelSize: 10 }
                                }
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    AsciiView {
                                        id: thumb
                                        html: savedTile.modelData.html || ""
                                        color: theme.textSoft
                                        fontFamily: "monospace"
                                        pixelSize: 10
                                        zoom: Math.min(1, parent.width / Math.max(1, naturalWidth), parent.height / Math.max(1, naturalHeight))
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Item { Layout.fillWidth: true }
                                    Button { text: "Load"; flat: true; focusPolicy: Qt.NoFocus; implicitHeight: 28; onClicked: omascii.useSaved(savedTile.modelData.id) }
                                    Button {
                                        text: page.deleting === savedTile.modelData.id ? "Really delete?" : "Delete"
                                        flat: true
                                        focusPolicy: Qt.NoFocus
                                        implicitHeight: 28
                                        Material.foreground: page.deleting === savedTile.modelData.id ? theme.danger : undefined
                                        onClicked: {
                                            if (page.deleting === savedTile.modelData.id) {
                                                omascii.removeSaved(savedTile.modelData.id);
                                                page.deleting = "";
                                            } else {
                                                page.deleting = savedTile.modelData.id;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Label {
                            anchors.centerIn: parent
                            visible: savedList.count === 0
                            text: "Nothing saved yet."
                            color: theme.textDim
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                // The art as it will boot, or the intro playing over it.
                Rectangle {
                    id: stage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 200
                    radius: 12
                    color: omascii.previewBackground
                    border.color: theme.border
                    clip: true

                    readonly property string shown: page.playing && omascii.frames.length > 0
                                                    ? omascii.frames[Math.min(page.frame, omascii.frames.length - 1)]
                                                    : omascii.previewHtml
                    AsciiView {
                        id: art
                        anchors.centerIn: parent
                        html: stage.shown
                        color: omascii.previewForeground
                        fontFamily: "monospace"
                        pixelSize: 14
                        zoom: Math.min(1.6, (stage.width - 40) / Math.max(1, naturalWidth), (stage.height - 40) / Math.max(1, naturalHeight))
                    }
                    RowLayout {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        spacing: 8
                        Label {
                            text: omascii.previewCols + " × " + omascii.previewRows + (omascii.rendering ? " · drawing…" : "")
                            color: theme.textMuted
                            font.pixelSize: 11
                            font.family: "monospace"
                        }
                        Label {
                            visible: page.playing
                            text: omascii.loadingFrames ? "building " + page.playingEffect + "…" : "▶ " + page.playingEffect
                            color: theme.accent
                            font.pixelSize: 11
                        }
                    }
                    Button {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        text: page.playing ? "■ Stop" : "▶ Play intro"
                        flat: true
                        focusPolicy: Qt.NoFocus
                        onClicked: page.playing ? page.stop() : page.play("")
                    }
                }

                // --- 2. Fine-tune ---
                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 300
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            SectionLabel { text: "② Fine-tune" }
                            Item { Layout.fillWidth: true }
                            Repeater {
                                model: ["Text layout", "Image", "Colour & style", "Animation"]
                                Chip {
                                    required property string modelData
                                    required property int index
                                    text: modelData
                                    chosen: page.tuneTab === index
                                    onClicked: page.tuneTab = index
                                }
                            }
                        }
                        StackLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            currentIndex: page.tuneTab

                            // Text layout
                            ScrollView {
                                id: textScroll
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: textScroll.availableWidth
                                    spacing: 8
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label { Layout.preferredWidth: 110; text: "Text"; color: theme.textSoft }
                                        TextField {
                                            Layout.fillWidth: true
                                            text: page.c.text || ""
                                            placeholderText: "Type \\n for a new line"
                                            onTextEdited: omascii.setOption("text", text)
                                        }
                                    }
                                    ChipRow { label: "Horizontal"; choices: page.o.layouts || []; value: page.c.hlayout; onPicked: v => omascii.setOption("hlayout", v) }
                                    ChipRow { label: "Vertical"; choices: page.o.layouts || []; value: page.c.vlayout; onPicked: v => omascii.setOption("vlayout", v) }
                                    SliderRow { label: "Wrap width"; from: 0; to: 240; stepSize: 1; decimals: 0; value: page.c.width || 0; onMoved: v => omascii.setOption("width", Math.round(v)) }
                                    SwitchRow { label: "Break on spaces"; checked: page.c.whitespaceBreak === true; onToggled: on => omascii.setOption("whitespaceBreak", on) }
                                    SliderRow {
                                        visible: String(page.c.font || "").startsWith("TTF ")
                                        label: "System font rows"; from: 2; to: 30; stepSize: 1; decimals: 0
                                        value: page.c.ttfRows || 8
                                        onMoved: v => omascii.setOption("ttfRows", Math.round(v))
                                    }
                                    ChipRow {
                                        visible: String(page.c.font || "").startsWith("TTF ")
                                        label: "Drawn with"; choices: ["quadrant", "braille", "halfblock", "blocks", "ascii", "detailed"]
                                        value: page.c.ttfCharset; onPicked: v => omascii.setOption("ttfCharset", v)
                                    }
                                }
                            }

                            // Image
                            ScrollView {
                                id: imageScroll
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: imageScroll.availableWidth
                                    spacing: 8
                                    Label {
                                        Layout.fillWidth: true
                                        text: page.c.source === "image" ? "Using " + page.home(page.c.image) : "Pick an image on the left to use one."
                                        color: page.c.source === "image" ? theme.text : theme.textDim
                                        elide: Text.ElideMiddle
                                    }
                                    SliderRow { label: "Columns"; from: 20; to: 240; stepSize: 1; decimals: 0; value: page.c.imageWidth || 80; onMoved: v => omascii.setOption("imageWidth", Math.round(v)) }
                                    ChipRow { label: "Charset"; choices: page.o.charsets || []; value: page.c.charset; onPicked: v => omascii.setOption("charset", v) }
                                    RowLayout {
                                        visible: page.c.charset === "custom"
                                        Label { Layout.preferredWidth: 110; text: "Ramp"; color: theme.textSoft }
                                        TextField { Layout.fillWidth: true; text: page.c.chars || ""; placeholderText: " .:oO@ (darkest first)"; font.family: "monospace"; onTextEdited: omascii.setOption("chars", text) }
                                    }
                                    SwitchRow { label: "Image colours"; checked: page.c.imageColors === true; onToggled: on => omascii.setOption("imageColors", on) }
                                    SwitchRow { label: "Invert"; hint: "Dense characters for dark pixels."; checked: page.c.invert === true; onToggled: on => omascii.setOption("invert", on) }
                                    SwitchRow { label: "Dither"; checked: page.c.dither === true; onToggled: on => omascii.setOption("dither", on) }
                                    SwitchRow { label: "Auto levels"; checked: page.c.normalize === true; onToggled: on => omascii.setOption("normalize", on) }
                                    SliderRow { label: "Threshold"; from: 0; to: 100; stepSize: 1; decimals: 0; value: page.c.threshold || 50; onMoved: v => omascii.setOption("threshold", Math.round(v)) }
                                    SliderRow { label: "Contrast"; from: 0.2; to: 3; value: page.c.contrast || 1; onMoved: v => omascii.setOption("contrast", Math.round(v * 100) / 100) }
                                    SliderRow { label: "Brightness"; from: 0.2; to: 3; value: page.c.brightness || 1; onMoved: v => omascii.setOption("brightness", Math.round(v * 100) / 100) }
                                }
                            }

                            // Colour & style
                            ScrollView {
                                id: styleScroll
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: styleScroll.availableWidth
                                    spacing: 8
                                    // TheDraw-style looks in one click: colours, shading behind
                                    // the ink, shadow and frame, and a font that suits them.
                                    RowLayout {
                                        visible: (page.o.presets || []).length > 0
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Label { Layout.preferredWidth: 110; Layout.alignment: Qt.AlignTop; topPadding: 6; text: "Presets"; color: theme.textSoft }
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 5
                                            Repeater {
                                                model: page.o.presets || []
                                                delegate: Rectangle {
                                                    id: preset
                                                    required property var modelData
                                                    // "theme" follows the Omarchy theme's own colours.
                                                    readonly property var stops: modelData.swatch === "theme"
                                                        ? ["red", "yellow", "green", "cyan", "blue", "magenta"].map(n => page.paletteHex(n)).filter(h => h.startsWith("#")).map(h => h.slice(1))
                                                        : modelData.swatch || []
                                                    readonly property bool chosen: Object.keys(modelData.options).every(k => JSON.stringify(page.c[k]) === JSON.stringify(modelData.options[k]))
                                                    implicitWidth: presetName.implicitWidth + 58
                                                    implicitHeight: 30
                                                    radius: 7
                                                    color: presetHover.hovered ? theme.hover : theme.inset
                                                    border.color: chosen ? theme.accent : theme.border
                                                    border.width: chosen ? 2 : 1
                                                    Row {
                                                        x: 8; anchors.verticalCenter: parent.verticalCenter
                                                        Repeater {
                                                            model: preset.stops
                                                            Rectangle { required property string modelData; width: 34 / Math.max(1, preset.stops.length); height: 12; color: "#" + modelData }
                                                        }
                                                    }
                                                    Label { id: presetName; x: 48; anchors.verticalCenter: parent.verticalCenter; text: preset.modelData.name; color: preset.chosen ? theme.accent : theme.textSoft; font.pixelSize: 12 }
                                                    ToolTip.visible: presetHover.hovered
                                                    ToolTip.text: page.presetFont ? "With " + preset.modelData.font : "Keeps your font"
                                                    HoverHandler { id: presetHover; cursorShape: Qt.PointingHandCursor }
                                                    TapHandler { onTapped: omascii.applyPreset(preset.modelData.options, page.presetFont ? preset.modelData.font : "") }
                                                }
                                            }
                                        }
                                    }
                                    SwitchRow {
                                        visible: (page.o.presets || []).length > 0
                                        label: "Presets pick a font"
                                        hint: "Switch to the TheDraw font each preset was made with (needs the TheDraw fonts)."
                                        checked: page.presetFont
                                        onToggled: on => page.presetFont = on
                                    }
                                    ColorRow { label: "Colour"; value: page.c.color; onPicked: v => omascii.setOption("color", v) }
                                    ChipRow { label: "Colour mode"; choices: page.o.colorModes || []; value: page.c.colorMode; onPicked: v => omascii.setOption("colorMode", v) }
                                    ColorRow {
                                        visible: ["gradient", "stripes", "split"].indexOf(page.c.colorMode) >= 0
                                        label: page.c.colorMode === "gradient" ? "Gradient to" : "Second colour"
                                        value: page.c.color2
                                        onPicked: v => omascii.setOption("color2", v)
                                    }
                                    // Ready-made colour runs, each shown as its gradient.
                                    RowLayout {
                                        visible: page.c.colorMode === "palette"
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Label { Layout.preferredWidth: 110; Layout.alignment: Qt.AlignTop; topPadding: 6; text: "Palette"; color: theme.textSoft }
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 5
                                            Repeater {
                                                model: page.o.palettes || []
                                                delegate: Rectangle {
                                                    id: pal
                                                    required property string modelData
                                                    readonly property var stops: (page.o.paletteStops || {})[modelData] || []
                                                    readonly property bool chosen: (page.c.colorPalette || "sunset") === modelData
                                                    implicitWidth: palName.implicitWidth + 58
                                                    implicitHeight: 30
                                                    radius: 7
                                                    color: palHover.hovered ? theme.hover : theme.inset
                                                    border.color: chosen ? theme.accent : theme.border
                                                    border.width: chosen ? 2 : 1
                                                    Row {
                                                        x: 8; anchors.verticalCenter: parent.verticalCenter
                                                        Repeater {
                                                            model: pal.stops
                                                            Rectangle { required property string modelData; width: 34 / Math.max(1, pal.stops.length); height: 12; color: "#" + modelData }
                                                        }
                                                    }
                                                    Label { id: palName; x: 48; anchors.verticalCenter: parent.verticalCenter; text: pal.modelData; color: pal.chosen ? theme.accent : theme.textSoft; font.pixelSize: 12 }
                                                    HoverHandler { id: palHover; cursorShape: Qt.PointingHandCursor }
                                                    TapHandler { onTapped: omascii.setOption("colorPalette", pal.modelData) }
                                                }
                                            }
                                        }
                                    }
                                    ChipRow {
                                        visible: ["gradient", "rainbow", "palette"].indexOf(page.c.colorMode) >= 0
                                        label: "Direction"
                                        choices: page.o.gradients || []
                                        value: page.c.gradient
                                        onPicked: v => omascii.setOption("gradient", v)
                                    }
                                    ChipRow {
                                        visible: (page.o.inkBgs || []).length > 0
                                        label: "Ink background"
                                        choices: page.o.inkBgs || []
                                        value: page.c.inkBg || "none"
                                        onPicked: v => omascii.setOption("inkBg", v)
                                    }
                                    SwitchRow { label: "Font colours"; hint: "Keep a TheDraw colour font's own colours."; checked: page.c.fontColors === true; onToggled: on => omascii.setOption("fontColors", on) }
                                    RowLayout {
                                        Label { Layout.preferredWidth: 110; text: "Fill"; color: theme.textSoft }
                                        TextField { Layout.preferredWidth: 160; text: page.c.fill || ""; placeholderText: "█ or 01"; font.family: "monospace"; onTextEdited: omascii.setOption("fill", text) }
                                    }
                                    ChipRow { label: "Flip"; choices: page.o.flips || []; value: page.c.flip; onPicked: v => omascii.setOption("flip", v) }
                                    ChipRow { label: "Shadow"; choices: page.o.shadows || []; value: page.c.shadow; onPicked: v => omascii.setOption("shadow", v) }
                                    ChipRow { label: "Border"; choices: page.o.borders || []; value: page.c.border; onPicked: v => omascii.setOption("border", v) }
                                    SliderRow { label: "Padding"; from: 0; to: 6; stepSize: 1; decimals: 0; value: page.c.padding || 0; onMoved: v => omascii.setOption("padding", Math.round(v)) }
                                }
                            }

                            // Animation
                            ScrollView {
                                id: animScroll
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: animScroll.availableWidth
                                    spacing: 8
                                    ChipRow { label: "On boot"; choices: page.o.styles || []; value: page.c.style; onPicked: v => omascii.setOption("style", v) }
                                    RowLayout {
                                        visible: page.c.style === "animated"
                                        Label {
                                            Layout.fillWidth: true
                                            text: (page.c.effects || []).length + " intro effects · fewer make a smaller initramfs"
                                            color: theme.textMuted
                                            font.pixelSize: 12
                                        }
                                        Button { text: "Select all"; flat: true; focusPolicy: Qt.NoFocus; onClicked: omascii.setEffects(page.o.effects || []) }
                                        Button { text: "Core 11"; flat: true; focusPolicy: Qt.NoFocus; onClicked: omascii.setEffects(page.o.coreEffects || []) }
                                        Button { text: "Clear"; flat: true; focusPolicy: Qt.NoFocus; onClicked: omascii.setEffects([]) }
                                    }
                                    // One block per group: the core set, the rest of ttfx,
                                    // the screensaver's own and its presets, omascii's originals.
                                    Repeater {
                                        model: page.c.style === "animated"
                                               ? ((page.o.effectGroups || []).length ? page.o.effectGroups
                                                                                     : [{ id: "all", name: "Effects", effects: page.o.effects || [] }])
                                               : []
                                        delegate: ColumnLayout {
                                            id: group
                                            required property var modelData
                                            readonly property var chosen: (page.c.effects || []).filter(e => group.modelData.effects.indexOf(e) >= 0)
                                            Layout.fillWidth: true
                                            spacing: 0
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.topMargin: 6
                                                SectionLabel { text: group.modelData.name }
                                                Label { text: group.chosen.length + " of " + group.modelData.effects.length; color: theme.textFaint; font.pixelSize: 11 }
                                                Item { Layout.fillWidth: true }
                                                Button {
                                                    text: "All"; flat: true; focusPolicy: Qt.NoFocus
                                                    onClicked: omascii.setEffects((page.o.effects || []).filter(e => (page.c.effects || []).indexOf(e) >= 0 || group.modelData.effects.indexOf(e) >= 0))
                                                }
                                                Button {
                                                    text: "None"; flat: true; focusPolicy: Qt.NoFocus
                                                    onClicked: omascii.setEffects((page.c.effects || []).filter(e => group.modelData.effects.indexOf(e) < 0))
                                                }
                                            }
                                            GridLayout {
                                                Layout.fillWidth: true
                                                columns: Math.max(2, Math.floor(width / 190))
                                                rowSpacing: 0
                                                columnSpacing: 6
                                                Repeater {
                                                    model: group.modelData.effects
                                                    delegate: RowLayout {
                                                        required property string modelData
                                                        spacing: 0
                                                        CheckBox {
                                                            Layout.fillWidth: true
                                                            text: modelData
                                                            checked: (page.c.effects || []).indexOf(modelData) >= 0
                                                            focusPolicy: Qt.NoFocus
                                                            onClicked: omascii.toggleEffect(modelData)
                                                        }
                                                        ToolButton {
                                                            text: "▶"
                                                            focusPolicy: Qt.NoFocus
                                                            ToolTip.visible: hovered
                                                            ToolTip.text: "Play " + modelData + " in the preview"
                                                            onClicked: page.play(modelData)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    SliderRow {
                                        visible: page.c.style === "animated"
                                        label: "Frames per intro"; from: 50; to: 500; stepSize: 10; decimals: 0
                                        value: page.c.maxFrames || 200
                                        onMoved: v => omascii.setOption("maxFrames", Math.round(v))
                                    }
                                }
                            }
                        }
                    }
                }

                // --- 3. Keep it ---
                Card {
                    Layout.fillWidth: true
                    implicitHeight: keepRow.implicitHeight + 24
                    RowLayout {
                        id: keepRow
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        SectionLabel { text: "③" }
                        TextField {
                            id: saveName
                            Layout.fillWidth: true
                            Layout.minimumWidth: 120
                            placeholderText: (page.c.source === "image" ? page.home(page.c.image).split("/").pop() : (page.c.font || "")) + " · " + (page.c.text || "")
                        }
                        Button { text: "★ Save"; flat: true; focusPolicy: Qt.NoFocus; onClicked: { omascii.saveToLibrary(saveName.text || saveName.placeholderText); saveName.text = ""; } }
                        Button { text: "Export GIF"; flat: true; focusPolicy: Qt.NoFocus; onClicked: omascii.exportGif() }
                        Button { text: "Undo boot change"; flat: true; focusPolicy: Qt.NoFocus; onClicked: omascii.restoreBoot() }
                        AccentButton {
                            text: "Apply to boot"
                            onClicked: omascii.applyToBoot()
                        }
                        KeyCap { text: "Ctrl ⏎" }
                    }
                }
            }
        }
    }

    // A row of choices with a caption, for omascii's option lists.
    component ChipRow: RowLayout {
        id: chipRow
        property string label
        property var choices: []
        property var value
        signal picked(string value)
        Layout.fillWidth: true
        spacing: 6
        Label { Layout.preferredWidth: 110; text: chipRow.label; color: theme.textSoft; Layout.alignment: Qt.AlignTop; topPadding: 6 }
        Flow {
            Layout.fillWidth: true
            spacing: 5
            Repeater {
                model: chipRow.choices
                Chip {
                    required property string modelData
                    text: modelData
                    chosen: chipRow.value === modelData
                    onClicked: chipRow.picked(modelData)
                }
            }
        }
    }

    // The theme's named colours as swatches, plus a hex of your own.
    component ColorRow: RowLayout {
        id: colorRow
        property string label
        property var value
        signal picked(string value)
        Layout.fillWidth: true
        spacing: 6
        Label { Layout.preferredWidth: 110; text: colorRow.label; color: theme.textSoft; Layout.alignment: Qt.AlignTop; topPadding: 4 }
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: Object.keys(omascii.palette)
                Rectangle {
                    required property string modelData
                    width: 24; height: 24; radius: 5
                    color: page.paletteHex(modelData)
                    border.color: colorRow.value === modelData ? theme.text : theme.borderStrong
                    border.width: colorRow.value === modelData ? 2 : 1
                    ToolTip.visible: swatchHover.hovered
                    ToolTip.text: modelData
                    HoverHandler { id: swatchHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: colorRow.picked(modelData) }
                }
            }
            TextField {
                width: 100
                height: 28
                text: String(colorRow.value || "").startsWith("#") ? colorRow.value : ""
                placeholderText: "#rrggbb"
                font.family: "monospace"
                font.pixelSize: 11
                onEditingFinished: if (/^#[0-9a-fA-F]{6}$/.test(text.trim())) colorRow.picked(text.trim())
            }
            ColorButton {
                value: colorRow.value || ""
                fallback: page.paletteHex(colorRow.value || "accent")
                title: colorRow.label
                onPicked: hex => colorRow.picked(hex)
            }
        }
    }
}
