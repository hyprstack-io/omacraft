import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// HyprVYZR: Kasm Workspaces on the desktop. Sign in to Kasm servers in the
// cloud (or anywhere), install one on this machine, or run Kasm's images
// natively in Docker; every workspace then starts from the carousel, a key,
// the bar folder or the side dock, in its own popup window that minimises to
// the bar. The omacraft.hyprvyzr plugin does the work through its `hyprvyzr`
// command; this page drives it.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property var tabs: [
        { id: "workspaces", name: "Workspaces" },
        { id: "servers", name: "Servers" },
        { id: "local", name: "This machine" },
        { id: "native", name: "Native" },
        { id: "launch", name: "Launchers & keys" },
        { id: "look", name: "Look & dashboard" }
    ]
    property string tab: tabs.map(t => t.id).indexOf(startTab) >= 0 ? startTab : "workspaces"
    property string removing: ""

    readonly property var info: plugins.plugins.find(p => p.id === "omacraft.hyprvyzr") || ({})
    readonly property bool installed: info.installed === true
    readonly property bool enabled: info.enabled === true
    readonly property bool ready: hyprvyzr.available
    readonly property var cfg: hyprvyzr.config || ({})
    readonly property var nativeCfg: cfg.native || ({})
    readonly property bool nativeOn: nativeCfg.enabled !== false
    readonly property var running: hyprvyzr.sessions || []
    readonly property var localInfo: hyprvyzr.local || ({})

    readonly property color accentColor: Qt.color(theme.accent)
    // accent-2, the suite's rule: the accent turned 50° round the hue wheel.
    readonly property color accent2: Qt.hsla((accentColor.hslHue + 50 / 360) % 1, Math.max(0.35, accentColor.hslSaturation),
                                             accentColor.hslLightness, 1)

    readonly property bool dialogOpen: removeConfirm.visible
    readonly property var shortcuts: [
        { keys: "W S L N K D", action: "Workspaces, Servers, This machine, Native, Keys, Look & dashboard" },
        { keys: "C", action: "Open the carousel over the desktop" },
        { keys: "R", action: "Ask every server for its workspaces again" },
        { keys: "Ctrl N", action: "Add a server" }
    ]

    function handleEscape() {
        if (removeConfirm.visible) { removeConfirm.visible = false; return true; }
        if (hyprvyzr.error !== "" || hyprvyzr.notice !== "") { hyprvyzr.dismissMessages(); return true; }
        return false;
    }
    function acceptDialog() {
        removeConfirm.visible = false;
        hyprvyzr.removeServer(page.removing);
    }

    onActiveChanged: if (active) hyprvyzr.refresh()

    readonly property bool keys: active && keysFree && !dialogOpen
    Shortcut { sequence: "W"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = "workspaces" }
    Shortcut { sequence: "S"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = "servers" }
    Shortcut { sequence: "L"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = "local" }
    Shortcut { sequence: "N"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = "native" }
    Shortcut { sequence: "K"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = "launch" }
    Shortcut { sequence: "D"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = "look" }
    Shortcut { sequence: "C"; context: Qt.ApplicationShortcut; enabled: page.keys && page.enabled; onActivated: hyprvyzr.openCarousel("all") }
    Shortcut { sequence: "R"; context: Qt.ApplicationShortcut; enabled: page.keys && page.ready; onActivated: hyprvyzr.refreshWorkspaces(true) }
    Shortcut {
        sequence: "Ctrl+N"; context: Qt.ApplicationShortcut; enabled: page.active && page.ready
        onActivated: { page.tab = "servers"; nameField.forceActiveFocus(); }
    }

    // A stat in the hero: a number over a word.
    component Stat: ColumnLayout {
        property string value
        property string label
        spacing: 0
        Label { text: parent.value; color: theme.text; font.pixelSize: 22; font.weight: Font.DemiBold; font.family: "JetBrains Mono" }
        Label { text: parent.label; color: theme.textMuted; font.pixelSize: 11; font.letterSpacing: 1; font.capitalization: Font.AllUppercase }
    }

    // A workspace's picture: Kasm's thumbnail, else its glyph, on its tint.
    component WorkspaceIcon: Rectangle {
        id: wi
        property var ws: ({})
        property int size: 56
        width: size; height: size
        radius: 0
        readonly property real shift: {
            const s = String(wi.ws.key || "");
            let h = 0;
            for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 997;
            return h / 997;
        }
        readonly property color tint: Qt.hsla((page.accentColor.hslHue + shift * 50 / 360) % 1, Math.max(0.35, page.accentColor.hslSaturation), 0.5, 1)
        color: Qt.rgba(tint.r, tint.g, tint.b, 0.16)
        border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.5)
        Image {
            id: wiImage
            anchors.fill: parent
            anchors.margins: wi.size * 0.14
            source: wi.ws.thumb ? "file://" + wi.ws.thumb : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize.width: wi.size * 2
            sourceSize.height: wi.size * 2
            opacity: wi.ws.installed === false ? 0.5 : 1
        }
        Label {
            visible: wiImage.status !== Image.Ready
            anchors.centerIn: parent
            text: wi.ws.glyph || String(wi.ws.name || "?").charAt(0).toUpperCase()
            color: Qt.lighter(wi.tint, 1.4)
            opacity: wi.ws.installed === false ? 0.6 : 1
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: wi.size * 0.5
            font.weight: Font.Bold
        }
    }

    // A small flat action.
    component Act: Button {
        flat: true
        focusPolicy: Qt.NoFocus
        Layout.preferredHeight: 34
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        contentHeight: column.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: column
            x: 20; y: 20
            width: scroller.width - 40
            spacing: 14

            PageHeader {
                title: "HyprVYZR"
                subtitle: "Kasm Workspaces, remote, local and native, in popups that minimise to the bar"
                glyph: "\u{f0379}"
                Button {
                    text: "Refresh"
                    flat: true
                    focusPolicy: Qt.NoFocus
                    visible: page.ready
                    onClicked: hyprvyzr.refreshWorkspaces(true)
                }
                KeyCap { text: "R"; visible: page.ready }
                AccentButton {
                    text: "Open carousel"
                    visible: page.ready
                    enabled: page.enabled
                    onClicked: hyprvyzr.openCarousel("all")
                }
                KeyCap { text: "C"; visible: page.ready }
            }

            // ---- The hero: the title arriving like a remote frame, and the numbers.
            Rectangle {
                id: hero
                Layout.fillWidth: true
                Layout.preferredHeight: heroColumn.implicitHeight + 40
                color: theme.sunken
                border.width: 0
                clip: true

                // A 2px accent → accent-2 frame, turning slowly: the HyprStack window border.
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 2
                    border.color: page.accentColor
                    opacity: 0.0
                }
                Canvas {
                    id: frame
                    anchors.fill: parent
                    property real angle: 0
                    NumberAnimation on angle { from: 0; to: 360; duration: 9000; loops: Animation.Infinite; running: page.active && hero.visible }
                    onAngleChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const a = angle * Math.PI / 180;
                        const cx = width / 2, cy = height / 2, r = Math.max(width, height);
                        const g = ctx.createLinearGradient(cx - Math.cos(a) * r, cy - Math.sin(a) * r, cx + Math.cos(a) * r, cy + Math.sin(a) * r);
                        g.addColorStop(0, page.accentColor);
                        g.addColorStop(1, page.accent2);
                        ctx.strokeStyle = g;
                        ctx.lineWidth = 2;
                        ctx.strokeRect(1, 1, width - 2, height - 2);
                        // A faint framebuffer grid behind the title.
                        ctx.strokeStyle = Qt.rgba(page.accentColor.r, page.accentColor.g, page.accentColor.b, 0.06);
                        ctx.lineWidth = 1;
                        for (let x = 24; x < width; x += 24) { ctx.beginPath(); ctx.moveTo(x + 0.5, 2); ctx.lineTo(x + 0.5, height - 2); ctx.stroke(); }
                        for (let y = 24; y < height; y += 24) { ctx.beginPath(); ctx.moveTo(2, y + 0.5); ctx.lineTo(width - 2, y + 0.5); ctx.stroke(); }
                    }
                }

                ColumnLayout {
                    id: heroColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 14

                    HyprvyzrTitle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: implicitHeight
                        maxCell: 8
                        running: page.active
                        ink: theme.text
                        accent: page.accentColor
                        accent2: page.accent2
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 28
                        Label {
                            Layout.fillWidth: true
                            text: "A Kasm workspace anywhere: on a server in the cloud, on this machine, or straight from Docker. Each one opens as a popup you can tile, detach or minimise to the bar."
                            color: theme.textSoft
                            wrapMode: Text.WordWrap
                            font.pixelSize: 13
                        }
                        Stat { value: String(hyprvyzr.servers.length); label: "servers" }
                        Stat { value: String(hyprvyzr.workspaces.length); label: "workspaces" }
                        Stat { value: String(page.running.length); label: "running" }
                    }
                }
            }

            NotInstalled {
                visible: !page.ready
                pluginId: "omacraft.hyprvyzr"
                what: "HyprVYZR's carousel, bar folder and its hyprvyzr command come in the HyprVYZR plugin."
            }

            // Installed but off: the carousel and bar folder need the shell to load it.
            Rectangle {
                Layout.fillWidth: true
                visible: page.ready && page.installed && !page.enabled
                implicitHeight: offRow.implicitHeight + 18
                radius: 8
                color: theme.warningFill
                border.color: theme.warningBorder
                RowLayout {
                    id: offRow
                    anchors.fill: parent
                    anchors.margins: 9
                    anchors.leftMargin: 14
                    Label {
                        Layout.fillWidth: true
                        text: "HyprVYZR is installed but not enabled, so the carousel and the bar folder can't open yet. Workspaces still start from here."
                        color: theme.warningText
                        wrapMode: Text.WordWrap
                    }
                    Button {
                        text: "Enable"
                        focusPolicy: Qt.NoFocus
                        enabled: !plugins.busy
                        onClicked: plugins.setEnabled("omacraft.hyprvyzr", true)
                    }
                }
            }

            MessageBar {
                error: hyprvyzr.error
                notice: hyprvyzr.busy !== "" ? hyprvyzr.busy : hyprvyzr.notice
                onDismissed: hyprvyzr.dismissMessages()
            }

            Segmented {
                visible: page.ready
                model: page.tabs
                current: page.tab
                onPicked: id => page.tab = id
            }

            // ================================================== Workspaces
            ColumnLayout {
                visible: page.ready && page.tab === "workspaces"
                Layout.fillWidth: true
                spacing: 12

                // Running sessions, with their controls.
                Card {
                    Layout.fillWidth: true
                    visible: page.running.length > 0
                    implicitHeight: runningCol.implicitHeight + 28
                    ColumnLayout {
                        id: runningCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        SectionLabel { text: "Running" }
                        Repeater {
                            model: page.running
                            RowLayout {
                                id: sRow
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 10
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    color: sRow.modelData.hidden ? theme.textFaint : theme.accent
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: sRow.modelData.name + "  ·  " + sRow.modelData.serverName
                                          + (sRow.modelData.hidden ? "  ·  minimised to the bar" : sRow.modelData.floating ? "  ·  popup" : "  ·  tiled")
                                    color: theme.text
                                    elide: Text.ElideRight
                                }
                                Act { text: sRow.modelData.hidden ? "Bring back" : "Minimise"; onClicked: hyprvyzr.sessionAction(sRow.modelData.hidden ? "show" : "hide", sRow.modelData.id) }
                                Act { text: sRow.modelData.floating ? "Tile" : "Popup"; onClicked: hyprvyzr.sessionAction(sRow.modelData.floating ? "tile" : "float", sRow.modelData.id) }
                                Act { text: "End"; Material.foreground: theme.danger; onClicked: hyprvyzr.sessionAction("end", sRow.modelData.id) }
                            }
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: hyprvyzr.workspaceErrors.length > 0
                    text: hyprvyzr.workspaceErrors.join("\n")
                    color: theme.warningText
                    wrapMode: Text.WordWrap
                    font.pixelSize: 12
                }

                // Empty: where to start.
                Card {
                    Layout.fillWidth: true
                    visible: hyprvyzr.workspaces.length === 0
                    implicitHeight: emptyCol.implicitHeight + 40
                    ColumnLayout {
                        id: emptyCol
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 40, 560)
                        spacing: 10
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: "No workspaces yet"
                            color: theme.text
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }
                        Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            color: theme.textMuted
                            text: "Sign in to a Kasm server, install one on this machine, or switch on native workspaces to run Kasm's images straight from Docker."
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            AccentButton { text: "Add a server"; onClicked: page.tab = "servers" }
                            Button { text: "This machine"; flat: true; focusPolicy: Qt.NoFocus; onClicked: page.tab = "local" }
                            Button { text: "Native"; flat: true; focusPolicy: Qt.NoFocus; onClicked: page.tab = "native" }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: Math.max(1, Math.floor(width / 300))
                    columnSpacing: 10
                    rowSpacing: 10
                    Repeater {
                        model: hyprvyzr.workspaces
                        Rectangle {
                            id: tile
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 84
                            color: tileHover.hovered ? theme.hover : theme.card
                            border.color: tileHover.hovered ? theme.accent : theme.border
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                WorkspaceIcon { ws: tile.modelData; size: 56 }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Label { Layout.fillWidth: true; text: tile.modelData.name; color: theme.text; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                    Label {
                                        Layout.fillWidth: true
                                        text: (tile.modelData.kind === "native" ? "\u{f0868}  native" : tile.modelData.kind === "local" ? "\u{f048b}  this machine" : "\u{f048d}  " + tile.modelData.serverName)
                                              + (tile.modelData.installed === false ? "  ·  downloads first" : "")
                                        color: theme.textMuted
                                        font.pixelSize: 11
                                        font.family: "JetBrainsMono Nerd Font"
                                        elide: Text.ElideRight
                                    }
                                }
                                Button {
                                    text: "Start"
                                    focusPolicy: Qt.NoFocus
                                    enabled: hyprvyzr.busy === ""
                                    onClicked: hyprvyzr.launch(tile.modelData.key)
                                }
                            }
                            HoverHandler { id: tileHover }
                            ToolTip.visible: tileHover.hovered && (tile.modelData.description || "") !== ""
                            ToolTip.delay: 500
                            ToolTip.text: tile.modelData.description || ""
                        }
                    }
                }
            }

            // ================================================== Servers
            ColumnLayout {
                visible: page.ready && page.tab === "servers"
                Layout.fillWidth: true
                spacing: 12

                Repeater {
                    model: hyprvyzr.servers
                    Card {
                        id: serverCard
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: serverRow.implicitHeight + 28
                        RowLayout {
                            id: serverRow
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12
                            Label {
                                text: serverCard.modelData.kind === "local" ? "\u{f048b}" : "\u{f048d}"
                                color: theme.accent
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 26
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label { text: serverCard.modelData.name; color: theme.text; font.weight: Font.DemiBold }
                                Label {
                                    Layout.fillWidth: true
                                    text: serverCard.modelData.url + "  ·  as " + serverCard.modelData.user
                                          + (serverCard.modelData.hasKey ? "  ·  API key saved" : "  ·  no API key: add it again")
                                    color: serverCard.modelData.hasKey ? theme.textMuted : theme.warningText
                                    font.pixelSize: 12
                                    font.family: "JetBrains Mono"
                                    elide: Text.ElideRight
                                }
                            }
                            Act { text: "Test"; onClicked: hyprvyzr.testServer(serverCard.modelData.id) }
                            Act { text: "Dashboard"; onClicked: hyprvyzr.openDashboard(serverCard.modelData.id) }
                            Act {
                                text: "Remove"
                                Material.foreground: theme.danger
                                onClicked: { page.removing = serverCard.modelData.id; removeConfirm.visible = true; }
                            }
                        }
                    }
                }

                // Sign in to a server.
                Card {
                    Layout.fillWidth: true
                    implicitHeight: addCol.implicitHeight + 32
                    ColumnLayout {
                        id: addCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        SectionLabel { text: "Sign in to a Kasm server" }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: theme.textDim
                            font.pixelSize: 12
                            textFormat: Text.StyledText
                            text: "In Kasm, as an admin: <b>Settings › Developers › Add API Key</b>, then give it <b>Images View</b>, "
                                  + "<b>Users View</b>, <b>Users Auth Session</b> and <b>User</b>. Sessions start as the Kasm user named below. "
                                  + "The key goes to your keyring (or a private file without one) and never into OmaCraft's settings."
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: width > 760 ? 2 : 1
                            columnSpacing: 16
                            rowSpacing: 10
                            Field {
                                label: "Name"
                                TextField { id: nameField; Layout.fillWidth: true; placeholderText: "reqt.net" }
                            }
                            Field {
                                label: "Address"
                                hint: "https only, with a port if it isn't 443."
                                TextField { id: urlField; Layout.fillWidth: true; placeholderText: "https://kasm.example.com" }
                            }
                            Field {
                                label: "Kasm user"
                                TextField { id: userField; Layout.fillWidth: true; placeholderText: "you@example.com" }
                            }
                            Field {
                                label: "Kind"
                                Segmented {
                                    id: kindSeg
                                    model: [{ id: "remote", name: "Remote" }, { id: "local", name: "This machine" }]
                                    current: "remote"
                                    onPicked: id => current = id
                                }
                            }
                            Field {
                                label: "API key"
                                TextField { id: keyField; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "API_KEY" }
                            }
                            Field {
                                label: "API key secret"
                                TextField { id: secretField; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "API_KEY_SECRET" }
                            }
                            Field {
                                label: "SSH for the dashboard theme"
                                hint: "Optional: where Look & dashboard installs the theme. root@host by default."
                                TextField { id: sshField; Layout.fillWidth: true; placeholderText: "root@kasm.example.com" }
                            }
                            SwitchRow {
                                id: insecureSwitch
                                visible: /^https:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?\/?$/.test(urlField.text.trim())
                                label: "Accept its own certificate"
                                hint: "Kasm's installer makes a self-signed one. Only allowed for a server on this machine."
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            AccentButton {
                                text: "Sign in"
                                enabled: hyprvyzr.busy === "" && nameField.text.trim() !== "" && urlField.text.trim() !== ""
                                         && userField.text.trim() !== "" && keyField.text !== "" && secretField.text !== ""
                                onClicked: hyprvyzr.addServer({
                                    name: nameField.text, url: urlField.text, user: userField.text, kind: kindSeg.current,
                                    insecure: insecureSwitch.visible && insecureSwitch.checked, ssh: sshField.text,
                                    apiKey: keyField.text, apiSecret: secretField.text
                                })
                            }
                        }
                        Connections {
                            target: hyprvyzr
                            function onServerAdded() {
                                nameField.text = ""; urlField.text = ""; userField.text = "";
                                keyField.text = ""; secretField.text = ""; sshField.text = "";
                            }
                        }
                    }
                }
            }

            // ================================================== This machine
            ColumnLayout {
                visible: page.ready && page.tab === "local"
                Layout.fillWidth: true
                spacing: 12

                Card {
                    Layout.fillWidth: true
                    implicitHeight: localCol.implicitHeight + 32
                    ColumnLayout {
                        id: localCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        RowLayout {
                            spacing: 10
                            Rectangle {
                                width: 10; height: 10; radius: 5
                                color: page.localInfo.running ? theme.success : page.localInfo.installed ? theme.warning : theme.textFaint
                            }
                            Label {
                                text: page.localInfo.running ? "Kasm is running on this machine"
                                      : page.localInfo.installed ? "Kasm is installed but not running"
                                      : "No Kasm server on this machine"
                                color: theme.text
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: theme.textMuted
                            text: page.localInfo.running
                                  ? "At " + page.localInfo.url + ". " + (page.localInfo.registered ? "It's on the Servers list." : "Add it on Servers with an API key from its admin panel.")
                                  : "Kasm " + "1.19.0" + " as a single server on https://localhost:" + (page.localInfo.port || 8443)
                                    + ". The install opens in a terminal, shows every step first, checks the download's sha256 and asks for your password for Kasm's own installer."
                        }
                        // What Kasm asks for, against this machine.
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: !page.localInfo.running
                            Chip { text: "Memory " + (page.localInfo.memoryGb || "?") + " GB (4+)"; dimmed: (page.localInfo.memoryGb || 0) < 4 }
                            Chip { text: "Free disk " + (page.localInfo.freeDiskGb || "?") + " GB (75+)"; dimmed: (page.localInfo.freeDiskGb || 0) < 75 }
                            Chip { text: page.localInfo.docker ? "Docker installed" : "Docker missing"; dimmed: !page.localInfo.docker }
                            Chip { text: "OS: " + (page.localInfo.os || "?") + (page.localInfo.supportedOs ? "" : " (not on Kasm's list)"); dimmed: !page.localInfo.supportedOs }
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: !page.localInfo.running && !page.localInfo.supportedOs
                            wrapMode: Text.WordWrap
                            color: theme.warningText
                            font.pixelSize: 12
                            text: "Kasm supports Ubuntu, Debian, RHEL and their relatives, not Arch, so its installer may stop part way here. Native workspaces need no server and work on this machine either way."
                        }
                        RowLayout {
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "Native instead"
                                flat: true
                                focusPolicy: Qt.NoFocus
                                visible: !page.localInfo.running
                                onClicked: page.tab = "native"
                            }
                            Act { text: "Open dashboard"; visible: page.localInfo.running === true; onClicked: hyprvyzr.openLocal() }
                            AccentButton {
                                text: page.localInfo.installed ? "Reinstall Kasm…" : "Install Kasm…"
                                visible: !page.localInfo.running
                                onClicked: hyprvyzr.installLocal()
                            }
                        }
                    }
                }
            }

            // ================================================== Native
            ColumnLayout {
                visible: page.ready && page.tab === "native"
                Layout.fillWidth: true
                spacing: 12

                Card {
                    Layout.fillWidth: true
                    implicitHeight: nativeCol.implicitHeight + 32
                    ColumnLayout {
                        id: nativeCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        SwitchRow {
                            label: "Native workspaces"
                            hint: "Kasm's workspace images run straight in Docker, no server: each start gets its own container on 127.0.0.1 with a password made for that run, removed when it ends."
                            checked: page.nativeOn
                            onToggled: on => hyprvyzr.setConfig("native.enabled", on)
                        }
                        RowLayout {
                            visible: page.nativeOn
                            spacing: 10
                            Label { text: "Image tag"; color: theme.textSoft; Layout.preferredWidth: 120 }
                            TextField {
                                Layout.preferredWidth: 140
                                text: page.nativeCfg.tag || "1.19.0"
                                validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9._-]{1,40}/ }
                                onEditingFinished: hyprvyzr.setConfig("native.tag", text)
                            }
                            Label { text: "Shared memory"; color: theme.textSoft }
                            TextField {
                                Layout.preferredWidth: 100
                                text: page.nativeCfg.shm || "512m"
                                validator: RegularExpressionValidator { regularExpression: /[0-9]{1,5}[mg]/ }
                                onEditingFinished: hyprvyzr.setConfig("native.shm", text)
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    visible: page.nativeOn
                    columns: Math.max(1, Math.floor(width / 300))
                    columnSpacing: 10
                    rowSpacing: 10
                    Repeater {
                        model: hyprvyzr.workspaces.filter(w => w.kind === "native")
                        Rectangle {
                            id: nTile
                            required property var modelData
                            readonly property string imageName: String(modelData.key).replace(/^native:/, "")
                            Layout.fillWidth: true
                            Layout.preferredHeight: 84
                            color: theme.card
                            border.color: theme.border
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                WorkspaceIcon { ws: nTile.modelData; size: 56 }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Label { text: nTile.modelData.name; color: theme.text; font.weight: Font.DemiBold }
                                    Label {
                                        Layout.fillWidth: true
                                        text: nTile.modelData.image + (nTile.modelData.installed ? "" : "  ·  not downloaded")
                                        color: theme.textMuted
                                        font.pixelSize: 11
                                        font.family: "JetBrains Mono"
                                        elide: Text.ElideRight
                                    }
                                }
                                Act {
                                    text: nTile.modelData.installed ? "Remove" : "Download"
                                    onClicked: nTile.modelData.installed ? hyprvyzr.removeNative(nTile.imageName) : hyprvyzr.pullNative(nTile.imageName)
                                }
                                Button {
                                    text: "Start"
                                    focusPolicy: Qt.NoFocus
                                    enabled: hyprvyzr.busy === ""
                                    onClicked: hyprvyzr.launch(nTile.modelData.key)
                                }
                            }
                        }
                    }
                }
            }

            // ================================================== Launchers & keys
            ColumnLayout {
                visible: page.ready && page.tab === "launch"
                Layout.fillWidth: true
                spacing: 12

                Card {
                    Layout.fillWidth: true
                    implicitHeight: placeCol.implicitHeight + 32
                    ColumnLayout {
                        id: placeCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        SectionLabel { text: "Where the launchers live" }
                        SwitchRow {
                            label: "A folder on the bar"
                            hint: "Slides open into your workspaces, running ones first. Minimised sessions wait in it with a badge; right-click for each one's controls."
                            checked: hyprvyzr.onBar
                            enabled: page.enabled
                            onToggled: on => hyprvyzr.setOnBar(on)
                        }
                        SwitchRow {
                            label: "On the side dock"
                            hint: plugins.isInstalled("omacraft.agentdock") ? "A HyprVYZR icon on the dock that opens the carousel." : "Install the Side Dock to put HyprVYZR on it."
                            checked: hyprvyzr.onDock
                            enabled: plugins.isInstalled("omacraft.agentdock")
                            onToggled: on => hyprvyzr.setOnDock(on)
                        }
                        Field {
                            label: "Session windows"
                            hint: "OmaCraft's window has the minimise-to-bar, popup/tile and end buttons. The browser window is a Chromium app with its own profile, for machines without OmaCraft."
                            Segmented {
                                model: [{ id: "native", name: "OmaCraft window" }, { id: "browser", name: "Browser app window" }]
                                current: page.cfg.window || "native"
                                onPicked: id => hyprvyzr.setConfig("window", id)
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    implicitHeight: keysCol.implicitHeight + 32
                    ColumnLayout {
                        id: keysCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        SectionLabel { text: "Keys" }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: theme.textDim
                            font.pixelSize: 12
                            text: "Each key opens the carousel on its own tab, over the desktop, without OmaCraft. They're written to ~/.config/hypr/omacraft_hyprvyzr.lua, which hyprland.lua loads."
                        }
                        Repeater {
                            model: hyprvyzr.keyTabs
                            RowLayout {
                                id: keyRow
                                required property var modelData
                                readonly property string bound: hyprvyzr.keys[modelData.tab] || ""
                                Layout.fillWidth: true
                                spacing: 10
                                ColumnLayout {
                                    Layout.preferredWidth: 220
                                    spacing: 0
                                    Label { text: keyRow.modelData.name; color: theme.text }
                                    Label { text: keyRow.modelData.hint; color: theme.textDim; font.pixelSize: 11 }
                                }
                                TextField {
                                    id: keyInput
                                    Layout.preferredWidth: 230
                                    placeholderText: keyRow.modelData.suggested || "none"
                                    text: keyRow.bound
                                    enabled: page.enabled
                                    onAccepted: hyprvyzr.bindKey(keyRow.modelData.tab, text.trim() === "" ? keyRow.modelData.suggested : text)
                                }
                                Button {
                                    text: keyRow.bound !== "" && keyInput.text === keyRow.bound ? "Bound" : "Set"
                                    enabled: page.enabled && !(keyRow.bound !== "" && keyInput.text === keyRow.bound)
                                             && (keyInput.text.trim() !== "" || keyRow.modelData.suggested !== "")
                                    focusPolicy: Qt.NoFocus
                                    onClicked: keyInput.accepted()
                                }
                                Act {
                                    text: "Clear"
                                    visible: keyRow.bound !== ""
                                    onClicked: { hyprvyzr.bindKey(keyRow.modelData.tab, ""); keyInput.text = ""; }
                                }
                                Act {
                                    text: "Try"
                                    enabled: page.enabled
                                    onClicked: hyprvyzr.openCarousel(keyRow.modelData.tab)
                                }
                                Item { Layout.fillWidth: true }
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: "In the carousel: ← → browse · ↑ ↓ tabs · type to filter · Enter starts as a popup · Shift Enter starts tiled · on Running, Enter brings one back and Ctrl X ends it."
                            color: theme.textMuted
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // ================================================== Look & dashboard
            ColumnLayout {
                visible: page.ready && page.tab === "look"
                Layout.fillWidth: true
                spacing: 12

                Card {
                    Layout.fillWidth: true
                    implicitHeight: lookCol.implicitHeight + 32
                    ColumnLayout {
                        id: lookCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        SectionLabel { text: "The carousel" }
                        SwitchRow {
                            label: "The HYPRVYZR title"
                            hint: "Arrives over the tabs like a remote frame painting in, then catches the light now and then."
                            checked: hyprvyzr.showTitle
                            onToggled: on => hyprvyzr.setShowTitle(on)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: hyprvyzr.cardBorderUrl !== ""
                            spacing: 8
                            Label { Layout.preferredWidth: 78; text: "Front card"; color: theme.textSoft; font.pixelSize: 12 }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 8
                                Repeater {
                                    model: wallPicker.cardEffects
                                    Rectangle {
                                        id: fxTile
                                        required property var modelData
                                        readonly property bool chosen: hyprvyzr.cardEffect === modelData.id
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
                                            source: hyprvyzr.cardBorderUrl
                                        }
                                        Binding { target: fxPreview.item; property: "effect"; value: fxTile.modelData.id; when: fxPreview.item !== null }
                                        Binding { target: fxPreview.item; property: "topLeft"; value: 5; when: fxPreview.item !== null }
                                        Binding { target: fxPreview.item; property: "bottomRight"; value: fxPreview.width - 5; when: fxPreview.item !== null }
                                        Binding { target: fxPreview.item; property: "lineWidth"; value: 2; when: fxPreview.item !== null }
                                        Binding { target: fxPreview.item; property: "color1"; value: page.accentColor; when: fxPreview.item !== null }
                                        Binding { target: fxPreview.item; property: "color2"; value: page.accent2; when: fxPreview.item !== null }
                                        Binding { target: fxPreview.item; property: "speed"; value: hyprvyzr.cardSpeed; when: fxPreview.item !== null }
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
                                        TapHandler { onTapped: hyprvyzr.setCardEffect(fxTile.modelData.id) }
                                    }
                                }
                            }
                        }
                        SliderRow {
                            visible: hyprvyzr.cardBorderUrl !== "" && hyprvyzr.cardEffect !== "plain"
                            label: "Front card speed"
                            from: 0.25; to: 3; stepSize: 0.05
                            suffix: "×"
                            value: hyprvyzr.cardSpeed
                            onMoved: v => hyprvyzr.setCardSpeed(v)
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    implicitHeight: dashCol.implicitHeight + 32
                    ColumnLayout {
                        id: dashCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        SectionLabel { text: "Kasm's dashboard in OmaCraft's look" }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: theme.textMuted
                            font.pixelSize: 12
                            text: "Rebuilds Kasm's admin and workspace dashboards in the current Omarchy theme: its colours, JetBrains Mono, square windows with the turning accent border, and the HYPRVYZR wordmark on the login. Kasm's own files stay untouched; its proxy adds one stylesheet and one small script, and nginx is checked before it reloads. Run it again after changing theme."
                        }
                        Repeater {
                            model: hyprvyzr.servers
                            RowLayout {
                                id: themeRow
                                required property var modelData
                                Layout.fillWidth: true
                                Label {
                                    Layout.fillWidth: true
                                    text: themeRow.modelData.name + "  ·  " + (themeRow.modelData.kind === "local" ? "with sudo, on this machine" : "over SSH as " + (themeRow.modelData.ssh || "root@" + String(themeRow.modelData.url).replace(/^https:\/\/|:\d+$/g, "")))
                                    color: theme.text
                                    elide: Text.ElideRight
                                }
                                Button {
                                    text: "Apply the theme…"
                                    focusPolicy: Qt.NoFocus
                                    onClicked: hyprvyzr.applyTheme(themeRow.modelData.id)
                                }
                            }
                        }
                        Label {
                            visible: hyprvyzr.servers.length === 0
                            text: "Add a server first."
                            color: theme.textDim
                        }
                    }
                }
            }
        }
    }

    Confirm {
        id: removeConfirm
        visible: false
        heading: "Remove " + page.removing + "?"
        body: "Its API key is deleted from the keyring too. Sessions already running on it keep running until they end."
        action: "Remove"
        onAccepted: page.acceptDialog()
        onRejected: removeConfirm.visible = false
    }
}
