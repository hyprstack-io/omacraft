import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// One marketplace: a searchable wall of cards, a page at a time, and a card
// opened out into its details and what can be done with it. Everything shown
// comes from a community catalogue, so all of it is drawn as plain text.
Item {
    id: page

    property string kind: "plugins"
    property string heading
    property string subtitle
    property string glyph
    property string noun: "plugin"

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property bool isPlugins: kind === "plugins"
    readonly property bool dialogOpen: confirm.visible
    readonly property var shortcuts: [
        { keys: "/", action: "Search" },
        { keys: "[ / ]", action: "Previous / next page" },
        { keys: "R", action: "Fetch the catalogue again" },
        { keys: "Esc", action: "Close the details" }
    ]

    property string query: ""
    property string category: ""
    property string filter: "all"
    property string sort: isPlugins ? "stars" : "name"
    property int pageNumber: 1
    property var opened: null

    onQueryChanged: pageNumber = 1
    onCategoryChanged: pageNumber = 1
    onFilterChanged: pageNumber = 1
    onSortChanged: pageNumber = 1
    onPageNumberChanged: grid.positionViewAtBeginning()
    onActiveChanged: if (active) market.load(kind)

    readonly property var result: { market.revision; return market.browse(kind, query, category, sort, filter, pageNumber); }
    readonly property bool busy: { market.revision; return market.loading(kind); }
    readonly property string problem: { market.revision; return market.problem(kind); }
    readonly property bool hasList: { market.revision; return market.loaded(kind); }
    readonly property string age: { market.revision; return market.age(kind); }
    // The open card, kept up to date as things are installed.
    readonly property var details: {
        market.revision;
        if (!opened) return null;
        const items = result.items;
        for (let i = 0; i < items.length; i++)
            if (items[i].id === opened.id) return items[i];
        return opened;
    }

    function handleEscape() {
        if (confirm.visible) { confirm.visible = false; return true; }
        if (opened !== null) { opened = null; return true; }
        if (market.error !== "" || market.notice !== "") { market.dismissMessages(); return true; }
        return false;
    }
    function acceptDialog() {
        if (!confirm.visible) return;
        confirm.visible = false;
        if (confirm.run) confirm.run();
    }
    function ask(heading, body, action, run) {
        confirm.heading = heading;
        confirm.body = body;
        confirm.action = action;
        confirm.run = run;
        confirm.visible = true;
    }
    function step(by) { pageNumber = Math.max(1, Math.min(result.pages, result.page + by)); }

    function askInstallPlugin(item, enable) {
        ask("Install " + item.name + "?",
            "Community plugins run as unsandboxed code inside your shell, with your account's access to files and credentials. "
            + (item.verified ? "This one passed the marketplace's automated checks, which are not a security audit, and installing takes the repository's latest code, which may be newer than what was checked."
                             : "This one has not been verified by the marketplace.")
            + "\n\n" + item.repo + "\n\nOnly install what you trust.",
            enable ? "Install and enable" : "Install",
            () => market.installPlugin(item.id, enable));
    }
    function askInstallTheme(item) {
        ask("Install " + item.name + "?",
            "This clones " + item.repo + " into ~/.config/omarchy/themes/" + item.folder
            + " and applies it straight away, as omarchy theme install does. Themes can include scripts and config, so install what you trust.",
            "Install and apply",
            () => market.installTheme(item.folder));
    }

    readonly property bool keys: active && keysFree && !confirm.visible
    Shortcut { sequence: "/"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: searchBox.forceActiveFocus() }
    Shortcut { sequence: "["; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.step(-1) }
    Shortcut { sequence: "]"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.step(1) }
    Shortcut { sequence: "R"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: market.load(page.kind, true) }

    // Holds the search back while typing.
    Timer { id: settle; interval: 180; onTriggered: page.query = searchBox.text.trim() }

    component Badge: Rectangle {
        property string text
        property color tone: theme.accent
        implicitWidth: badgeLabel.implicitWidth + 12
        implicitHeight: 20
        radius: 5
        color: Qt.rgba(Qt.color(tone).r, Qt.color(tone).g, Qt.color(tone).b, 0.16)
        border.color: tone
        Label { id: badgeLabel; anchors.centerIn: parent; text: parent.text; color: parent.tone; font.pixelSize: 10; font.weight: Font.DemiBold }
    }

    // Level with an AccentButton beside it.
    component SheetButton: Button {
        flat: true
        focusPolicy: Qt.NoFocus
        implicitHeight: 36
        topInset: 0
        bottomInset: 0
    }

    // The picture, or the listing's initials on the theme's colours until
    // there is one.
    component Picture: Rectangle {
        id: picture
        property string source
        property string initials
        clip: true
        color: theme.sunken
        Label {
            anchors.centerIn: parent
            visible: image.status !== Image.Ready
            text: picture.initials
            textFormat: Text.PlainText
            color: theme.textFaint
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: picture.height * 0.28
            font.weight: Font.Bold
        }
        Image {
            id: image
            anchors.fill: parent
            source: picture.source
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 640
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        PageHeader {
            title: page.heading
            subtitle: page.subtitle + (page.age !== "" ? ", fetched " + page.age : "")
            glyph: page.glyph
            AccentButton {
                text: page.busy ? "Fetching…" : "Refresh"
                enabled: !page.busy
                onClicked: market.load(page.kind, true)
            }
            KeyCap { text: "R" }
        }

        MessageBar {
            error: market.error
            notice: market.notice
            onDismissed: market.dismissMessages()
        }

        Rectangle {
            Layout.fillWidth: true
            visible: page.problem !== "" && page.hasList
            implicitHeight: staleLabel.implicitHeight + 16
            radius: 8
            color: theme.warningFill
            border.color: theme.warningBorder
            Label {
                id: staleLabel
                anchors.fill: parent
                anchors.margins: 8
                wrapMode: Text.WordWrap
                color: theme.warningText
                text: "Couldn't refresh the catalogue, so this is the last copy fetched. " + page.problem
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            SearchBox {
                id: searchBox
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                placeholderText: "Search " + page.noun + "s, authors and tags"
                onTextChanged: settle.restart()
            }
            KeyCap { text: "/"; visible: page.width > 820 }
            Segmented {
                model: page.isPlugins
                       ? [{ id: "all", name: "All" }, { id: "installable", name: "Installable" }, { id: "verified", name: "Verified" }, { id: "installed", name: "Installed" }]
                       : [{ id: "all", name: "All" }, { id: "installed", name: "Installed" }]
                current: page.filter
                onPicked: id => page.filter = id
            }
            Segmented {
                visible: page.isPlugins
                model: [{ id: "stars", name: "Starred" }, { id: "recent", name: "Newest" }, { id: "name", name: "A–Z" }]
                current: page.sort
                onPicked: id => page.sort = id
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: page.isPlugins && page.hasList
            spacing: 6
            Chip { text: "Everything"; chosen: page.category === ""; onClicked: page.category = "" }
            Repeater {
                model: { market.revision; return market.categories(); }
                Chip {
                    required property var modelData
                    text: modelData.name + "  " + modelData.count
                    chosen: page.category === modelData.id
                    onClicked: page.category = modelData.id
                }
            }
        }

        // ---- the wall
        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: page.result.items.length > 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            readonly property int across: Math.max(1, Math.floor(width / 280))
            cellWidth: width / across
            cellHeight: cellWidth * 0.5625 + (page.isPlugins ? 92 : 56)
            model: page.result.items
            ScrollBar.vertical: ScrollBar {}
            delegate: Item {
                id: cell
                required property var modelData
                objectName: "card-" + modelData.id
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    id: tile
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: 10
                    color: cellHover.hovered ? theme.hover : theme.card
                    border.color: cellHover.hovered ? theme.accent : theme.border
                    clip: true
                    scale: cellHover.hovered ? 1.015 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    Picture {
                        id: shot
                        x: 1; y: 1
                        width: parent.width - 2
                        height: width * 0.5625
                        topLeftRadius: 9
                        topRightRadius: 9
                        source: cell.modelData.thumbnail
                        initials: page.isPlugins ? cell.modelData.initials : cell.modelData.name.slice(0, 2).toUpperCase()
                    }
                    Row {
                        x: 8; y: 8
                        spacing: 4
                        Badge {
                            visible: cell.modelData.state !== "available"
                            text: ({ enabled: "ON", disabled: "OFF", installed: "INSTALLED", current: "IN USE", taken: "NAME IN USE" })[cell.modelData.state] || ""
                            tone: cell.modelData.state === "taken" ? theme.warningText : theme.accent
                        }
                    }
                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: shot.bottom
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        anchors.topMargin: 8
                        spacing: 1
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label {
                                Layout.fillWidth: true
                                text: cell.modelData.name
                                textFormat: Text.PlainText
                                color: theme.text
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Label {
                                visible: page.isPlugins && cell.modelData.verified === true
                                text: "\u{f0483}"
                                color: theme.accent
                                font.family: "JetBrainsMono Nerd Font"
                                ToolTip.visible: verifiedHover.hovered
                                ToolTip.text: "Passed the marketplace's automated checks"
                                HoverHandler { id: verifiedHover }
                            }
                            Label {
                                visible: page.isPlugins && cell.modelData.stars > 0
                                text: "\u{f04ce} " + cell.modelData.stars
                                color: theme.textMuted
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: cell.modelData.author
                            textFormat: Text.PlainText
                            color: theme.textMuted
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Label {
                            visible: page.isPlugins
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: cell.modelData.description || ""
                            textFormat: Text.PlainText
                            color: theme.textDim
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
                HoverHandler { id: cellHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: page.opened = cell.modelData }
            }
        }

        // ---- when there's no wall to show
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: page.result.items.length === 0
            spacing: 10
            Item { Layout.fillHeight: true }
            BusyIndicator { Layout.alignment: Qt.AlignHCenter; visible: page.busy; running: visible }
            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.maximumWidth: 520
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                color: page.problem !== "" && !page.hasList ? theme.danger : theme.textMuted
                text: page.busy ? "Fetching the catalogue…"
                    : !page.hasList ? (page.problem !== "" ? "Couldn't fetch the catalogue. " + page.problem : "No catalogue yet.")
                    : page.filter === "installed" && page.query === "" ? "Nothing from here is installed yet."
                    : "No " + page.noun + "s match that."
            }
            Button {
                Layout.alignment: Qt.AlignHCenter
                visible: !page.busy && !page.hasList
                text: "Try again"
                flat: true
                focusPolicy: Qt.NoFocus
                onClicked: market.load(page.kind, true)
            }
            Item { Layout.fillHeight: true }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: page.result.total > 0
            spacing: 8
            Label {
                text: page.result.total.toLocaleString(Qt.locale(), "f", 0) + " " + page.noun + (page.result.total === 1 ? "" : "s")
                color: theme.textMuted
                font.pixelSize: 12
            }
            Item { Layout.fillWidth: true }
            Button { text: "Previous"; flat: true; focusPolicy: Qt.NoFocus; enabled: page.result.page > 1; onClicked: page.step(-1) }
            KeyCap { text: "[" }
            Label { text: "Page " + page.result.page + " of " + page.result.pages; color: theme.textSoft; font.pixelSize: 12 }
            KeyCap { text: "]" }
            Button { text: "Next"; flat: true; focusPolicy: Qt.NoFocus; enabled: page.result.page < page.result.pages; onClicked: page.step(1) }
        }
    }

    // ---- a card opened out
    Rectangle {
        anchors.fill: parent
        visible: page.opened !== null
        color: "#a0000000"
        z: 20
        MouseArea { anchors.fill: parent; onClicked: page.opened = null }

        Rectangle {
            id: sheet
            objectName: "sheet"
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.min(560, parent.width - 60)
            color: theme.raised
            border.color: theme.borderStrong
            MouseArea { anchors.fill: parent }

            readonly property var item: page.details || ({})
            readonly property bool working: market.working !== "" && (market.working === item.id || market.working === item.folder)
            readonly property string state: item.state || "available"

            ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth
                ColumnLayout {
                    width: sheet.width
                    spacing: 12
                    Picture {
                        Layout.fillWidth: true
                        Layout.preferredHeight: sheet.width * 0.5625
                        source: sheet.item.image || ""
                        initials: sheet.item.initials || (sheet.item.name || "").slice(0, 2).toUpperCase()
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        Layout.bottomMargin: 20
                        spacing: 10
                        Label {
                            Layout.fillWidth: true
                            text: sheet.item.name || ""
                            textFormat: Text.PlainText
                            color: theme.text
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                        }
                        Label {
                            Layout.fillWidth: true
                            text: "by " + (sheet.item.author || "unknown")
                                  + (sheet.item.version ? "  ·  " + sheet.item.version : "")
                                  + (sheet.item.license ? "  ·  " + sheet.item.license : "")
                            textFormat: Text.PlainText
                            color: theme.textMuted
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                        Flow {
                            visible: page.isPlugins
                            Layout.fillWidth: true
                            spacing: 4
                            Badge { text: sheet.item.verified ? "VERIFIED" : "UNVERIFIED"; tone: sheet.item.verified ? theme.accent : theme.warningText }
                            Badge { visible: !!sheet.item.kind; text: (sheet.item.kind || "").toUpperCase(); tone: theme.textSoft }
                            Badge { visible: !!sheet.item.category; text: (sheet.item.category || "").toUpperCase(); tone: theme.textSoft }
                        }
                        Label {
                            visible: page.isPlugins
                            Layout.fillWidth: true
                            text: sheet.item.description || ""
                            textFormat: Text.PlainText
                            color: theme.textSoft
                            wrapMode: Text.Wrap
                        }
                        Label {
                            visible: !!sheet.item.note
                            Layout.fillWidth: true
                            text: sheet.item.note || ""
                            textFormat: Text.PlainText
                            color: theme.textDim
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                        Label {
                            visible: sheet.state === "taken"
                            Layout.fillWidth: true
                            text: "You already have a different theme in ~/.config/omarchy/themes/" + (sheet.item.folder || "")
                                  + ". Installing this one would delete it, so OmaCraft won't."
                            color: theme.warningText
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                        Label {
                            visible: sheet.item.managed === true
                            Layout.fillWidth: true
                            text: "OmaCraft looks after this one on the Plugin Suite page."
                            color: theme.textDim
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }

                        Flow {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 8
                            // Plugins
                            AccentButton {
                                visible: page.isPlugins && sheet.state === "available" && sheet.item.canInstall === true
                                enabled: market.working === ""
                                text: sheet.working ? "Installing…" : "Install and enable"
                                onClicked: page.askInstallPlugin(sheet.item, true)
                            }
                            SheetButton {
                                visible: page.isPlugins && sheet.state === "available" && sheet.item.canInstall === true
                                enabled: market.working === ""
                                text: "Install only"
                                onClicked: page.askInstallPlugin(sheet.item, false)
                            }
                            AccentButton {
                                visible: page.isPlugins && (sheet.state === "enabled" || sheet.state === "disabled") && !sheet.item.managed
                                enabled: market.working === ""
                                text: sheet.state === "enabled" ? "Turn off" : "Turn on"
                                onClicked: market.setPluginEnabled(sheet.item.id, sheet.state !== "enabled")
                            }
                            SheetButton {
                                visible: page.isPlugins && (sheet.state === "enabled" || sheet.state === "disabled") && !sheet.item.managed
                                enabled: market.working === ""
                                text: "Update"
                                onClicked: market.updatePlugin(sheet.item.id)
                            }
                            SheetButton {
                                visible: page.isPlugins && (sheet.state === "enabled" || sheet.state === "disabled") && !sheet.item.managed
                                enabled: market.working === ""
                                text: "Remove"
                                Material.foreground: theme.danger
                                onClicked: page.ask("Remove " + sheet.item.name + "?", "Omarchy deletes its folder. It can be installed again from here.", "Remove",
                                                    () => market.removePlugin(sheet.item.id))
                            }
                            // Themes
                            AccentButton {
                                visible: !page.isPlugins && sheet.state === "available"
                                enabled: market.working === ""
                                text: sheet.working ? "Installing…" : "Install and apply"
                                onClicked: page.askInstallTheme(sheet.item)
                            }
                            AccentButton {
                                visible: !page.isPlugins && sheet.state === "installed"
                                enabled: market.working === ""
                                text: sheet.working ? "Working…" : "Apply"
                                onClicked: market.applyTheme(sheet.item.folder)
                            }
                            SheetButton {
                                visible: !page.isPlugins && (sheet.state === "installed" || sheet.state === "current")
                                enabled: market.working === ""
                                text: "Update"
                                onClicked: market.updateTheme(sheet.item.folder)
                            }
                            SheetButton {
                                visible: !page.isPlugins && sheet.state === "installed"
                                enabled: market.working === ""
                                text: "Remove"
                                Material.foreground: theme.danger
                                onClicked: page.ask("Remove " + sheet.item.name + "?", "Omarchy deletes its folder. It can be installed again from here.", "Remove",
                                                    () => market.removeTheme(sheet.item.folder))
                            }
                            SheetButton {
                                text: "Open repository"
                                onClicked: market.openRepository(sheet.item.repo)
                            }
                        }
                        BusyIndicator { visible: sheet.working; running: visible; implicitWidth: 28; implicitHeight: 28 }
                        Label {
                            visible: page.isPlugins
                            Layout.fillWidth: true
                            text: "Community plugins are made by independent people and run unsandboxed. Read the code before you trust it."
                            color: theme.textFaint
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    Confirm {
        id: confirm
        property var run: null
        keepText: "Cancel"
        onAccepted: page.acceptDialog()
        onRejected: visible = false
    }
}
