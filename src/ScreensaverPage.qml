import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Omacraft 1.0

// Screensaver: the Omarchy screensaver's art, its effects and when it starts,
// laid out like Boot Splash. Everything here goes through `saver`, which only
// writes the screensaver's files: never omascii's boot design or Plymouth.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property bool dialogOpen: false
    readonly property var d: saver.design
    readonly property var o: saver.options
    // The list being browsed on the left, or "" to follow the art in use.
    property string browsing: ""
    // Where the art comes from: current, omarchy, figlet, tdf, ttf or image.
    readonly property string source: browsing !== "" ? browsing : saver.artSource === "design"
                            ? (d.source === "image" ? "image" : String(d.font || "").startsWith("TTF ") ? "ttf"
                               : String(d.font || "").startsWith("TDF ") ? "tdf" : "figlet")
                            : saver.artSource
    property int tuneTab: 0
    property bool playing: false
    property int frame: 0
    property string playingEffect: ""
    readonly property bool designing: saver.artSource === "design"
    readonly property var shortcuts: [
        { keys: "↑ ↓", action: "Browse fonts, using each one" },
        { keys: "Ctrl F", action: "Search the list" },
        { keys: "Ctrl P", action: "Play an effect over the art" },
        { keys: "Ctrl Enter", action: "Apply to the screensaver" },
        { keys: "Ctrl T", action: "Apply and start the screensaver now" },
        { keys: "Ctrl Z", action: "Undo (Ctrl Shift Z redo)" },
        { keys: "Esc", action: "Stop the effect, clear the search" }
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
        if (saver.error !== "" || saver.notice !== "") {
            saver.dismissMessages();
            return true;
        }
        return false;
    }
    function acceptDialog() {}

    function useSource(name) {
        search.text = "";
        if (name === "current" || name === "omarchy") {
            page.browsing = "";
            saver.setArtSource(name);
            return;
        }
        page.browsing = name;
        if (name === "image") {
            saver.loadImages();
            if (d.image)
                saver.setOption("image", d.image);
            return;
        }
        saver.fontSet = name;
    }
    function browse(step) {
        const list = saver.fonts;
        if (list.length === 0) return;
        let i = Math.max(0, Math.min(list.length - 1, fontList.currentIndex + step));
        fontList.currentIndex = i;
        saver.setOption("font", list[i].name);
    }
    function allEffects() {
        let all = [];
        for (const group of (o.effectGroups || []))
            all = all.concat(group.effects);
        return all;
    }
    function play(effect) {
        let chosen = effect;
        if (!chosen) {
            // Omarchy's own picks at random among every ttfx effect; so does this.
            const pool = saver.mode === "custom" && saver.effects.length ? saver.effects : page.allEffects().filter(e => e.indexOf("-") < 0);
            chosen = pool.length ? pool[Math.floor(Math.random() * pool.length)] : "";
        }
        if (chosen === "") return;
        page.playingEffect = chosen;
        page.frame = 0;
        page.playing = true;
        saver.loadFrames(chosen);
    }
    function stop() {
        page.playing = false;
        player.stop();
    }
    function minutes(seconds) {
        return seconds % 60 === 0 ? (seconds / 60) + " min" : seconds >= 60 ? Math.floor(seconds / 60) + " min " + (seconds % 60) + " s" : seconds + " s";
    }

    onActiveChanged: if (active && !saver.loaded) saver.refresh(); else if (active) saver.refreshSystem()

    Connections {
        target: saver
        function onFramesChanged() {
            if (page.playing && saver.frames.length > 0) {
                page.frame = 0;
                player.restart();
            } else if (page.playing && !saver.loadingFrames) {
                page.playing = false;
            }
        }
    }

    Timer {
        id: player
        interval: Math.max(10, Math.round(1000 / saver.fps))
        repeat: true
        onTriggered: {
            if (page.frame + 1 >= saver.frames.length) {
                page.stop();
                return;
            }
            page.frame++;
        }
    }

    readonly property bool keys: active
    readonly property bool letters: keys && keysFree
    readonly property bool listing: page.source === "figlet" || page.source === "tdf" || page.source === "ttf"
    Shortcut { sequence: "Up"; context: Qt.ApplicationShortcut; enabled: page.keys && (page.keysFree || search.activeFocus) && page.listing; onActivated: page.browse(-1) }
    Shortcut { sequence: "Down"; context: Qt.ApplicationShortcut; enabled: page.keys && (page.keysFree || search.activeFocus) && page.listing; onActivated: page.browse(1) }
    Shortcut { sequence: "Ctrl+F"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: search.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+P"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.playing ? page.stop() : page.play("") }
    Shortcut { sequences: ["Ctrl+Return", "Ctrl+Enter"]; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: saver.apply() }
    Shortcut { sequence: "Ctrl+T"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: saver.tryIt() }
    Shortcut { sequence: "Ctrl+Z"; context: Qt.ApplicationShortcut; enabled: page.letters; onActivated: saver.undo() }
    Shortcut { sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]; context: Qt.ApplicationShortcut; enabled: page.letters; onActivated: saver.redo() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        PageHeader {
            title: "Screensaver"
            subtitle: "The Omarchy screensaver: its art, its effects and when it starts. Only the screensaver; the boot screen is Boot Splash's."
            glyph: "\u{f1104}"
            StatePill {
                visible: saver.loaded
                text: saver.dirty ? "Not applied yet"
                    : saver.applied.mode === "custom" ? "Plays your " + (saver.applied.effects || []).length + " effects"
                    : "Plays Omarchy's effects"
                on: !saver.dirty
                warn: saver.dirty
            }
            Button { text: "Undo"; flat: true; focusPolicy: Qt.NoFocus; enabled: saver.canUndo; onClicked: saver.undo() }
            Button { text: "Redo"; flat: true; focusPolicy: Qt.NoFocus; enabled: saver.canRedo; onClicked: saver.redo() }
        }

        // The screensaver itself: on or off, and when it starts.
        Card {
            Layout.fillWidth: true
            implicitHeight: systemColumn.implicitHeight + 20
            GridLayout {
                id: systemColumn
                anchors.fill: parent
                anchors.margins: 10
                // Side by side when there's room, stacked when not.
                columns: width > 900 ? 2 : 1
                columnSpacing: 16
                rowSpacing: 6
                RowLayout {
                    spacing: 12
                    Switch {
                        checked: saver.enabled
                        focusPolicy: Qt.NoFocus
                        onToggled: {
                            const wanted = checked;
                            checked = Qt.binding(() => saver.enabled);
                            saver.setEnabled(wanted);
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Label { text: saver.enabled ? "Screensaver on" : "Screensaver off"; color: theme.text }
                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: saver.enabled ? "After " + page.minutes(saver.idleSeconds) + " idle · locks after " + page.minutes(saver.lockSeconds)
                                                : "Omarchy won't start it when idle"
                            color: theme.textFaint
                            font.pixelSize: 11
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Label { text: "Start after"; color: theme.textSoft }
                    Slider {
                        id: idle
                        Layout.fillWidth: true
                        Layout.minimumWidth: 120
                        from: 30; to: 1800; stepSize: 30
                        value: saver.idleSeconds
                        focusPolicy: Qt.NoFocus
                        onMoved: idleCommit.restart()
                        Timer { id: idleCommit; interval: 300; onTriggered: saver.setIdleSeconds(Math.round(idle.value)) }
                    }
                    Label { text: page.minutes(Math.round(idle.value)); color: theme.textMuted; font.family: "monospace"; Layout.preferredWidth: 90 }
                    Button { text: "▶ Try it"; flat: true; focusPolicy: Qt.NoFocus; onClicked: saver.tryIt() }
                }
            }
        }

        MessageBar {
            error: saver.error
            notice: saver.notice
            onDismissed: saver.dismissMessages()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // --- 1. The art ---
            Card {
                Layout.preferredWidth: Math.min(330, page.width * 0.34)
                Layout.minimumWidth: 200
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    SectionLabel { text: "① The art" }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 5
                        Repeater {
                            model: [{ id: "current", name: "As it is" }, { id: "omarchy", name: "Omarchy logo" },
                                    { id: "figlet", name: "FIGlet", designer: true }, { id: "tdf", name: "TheDraw", designer: true },
                                    { id: "ttf", name: "System", designer: true }, { id: "image", name: "Image", designer: true }]
                            Chip {
                                required property var modelData
                                text: modelData.name
                                chosen: page.source === modelData.id
                                dimmed: modelData.designer === true && !saver.available
                                onClicked: if (modelData.designer !== true || saver.available) page.useSource(modelData.id)
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: page.source === "current" || page.source === "omarchy" || !saver.available
                        wrapMode: Text.WordWrap
                        color: theme.textDim
                        font.pixelSize: 12
                        text: !saver.available && page.listing ? "Designing art needs omascii: install it on the Plugin Suite page."
                            : page.source === "current" ? "Keeps ~/.config/omarchy/branding/screensaver.txt as it is: Omarchy's menu edits it too (Style › Screensaver)."
                            : page.source === "omarchy" ? "Omarchy's own logo, the screensaver's default."
                            : "Pick a font, or an image, to design new art."
                    }
                    TextField {
                        id: search
                        Layout.fillWidth: true
                        visible: (page.listing || page.source === "image") && saver.available
                        placeholderText: page.source === "image" ? "Image path, or filter below" : "Search " + saver.fontTotal + " fonts"
                        onTextChanged: if (page.source !== "image") saver.fontFilter = text
                        onAccepted: if (page.source === "image" && text.trim() !== "") saver.setOption("image", text.trim())
                    }

                    // Fonts.
                    ListView {
                        id: fontList
                        visible: page.listing && saver.available
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: saver.fonts
                        currentIndex: -1
                        highlightMoveDuration: 0
                        ScrollBar.vertical: ScrollBar {}
                        delegate: ItemDelegate {
                            required property var modelData
                            required property int index
                            readonly property bool inUse: page.designing && page.d.source !== "image" && page.d.font === modelData.name
                            width: fontList.width - 10
                            height: 34
                            focusPolicy: Qt.NoFocus
                            highlighted: inUse
                            contentItem: RowLayout {
                                spacing: 8
                                Label { Layout.fillWidth: true; text: modelData.name; color: inUse ? theme.accent : theme.text; elide: Text.ElideRight }
                                Label { text: modelData.detail; color: theme.textFaint; font.pixelSize: 10; elide: Text.ElideRight; Layout.maximumWidth: 120 }
                            }
                            onClicked: {
                                fontList.currentIndex = index;
                                saver.setOption("font", modelData.name);
                            }
                        }
                        Label {
                            anchors.centerIn: parent
                            width: parent.width - 20
                            visible: fontList.count === 0
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            color: theme.textDim
                            text: saver.loadingFonts ? "Loading fonts…" : page.source === "tdf" ? "No TheDraw fonts: Boot Splash downloads them." : "No fonts match."
                        }
                    }

                    // Images.
                    ListView {
                        id: imageList
                        visible: page.source === "image" && saver.available
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: saver.images.filter(i => search.text === "" || i.path.toLowerCase().indexOf(search.text.toLowerCase()) >= 0)
                        ScrollBar.vertical: ScrollBar {}
                        delegate: ItemDelegate {
                            required property var modelData
                            readonly property bool inUse: page.designing && page.d.source === "image" && page.d.image === modelData.path
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
                            onClicked: saver.setOption("image", modelData.path)
                        }
                    }
                    Item { Layout.fillHeight: true; visible: !fontList.visible && !imageList.visible }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                // The art on the screensaver's black, or an effect playing over it.
                Rectangle {
                    id: stage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 200
                    radius: 12
                    color: "#000000"
                    border.color: theme.border
                    clip: true

                    readonly property bool showingFrames: page.playing && saver.frames.length > 0
                    AsciiView {
                        anchors.centerIn: parent
                        html: stage.showingFrames ? saver.frames[Math.min(page.frame, saver.frames.length - 1)] : saver.artHtml
                        color: "#e0e2de"
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
                            text: saver.artCols + " × " + saver.artRows + (saver.rendering ? " · drawing…" : "")
                            color: theme.textMuted
                            font.pixelSize: 11
                            font.family: "monospace"
                        }
                        Label {
                            visible: page.playing
                            text: saver.loadingFrames ? "building " + page.playingEffect + "…" : "▶ " + page.playingEffect
                            color: theme.accent
                            font.pixelSize: 11
                        }
                    }
                    Button {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        text: page.playing ? "■ Stop" : "▶ Play an effect"
                        flat: true
                        focusPolicy: Qt.NoFocus
                        onClicked: page.playing ? page.stop() : page.play("")
                    }
                }

                // --- 2. Effects and fine-tuning ---
                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 300
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6
                        Flow {
                            Layout.fillWidth: true
                            spacing: 5
                            SectionLabel { text: "②  "; height: 28; verticalAlignment: Text.AlignVCenter }
                            Repeater {
                                model: ["Effects", "Timing", "Text", "Style", "Image"]
                                Chip {
                                    required property string modelData
                                    required property int index
                                    text: modelData
                                    chosen: page.tuneTab === index
                                    dimmed: index >= 2 && !page.designing
                                    onClicked: page.tuneTab = index
                                }
                            }
                        }
                        StackLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            currentIndex: page.tuneTab

                            // Effects
                            ScrollView {
                                id: effectScroll
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: effectScroll.availableWidth
                                    spacing: 8
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Label { text: "Plays"; color: theme.textSoft; height: 32; width: 60; verticalAlignment: Text.AlignVCenter }
                                        Chip { text: "Omarchy's own"; chosen: saver.mode === "omarchy"; onClicked: saver.setMode("omarchy") }
                                        Chip { text: "Effects I pick"; chosen: saver.mode === "custom"; onClicked: saver.setMode("custom") }
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        color: theme.textMuted
                                        font.pixelSize: 12
                                        text: saver.mode === "omarchy"
                                              ? "A random ttfx effect each time, as Omarchy ships it. Nothing extra is installed."
                                              : saver.effects.length + " effects, from the same sets as the boot screen's intros. "
                                                + (saver.hook === "ours" ? "Screensaver's hook is installed."
                                                   : saver.hook === "foreign" ? "/usr/local/bin/omarchy-screensaver belongs to something else, so these can't play."
                                                   : "Applying installs a small hook in /usr/local/bin (asks for your password once).")
                                    }
                                    RowLayout {
                                        visible: saver.mode === "custom"
                                        Item { Layout.fillWidth: true }
                                        Button { text: "Select all"; flat: true; focusPolicy: Qt.NoFocus; onClicked: saver.setEffects(page.allEffects()) }
                                        Button { text: "Clear"; flat: true; focusPolicy: Qt.NoFocus; onClicked: saver.setEffects([]) }
                                    }
                                    Repeater {
                                        model: saver.mode === "custom" ? (page.o.effectGroups || []) : []
                                        delegate: ColumnLayout {
                                            id: group
                                            required property var modelData
                                            readonly property var chosen: saver.effects.filter(e => group.modelData.effects.indexOf(e) >= 0)
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
                                                    onClicked: saver.setEffects(page.allEffects().filter(e => saver.effects.indexOf(e) >= 0 || group.modelData.effects.indexOf(e) >= 0))
                                                }
                                                Button {
                                                    text: "None"; flat: true; focusPolicy: Qt.NoFocus
                                                    onClicked: saver.setEffects(saver.effects.filter(e => group.modelData.effects.indexOf(e) < 0))
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
                                                            checked: saver.effects.indexOf(modelData) >= 0
                                                            focusPolicy: Qt.NoFocus
                                                            onClicked: saver.toggleEffect(modelData)
                                                        }
                                                        ToolButton {
                                                            text: "▶"
                                                            focusPolicy: Qt.NoFocus
                                                            ToolTip.visible: hovered
                                                            ToolTip.text: "Play " + modelData + " over the art"
                                                            onClicked: page.play(modelData)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Timing
                            ScrollView {
                                id: timingScroll
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: timingScroll.availableWidth
                                    spacing: 8
                                    Label {
                                        Layout.fillWidth: true
                                        visible: saver.mode === "omarchy"
                                        wrapMode: Text.WordWrap
                                        color: theme.textMuted
                                        font.pixelSize: 12
                                        text: "Omarchy's own effects play at its own pace. These apply to the effects you pick."
                                    }
                                    ChipRow {
                                        label: "Order"; choices: ["random", "sequence"]; value: saver.order
                                        onPicked: v => saver.setOrder(v)
                                    }
                                    SliderRow { label: "Frame rate"; from: 15; to: 240; stepSize: 5; decimals: 0; suffix: " fps"; value: saver.frameRate; onMoved: v => saver.setFrameRate(Math.round(v)) }
                                    SliderRow { label: "Rest between"; from: 0; to: 60; stepSize: 1; decimals: 0; suffix: " s"; value: saver.pause; onMoved: v => saver.setPause(Math.round(v)) }
                                }
                            }

                            // Text
                            ScrollView {
                                id: textScroll
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: textScroll.availableWidth
                                    spacing: 8
                                    DesignHint {}
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label { Layout.preferredWidth: 110; text: "Word"; color: theme.textSoft }
                                        TextField {
                                            Layout.fillWidth: true
                                            enabled: saver.available
                                            text: page.d.text || ""
                                            placeholderText: "Type \\n for a new line"
                                            onTextEdited: saver.setOption("text", text)
                                        }
                                    }
                                    ChipRow { label: "Horizontal"; choices: page.o.layouts || []; value: page.d.hlayout; onPicked: v => saver.setOption("hlayout", v) }
                                    ChipRow { label: "Vertical"; choices: page.o.layouts || []; value: page.d.vlayout; onPicked: v => saver.setOption("vlayout", v) }
                                    SliderRow { label: "Wrap width"; from: 0; to: 240; stepSize: 1; decimals: 0; value: page.d.width || 0; onMoved: v => saver.setOption("width", Math.round(v)) }
                                    SwitchRow { label: "Break on spaces"; checked: page.d.whitespaceBreak === true; onToggled: on => saver.setOption("whitespaceBreak", on) }
                                    SliderRow {
                                        visible: String(page.d.font || "").startsWith("TTF ")
                                        label: "System font rows"; from: 2; to: 30; stepSize: 1; decimals: 0
                                        value: page.d.ttfRows || 8
                                        onMoved: v => saver.setOption("ttfRows", Math.round(v))
                                    }
                                }
                            }

                            // Style
                            ScrollView {
                                id: styleScroll
                                contentWidth: availableWidth
                                clip: true
                                ColumnLayout {
                                    width: styleScroll.availableWidth
                                    spacing: 8
                                    DesignHint {}
                                    Label {
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        color: theme.textMuted
                                        font.pixelSize: 12
                                        text: "The effects colour the screensaver, so the art is shapes only."
                                    }
                                    RowLayout {
                                        Label { Layout.preferredWidth: 110; text: "Fill"; color: theme.textSoft }
                                        TextField { Layout.preferredWidth: 160; text: page.d.fill || ""; placeholderText: "█ or 01"; font.family: "monospace"; onTextEdited: saver.setOption("fill", text) }
                                    }
                                    ChipRow { label: "Flip"; choices: page.o.flips || []; value: page.d.flip; onPicked: v => saver.setOption("flip", v) }
                                    ChipRow { label: "Shadow"; choices: page.o.shadows || []; value: page.d.shadow; onPicked: v => saver.setOption("shadow", v) }
                                    ChipRow { label: "Border"; choices: page.o.borders || []; value: page.d.border; onPicked: v => saver.setOption("border", v) }
                                    SliderRow { label: "Padding"; from: 0; to: 6; stepSize: 1; decimals: 0; value: page.d.padding || 0; onMoved: v => saver.setOption("padding", Math.round(v)) }
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
                                        text: page.designing && page.d.source === "image" ? "Using " + String(page.d.image).replace(/^\/home\/[^/]+/, "~") : "Pick an image on the left to use one."
                                        color: page.designing && page.d.source === "image" ? theme.text : theme.textDim
                                        elide: Text.ElideMiddle
                                    }
                                    SliderRow { label: "Columns"; from: 20; to: 240; stepSize: 1; decimals: 0; value: page.d.imageWidth || 80; onMoved: v => saver.setOption("imageWidth", Math.round(v)) }
                                    ChipRow { label: "Charset"; choices: page.o.charsets || []; value: page.d.charset; onPicked: v => saver.setOption("charset", v) }
                                    RowLayout {
                                        visible: page.d.charset === "custom"
                                        Label { Layout.preferredWidth: 110; text: "Ramp"; color: theme.textSoft }
                                        TextField { Layout.fillWidth: true; text: page.d.chars || ""; placeholderText: " .:oO@ (darkest first)"; font.family: "monospace"; onTextEdited: saver.setOption("chars", text) }
                                    }
                                    SwitchRow { label: "Invert"; hint: "Dense characters for dark pixels."; checked: page.d.invert === true; onToggled: on => saver.setOption("invert", on) }
                                    SwitchRow { label: "Dither"; checked: page.d.dither === true; onToggled: on => saver.setOption("dither", on) }
                                    SwitchRow { label: "Auto levels"; checked: page.d.normalize === true; onToggled: on => saver.setOption("normalize", on) }
                                    SliderRow { label: "Threshold"; from: 0; to: 100; stepSize: 1; decimals: 0; value: page.d.threshold || 50; onMoved: v => saver.setOption("threshold", Math.round(v)) }
                                    SliderRow { label: "Contrast"; from: 0.2; to: 3; value: page.d.contrast || 1; onMoved: v => saver.setOption("contrast", Math.round(v * 100) / 100) }
                                    SliderRow { label: "Brightness"; from: 0.2; to: 3; value: page.d.brightness || 1; onMoved: v => saver.setOption("brightness", Math.round(v * 100) / 100) }
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
                        Item { Layout.fillWidth: true; visible: keepRow.width <= 760 }
                        Label {
                            Layout.fillWidth: true
                            visible: keepRow.width > 760
                            text: "Writes ~/.config/omarchy/branding/screensaver.txt and Screensaver's settings. The boot screen stays as it is."
                            color: theme.textFaint
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                        Button {
                            visible: saver.hasBackup
                            text: "Put back the old text"
                            flat: true
                            focusPolicy: Qt.NoFocus
                            ToolTip.visible: hovered
                            ToolTip.text: "The screensaver text from before Screensaver first changed it"
                            onClicked: saver.restoreBackup()
                        }
                        Button {
                            visible: saver.hook === "ours" || saver.hook === "outdated"
                            enabled: !saver.busy
                            text: saver.hook === "outdated" ? "Update hook" : "Remove hook"
                            flat: true
                            focusPolicy: Qt.NoFocus
                            ToolTip.visible: hovered
                            ToolTip.text: saver.hook === "outdated" ? "A newer hook came with this OmaCraft" : "Back to Omarchy's screensaver script, untouched"
                            onClicked: saver.hook === "outdated" ? saver.installHook() : saver.removeHook()
                        }
                        Button { text: "Apply and try"; flat: true; focusPolicy: Qt.NoFocus; enabled: !saver.busy; onClicked: saver.tryIt() }
                        AccentButton {
                            text: "Apply to screensaver"
                            enabled: !saver.busy
                            onClicked: saver.apply()
                        }
                        KeyCap { text: "Ctrl ⏎"; visible: keepRow.width > 560 }
                    }
                }
            }
        }
    }

    // Shown on the design tabs while the art isn't a design.
    component DesignHint: Label {
        Layout.fillWidth: true
        visible: !page.designing
        wrapMode: Text.WordWrap
        color: theme.textDim
        font.pixelSize: 12
        text: "These shape a designed word or image. Pick FIGlet, TheDraw, System or Image on the left to design one; editing here starts one from your last design."
    }

    // A row of choices with a caption.
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
}
