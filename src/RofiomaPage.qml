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

    readonly property bool dialogOpen: false
    readonly property var shortcuts: [
        { keys: "T / Shift T", action: "Next / previous tab" },
        { keys: "O", action: "Open this tab's popup for real" }
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
    function acceptDialog() {}
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

    // A glyph that opens the chooser.
    component GlyphButton: Rectangle {
        id: gb
        property string glyph
        signal chosen(string symbol)
        implicitWidth: 36
        implicitHeight: 32
        radius: 7
        color: gbHover.hovered ? theme.hover : theme.inset
        border.color: theme.border
        Label {
            anchors.centerIn: parent
            text: gb.glyph
            color: theme.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 17
        }
        HoverHandler { id: gbHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: glyphChooser.choose(gb.glyph, symbol => gb.chosen(symbol)) }
        ToolTip.visible: gbHover.hovered
        ToolTip.delay: 400
        ToolTip.text: "Pick a Nerd Font glyph"
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
                            SliderRow { label: "Button size"; from: 60; to: 260; stepSize: 2; decimals: 0; suffix: "px"; value: page.power.size || 150; onMoved: v => rofioma.set("power.size", Math.round(v)) }
                            SliderRow { label: "Icon size"; from: 12; to: 96; stepSize: 1; decimals: 0; suffix: "pt"; value: page.power.glyphSize || 44; onMoved: v => rofioma.set("power.glyphSize", Math.round(v)) }
                            SliderRow { label: "Spacing"; from: 0; to: 48; stepSize: 1; decimals: 0; suffix: "px"; value: page.power.spacing !== undefined ? page.power.spacing : 14; onMoved: v => rofioma.set("power.spacing", Math.round(v)) }
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

                        Section {
                            title: "Buttons"
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: theme.textDim
                                font.pixelSize: 11
                                text: "On or off, icon, name, the command it runs, its letter, and whether it asks first."
                            }
                            Repeater {
                                model: (page.cfg.power || {}).buttons || []
                                delegate: RowLayout {
                                    id: buttonRow
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Switch {
                                        checked: buttonRow.modelData.enabled !== false
                                        focusPolicy: Qt.NoFocus
                                        onToggled: rofioma.setPowerButton(buttonRow.index, "enabled", checked)
                                    }
                                    GlyphButton {
                                        glyph: buttonRow.modelData.glyph
                                        onChosen: symbol => rofioma.setPowerButton(buttonRow.index, "glyph", symbol)
                                    }
                                    TextField {
                                        Layout.preferredWidth: 96
                                        text: buttonRow.modelData.label
                                        onEditingFinished: if (text !== buttonRow.modelData.label) rofioma.setPowerButton(buttonRow.index, "label", text)
                                    }
                                    TextField {
                                        Layout.fillWidth: true
                                        text: buttonRow.modelData.command
                                        font.family: "monospace"
                                        font.pixelSize: 11
                                        onEditingFinished: if (text !== buttonRow.modelData.command) rofioma.setPowerButton(buttonRow.index, "command", text)
                                    }
                                    TextField {
                                        Layout.preferredWidth: 34
                                        horizontalAlignment: Text.AlignHCenter
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
                                    }
                                    ToolButton { text: "\u{f005d}"; font.family: "JetBrainsMono Nerd Font"; enabled: buttonRow.index > 0; focusPolicy: Qt.NoFocus; onClicked: rofioma.movePowerButton(buttonRow.index, buttonRow.index - 1) }
                                    ToolButton { text: "\u{f0045}"; font.family: "JetBrainsMono Nerd Font"; enabled: buttonRow.index < ((page.cfg.power || {}).buttons || []).length - 1; focusPolicy: Qt.NoFocus; onClicked: rofioma.movePowerButton(buttonRow.index, buttonRow.index + 1) }
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
                                delegate: RowLayout {
                                    id: itemRow
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    spacing: 6
                                    GlyphButton {
                                        glyph: itemRow.modelData.glyph || ""
                                        onChosen: symbol => rofioma.setMenuItem(menuEditor.m.id, itemRow.index, "glyph", symbol)
                                    }
                                    TextField {
                                        Layout.preferredWidth: 130
                                        text: itemRow.modelData.label
                                        onEditingFinished: if (text !== itemRow.modelData.label) rofioma.setMenuItem(menuEditor.m.id, itemRow.index, "label", text)
                                    }
                                    TextField {
                                        Layout.fillWidth: true
                                        text: itemRow.modelData.command
                                        placeholderText: "Command to run"
                                        font.family: "monospace"
                                        font.pixelSize: 11
                                        onEditingFinished: if (text !== itemRow.modelData.command) rofioma.setMenuItem(menuEditor.m.id, itemRow.index, "command", text)
                                    }
                                    ToolButton { text: "\u{f005d}"; font.family: "JetBrainsMono Nerd Font"; enabled: itemRow.index > 0; focusPolicy: Qt.NoFocus; onClicked: rofioma.moveMenuItem(menuEditor.m.id, itemRow.index, itemRow.index - 1) }
                                    ToolButton { text: "\u{f0045}"; font.family: "JetBrainsMono Nerd Font"; enabled: itemRow.index < (menuEditor.m.items || []).length - 1; focusPolicy: Qt.NoFocus; onClicked: rofioma.moveMenuItem(menuEditor.m.id, itemRow.index, itemRow.index + 1) }
                                    ToolButton { text: "\u{f0156}"; font.family: "JetBrainsMono Nerd Font"; focusPolicy: Qt.NoFocus; onClicked: rofioma.removeMenuItem(menuEditor.m.id, itemRow.index) }
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
                            title: "Your binds (" + rofioma.binds.length + ")"
                            SearchBox { id: bindSearch; Layout.fillWidth: true; placeholderText: "Filter keys or descriptions" }
                            Repeater {
                                model: rofioma.binds.filter(b => {
                                    const q = bindSearch.text.toLowerCase();
                                    return q === "" || b.keys.toLowerCase().indexOf(q) >= 0 || b.description.toLowerCase().indexOf(q) >= 0;
                                }).slice(0, 200)
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Label { Layout.preferredWidth: 200; text: modelData.keys; color: theme.accent; font.family: "monospace"; font.pixelSize: 11; elide: Text.ElideRight }
                                    Label { Layout.fillWidth: true; text: modelData.description; color: theme.textSoft; elide: Text.ElideRight }
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
                            id: widgetsSection
                            title: "Control centre"
                            readonly property var chosen: (page.cfg.notify || {}).widgets || []
                            SliderRow { label: "Width"; from: 300; to: 760; stepSize: 10; decimals: 0; suffix: "px"; value: (page.cfg.notify || {}).centerWidth || 460; onMoved: v => rofioma.set("notify.centerWidth", Math.round(v)) }
                            Label { Layout.fillWidth: true; text: "Widgets, top to bottom:"; color: theme.textDim; font.pixelSize: 12 }
                            Repeater {
                                // The chosen ones in their order, then the rest.
                                model: widgetsSection.chosen.map(id => rofioma.notifyWidgets.find(w => w.id === id)).filter(w => w)
                                       .concat(rofioma.notifyWidgets.filter(w => widgetsSection.chosen.indexOf(w.id) < 0))
                                delegate: RowLayout {
                                    id: widgetRow
                                    required property var modelData
                                    readonly property int at: widgetsSection.chosen.indexOf(modelData.id)
                                    Layout.fillWidth: true
                                    function move(step) {
                                        const list = widgetsSection.chosen.slice();
                                        const to = at + step;
                                        if (at < 0 || to < 0 || to >= list.length) return;
                                        list.splice(to, 0, list.splice(at, 1)[0]);
                                        rofioma.set("notify.widgets", list);
                                    }
                                    Switch {
                                        checked: widgetRow.at >= 0
                                        focusPolicy: Qt.NoFocus
                                        onToggled: {
                                            const list = widgetsSection.chosen.filter(id => id !== widgetRow.modelData.id);
                                            if (checked) list.push(widgetRow.modelData.id);
                                            rofioma.set("notify.widgets", list);
                                        }
                                    }
                                    Label { Layout.fillWidth: true; text: widgetRow.modelData.name; color: widgetRow.at >= 0 ? theme.text : theme.textDim }
                                    ToolButton { visible: widgetRow.at >= 0; text: "\u{f005d}"; font.family: "JetBrainsMono Nerd Font"; enabled: widgetRow.at > 0; focusPolicy: Qt.NoFocus; onClicked: widgetRow.move(-1) }
                                    ToolButton { visible: widgetRow.at >= 0; text: "\u{f0045}"; font.family: "JetBrainsMono Nerd Font"; enabled: widgetRow.at < widgetsSection.chosen.length - 1; focusPolicy: Qt.NoFocus; onClicked: widgetRow.move(1) }
                                }
                            }
                        }
                    }

                    // ======================================== Look
                    ColumnLayout {
                        spacing: 14

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
                            GridLayout {
                                visible: (page.cfg.look || {}).colors === "custom"
                                columns: 4
                                rowSpacing: 8
                                columnSpacing: 10
                                Repeater {
                                    model: [{ id: "bg", name: "Background" }, { id: "fg", name: "Text" }, { id: "accent", name: "Accent" }, { id: "urgent", name: "Urgent" }]
                                    RowLayout {
                                        required property var modelData
                                        spacing: 6
                                        ColorButton {
                                            value: (((page.cfg.look || {}).custom) || {})[modelData.id] || ""
                                            title: modelData.name
                                            onPicked: hex => rofioma.set("look.custom." + modelData.id, hex)
                                        }
                                        Label { text: modelData.name; color: theme.textSoft }
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
