import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Wallpapers and the colours they give Omarchy, from the Studio plugin's
// hyprskin: browse Wallhaven, your downloads and your own folders, keep
// favourites, and pick how the wallpaper becomes the theme (Material,
// matugen, wallbash, pywal, flavours) for the shell, borders, terminals,
// editors and the rest.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    property string tab: ["wallhaven", "library", "favorites", "folders", "colors"].indexOf(startTab) >= 0 ? startTab : "wallhaven"
    property string deleting: ""
    property bool filtersOpen: false

    readonly property bool dialogOpen: deleteConfirm.visible
    readonly property var shortcuts: [
        { keys: "W L F D C", action: "Wallhaven, Library, Favourites, Folders, Colours" },
        { keys: "N", action: "Next wallpaper from the auto-change source" },
        { keys: "T", action: "Rebuild Omarchy's colours from the wallpaper" },
        { keys: "Ctrl F", action: "Search Wallhaven" },
        { keys: "Right-click", action: "A wallpaper's options: keep colours, favourite, delete" }
    ]

    readonly property var cfg: wallpaper.status.settings || ({})
    readonly property var paletteCfg: cfg.palette || ({})
    readonly property var colors: wallpaper.status.palette || ({})
    readonly property var tools: wallpaper.status.tools || ({})
    readonly property string currentPath: wallpaper.status.current || ""

    function basename(p) { return String(p || "").substring(String(p || "").lastIndexOf("/") + 1); }
    function isCurrent(path) { return currentPath !== "" && (currentPath === path || basename(currentPath) === basename(path)); }

    function handleEscape() {
        if (deleteConfirm.visible) { deleteConfirm.visible = false; return true; }
        if (wallpaper.error !== "" || wallpaper.notice !== "") { wallpaper.dismissMessages(); return true; }
        return false;
    }
    function acceptDialog() {
        deleteConfirm.visible = false;
        wallpaper.deleteFromLibrary(page.deleting);
    }
    function askDelete(path) {
        page.deleting = path;
        deleteConfirm.visible = true;
    }

    // ---- Wallhaven search form, seeded once from the saved search
    property bool seeded: false
    property var form: ({ query: "", sorting: "toplist", topRange: "1M", categories: "111", purity: "100", atleast: "", ratios: "", color: "" })
    function seed() {
        if (seeded || !cfg.search) return;
        seeded = true;
        form = Object.assign({}, form, cfg.search);
        query.text = form.query || "";
        if (active && tab === "wallhaven" && !wallpaper.searched) runSearch();
    }
    function setForm(key, value, go) {
        const f = Object.assign({}, form);
        f[key] = value;
        form = f;
        if (go !== false) runSearch();
    }
    function toggleBit(mask, index) {
        const bits = String(mask || "000").split("");
        bits[index] = bits[index] === "1" ? "0" : "1";
        const out = bits.join("");
        return out === "000" ? mask : out;
    }
    function runSearch() {
        // hyprskin saves each search as the auto-change source, so never
        // search before the saved one has been loaded into the form.
        if (!seeded) return;
        setForm("query", query.text.trim(), false);
        wallpaper.search(form);
    }

    Connections {
        target: wallpaper
        function onStatusChanged() { page.seed(); }
    }

    onActiveChanged: {
        if (!active) return;
        wallpaper.refresh();
        wallpaper.refreshLibrary();
        wallpaper.refreshFavorites();
        seed();
        if (tab === "wallhaven" && !wallpaper.searched && seeded) runSearch();
    }
    onTabChanged: {
        if (tab === "library") wallpaper.refreshLibrary();
        if (tab === "favorites") wallpaper.refreshFavorites();
        if (tab === "folders" && wallpaper.localResults.length === 0) wallpaper.localSearch(localQuery.text, localSort.value);
        if (tab === "wallhaven" && !wallpaper.searched) runSearch();
    }

    readonly property bool keys: active && keysFree && !dialogOpen && wallpaper.available
    Shortcut { sequence: "W"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = "wallhaven" }
    Shortcut { sequence: "L"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = "library" }
    Shortcut { sequence: "F"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = "favorites" }
    Shortcut { sequence: "D"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = "folders" }
    Shortcut { sequence: "C"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = "colors" }
    Shortcut { sequence: "N"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: wallpaper.next() }
    Shortcut { sequence: "T"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: wallpaper.retheme() }
    Shortcut {
        sequence: "Ctrl+F"; context: Qt.ApplicationShortcut; enabled: page.active && wallpaper.available
        onActivated: { page.tab = "wallhaven"; query.forceActiveFocus(); query.selectAll(); }
    }

    // A row of chips for one setting.
    component ChipRow: RowLayout {
        id: row
        property string label
        property var choices: []        // [{ value, label }]
        property var value
        property var isChosen: null     // optional (value) => bool, for multi-select rows
        signal picked(var value)
        Layout.fillWidth: true
        spacing: 10
        Label { Layout.preferredWidth: 96; text: row.label; color: theme.textSoft; font.pixelSize: 12 }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: row.choices
                Chip {
                    required property var modelData
                    text: modelData.label
                    chosen: row.isChosen ? row.isChosen(modelData.value) : row.value === modelData.value
                    onClicked: row.picked(modelData.value)
                }
            }
        }
    }

    // A grid of wallpapers that asks for more near its end.
    component WallGrid: GridView {
        id: grid
        signal nearEnd()
        clip: true
        readonly property int columns: Math.max(2, Math.floor(width / 230))
        cellWidth: Math.floor(width / columns)
        cellHeight: Math.floor(cellWidth * 0.62)
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        onContentYChanged: if (contentHeight - contentY - height < cellHeight * 2) grid.nearEnd()
        onCountChanged: if (contentHeight <= height) grid.nearEnd()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        PageHeader {
            title: "Wallpapers"
            subtitle: "Wallhaven, your library and folders, favourites, and the colours the wallpaper gives Omarchy"
            glyph: "\u{f08b9}"
            Button {
                text: "Next"
                flat: true
                focusPolicy: Qt.NoFocus
                visible: wallpaper.available
                enabled: !wallpaper.applying
                onClicked: wallpaper.next()
            }
            KeyCap { text: "N"; visible: wallpaper.available }
            AccentButton {
                text: wallpaper.busyTarget === "theme" ? "Building colours…" : "Use wallpaper colours"
                visible: wallpaper.available
                enabled: !wallpaper.applying
                onClicked: wallpaper.retheme()
            }
            KeyCap { text: "T"; visible: wallpaper.available }
        }

        NotInstalled {
            visible: !wallpaper.available
            pluginId: "omacraft.studio"
            what: "Wallpapers and their colours come from Hyprskin, inside the Studio plugin, which also draws the wallpaper."
        }

        MessageBar {
            error: wallpaper.error
            notice: wallpaper.notice
            onDismissed: wallpaper.dismissMessages()
        }

        // ---- Now showing, and the tabs
        RowLayout {
            Layout.fillWidth: true
            visible: wallpaper.available
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 168
                Layout.preferredHeight: 94
                radius: 9
                color: theme.inset
                border.color: theme.border
                clip: true
                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: page.currentPath === "" ? "" : "file://" + page.currentPath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 400
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Label {
                    Layout.fillWidth: true
                    text: page.currentPath === "" ? "No wallpaper yet" : page.basename(page.currentPath)
                    color: theme.text
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                }
                Label {
                    Layout.fillWidth: true
                    text: (wallpaper.status.themeIsDynamic ? "Omarchy follows its colours" : "Theme: " + (wallpaper.status.theme || "?"))
                          + " · " + (page.colors.scheme ? page.colors.scheme + " via " + (page.colors.engine || "built-in") : "no palette yet")
                    color: theme.textMuted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                // The palette the wallpaper gave.
                Row {
                    spacing: 3
                    Repeater {
                        model: ["background", "lighter_background", "foreground", "accent", "red", "orange", "yellow", "green", "cyan", "blue", "magenta"]
                        Rectangle {
                            required property string modelData
                            visible: page.colors[modelData] !== undefined
                            width: 22; height: 14; radius: 3
                            color: page.colors[modelData] || "transparent"
                            border.color: "#33ffffff"
                            ToolTip.visible: sw.hovered
                            ToolTip.text: modelData + " " + (page.colors[modelData] || "")
                            HoverHandler { id: sw }
                        }
                    }
                }
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: [
                            { id: "wallhaven", name: "Wallhaven", key: "W" },
                            { id: "library", name: "Library · " + wallpaper.library.length, key: "L" },
                            { id: "favorites", name: "Favourites · " + wallpaper.favorites.length, key: "F" },
                            { id: "folders", name: "Folders", key: "D" },
                            { id: "colors", name: "Colours", key: "C" }
                        ]
                        Chip {
                            required property var modelData
                            text: modelData.name + "  " + modelData.key
                            chosen: page.tab === modelData.id
                            onClicked: page.tab = modelData.id
                        }
                    }
                }
            }
        }

        // ---- The picker key: these wallpapers over the desktop, without this window
        Card {
            id: pickerCard
            Layout.fillWidth: true
            visible: wallpaper.available
            implicitHeight: pickerColumn.implicitHeight + 24

            readonly property var plugin: { plugins.plugins; return plugins.plugin("omacraft.wallpicker"); }
            readonly property bool installed: plugin.installed === true
            readonly property bool enabled: plugin.enabled === true

            ColumnLayout {
            id: pickerColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                id: pickerRow
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        text: "Picker key"
                        color: theme.text
                        font.weight: Font.DemiBold
                    }
                    Label {
                        Layout.fillWidth: true
                        text: wallPicker.error !== "" ? wallPicker.error
                            : !pickerCard.installed ? "Omarchy's background switcher with these wallpapers in it: the theme's backgrounds, Wallhaven, the library and favourites. Install it to give it a key."
                            : !pickerCard.enabled ? "Installed. Enable it so the shell can open it."
                            : wallPicker.bound ? wallPicker.key + " opens it over the desktop; picking a wallpaper sets it and its colours. OmaCraft stays closed."
                            : "No key yet. " + wallPicker.defaultKey + " is free in Omarchy's defaults."
                        color: wallPicker.error !== "" ? theme.danger : theme.textMuted
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }

                Button {
                    visible: !pickerCard.installed || !pickerCard.enabled
                    text: !pickerCard.installed ? "Install" : "Enable"
                    enabled: !plugins.busy
                    focusPolicy: Qt.NoFocus
                    onClicked: pickerCard.installed ? plugins.setEnabled("omacraft.wallpicker", true) : plugins.install("omacraft.wallpicker")
                }
                TextField {
                    id: pickerKey
                    visible: pickerCard.installed && pickerCard.enabled
                    Layout.preferredWidth: 190
                    placeholderText: wallPicker.defaultKey
                    text: wallPicker.key
                    onAccepted: wallPicker.bind(text.trim() === "" ? wallPicker.defaultKey : text)
                }
                Button {
                    visible: pickerKey.visible
                    text: wallPicker.bound && pickerKey.text === wallPicker.key ? "Bound" : "Set key"
                    enabled: !(wallPicker.bound && pickerKey.text === wallPicker.key)
                    focusPolicy: Qt.NoFocus
                    onClicked: pickerKey.accepted()
                }
                Button {
                    visible: pickerKey.visible && wallPicker.bound
                    text: "Remove key"
                    flat: true
                    focusPolicy: Qt.NoFocus
                    onClicked: wallPicker.unbind()
                }
                Button {
                    visible: pickerKey.visible
                    text: "Open picker"
                    flat: true
                    focusPolicy: Qt.NoFocus
                    onClicked: wallPicker.open(page.tab === "library" || page.tab === "favorites" || page.tab === "wallhaven" ? page.tab : "")
                }
            }

            SwitchRow {
                label: "The SELECT WALLPAPER title"
                hint: "Lands over the tabs in tiles that decrypt into place, then catches the light now and then."
                checked: wallPicker.showTitle
                onToggled: on => wallPicker.setShowTitle(on)
            }

            // The card in front of the carousel: each tile plays its effect
            // with the picker's own CardBorder.qml.
            RowLayout {
                Layout.fillWidth: true
                visible: wallPicker.cardBorderUrl !== ""
                spacing: 8
                Label {
                    Layout.preferredWidth: 78
                    text: "Front card"
                    color: theme.textSoft
                    font.pixelSize: 12
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: wallPicker.cardEffects
                        Rectangle {
                            id: fxTile
                            required property var modelData
                            readonly property bool chosen: wallPicker.cardEffect === modelData.id
                            width: 96; height: 58
                            radius: 6
                            color: fxHover.hovered ? theme.hover : theme.inset
                            border.color: chosen ? theme.accent : theme.border
                            border.width: chosen ? 2 : 1
                            ToolTip.visible: fxHover.hovered
                            ToolTip.delay: 400
                            ToolTip.text: modelData.description

                            Loader {
                                id: fxPreview
                                x: 10; y: 8
                                width: parent.width - 20; height: 26
                                source: wallPicker.cardBorderUrl
                            }
                            Binding { target: fxPreview.item; property: "effect"; value: fxTile.modelData.id; when: fxPreview.item !== null }
                            Binding { target: fxPreview.item; property: "topLeft"; value: 5; when: fxPreview.item !== null }
                            Binding { target: fxPreview.item; property: "bottomRight"; value: fxPreview.width - 5; when: fxPreview.item !== null }
                            Binding { target: fxPreview.item; property: "lineWidth"; value: 2; when: fxPreview.item !== null }
                            Binding { target: fxPreview.item; property: "color1"; value: theme.accent; when: fxPreview.item !== null }
                            Binding { target: fxPreview.item; property: "color2"; value: page.colors.cyan || theme.textSoft; when: fxPreview.item !== null }
                            Binding { target: fxPreview.item; property: "speed"; value: wallPicker.cardSpeed; when: fxPreview.item !== null }
                            // Only the chosen one and the one under the pointer move.
                            Binding { target: fxPreview.item; property: "running"; value: fxTile.chosen || fxHover.hovered; when: fxPreview.item !== null }

                            Label {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: fxTile.modelData.name
                                color: fxTile.chosen ? theme.text : theme.textMuted
                                font.pixelSize: 10
                            }
                            HoverHandler { id: fxHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: wallPicker.setCardEffect(fxTile.modelData.id) }
                        }
                    }
                }
            }
            SliderRow {
                visible: wallPicker.cardBorderUrl !== "" && wallPicker.cardEffect !== "plain"
                label: "Front card speed"
                from: 0.25; to: 3; stepSize: 0.05
                suffix: "×"
                value: wallPicker.cardSpeed
                onMoved: v => wallPicker.setCardSpeed(v)
            }
            }
        }

        // ---- Wallhaven
        ColumnLayout {
            visible: wallpaper.available && page.tab === "wallhaven"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Card {
                Layout.fillWidth: true
                implicitHeight: filters.implicitHeight + 28
                ColumnLayout {
                    id: filters
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        TextField {
                            id: query
                            Layout.fillWidth: true
                            placeholderText: "Search wallhaven.cc: tags, #tag, @user, id:123, like:abc123"
                            onAccepted: page.runSearch()
                        }
                        Button {
                            text: page.filtersOpen ? "Hide filters" : "Filters"
                            flat: true
                            focusPolicy: Qt.NoFocus
                            onClicked: page.filtersOpen = !page.filtersOpen
                        }
                        AccentButton { text: wallpaper.searching ? "Searching…" : "Search"; onClicked: page.runSearch() }
                        KeyCap { text: "Ctrl F" }
                    }
                    // What the search is set to, while the filters are folded.
                    Label {
                        visible: !page.filtersOpen
                        Layout.fillWidth: true
                        text: {
                            const f = page.form;
                            const names = ["General", "Anime", "People"].filter((n, i) => String(f.categories || "111")[i] === "1");
                            const purity = ["SFW", "Sketchy", "NSFW"].filter((n, i) => String(f.purity || "100")[i] === "1");
                            const sort = { toplist: "Top of " + f.topRange, date_added: "Latest", hot: "Hot", views: "Most viewed", favorites: "Most favourited", random: "Random", relevance: "Relevance" }[f.sorting] || f.sorting;
                            return [sort, names.join(" + "), purity.join(" + "), f.atleast ? "≥ " + f.atleast : "", f.ratios || ""].filter(x => x).join(" · ");
                        }
                        color: theme.textMuted
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    ChipRow {
                        visible: page.filtersOpen
                        label: "Sort"
                        value: page.form.sorting
                        choices: [
                            { value: "toplist", label: "Top" }, { value: "hot", label: "Hot" },
                            { value: "date_added", label: "Latest" }, { value: "views", label: "Views" },
                            { value: "favorites", label: "Favourites" }, { value: "random", label: "Random" },
                            { value: "relevance", label: "Relevance" }
                        ]
                        onPicked: v => page.setForm("sorting", v)
                    }
                    ChipRow {
                        visible: page.filtersOpen && page.form.sorting === "toplist"
                        label: "Over"
                        value: page.form.topRange
                        choices: [
                            { value: "1d", label: "Day" }, { value: "3d", label: "3 days" }, { value: "1w", label: "Week" },
                            { value: "1M", label: "Month" }, { value: "3M", label: "3 months" },
                            { value: "6M", label: "6 months" }, { value: "1y", label: "Year" }
                        ]
                        onPicked: v => page.setForm("topRange", v)
                    }
                    ChipRow {
                        visible: page.filtersOpen
                        label: "Categories"
                        isChosen: v => String(page.form.categories || "111")[v] === "1"
                        choices: [{ value: 0, label: "General" }, { value: 1, label: "Anime" }, { value: 2, label: "People" }]
                        onPicked: v => page.setForm("categories", page.toggleBit(page.form.categories, v))
                    }
                    ChipRow {
                        visible: page.filtersOpen
                        label: "Purity"
                        isChosen: v => String(page.form.purity || "100")[v] === "1"
                        choices: [{ value: 0, label: "SFW" }, { value: 1, label: "Sketchy" }, { value: 2, label: "NSFW (API key)" }]
                        onPicked: v => page.setForm("purity", page.toggleBit(page.form.purity, v))
                    }
                    ChipRow {
                        visible: page.filtersOpen
                        label: "At least"
                        value: page.form.atleast || ""
                        choices: [
                            { value: "", label: "Any size" }, { value: "1920x1080", label: "1080p" },
                            { value: "2560x1440", label: "1440p" }, { value: "3440x1440", label: "Ultrawide" },
                            { value: "3840x2160", label: "4K" }
                        ]
                        onPicked: v => page.setForm("atleast", v)
                    }
                    ChipRow {
                        visible: page.filtersOpen
                        label: "Shape"
                        value: page.form.ratios || ""
                        choices: [
                            { value: "", label: "Any" }, { value: "16x9", label: "16:9" }, { value: "16x10", label: "16:10" },
                            { value: "21x9", label: "21:9" }, { value: "landscape", label: "Landscape" }, { value: "portrait", label: "Portrait" }
                        ]
                        onPicked: v => page.setForm("ratios", v)
                    }
                    RowLayout {
                        visible: page.filtersOpen
                        Layout.fillWidth: true
                        spacing: 10
                        Label { Layout.preferredWidth: 96; text: "API key"; color: theme.textSoft; font.pixelSize: 12 }
                        TextField {
                            id: apiKey
                            Layout.fillWidth: true
                            echoMode: TextInput.Password
                            placeholderText: page.cfg.apiKey === "set" ? "Saved. Paste a new one to replace it" : "Optional: for NSFW and your own collections (wallhaven.cc › Settings › Account)"
                            onAccepted: { if (text.trim() !== "") { wallpaper.setOption("apiKey", text.trim()); text = ""; } }
                        }
                        Button { text: "Save key"; flat: true; focusPolicy: Qt.NoFocus; enabled: apiKey.text.trim() !== ""; onClicked: apiKey.accepted() }
                    }
                }
            }

            Label {
                text: !wallpaper.searched ? "" : wallpaper.total > 0
                      ? wallpaper.results.length + " of " + wallpaper.total + " shown · click to set, right-click for more"
                      : "Nothing matched."
                color: theme.textMuted
                font.pixelSize: 12
            }

            WallGrid {
                id: wallhavenGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: wallpaper.results
                onNearEnd: wallpaper.loadMore()
                delegate: Item {
                    required property var modelData
                    width: wallhavenGrid.cellWidth
                    height: wallhavenGrid.cellHeight
                    WallpaperTile {
                        anchors.fill: parent
                        anchors.margins: 5
                        target: parent.modelData.id
                        thumb: parent.modelData.thumb || parent.modelData.thumbRemote || ""
                        caption: parent.modelData.id
                        detail: parent.modelData.resolution
                        url: parent.modelData.url
                        meta: parent.modelData
                        current: page.basename(page.currentPath).indexOf("wallhaven-" + parent.modelData.id + ".") === 0
                    }
                }
                footer: Item {
                    width: wallhavenGrid.width
                    height: wallpaper.searching ? 56 : 0
                    BusyIndicator { anchors.centerIn: parent; running: wallpaper.searching; visible: running }
                }
            }
        }

        // ---- Library: what's been downloaded
        ColumnLayout {
            visible: wallpaper.available && page.tab === "library"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.fillWidth: true
                    text: wallpaper.library.length + " downloaded to " + (page.cfg.library || "~/Pictures/Wallhaven").replace(/^\/home\/[^/]+/, "~")
                          + " · right-click one to delete it"
                    color: theme.textMuted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                Button { text: "Open folder"; flat: true; focusPolicy: Qt.NoFocus; onClicked: wallpaper.openUrl("file://" + (page.cfg.library || "")) }
            }
            WallGrid {
                id: libraryGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: wallpaper.library
                delegate: Item {
                    required property var modelData
                    width: libraryGrid.cellWidth
                    height: libraryGrid.cellHeight
                    WallpaperTile {
                        anchors.fill: parent
                        anchors.margins: 5
                        target: parent.modelData.path
                        thumb: parent.modelData.path
                        caption: parent.modelData.name
                        file: parent.modelData.path
                        inLibrary: true
                        current: page.isCurrent(parent.modelData.path)
                        onDeleteRequested: path => page.askDelete(path)
                    }
                }
            }
            Label {
                visible: wallpaper.library.length === 0
                text: "Nothing downloaded yet. Setting a Wallhaven wallpaper saves it here."
                color: theme.textFaint
            }
        }

        // ---- Favourites
        ColumnLayout {
            visible: wallpaper.available && page.tab === "favorites"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            Label {
                Layout.fillWidth: true
                text: "Hearts are kept in ~/.local/share/hyprskin/favorites.json (Wallhaven's API can't write to your collections). Auto-change can draw from them under Colours › Auto-change."
                color: theme.textMuted
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
            WallGrid {
                id: favoritesGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: wallpaper.favorites
                delegate: Item {
                    required property var modelData
                    width: favoritesGrid.cellWidth
                    height: favoritesGrid.cellHeight
                    WallpaperTile {
                        readonly property string libraryRoot: page.cfg.library || ""
                        anchors.fill: parent
                        anchors.margins: 5
                        target: parent.modelData.target || parent.modelData.key
                        thumb: parent.modelData.thumb || parent.modelData.thumbRemote || ""
                        caption: page.basename(parent.modelData.target || parent.modelData.key)
                        detail: parent.modelData.resolution || ""
                        url: parent.modelData.url || ""
                        file: parent.modelData.local || parent.modelData.downloaded ? parent.modelData.target : ""
                        inLibrary: libraryRoot !== "" && String(parent.modelData.target || "").indexOf(libraryRoot + "/") === 0
                        missing: parent.modelData.missing === true
                        current: page.isCurrent(parent.modelData.target || "")
                        onDeleteRequested: path => page.askDelete(path)
                    }
                }
            }
            Label {
                visible: wallpaper.favorites.length === 0
                text: "No favourites yet. Hover any wallpaper and click its heart."
                color: theme.textFaint
            }
        }

        // ---- Your own folders
        ColumnLayout {
            visible: wallpaper.available && page.tab === "folders"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            Card {
                Layout.fillWidth: true
                implicitHeight: folderColumn.implicitHeight + 28
                ColumnLayout {
                    id: folderColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        SectionLabel { text: "Folders" }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: (page.cfg.local || {}).folders || []
                                Chip {
                                    required property string modelData
                                    text: modelData + "  ✕"
                                    onClicked: wallpaper.removeFolder(modelData)
                                }
                            }
                        }
                        Button { text: "Add folder"; flat: true; focusPolicy: Qt.NoFocus; onClicked: wallpaper.addFolder() }
                        Button { text: "Rescan"; flat: true; focusPolicy: Qt.NoFocus; enabled: !wallpaper.scanning; onClicked: wallpaper.localSearch(localQuery.text, localSort.value, true) }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        TextField {
                            id: localQuery
                            Layout.fillWidth: true
                            placeholderText: "Filter by name or path (words, or ~/folder)"
                            onAccepted: wallpaper.localSearch(text, localSort.value)
                        }
                    }
                    ChipRow {
                        id: localSort
                        label: "Order"
                        value: "newest"
                        choices: [{ value: "newest", label: "Newest" }, { value: "oldest", label: "Oldest" }, { value: "name", label: "Name" }, { value: "random", label: "Shuffle" }]
                        onPicked: v => { localSort.value = v; wallpaper.localSearch(localQuery.text, v); }
                    }
                    ChipRow {
                        label: "Skip under"
                        value: Number((page.cfg.local || {}).minWidth) || 0
                        choices: [{ value: 0, label: "Show all" }, { value: 1280, label: "1280 px" }, { value: 1920, label: "1920 px" }, { value: 2560, label: "2560 px" }]
                        onPicked: v => { wallpaper.setOption("local.minWidth", v); wallpaper.localSearch(localQuery.text, localSort.value); }
                    }
                }
            }
            Label {
                text: wallpaper.scanning && wallpaper.localResults.length === 0 ? "Scanning…" : wallpaper.localTotal + " images"
                color: theme.textMuted
                font.pixelSize: 12
            }
            WallGrid {
                id: localGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: wallpaper.localResults
                onNearEnd: wallpaper.loadMoreLocal()
                delegate: Item {
                    required property var modelData
                    width: localGrid.cellWidth
                    height: localGrid.cellHeight
                    WallpaperTile {
                        readonly property string libraryRoot: page.cfg.library || ""
                        anchors.fill: parent
                        anchors.margins: 5
                        target: parent.modelData.path
                        thumb: parent.modelData.thumb || parent.modelData.path
                        caption: parent.modelData.name
                        detail: parent.modelData.dir || ""
                        file: parent.modelData.path
                        inLibrary: libraryRoot !== "" && parent.modelData.path.indexOf(libraryRoot + "/") === 0
                        current: page.isCurrent(parent.modelData.path)
                        onDeleteRequested: path => page.askDelete(path)
                    }
                }
            }
        }

        // ---- Colours: how the wallpaper becomes the Omarchy theme
        ScrollView {
            id: colorScroll
            visible: wallpaper.available && page.tab === "colors"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: colorScroll.availableWidth
                spacing: 14

                Card {
                    Layout.fillWidth: true
                    implicitHeight: follow.implicitHeight + 32
                    ColumnLayout {
                        id: follow
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        SwitchRow {
                            label: "Every new wallpaper recolours Omarchy"
                            hint: "Builds the hyprskin theme from each wallpaper and applies it with omarchy theme set, so the shell (bar, menus, notifications, OSD, lock screen), Hyprland borders, terminals, editors, btop, the browser and icons all follow it. Off: wallpapers change, the theme stays."
                            checked: page.cfg.dynamicColors === true
                            onToggled: on => {
                                wallpaper.setOption("dynamicColors", on);
                                // Wallpaper colours mean all of them.
                                if (on)
                                    themeSync.followAll();
                            }
                        }
                    }
                }

                // OmaCraft's own parts: each keeps colours of its own unless
                // it follows the theme the wallpaper builds.
                Card {
                    Layout.fillWidth: true
                    implicitHeight: partsColumn.implicitHeight + 32
                    ColumnLayout {
                        id: partsColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            SectionLabel { text: "OmaCraft's parts that follow too" }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: themeSync.allFollow ? "All follow" : "Make them all follow"
                                enabled: !themeSync.allFollow
                                flat: true
                                focusPolicy: Qt.NoFocus
                                onClicked: themeSync.followAll()
                            }
                        }
                        Repeater {
                            model: themeSync.parts.filter(p => p.available)
                            SwitchRow {
                                required property var modelData
                                label: modelData.label
                                hint: modelData.description + (modelData.fixed ? " It already follows the theme." : "")
                                checked: modelData.follow
                                enabled: !modelData.fixed
                                onToggled: on => themeSync.setFollow(modelData.id, on)
                            }
                        }
                    }
                }

                // Schemes: the five ways of reading colours from an image.
                PaletteCard { Layout.fillWidth: true }

                // Which parts follow.
                Card {
                    Layout.fillWidth: true
                    implicitHeight: targetColumn.implicitHeight + 32
                    ColumnLayout {
                        id: targetColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        SectionLabel { text: "What follows the wallpaper" }
                        Repeater {
                            model: wallpaper.targetInfo.targets || []
                            SwitchRow {
                                required property var modelData
                                label: modelData.label
                                hint: modelData.description
                                checked: modelData.follow !== false
                                onToggled: on => wallpaper.setOption("targets." + modelData.id, on, true)
                            }
                        }
                        ChipRow {
                            label: "The rest keep"
                            value: page.cfg.keepTheme || ""
                            choices: [{ value: "", label: "The last theme" }].concat((wallpaper.targetInfo.themes || []).map(t => ({ value: t, label: t })))
                            onPicked: v => wallpaper.setOption("keepTheme", v, true)
                        }
                    }
                }

                // Drawing and changing.
                Card {
                    Layout.fillWidth: true
                    implicitHeight: displayColumn.implicitHeight + 32
                    ColumnLayout {
                        id: displayColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        SectionLabel { text: "Display and auto-change" }
                        ChipRow {
                            label: "Fit"
                            value: page.cfg.fill || "crop"
                            choices: [{ value: "crop", label: "Fill" }, { value: "fit", label: "Fit" }, { value: "stretch", label: "Stretch" }, { value: "center", label: "Centre" }, { value: "tile", label: "Tile" }]
                            onPicked: v => wallpaper.setOption("fill", v)
                        }
                        ChipRow {
                            label: "Change every"
                            value: Number((page.cfg.rotation || {}).interval) || 0
                            choices: [{ value: 0, label: "Off" }, { value: 5, label: "5 min" }, { value: 15, label: "15 min" }, { value: 30, label: "30 min" }, { value: 60, label: "1 h" }, { value: 180, label: "3 h" }, { value: 1440, label: "Daily" }]
                            onPicked: v => wallpaper.setOption("rotation.interval", v)
                        }
                        ChipRow {
                            label: "Pick from"
                            value: (page.cfg.rotation || {}).source || "search"
                            choices: [{ value: "search", label: "The last search" }, { value: "library", label: "Library" }, { value: "favorites", label: "Favourites" }, { value: "local", label: "Your folders" }]
                            onPicked: v => wallpaper.setOption("rotation.source", v)
                        }
                        Label {
                            Layout.fillWidth: true
                            text: "Transitions between wallpapers are set in the Studio hub (Studio › Transitions); the shell's Studio service draws them."
                            color: theme.textDim
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    Confirm {
        id: deleteConfirm
        heading: "Delete " + page.basename(page.deleting) + "?"
        body: "It's removed from " + (page.cfg.library || "the library").replace(/^\/home\/[^/]+/, "~") + ". A favourite of it stays and downloads it again when used."
        action: "Delete"
        onAccepted: page.acceptDialog()
        onRejected: visible = false
    }
}
