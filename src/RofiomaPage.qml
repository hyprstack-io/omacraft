import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// ROFIoma: rofi-styled popups (the power menu, menus of your own, the emoji
// and glyph pickers, a keybinding cheatsheet) and swaync's notifications.
// Every change is written straight to rofioma.json and the files rofi and
// swaync read; the stage on the left draws the popup as they will.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property bool dialogOpen: packConfirm.visible
    readonly property var shortcuts: [
        { keys: "T / Shift T", action: "Next / previous tab" },
        { keys: "O", action: "Open this tab's popup for real" },
        { keys: "R", action: "Play the stage's entrance again" }
    ]

    readonly property var tabs: [
        { id: "power", name: "Power" },
        { id: "menus", name: "Menus" },
        { id: "symbols", name: "Emoji & Glyphs" },
        { id: "keybinds", name: "Keybinds" },
        { id: "notify", name: "Notifications" },
        { id: "look", name: "Look" }
    ]
    property string tab: ["power", "menus", "symbols", "keybinds", "notify", "look"].indexOf(startTab) >= 0 ? startTab : "power"
    property string menuId: ""
    property bool showCenter: false

    readonly property var cfg: rofioma.config
    readonly property var pal: rofioma.palette
    readonly property var power: cfg.power || {}

    // Hyprland's name for a pressed key, and the combo with its modifiers,
    // as the overlay's cheatsheet reads them. Shifted symbols bind as their
    // unshifted key.
    function keyName(event) {
        const k = event.key;
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k);
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k);
        if (k >= Qt.Key_F1 && k <= Qt.Key_F24) return "F" + (k - Qt.Key_F1 + 1);
        const named = {};
        named[Qt.Key_Return] = "RETURN"; named[Qt.Key_Enter] = "RETURN"; named[Qt.Key_Space] = "SPACE";
        named[Qt.Key_Tab] = "TAB"; named[Qt.Key_Backtab] = "TAB"; named[Qt.Key_Backspace] = "BACKSPACE";
        named[Qt.Key_Delete] = "DELETE"; named[Qt.Key_Insert] = "INSERT"; named[Qt.Key_Home] = "HOME"; named[Qt.Key_End] = "END";
        named[Qt.Key_PageUp] = "PAGE_UP"; named[Qt.Key_PageDown] = "PAGE_DOWN"; named[Qt.Key_Print] = "PRINT";
        named[Qt.Key_Left] = "LEFT"; named[Qt.Key_Right] = "RIGHT"; named[Qt.Key_Up] = "UP"; named[Qt.Key_Down] = "DOWN";
        named[Qt.Key_Comma] = "COMMA"; named[Qt.Key_Less] = "COMMA"; named[Qt.Key_Period] = "PERIOD"; named[Qt.Key_Greater] = "PERIOD";
        named[Qt.Key_Slash] = "SLASH"; named[Qt.Key_Question] = "SLASH"; named[Qt.Key_Minus] = "MINUS"; named[Qt.Key_Underscore] = "MINUS";
        named[Qt.Key_Equal] = "EQUAL"; named[Qt.Key_Plus] = "EQUAL"; named[Qt.Key_Semicolon] = "SEMICOLON"; named[Qt.Key_Colon] = "SEMICOLON";
        named[Qt.Key_Apostrophe] = "APOSTROPHE"; named[Qt.Key_QuoteDbl] = "APOSTROPHE"; named[Qt.Key_QuoteLeft] = "GRAVE";
        named[Qt.Key_AsciiTilde] = "GRAVE"; named[Qt.Key_BracketLeft] = "BRACKETLEFT"; named[Qt.Key_BraceLeft] = "BRACKETLEFT";
        named[Qt.Key_BracketRight] = "BRACKETRIGHT"; named[Qt.Key_BraceRight] = "BRACKETRIGHT";
        named[Qt.Key_Backslash] = "BACKSLASH"; named[Qt.Key_Bar] = "BACKSLASH";
        named[Qt.Key_Exclam] = "1"; named[Qt.Key_At] = "2"; named[Qt.Key_NumberSign] = "3"; named[Qt.Key_Dollar] = "4";
        named[Qt.Key_Percent] = "5"; named[Qt.Key_AsciiCircum] = "6"; named[Qt.Key_Ampersand] = "7"; named[Qt.Key_Asterisk] = "8";
        named[Qt.Key_ParenLeft] = "9"; named[Qt.Key_ParenRight] = "0";
        return named[k] || "";
    }
    function isModifierKey(k) {
        return k === Qt.Key_Shift || k === Qt.Key_Control || k === Qt.Key_Alt || k === Qt.Key_Meta
            || k === Qt.Key_Super_L || k === Qt.Key_Super_R || k === Qt.Key_AltGr || k === Qt.Key_CapsLock;
    }
    function comboOf(event) {
        const name = keyName(event);
        if (name === "") return "";
        const keys = [];
        if (event.modifiers & Qt.MetaModifier) keys.push("SUPER");
        if (event.modifiers & Qt.ShiftModifier) keys.push("SHIFT");
        if (event.modifiers & Qt.ControlModifier) keys.push("CTRL");
        if (event.modifiers & Qt.AltModifier) keys.push("ALT");
        keys.push(name);
        return keys.join(" + ");
    }
    readonly property var notifyCfg: cfg.notify || {}
    readonly property var lookCfg: cfg.look || {}
    readonly property var currentMenu: {
        const menus = cfg.menus || [];
        for (let i = 0; i < menus.length; i++)
            if (menus[i].id === menuId)
                return menus[i];
        return menus.length ? menus[0] : null;
    }
    readonly property string popup: tab === "menus" ? (currentMenu ? "menu-" + currentMenu.id : "")
                                  : tab === "symbols" ? "emoji" : tab === "look" ? "power" : tab
    readonly property var emojiSample: rofioma.searchSymbols("emoji", "", "", 70)

    function handleEscape() {
        if (packConfirm.visible) {
            packConfirm.visible = false;
            return true;
        }
        if (glyphChooser.opened) {
            glyphChooser.close();
            return true;
        }
        if (rofioma.error !== "" || rofioma.notice !== "") {
            rofioma.dismissMessages();
            return true;
        }
        return false;
    }
    function acceptDialog() {
        if (!packConfirm.visible) return;
        packConfirm.visible = false;
        rofioma.installWidgetPack(packConfirm.pack.path);
    }
    function cycleTab(step) {
        let i = tabs.findIndex(t => t.id === tab);
        tab = tabs[(i + step + tabs.length) % tabs.length].id;
    }
    function openPopup() {
        if (popup !== "" && popup !== "notify")
            rofioma.open(popup);
        else if (popup === "notify")
            rofioma.testNotification();
    }

    readonly property bool keys: active && keysFree
    Shortcut { sequence: "T"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.cycleTab(1) }
    Shortcut { sequence: "Shift+T"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.cycleTab(-1) }
    Shortcut { sequence: "O"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.openPopup() }
    Shortcut { sequence: "R"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: stageView.replay() }

    onActiveChanged: if (active) { rofioma.reload(); rofioma.refreshBinds(); }

    // ------------------------------------------------------------ pieces

    // A popup's key: typed as Hyprland writes it, bound on Enter or Bind.
    component KeyRow: RowLayout {
        id: keyRow
        property string popup
        property string suggested
        property string label: "Key"
        readonly property string bound: (page.cfg.keys || {})[popup] || ""
        Layout.fillWidth: true
        spacing: 8
        Label { text: keyRow.label; color: theme.textSoft; Layout.preferredWidth: 120 }
        TextField {
            id: keyField
            Layout.fillWidth: true
            text: keyRow.bound
            placeholderText: keyRow.suggested
            font.family: "monospace"
            onAccepted: rofioma.bindKey(keyRow.popup, text !== "" ? text : keyRow.suggested)
        }
        Button {
            text: keyRow.bound === "" ? "Bind" : "Rebind"
            flat: true
            focusPolicy: Qt.NoFocus
            onClicked: rofioma.bindKey(keyRow.popup, keyField.text !== "" ? keyField.text : keyRow.suggested)
        }
        Button {
            visible: keyRow.bound !== ""
            text: "Clear"
            flat: true
            focusPolicy: Qt.NoFocus
            onClicked: rofioma.bindKey(keyRow.popup, "")
        }
    }

    // A text field sized for a row of other controls: Material's own is
    // tall and padded enough to crush a short one to a sliver.
    component CompactField: TextField {
        implicitHeight: 40
        topPadding: 8
        bottomPadding: 8
        leftPadding: 10
        rightPadding: 10
        font.pixelSize: 13
    }

    // A glyph that opens the chooser.
    component GlyphButton: Rectangle {
        id: gb
        property string glyph
        signal chosen(string symbol)
        implicitWidth: 40
        implicitHeight: 40
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        radius: 8
        color: gbHover.hovered ? theme.hover : theme.inset
        border.color: theme.border
        Label {
            anchors.centerIn: parent
            text: gb.glyph
            color: theme.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 19
        }
        HoverHandler { id: gbHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: glyphChooser.choose(gb.glyph, symbol => gb.chosen(symbol)) }
        ToolTip.visible: gbHover.hovered
        ToolTip.delay: 400
        ToolTip.text: "Pick a Nerd Font glyph"
    }

    // A square glyph button the size of a GlyphButton, so its glyph sits
    // centred in its own frame instead of in a wide, padded ToolButton.
    component OrderButton: Rectangle {
        id: ob
        property string glyph
        property string hint
        property bool danger: false
        signal clicked()
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        radius: 8
        opacity: enabled ? 1 : 0.35
        color: obHover.hovered && enabled ? theme.hover : "transparent"
        border.color: obHover.hovered && enabled ? theme.border : "transparent"
        Label {
            anchors.centerIn: parent
            text: ob.glyph
            color: ob.danger && obHover.hovered ? theme.danger : theme.textSoft
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 17
        }
        HoverHandler { id: obHover; cursorShape: ob.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: ob.enabled; onTapped: ob.clicked() }
        ToolTip.visible: obHover.hovered && hint !== ""
        ToolTip.delay: 400
        ToolTip.text: hint
    }

    component Section: Card {
        default property alias body: column.data
        property string title
        Layout.fillWidth: true
        implicitHeight: column.implicitHeight + 32
        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            SectionLabel { text: title; visible: title !== "" }
        }
    }

    // A labelled row of chips, wrapping.
    component Picks: RowLayout {
        id: picks
        property string label
        property var options: []
        property string current
        signal picked(string id)
        Layout.fillWidth: true
        spacing: 8
        Label { text: picks.label; color: theme.textSoft; Layout.preferredWidth: 90; Layout.alignment: Qt.AlignTop; Layout.topMargin: 6 }
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: picks.options
                Chip {
                    required property var modelData
                    text: modelData.name
                    chosen: picks.current === modelData.id
                    onClicked: picks.picked(modelData.id)
                    ToolTip.visible: hoverTip.hovered && modelData.description !== undefined
                    ToolTip.delay: 450
                    ToolTip.text: modelData.description || ""
                    HoverHandler { id: hoverTip }
                }
            }
        }
    }

    // How a popup moves: its entrance, its lit card and what's behind it. set
    // writes one of them, so this serves the power menu and every menu.
    component EffectsSection: Section {
        id: fxSection
        property var source: ({})
        property string defaultEnter: "fade"
        property bool hoverable: true
        property var writer: null
        title: "Effects"

        Label {
            visible: (page.cfg.look || {}).engine === "rofi"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: theme.warningText
            font.pixelSize: 11
            text: "These play in the OmaCraft popups, which are set to rofi in Look. rofi draws popups without animation."
        }
        Picks {
            label: "Entrance"
            options: rofioma.powerEnters
            current: fxSection.source.enter || fxSection.defaultEnter
            onPicked: id => { fxSection.writer("enter", id); stageView.replay(); }
        }
        Picks {
            visible: fxSection.hoverable
            label: "Hover"
            options: rofioma.powerHovers
            current: fxSection.source.hover || "hyde"
            onPicked: id => fxSection.writer("hover", id)
        }
        Label {
            visible: !fxSection.hoverable
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: theme.textDim
            font.pixelSize: 11
            text: "The Wlogout style keeps HyDE's own hover; its bar swells out of the row."
        }
        Picks {
            label: "Backdrop"
            options: rofioma.backdrops
            current: fxSection.source.backdrop || "dim"
            onPicked: id => fxSection.writer("backdrop", id)
        }
        SliderRow {
            label: "Duration"
            from: 0.4; to: 2.5; stepSize: 0.1; decimals: 1; suffix: "×"
            value: fxSection.source.speed || 1
            onMoved: v => { fxSection.writer("speed", Math.round(v * 10) / 10); stageView.replay(); }
        }
        RowLayout {
            Item { Layout.fillWidth: true }
            Button { text: "Play again"; flat: true; focusPolicy: Qt.NoFocus; onClicked: stageView.replay() }
        }
    }

    component OpenButton: AccentButton {
        property string label
        text: label
    }

    // ------------------------------------------------------------ layout
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        PageHeader {
            title: "ROFIoma"
            subtitle: "Rofi popups and swaync notifications, written to " + rofioma.outputDir.replace(/^\/home\/[^/]+/, "~")
            glyph: "\u{f1401}"
            AccentButton {
                text: page.tab === "notify" ? "Send test notifications" : "Open popup"
                enabled: page.popup !== ""
                onClicked: page.openPopup()
            }
            KeyCap { text: "O" }
        }

        // What's not installed, with a way to put it right.
        Rectangle {
            Layout.fillWidth: true
            visible: rofioma.missing.length > 0
            implicitHeight: missingRow.implicitHeight + 20
            radius: 8
            color: theme.warningFill
            border.color: theme.warningBorder
            RowLayout {
                id: missingRow
                anchors.fill: parent
                anchors.margins: 10
                anchors.leftMargin: 14
                spacing: 10
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: theme.warningText
                    text: "Not installed: " + rofioma.missing.map(m => m.program).join(", ")
                          + ". The popups need rofi and jq, the pickers wl-copy and wtype, and Notifications needs swaync."
                }
                Button { text: "Install"; flat: true; focusPolicy: Qt.NoFocus; onClicked: rofioma.installMissing() }
                Button { text: "Check again"; flat: true; focusPolicy: Qt.NoFocus; onClicked: rofioma.reload() }
            }
        }

        MessageBar {
            error: rofioma.error
            notice: rofioma.notice
            onDismissed: rofioma.dismissMessages()
        }

        // The shell overlay that draws the power menu, the menus and the
        // cheatsheet with HyDE's hover. Without it they open in rofi.
        Rectangle {
            id: overlayCard
            readonly property var plugin: { plugins.plugins; return plugins.plugin("omacraft.rofioma"); }
            readonly property bool installed: plugin.installed === true
            readonly property bool on: installed && plugin.enabled === true
            readonly property bool wanted: (page.cfg.look || {}).engine !== "rofi"
            visible: wanted && !on && ["power", "menus", "keybinds"].indexOf(page.tab) >= 0
            Layout.fillWidth: true
            implicitHeight: overlayRow.implicitHeight + 20
            radius: 10
            color: theme.inset
            border.color: theme.accent
            RowLayout {
                id: overlayRow
                anchors.fill: parent
                anchors.margins: 10
                anchors.leftMargin: 14
                spacing: 10
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: theme.text
                    text: !overlayCard.installed
                          ? "Install ROFIoma popups for HyDE's hover (cards swell, round off and bounce) and click-to-move keybinds. Until then these open in rofi, which can't animate."
                          : "ROFIoma popups is installed but off. Enable it so these open with HyDE's hover instead of in rofi."
                }
                Button {
                    text: overlayCard.installed ? "Enable" : "Install"
                    enabled: !plugins.busy
                    focusPolicy: Qt.NoFocus
                    onClicked: overlayCard.installed ? plugins.setEnabled("omacraft.rofioma", true) : plugins.install("omacraft.rofioma")
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Segmented {
                model: page.tabs
                current: page.tab
                onPicked: id => page.tab = id
            }
            KeyCap { text: "T" }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // ---- the stage
            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: Math.round((page.width - 56) * 0.52)
                Layout.maximumWidth: Layout.preferredWidth
                spacing: 10
                RofiPreview {
                    id: stageView
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round((page.width - 56) * 0.52 * 0.5625)
                    kind: page.tab === "menus" ? "menu" : page.tab === "look" ? "power" : page.tab
                    pal: page.pal
                    look: page.cfg.look || {}
                    power: page.cfg.power || {}
                    menu: page.currentMenu || {}
                    symbols: page.cfg.symbols || {}
                    notify: page.cfg.notify || {}
                    sample: page.tab === "keybinds" ? rofioma.binds : page.emojiSample
                    showCenter: page.showCenter
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: theme.textFaint
                    font.pixelSize: 11
                    text: page.tab === "power" ? "Hover a button to select it, as the arrow keys do. In rofi, each button's letter picks it straight away."
                        : page.tab === "notify" ? "swaync draws these. The preview follows its position, sizes and widgets."
                        : page.tab === "menus" && !page.currentMenu ? "Make a menu on the right to see it here."
                        : "Drawn as rofi draws it, scaled from a 1920 pixel wide screen."
                }
                Item { Layout.fillHeight: true }
            }

            // ---- the settings
            ScrollView {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true

                StackLayout {
                    width: scroll.availableWidth
                    currentIndex: page.tabs.findIndex(t => t.id === page.tab)
                    // As tall as the tab showing, not the tallest tab.
                    implicitHeight: children[currentIndex] ? children[currentIndex].implicitHeight : 0
                    height: implicitHeight

                    // ======================================== Power
                    ColumnLayout {
                        spacing: 14

                        Section {
                            title: "Style"
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 8
                                columnSpacing: 8
                                Repeater {
                                    model: rofioma.powerStyles
                                    delegate: Rectangle {
                                        id: styleTile
                                        required property var modelData
                                        readonly property bool chosen: (page.cfg.power || {}).style === modelData.id
                                        readonly property color tone: Qt.color(theme.accent)
                                        Layout.fillWidth: true
                                        implicitHeight: 58
                                        radius: 9
                                        color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.14) : styleHover.hovered ? theme.hover : theme.inset
                                        border.color: chosen ? theme.accent : theme.border
                                        border.width: chosen ? 2 : 1
                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 9
                                            spacing: 1
                                            Label { text: styleTile.modelData.name; color: styleTile.chosen ? theme.accent : theme.text; font.weight: Font.DemiBold }
                                            Label { Layout.fillWidth: true; text: styleTile.modelData.description; color: theme.textMuted; font.pixelSize: 10; elide: Text.ElideRight }
                                        }
                                        HoverHandler { id: styleHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: rofioma.set("power.style", styleTile.modelData.id) }
                                    }
                                }
                            }
                            Label {
                                visible: page.power.style === "wlogout"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: theme.textDim
                                font.pixelSize: 11
                                text: rofioma.missing.some(t => t.program === "wlogout")
                                      ? "wlogout isn't installed, so this opens as the rofi Row until it is (install it from the AUR above)."
                                      : "Drawn by wlogout, sized from your screen as HyDE sizes it: the bar's height and ends come from the monitor, the icon from Icon size."
                            }
                            SliderRow { visible: page.power.style !== "wlogout"; label: "Button size"; from: 60; to: 260; stepSize: 2; decimals: 0; suffix: "px"; value: page.power.size || 150; onMoved: v => rofioma.set("power.size", Math.round(v)) }
                            SliderRow { label: "Icon size"; from: 12; to: 96; stepSize: 1; decimals: 0; suffix: "pt"; value: page.power.glyphSize || 44; onMoved: v => rofioma.set("power.glyphSize", Math.round(v)) }
                            SliderRow { visible: page.power.style !== "wlogout"; label: "Spacing"; from: 0; to: 48; stepSize: 1; decimals: 0; suffix: "px"; value: page.power.spacing !== undefined ? page.power.spacing : 14; onMoved: v => rofioma.set("power.spacing", Math.round(v)) }
                            SliderRow {
                                visible: (page.cfg.power || {}).style !== "list"
                                label: "Dim the screen"; from: 0; to: 0.9; stepSize: 0.05; suffix: ""
                                value: page.power.dim !== undefined ? page.power.dim : 0.55
                                onMoved: v => rofioma.set("power.dim", Math.round(v * 100) / 100)
                            }
                            SwitchRow {
                                visible: (page.cfg.power || {}).style !== "pill"
                                label: "Labels"
                                hint: "The action's name under its icon."
                                checked: (page.cfg.power || {}).labels !== false
                                onToggled: on => rofioma.set("power.labels", on)
                            }
                            KeyRow { popup: "power"; suggested: "SUPER + CTRL + ESCAPE" }
                        }

                        EffectsSection {
                            source: page.power
                            defaultEnter: "cascade"
                            hoverable: page.power.style !== "wlogout"
                            writer: (field, value) => rofioma.set("power." + field, value)
                        }

                        Section {
                            title: "Buttons"
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: theme.textDim
                                font.pixelSize: 11
                                text: "Each button's icon, name, letter, whether it asks first and whether it's shown, with the command it runs underneath."
                            }
                            // One tile per button: the icon, name, letter and
                            // order on top, the command it runs underneath.
                            Repeater {
                                model: (page.cfg.power || {}).buttons || []
                                delegate: Rectangle {
                                    id: buttonRow
                                    required property var modelData
                                    required property int index
                                    readonly property bool on: modelData.enabled !== false
                                    readonly property int count: ((page.cfg.power || {}).buttons || []).length
                                    Layout.fillWidth: true
                                    implicitHeight: buttonCol.implicitHeight + 20
                                    radius: 10
                                    color: theme.inset
                                    border.color: theme.border
                                    opacity: on ? 1 : 0.6

                                    ColumnLayout {
                                        id: buttonCol
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 8
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            GlyphButton {
                                                glyph: buttonRow.modelData.glyph
                                                onChosen: symbol => rofioma.setPowerButton(buttonRow.index, "glyph", symbol)
                                            }
                                            CompactField {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: 80
                                                text: buttonRow.modelData.label
                                                placeholderText: "Name"
                                                onEditingFinished: if (text !== buttonRow.modelData.label) rofioma.setPowerButton(buttonRow.index, "label", text)
                                            }
                                            CompactField {
                                                Layout.preferredWidth: 44
                                                horizontalAlignment: Text.AlignHCenter
                                                leftPadding: 4
                                                rightPadding: 4
                                                maximumLength: 1
                                                text: buttonRow.modelData.key || ""
                                                font.family: "monospace"
                                                onEditingFinished: if (text !== (buttonRow.modelData.key || "")) rofioma.setPowerButton(buttonRow.index, "key", text.toLowerCase())
                                                ToolTip.visible: hovered
                                                ToolTip.text: "The letter that picks it"
                                            }
                                            CheckBox {
                                                text: "Ask"
                                                checked: buttonRow.modelData.confirm === true
                                                focusPolicy: Qt.NoFocus
                                                onToggled: rofioma.setPowerButton(buttonRow.index, "confirm", checked)
                                                ToolTip.visible: hovered
                                                ToolTip.text: "Ask before running it"
                                            }
                                            Switch {
                                                checked: buttonRow.on
                                                focusPolicy: Qt.NoFocus
                                                onToggled: rofioma.setPowerButton(buttonRow.index, "enabled", checked)
                                                ToolTip.visible: hovered
                                                ToolTip.text: buttonRow.on ? "Shown in the menu" : "Left out of the menu"
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            CompactField {
                                                Layout.fillWidth: true
                                                text: buttonRow.modelData.command
                                                placeholderText: "Command to run"
                                                font.family: "monospace"
                                                font.pixelSize: 12
                                                onEditingFinished: if (text !== buttonRow.modelData.command) rofioma.setPowerButton(buttonRow.index, "command", text)
                                            }
                                            OrderButton { glyph: "\u{f005d}"; hint: "Move earlier"; enabled: buttonRow.index > 0; onClicked: rofioma.movePowerButton(buttonRow.index, buttonRow.index - 1) }
                                            OrderButton { glyph: "\u{f0045}"; hint: "Move later"; enabled: buttonRow.index < buttonRow.count - 1; onClicked: rofioma.movePowerButton(buttonRow.index, buttonRow.index + 1) }
                                        }
                                    }
                                }
                            }
                            RowLayout {
                                Item { Layout.fillWidth: true }
                                Button { text: "Reset the power menu"; flat: true; focusPolicy: Qt.NoFocus; onClicked: rofioma.resetPower() }
                            }
                        }
                    }

                    // ======================================== Menus
                    ColumnLayout {
                        spacing: 14

                        Section {
                            title: "Your menus"
                            Flow {
                                Layout.fillWidth: true
                                spacing: 6
                                visible: (page.cfg.menus || []).length > 0
                                Repeater {
                                    model: page.cfg.menus || []
                                    Chip {
                                        required property var modelData
                                        text: modelData.name
                                        chosen: page.currentMenu !== null && page.currentMenu.id === modelData.id
                                        onClicked: page.menuId = modelData.id
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                TextField {
                                    id: newMenuName
                                    Layout.fillWidth: true
                                    placeholderText: "A name for a new menu, like Apps, Screenshots or Session"
                                    onAccepted: if (text.trim() !== "") { page.menuId = rofioma.addMenu(text.trim()); text = ""; }
                                }
                                Button {
                                    text: "New menu"
                                    flat: true
                                    focusPolicy: Qt.NoFocus
                                    enabled: newMenuName.text.trim() !== ""
                                    onClicked: { page.menuId = rofioma.addMenu(newMenuName.text.trim()); newMenuName.text = ""; }
                                }
                            }
                        }

                        Section {
                            id: menuEditor
                            visible: page.currentMenu !== null
                            title: page.currentMenu ? page.currentMenu.name : ""
                            readonly property var m: page.currentMenu || ({})

                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Name"; color: theme.textSoft; Layout.preferredWidth: 120 }
                                TextField {
                                    Layout.fillWidth: true
                                    text: menuEditor.m.name || ""
                                    onEditingFinished: if (text.trim() !== "" && text !== menuEditor.m.name) rofioma.setMenu(menuEditor.m.id, "name", text.trim())
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Prompt"; color: theme.textSoft; Layout.preferredWidth: 120 }
                                TextField {
                                    Layout.fillWidth: true
                                    text: menuEditor.m.prompt || ""
                                    onEditingFinished: if (text !== menuEditor.m.prompt) rofioma.setMenu(menuEditor.m.id, "prompt", text)
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Layout"; color: theme.textSoft; Layout.preferredWidth: 120 }
                                Segmented {
                                    model: rofioma.menuLayouts
                                    current: menuEditor.m.layout || "list"
                                    onPicked: id => rofioma.setMenu(menuEditor.m.id, "layout", id)
                                }
                                Item { Layout.fillWidth: true }
                            }
                            SliderRow {
                                visible: menuEditor.m.layout === "grid"
                                label: "Columns"; from: 2; to: 8; stepSize: 1; decimals: 0
                                value: menuEditor.m.columns || 3
                                onMoved: v => rofioma.setMenu(menuEditor.m.id, "columns", Math.round(v))
                            }
                            SliderRow {
                                label: "Width"; from: 240; to: 1400; stepSize: 10; decimals: 0; suffix: "px"
                                value: menuEditor.m.width || 420
                                onMoved: v => rofioma.setMenu(menuEditor.m.id, "width", Math.round(v))
                            }
                            SwitchRow {
                                label: "Search line"
                                hint: "Typing filters the items either way; this shows what's typed."
                                checked: menuEditor.m.search !== false
                                onToggled: on => rofioma.setMenu(menuEditor.m.id, "search", on)
                            }
                            KeyRow { popup: "menu-" + (menuEditor.m.id || ""); suggested: "SUPER + ALT + M" }

                            SectionLabel { text: "Items"; Layout.topMargin: 6 }
                            Repeater {
                                model: menuEditor.m.items || []
                                delegate: Rectangle {
                                    id: itemRow
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    implicitHeight: itemCol.implicitHeight + 20
                                    radius: 10
                                    color: theme.inset
                                    border.color: theme.border

                                    ColumnLayout {
                                        id: itemCol
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 8
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            GlyphButton {
                                                glyph: itemRow.modelData.glyph || ""
                                                onChosen: symbol => rofioma.setMenuItem(menuEditor.m.id, itemRow.index, "glyph", symbol)
                                            }
                                            CompactField {
                                                Layout.fillWidth: true
                                                text: itemRow.modelData.label
                                                placeholderText: "Name"
                                                onEditingFinished: if (text !== itemRow.modelData.label) rofioma.setMenuItem(menuEditor.m.id, itemRow.index, "label", text)
                                            }
                                            OrderButton { glyph: "\u{f005d}"; hint: "Move earlier"; enabled: itemRow.index > 0; onClicked: rofioma.moveMenuItem(menuEditor.m.id, itemRow.index, itemRow.index - 1) }
                                            OrderButton { glyph: "\u{f0045}"; hint: "Move later"; enabled: itemRow.index < (menuEditor.m.items || []).length - 1; onClicked: rofioma.moveMenuItem(menuEditor.m.id, itemRow.index, itemRow.index + 1) }
                                            OrderButton { glyph: "\u{f0156}"; hint: "Remove"; danger: true; onClicked: rofioma.removeMenuItem(menuEditor.m.id, itemRow.index) }
                                        }
                                        CompactField {
                                            Layout.fillWidth: true
                                            text: itemRow.modelData.command
                                            placeholderText: "Command to run"
                                            font.family: "monospace"
                                            font.pixelSize: 12
                                            onEditingFinished: if (text !== itemRow.modelData.command) rofioma.setMenuItem(menuEditor.m.id, itemRow.index, "command", text)
                                        }
                                    }
                                }
                            }
                            RowLayout {
                                Button { text: "Add item"; flat: true; focusPolicy: Qt.NoFocus; onClicked: rofioma.addMenuItem(menuEditor.m.id) }
                                Item { Layout.fillWidth: true }
                                Button {
                                    text: "Delete menu"
                                    flat: true
                                    focusPolicy: Qt.NoFocus
                                    Material.foreground: theme.danger
                                    onClicked: { rofioma.removeMenu(menuEditor.m.id); page.menuId = ""; }
                                }
                            }
                        }

                        EffectsSection {
                            visible: page.currentMenu !== null
                            source: page.currentMenu || ({})
                            writer: (field, value) => { if (page.currentMenu) rofioma.setMenu(page.currentMenu.id, field, value); }
                        }
                    }

                    // ======================================== Symbols
                    ColumnLayout {
                        spacing: 14

                        Section {
                            title: "Picker"
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Layout"; color: theme.textSoft; Layout.preferredWidth: 120 }
                                Segmented {
                                    model: [{ id: "grid", name: "Grid" }, { id: "list", name: "List" }]
                                    current: (page.cfg.symbols || {}).layout || "grid"
                                    onPicked: id => rofioma.set("symbols.layout", id)
                                }
                                Item { Layout.fillWidth: true }
                            }
                            SliderRow {
                                visible: ((page.cfg.symbols || {}).layout || "grid") === "grid"
                                label: "Columns"; from: 3; to: 14; stepSize: 1; decimals: 0
                                value: (page.cfg.symbols || {}).columns || 8
                                onMoved: v => rofioma.set("symbols.columns", Math.round(v))
                            }
                            SliderRow {
                                label: "Width"; from: 360; to: 1400; stepSize: 10; decimals: 0; suffix: "px"
                                value: (page.cfg.symbols || {}).width || 720
                                onMoved: v => rofioma.set("symbols.width", Math.round(v))
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "On Enter"; color: theme.textSoft; Layout.preferredWidth: 120 }
                                Segmented {
                                    model: [{ id: "copy", name: "Copy" }, { id: "type", name: "Type it" }, { id: "both", name: "Both" }]
                                    current: (page.cfg.symbols || {}).action || "copy"
                                    onPicked: id => rofioma.set("symbols.action", id)
                                }
                                Item { Layout.fillWidth: true }
                            }
                            SwitchRow {
                                label: "Recent first"
                                hint: "The last 24 picks head the list, and stay searchable by name."
                                checked: (page.cfg.symbols || {}).recents !== false
                                onToggled: on => rofioma.set("symbols.recents", on)
                            }
                            KeyRow { popup: "emoji"; label: "Emoji key"; suggested: "SUPER + ALT + PERIOD" }
                            KeyRow { popup: "glyphs"; label: "Glyph key"; suggested: "SUPER + ALT + G" }
                            RowLayout {
                                Item { Layout.fillWidth: true }
                                Button { text: "Open the glyph picker"; flat: true; focusPolicy: Qt.NoFocus; onClicked: rofioma.open("glyphs") }
                            }
                        }

                        // The mapper: every emoji and Nerd Font glyph, searchable here too.
                        Section {
                            id: mapper
                            title: "Symbol mapper"
                            property string kind: "glyphs"
                            property string set: ""
                            property var hovered: null
                            readonly property var results: rofioma.searchSymbols(kind, mapperSearch.text, set, 600)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Segmented {
                                    model: [{ id: "glyphs", name: "Nerd Font" }, { id: "emoji", name: "Emoji" }]
                                    current: mapper.kind
                                    onPicked: id => { mapper.kind = id; mapper.set = ""; }
                                }
                                SearchBox {
                                    id: mapperSearch
                                    Layout.fillWidth: true
                                    placeholderText: "Search by name or codepoint"
                                }
                            }
                            ComboBox {
                                Layout.fillWidth: true
                                model: ["Every set"].concat(rofioma.symbolSets(mapper.kind))
                                currentIndex: 0
                                onActivated: index => mapper.set = index === 0 ? "" : model[index]
                                focusPolicy: Qt.NoFocus
                            }
                            GridView {
                                id: symbolGrid
                                Layout.fillWidth: true
                                Layout.preferredHeight: 300
                                clip: true
                                cellWidth: width / Math.max(1, Math.floor(width / 46))
                                cellHeight: 46
                                model: mapper.results
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar {}
                                delegate: Rectangle {
                                    id: symbolCell
                                    required property var modelData
                                    width: symbolGrid.cellWidth - 4
                                    height: symbolGrid.cellHeight - 4
                                    radius: 7
                                    color: cellHover.hovered ? theme.hover : theme.inset
                                    border.color: cellHover.hovered ? theme.accent : "transparent"
                                    Label {
                                        anchors.centerIn: parent
                                        text: symbolCell.modelData.symbol
                                        color: theme.text
                                        font.family: mapper.kind === "glyphs" ? "JetBrainsMono Nerd Font" : "Noto Color Emoji"
                                        font.pixelSize: 21
                                    }
                                    HoverHandler { id: cellHover; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) mapper.hovered = symbolCell.modelData }
                                    TapHandler { onTapped: rofioma.copy(symbolCell.modelData.symbol) }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    color: theme.textMuted
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                    text: mapper.hovered ? "U+" + mapper.hovered.code + "   " + mapper.hovered.name + "   · " + mapper.hovered.set
                                                         : mapper.results.length + (mapper.results.length >= 600 ? "+" : "") + " found. Click one to copy it."
                                }
                            }
                        }
                    }

                    // ======================================== Keybinds
                    ColumnLayout {
                        spacing: 14
                        Section {
                            title: "Cheatsheet"
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: theme.textDim
                                font.pixelSize: 12
                                text: "Every Hyprland bind that has a description, read live with hyprctl each time it opens, so it never goes stale."
                            }
                            KeyRow { popup: "keybinds"; suggested: "SUPER + SHIFT + K" }
                            SwitchRow {
                                label: "Enter runs the bind"
                                hint: "Binds that run a command run it; the rest (Lua binds) just close the list."
                                checked: (page.cfg.keybinds || {}).run !== false
                                onToggled: on => rofioma.set("keybinds.run", on)
                            }
                        }
                        Section {
                            id: bindsSection
                            title: "Your binds (" + rofioma.binds.length + ")"
                            // The row waiting for its new keys, by its keys.
                            property string editing: ""
                            function stop() {
                                if (editing === "") return;
                                editing = "";
                                rofioma.captureKeys(false);
                            }
                            function start(keys) {
                                editing = keys;
                                rofioma.captureKeys(true);
                                captureCatcher.forceActiveFocus();
                            }
                            function move(from, to) {
                                bindsSection.problem = rofioma.moveBind(from, to);
                                stop();
                            }
                            property string problem: ""
                            Component.onDestruction: stop()

                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: theme.textDim
                                font.pixelSize: 12
                                text: "Click a bind, then press its new keys. Hyprland's binds pause while it waits, so a key that's taken won't run. "
                                      + "A moved bind keeps its action; Backspace while it waits puts it back."
                            }
                            SearchBox { id: bindSearch; Layout.fillWidth: true; placeholderText: "Filter keys or descriptions" }
                            Label {
                                visible: bindsSection.problem !== ""
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: theme.danger
                                text: bindsSection.problem
                            }
                            // Takes the keys pressed while a row waits.
                            Item {
                                id: captureCatcher
                                Layout.preferredHeight: 0
                                Layout.preferredWidth: 0
                                Keys.onPressed: event => {
                                    event.accepted = true;
                                    if (bindsSection.editing === "" || page.isModifierKey(event.key)) return;
                                    const row = rofioma.binds.find(b => b.keys === bindsSection.editing) || {};
                                    if (event.key === Qt.Key_Escape && !event.modifiers) return bindsSection.stop();
                                    if (event.key === Qt.Key_Backspace && !event.modifiers)
                                        return row.movedFrom ? bindsSection.move(bindsSection.editing, "") : bindsSection.stop();
                                    const combo = page.comboOf(event);
                                    if (combo === "") { bindsSection.problem = "That key has no name Hyprland binds by."; return; }
                                    bindsSection.move(bindsSection.editing, combo);
                                }
                                onActiveFocusChanged: if (!activeFocus) bindsSection.stop()
                            }
                            Repeater {
                                model: rofioma.binds.filter(b => {
                                    const q = bindSearch.text.toLowerCase();
                                    return q === "" || b.keys.toLowerCase().indexOf(q) >= 0 || b.description.toLowerCase().indexOf(q) >= 0;
                                }).slice(0, 200)
                                delegate: Rectangle {
                                    id: bindRow
                                    required property var modelData
                                    readonly property bool waiting: bindsSection.editing === modelData.keys
                                    Layout.fillWidth: true
                                    implicitHeight: 38
                                    radius: 8
                                    color: waiting ? Qt.rgba(Qt.color(theme.accent).r, Qt.color(theme.accent).g, Qt.color(theme.accent).b, 0.14)
                                         : bindHover.hovered ? theme.hover : "transparent"
                                    border.color: waiting ? theme.accent : "transparent"
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 12
                                        Rectangle {
                                            Layout.preferredWidth: 230
                                            Layout.preferredHeight: 26
                                            radius: 6
                                            color: bindRow.waiting ? theme.accent : theme.inset
                                            border.color: bindRow.waiting ? theme.accent : theme.border
                                            Label {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                verticalAlignment: Text.AlignVCenter
                                                text: bindRow.waiting ? "Press the new keys…" : bindRow.modelData.keys
                                                color: bindRow.waiting ? theme.accentForeground : theme.accent
                                                font.family: "monospace"
                                                font.pixelSize: 12
                                                font.bold: bindRow.waiting
                                                elide: Text.ElideMiddle
                                            }
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            text: bindRow.waiting ? (bindRow.modelData.movedFrom ? "Esc cancels · Backspace puts it back on " + bindRow.modelData.movedFrom : "Esc cancels")
                                                                  : bindRow.modelData.description
                                            color: bindRow.waiting ? theme.text : theme.textSoft
                                            elide: Text.ElideRight
                                        }
                                        Label {
                                            visible: !bindRow.waiting && bindRow.modelData.movedFrom !== ""
                                            text: "moved from " + bindRow.modelData.movedFrom
                                            color: theme.textDim
                                            font.pixelSize: 11
                                            font.italic: true
                                        }
                                        Label {
                                            visible: bindHover.hovered && !bindRow.waiting
                                            text: "\u{f03eb}"
                                            color: theme.textMuted
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                        }
                                    }
                                    HoverHandler { id: bindHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: bindRow.waiting ? bindsSection.stop() : bindsSection.start(bindRow.modelData.keys) }
                                    ToolTip.visible: bindHover.hovered && !bindRow.waiting
                                    ToolTip.delay: 600
                                    ToolTip.text: "Click, then press its new keys"
                                }
                            }
                            Button { text: "Read again"; flat: true; focusPolicy: Qt.NoFocus; onClicked: rofioma.refreshBinds() }
                        }
                    }

                    // ======================================== Notifications
                    ColumnLayout {
                        spacing: 14

                        Section {
                            title: "Who shows notifications"
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                StatePill {
                                    text: rofioma.swayncOwns ? "swaync" : "Omarchy shell"
                                    on: rofioma.swayncOwns
                                }
                                Label {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    color: theme.textSoft
                                    text: rofioma.swayncOwns
                                          ? "swaync has them, styled here. The shell's own notification daemon is off."
                                          : "The Omarchy shell has them. Hand them to swaync to use the style below; you can take them back any time."
                                }
                                Button {
                                    text: rofioma.swayncOwns ? "Give back to the shell" : "Hand to swaync"
                                    flat: true
                                    focusPolicy: Qt.NoFocus
                                    onClicked: rofioma.handNotificationsToSwaync(!rofioma.swayncOwns)
                                }
                            }
                            SwitchRow {
                                label: "Write swaync's style and config"
                                hint: "~/.config/swaync/style.css and config.json. What was there is kept once, beside them, as .before-omacraft-*."
                                checked: (page.cfg.notify || {}).manage === true
                                onToggled: on => rofioma.set("notify.manage", on)
                            }
                            // Opens whoever has the notifications: swaync's panel, or the shell's history.
                            KeyRow { popup: "notifications"; label: "Control centre key"; suggested: "SUPER + ALT + N" }
                            SwitchRow {
                                label: "Preview the control centre"
                                hint: "swaync-client -t opens it; it lists the widgets below."
                                checked: page.showCenter
                                onToggled: on => page.showCenter = on
                            }
                        }

                        Section {
                            title: "Popups"
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Position"; color: theme.textSoft; Layout.preferredWidth: 120; Layout.alignment: Qt.AlignTop }
                                GridLayout {
                                    columns: 3
                                    rowSpacing: 4
                                    columnSpacing: 4
                                    Repeater {
                                        model: ["top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right"]
                                        Chip {
                                            required property string modelData
                                            text: modelData.replace("-", " ")
                                            chosen: ((page.cfg.notify || {}).position || "top-right") === modelData
                                            onClicked: rofioma.set("notify.position", modelData)
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                            }
                            SliderRow { label: "Width"; from: 260; to: 640; stepSize: 10; decimals: 0; suffix: "px"; value: page.notifyCfg.width || 380; onMoved: v => rofioma.set("notify.width", Math.round(v)) }
                            SliderRow { label: "Icon size"; from: 16; to: 96; stepSize: 2; decimals: 0; suffix: "px"; value: page.notifyCfg.iconSize || 48; onMoved: v => rofioma.set("notify.iconSize", Math.round(v)) }
                            SliderRow { label: "Edge margin"; from: 0; to: 60; stepSize: 1; decimals: 0; suffix: "px"; value: page.notifyCfg.margin !== undefined ? page.notifyCfg.margin : 12; onMoved: v => rofioma.set("notify.margin", Math.round(v)) }
                            SliderRow { label: "Timeout"; from: 1; to: 30; stepSize: 1; decimals: 0; suffix: "s"; value: page.notifyCfg.timeout || 6; onMoved: v => rofioma.set("notify.timeout", Math.round(v)) }
                            SliderRow { label: "Low urgency"; from: 1; to: 30; stepSize: 1; decimals: 0; suffix: "s"; value: page.notifyCfg.timeoutLow || 3; onMoved: v => rofioma.set("notify.timeoutLow", Math.round(v)) }
                            SliderRow { label: "Critical"; from: 0; to: 60; stepSize: 1; decimals: 0; suffix: "s"; value: page.notifyCfg.timeoutCritical || 0; onMoved: v => rofioma.set("notify.timeoutCritical", Math.round(v)) }
                            Label { Layout.fillWidth: true; text: "A critical timeout of 0 keeps them until dismissed."; color: theme.textFaint; font.pixelSize: 11 }
                            SwitchRow {
                                label: "Accent edge"
                                hint: "A stripe of the accent down each notification's left side (red for critical ones)."
                                checked: (page.cfg.notify || {}).accentEdge !== false
                                onToggled: on => rofioma.set("notify.accentEdge", on)
                            }
                        }

                        Section {
                            title: "Effects"
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: theme.textDim
                                font.pixelSize: 11
                                text: "GTK CSS that swaync plays. Send test notifications to see them for real; the stage plays them too."
                            }
                            component NotifyPicks: RowLayout {
                                id: notifyPicks
                                property string label
                                property string field
                                property string fallback
                                property var options: []
                                Layout.fillWidth: true
                                spacing: 8
                                Label { text: notifyPicks.label; color: theme.textSoft; Layout.preferredWidth: 110; Layout.alignment: Qt.AlignTop; Layout.topMargin: 6 }
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Repeater {
                                        model: notifyPicks.options
                                        Chip {
                                            required property var modelData
                                            text: modelData.name
                                            chosen: ((page.cfg.notify || {})[notifyPicks.field] || notifyPicks.fallback) === modelData.id
                                            onClicked: { rofioma.set("notify." + notifyPicks.field, modelData.id); stageView.replay(); }
                                        }
                                    }
                                }
                            }
                            NotifyPicks {
                                label: "Arrives by"; field: "enter"; fallback: "slide"
                                options: [{ id: "slide", name: "Slide" }, { id: "fade", name: "Fade" }, { id: "pop", name: "Pop" }, { id: "drop", name: "Drop" }, { id: "flip", name: "Flip" }, { id: "none", name: "None" }]
                            }
                            NotifyPicks {
                                label: "On hover"; field: "hover"; fallback: "lift"
                                options: [{ id: "lift", name: "Lift" }, { id: "glow", name: "Glow" }, { id: "none", name: "None" }]
                            }
                            NotifyPicks {
                                label: "Critical alarm"; field: "critical"; fallback: "pulse"
                                options: [{ id: "pulse", name: "Pulse" }, { id: "glow", name: "Glow" }, { id: "shake", name: "Shake" }, { id: "none", name: "None" }]
                            }
                            NotifyPicks {
                                label: "Control centre"; field: "center"; fallback: "slide"
                                options: [{ id: "slide", name: "Slide" }, { id: "fade", name: "Fade" }, { id: "pop", name: "Pop" }, { id: "none", name: "None" }]
                            }
                            SliderRow { label: "Speed"; from: 80; to: 800; stepSize: 10; decimals: 0; suffix: "ms"; value: page.notifyCfg.duration || 200; onMoved: v => rofioma.set("notify.duration", Math.round(v)) }
                        }

                        Section {
                            title: "Control centre"
                            SliderRow { label: "Width"; from: 300; to: 760; stepSize: 10; decimals: 0; suffix: "px"; value: (page.cfg.notify || {}).centerWidth || 460; onMoved: v => rofioma.set("notify.centerWidth", Math.round(v)) }
                            WidgetBoard {
                                Layout.fillWidth: true
                                onReviewPack: pack => { packConfirm.pack = pack; packConfirm.visible = true; }
                            }
                        }
                    }

                    // ======================================== Look
                    ColumnLayout {
                        spacing: 14

                        Section {
                            title: "Drawn by"
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Popups"; color: theme.textSoft; Layout.preferredWidth: 120 }
                                Segmented {
                                    model: [{ id: "shell", name: "OmaCraft popups" }, { id: "rofi", name: "rofi" }]
                                    current: (page.cfg.look || {}).engine === "rofi" ? "rofi" : "shell"
                                    onPicked: id => rofioma.set("look.engine", id)
                                }
                                Item { Layout.fillWidth: true }
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: theme.textDim
                                font.pixelSize: 12
                                text: (page.cfg.look || {}).engine === "rofi"
                                      ? "rofi draws the power menu, your menus and the cheatsheet: no animation, and keybinds can only be moved here in OmaCraft."
                                      : "The ROFIoma popups plugin draws the power menu, your menus and the cheatsheet in the shell, with HyDE's hover on every card. "
                                        + "If it isn't installed or enabled they open in rofi (or wlogout for the Wlogout style). The emoji and glyph pickers stay in rofi."
                            }
                        }

                        Section {
                            title: "Colours"
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "From"; color: theme.textSoft; Layout.preferredWidth: 120 }
                                Segmented {
                                    model: [{ id: "theme", name: "Omarchy theme" }, { id: "custom", name: "My own" }]
                                    current: (page.cfg.look || {}).colors || "theme"
                                    onPicked: id => rofioma.set("look.colors", id)
                                }
                                Item { Layout.fillWidth: true }
                            }
                            Label {
                                visible: ((page.cfg.look || {}).colors || "theme") === "theme"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: theme.textDim
                                font.pixelSize: 12
                                text: "The current theme's background, foreground, accent and red. Switch theme and reopen this page to bring the popups along."
                            }
                            // Any colour at all, from the wheel. Picking one from the
                            // theme's colours makes the rest your own too, starting as they are.
                            Label {
                                Layout.fillWidth: true
                                text: "Click a colour to open the wheel."
                                color: theme.textDim
                                font.pixelSize: 12
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 8
                                columnSpacing: 8
                                Repeater {
                                    model: [{ id: "accent", name: "Accent" }, { id: "bg", name: "Background" }, { id: "fg", name: "Text" }, { id: "urgent", name: "Urgent" }]
                                    Rectangle {
                                        id: colourTile
                                        required property var modelData
                                        readonly property string hex: page.pal[modelData.id] || "#000000"
                                        Layout.fillWidth: true
                                        implicitHeight: 54
                                        radius: 9
                                        color: tileHover.hovered ? theme.hover : theme.inset
                                        border.color: wheel.opened ? theme.accent : theme.border
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 10
                                            Rectangle {
                                                Layout.preferredWidth: 38
                                                Layout.preferredHeight: 38
                                                radius: 19
                                                color: colourTile.hex
                                                border.color: theme.borderStrong
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                Label { Layout.fillWidth: true; text: colourTile.modelData.name; color: theme.text; font.weight: Font.DemiBold }
                                                Label { Layout.fillWidth: true; text: colourTile.hex; color: theme.textMuted; font.family: "monospace"; font.pixelSize: 11 }
                                            }
                                            Label { text: "\u{f0266}"; color: theme.textMuted; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 17 }
                                        }
                                        HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: wheel.openWith(colourTile.hex) }
                                        ColorPicker {
                                            id: wheel
                                            title: colourTile.modelData.name
                                            onPicked: hex => rofioma.setCustomColor(colourTile.modelData.id, hex)
                                        }
                                    }
                                }
                            }
                            Row {
                                spacing: 4
                                Repeater {
                                    model: ["bg", "alt", "fg", "muted", "accent", "urgent"]
                                    Rectangle {
                                        required property string modelData
                                        width: 34; height: 18; radius: 4
                                        color: page.pal[modelData] || "transparent"
                                        border.color: theme.border
                                        ToolTip.visible: swHover.hovered
                                        ToolTip.text: modelData + "  " + (page.pal[modelData] || "")
                                        HoverHandler { id: swHover }
                                    }
                                }
                            }
                        }

                        Section {
                            title: "Shape and type"
                            FontField {
                                label: "Font"
                                labelWidth: 120
                                value: (page.cfg.look || {}).font || ""
                                placeholder: "JetBrainsMono Nerd Font"
                                onPicked: family => rofioma.set("look.font", family !== "" ? family : "JetBrainsMono Nerd Font")
                            }
                            SliderRow { label: "Font size"; from: 8; to: 24; stepSize: 1; decimals: 0; suffix: "pt"; value: page.lookCfg.fontSize || 12; onMoved: v => rofioma.set("look.fontSize", Math.round(v)) }
                            SliderRow { label: "Corners"; from: 0; to: 40; stepSize: 1; decimals: 0; suffix: "px"; value: page.lookCfg.radius !== undefined ? page.lookCfg.radius : 14; onMoved: v => rofioma.set("look.radius", Math.round(v)) }
                            SliderRow { label: "Border"; from: 0; to: 8; stepSize: 1; decimals: 0; suffix: "px"; value: page.lookCfg.border !== undefined ? page.lookCfg.border : 2; onMoved: v => rofioma.set("look.border", Math.round(v)) }
                            SliderRow { label: "Opacity"; from: 0.4; to: 1; stepSize: 0.01; value: page.lookCfg.opacity !== undefined ? page.lookCfg.opacity : 0.94; onMoved: v => rofioma.set("look.opacity", Math.round(v * 100) / 100) }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: theme.textFaint
                                font.pixelSize: 11
                                text: "These apply to every popup and to swaync's notifications."
                            }
                        }
                    }
                }
            }
        }
    }

    // A widget pack's commands run when its buttons are pressed, so they're
    // shown before it's let in.
    Confirm {
        id: packConfirm
        property var pack: ({})
        heading: "Install " + (pack.names || []).join(", ") + "?"
        body: (pack.commands || []).length
              ? "These commands will run when you use it:\n\n" + pack.commands.map(c => "  " + c).join("\n")
              : "It doesn't run any commands."
        action: "Install"
        keepText: "Cancel"
        onAccepted: page.acceptDialog()
        onRejected: visible = false
    }

    // ------------------------------------------------------------ glyph chooser
    Popup {
        id: glyphChooser
        property var onChosen: null
        property string current
        function choose(glyph, callback) {
            current = glyph;
            onChosen = callback;
            chooserSearch.text = "";
            open();
            chooserSearch.forceActiveFocus();
        }
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(620, page.width - 60)
        height: Math.min(520, page.height - 60)
        modal: true
        padding: 16
        background: Rectangle { radius: 12; color: theme.raised; border.color: theme.border }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Pick a glyph"; color: theme.text; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Label { text: glyphChooser.current; color: theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22 }
            }
            SearchBox { id: chooserSearch; Layout.fillWidth: true; placeholderText: "power, lock, terminal, f0425…" }
            GridView {
                id: chooserGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: width / Math.max(1, Math.floor(width / 48))
                cellHeight: 48
                model: glyphChooser.opened ? rofioma.searchSymbols("glyphs", chooserSearch.text, "", 800) : []
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    id: chooserCell
                    required property var modelData
                    width: chooserGrid.cellWidth - 4
                    height: chooserGrid.cellHeight - 4
                    radius: 7
                    color: chooserHover.hovered ? theme.hover : theme.inset
                    border.color: modelData.symbol === glyphChooser.current ? theme.accent : "transparent"
                    Label {
                        anchors.centerIn: parent
                        text: chooserCell.modelData.symbol
                        color: theme.text
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 21
                    }
                    HoverHandler { id: chooserHover; cursorShape: Qt.PointingHandCursor }
                    ToolTip.visible: chooserHover.hovered
                    ToolTip.delay: 300
                    ToolTip.text: chooserCell.modelData.name + "  (" + chooserCell.modelData.set + ")"
                    TapHandler {
                        onTapped: {
                            if (glyphChooser.onChosen) glyphChooser.onChosen(chooserCell.modelData.symbol);
                            glyphChooser.close();
                        }
                    }
                }
            }
        }
    }
}
