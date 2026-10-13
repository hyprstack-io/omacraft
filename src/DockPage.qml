import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// The Agent Dock's three settings tabs (General, Items, Agents), with room
// to see everything at once.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property bool dialogOpen: false
    property int tab: 0
    property int editing: -2 // -2 closed, -1 a new agent, else its index
    readonly property var s: dock.settings
    readonly property var shortcuts: [
        { keys: "G / I / A", action: "General, Items, Agents" },
        { keys: "Space", action: "Show or hide the dock's panel" },
        { keys: "S", action: "Open the dock's own settings card" }
    ]

    function handleEscape() {
        if (page.editing !== -2) {
            page.editing = -2;
            return true;
        }
        if (dock.error !== "" || dock.notice !== "") {
            dock.dismissMessages();
            return true;
        }
        return false;
    }
    function acceptDialog() {}
    function home(path) { return String(path || "").replace(/^\/home\/[^/]+/, "~"); }

    onActiveChanged: if (active) { dock.reload(); dock.refreshMonitors(); }

    readonly property bool keys: active && keysFree && dock.available
    Shortcut { sequence: "G"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 0 }
    Shortcut { sequence: "I"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 1 }
    Shortcut { sequence: "A"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.tab = 2 }
    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: dock.toggleDock() }
    Shortcut { sequence: "S"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: dock.openDockSettings() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        PageHeader {
            title: "Agent Dock"
            subtitle: "The edge dock, its apps, and a terminal tab per AI agent"
            glyph: "\u{f06a9}"
            Button { text: "Show / hide dock"; flat: true; focusPolicy: Qt.NoFocus; enabled: dock.running; onClicked: dock.toggleDock() }
            Button { text: "Dock's own settings"; flat: true; focusPolicy: Qt.NoFocus; enabled: dock.running; onClicked: dock.openDockSettings() }
        }

        NotInstalled {
            visible: !dock.available
            pluginId: "skll.agentdock"
            what: "The dock is a shell panel from the Agent Dock plugin."
        }

        MessageBar {
            error: dock.error
            notice: dock.notice
            onDismissed: dock.dismissMessages()
        }

        MessageBar {
            visible: dock.available && !dock.running
            notice: "The dock isn't enabled. Changes here are saved and take effect when it starts. Enable it on the Plugins page."
        }

        TabBar {
            id: tabs
            visible: dock.available
            Layout.fillWidth: true
            currentIndex: page.tab
            onCurrentIndexChanged: page.tab = currentIndex
            background: null
            Repeater {
                model: ["General", "Items", "Agents"]
                TabButton {
                    required property string modelData
                    text: modelData
                    focusPolicy: Qt.NoFocus
                    width: implicitWidth + 24
                }
            }
        }

        StackLayout {
            visible: dock.available
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: page.tab

            // --- General ---
            ScrollView {
                id: generalScroll
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    width: generalScroll.availableWidth
                    spacing: 14

                    Card {
                        Layout.fillWidth: true
                        implicitHeight: general.implicitHeight + 36
                        ColumnLayout {
                            id: general
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 14

                            SectionLabel { text: "Where" }
                            RowLayout {
                                spacing: 8
                                Label { Layout.preferredWidth: 120; text: "Screen edge"; color: "#d6d6da" }
                                Repeater {
                                    model: [{ id: "left", name: "Left" }, { id: "right", name: "Right" }]
                                    Chip {
                                        required property var modelData
                                        text: modelData.name
                                        chosen: page.s.position === modelData.id
                                        onClicked: dock.set("position", modelData.id)
                                    }
                                }
                            }
                            RowLayout {
                                spacing: 8
                                Label { Layout.preferredWidth: 120; text: "Monitor"; color: "#d6d6da" }
                                Chip {
                                    text: "Focused"
                                    chosen: dock.monitor === ""
                                    onClicked: dock.setMonitor("")
                                }
                                Repeater {
                                    model: dock.monitors
                                    Chip {
                                        required property string modelData
                                        text: modelData
                                        chosen: dock.monitor === modelData
                                        onClicked: dock.setMonitor(modelData)
                                    }
                                }
                            }

                            SectionLabel { text: "Look"; Layout.topMargin: 6 }
                            SliderRow {
                                label: "Floating gap"
                                from: 0; to: 48; stepSize: 1; decimals: 0; suffix: " px"
                                value: page.s.gap || 0
                                onMoved: value => dock.set("gap", Math.round(value))
                            }
                            SliderRow {
                                label: "Icon size"
                                from: 18; to: 56; stepSize: 1; decimals: 0; suffix: " px"
                                value: page.s.iconSize || 28
                                onMoved: value => dock.set("iconSize", Math.round(value))
                            }
                            SliderRow {
                                label: "Opacity"
                                from: 0.3; to: 1; stepSize: 0.01
                                value: page.s.opacity || 0.94
                                onMoved: value => dock.set("opacity", Math.round(value * 100) / 100)
                            }
                            SliderRow {
                                label: "Panel width"
                                from: 320; to: 1600; stepSize: 10; decimals: 0; suffix: " px"
                                value: page.s.width || 520
                                onMoved: value => dock.set("width", Math.round(value))
                            }

                            SectionLabel { text: "Space on screen"; Layout.topMargin: 6 }
                            SwitchRow {
                                label: "Reserve space while collapsed"
                                hint: "Windows tile beside the dock instead of under it."
                                checked: page.s.reserveCollapsed === true
                                onToggled: on => dock.set("reserveCollapsed", on)
                            }
                            SwitchRow {
                                label: "Reserve space while expanded"
                                hint: "Windows make room for the agent panel when it opens."
                                checked: page.s.reserveExpanded === true
                                onToggled: on => dock.set("reserveExpanded", on)
                            }

                            SectionLabel { text: "Agents"; Layout.topMargin: 6 }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Label { Layout.preferredWidth: 120; text: "Start folder"; color: "#d6d6da" }
                                TextField {
                                    Layout.fillWidth: true
                                    text: page.s.cwd || ""
                                    placeholderText: "~ (home)"
                                    font.family: "monospace"
                                    onEditingFinished: if (text !== (page.s.cwd || "")) dock.set("cwd", text.trim())
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                text: "New agent sessions start here, unless the agent has its own folder."
                                color: "#74747d"
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            // --- Items ---
            RowLayout {
                spacing: 14

                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            SectionLabel { text: "On the dock, top to bottom" }
                            Item { Layout.fillWidth: true }
                            Button { text: "+ Spacer"; flat: true; focusPolicy: Qt.NoFocus; onClicked: dock.addSpacer() }
                            Button { text: "+ Divider"; flat: true; focusPolicy: Qt.NoFocus; onClicked: dock.addDivider() }
                        }
                        ListView {
                            id: itemList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            model: dock.dock
                            ScrollBar.vertical: ScrollBar {}
                            delegate: Rectangle {
                                id: row
                                required property var modelData
                                required property int index
                                width: itemList.width - 12
                                height: 44
                                radius: 8
                                color: rowHover.hovered ? "#1b1b1f" : "#111113"
                                border.color: "#26262b"
                                HoverHandler { id: rowHover }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 6
                                    spacing: 10
                                    Item {
                                        implicitWidth: 26; implicitHeight: 26
                                        Image {
                                            anchors.fill: parent
                                            visible: row.modelData.type === "app" && (row.modelData.icon || "") !== ""
                                            source: visible ? "image://icon/" + row.modelData.icon : ""
                                            sourceSize: Qt.size(52, 52)
                                        }
                                        Label {
                                            anchors.centerIn: parent
                                            visible: row.modelData.type !== "app"
                                            text: row.modelData.type === "cmd" ? (row.modelData.glyph || "›")
                                                : row.modelData.type === "divider" ? "—" : "␣"
                                            color: "#d6d6da"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 16
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Label {
                                            Layout.fillWidth: true
                                            text: row.modelData.label || ""
                                            color: row.modelData.type === "spacer" || row.modelData.type === "divider" ? "#8a8a93" : "white"
                                            elide: Text.ElideRight
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            visible: text !== ""
                                            text: row.modelData.type === "cmd" ? row.modelData.command
                                                : row.modelData.type === "app" ? row.modelData.id + (row.modelData.missing ? " · not installed" : "") : ""
                                            color: row.modelData.missing ? "#ff8a8a" : "#5f5f68"
                                            font.pixelSize: 11
                                            font.family: "monospace"
                                            elide: Text.ElideMiddle
                                        }
                                    }
                                    ToolButton { text: "↑"; focusPolicy: Qt.NoFocus; enabled: row.index > 0; onClicked: dock.moveItem(row.index, row.index - 1) }
                                    ToolButton { text: "↓"; focusPolicy: Qt.NoFocus; enabled: row.index < dock.dock.length - 1; onClicked: dock.moveItem(row.index, row.index + 1) }
                                    ToolButton { text: "✕"; focusPolicy: Qt.NoFocus; onClicked: dock.removeItem(row.index) }
                                }
                            }
                        }
                    }
                }

                Card {
                    Layout.preferredWidth: Math.min(420, page.width * 0.42)
                    Layout.fillHeight: true
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        SectionLabel { text: "Add an app" }
                        TextField {
                            id: appSearch
                            Layout.fillWidth: true
                            placeholderText: "Search installed apps"
                        }
                        ListView {
                            id: appList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: page.active && page.tab === 1 ? dock.apps(appSearch.text) : []
                            ScrollBar.vertical: ScrollBar {}
                            delegate: ItemDelegate {
                                required property var modelData
                                width: appList.width - 12
                                height: 38
                                focusPolicy: Qt.NoFocus
                                contentItem: RowLayout {
                                    spacing: 10
                                    Image {
                                        Layout.preferredWidth: 22; Layout.preferredHeight: 22
                                        source: modelData.icon ? "image://icon/" + modelData.icon : ""
                                        sourceSize: Qt.size(44, 44)
                                    }
                                    Label { Layout.fillWidth: true; text: modelData.name; color: "white"; elide: Text.ElideRight }
                                    Label { text: "Add"; color: theme.accent; font.pixelSize: 12 }
                                }
                                onClicked: dock.addApp(modelData.id)
                            }
                        }

                        SectionLabel { text: "Add a command"; Layout.topMargin: 6 }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            TextField { id: cmdName; Layout.fillWidth: true; placeholderText: "Name" }
                            TextField { id: cmdGlyph; Layout.preferredWidth: 64; placeholderText: "Glyph"; font.family: "JetBrainsMono Nerd Font" }
                        }
                        TextField { id: cmdLine; Layout.fillWidth: true; placeholderText: "Command, e.g. omarchy-launch-browser"; font.family: "monospace" }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: "Add command"
                            focusPolicy: Qt.NoFocus
                            enabled: cmdName.text.trim() !== "" && cmdLine.text.trim() !== ""
                            onClicked: {
                                dock.addCommand(cmdName.text, cmdGlyph.text, cmdLine.text);
                                cmdName.text = ""; cmdGlyph.text = ""; cmdLine.text = "";
                            }
                        }
                    }
                }
            }

            // --- Agents ---
            ScrollView {
                id: agentScroll
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    width: agentScroll.availableWidth
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: dock.customAgents ? "Agents come from " + page.home(dock.configPath) + ", which the dock reloads on save."
                                                    : "The dock's built-in agents. Changing them writes " + page.home(dock.configPath) + "."
                            color: "#8a8a93"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                        Button { text: "+ Agent"; flat: true; focusPolicy: Qt.NoFocus; onClicked: page.editing = -1 }
                        Button { text: "Reset to built-in"; flat: true; focusPolicy: Qt.NoFocus; visible: dock.customAgents; onClicked: dock.resetAgents() }
                    }

                    Repeater {
                        model: dock.agents
                        delegate: Card {
                            id: agentCard
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: agentRow.implicitHeight + 24
                            RowLayout {
                                id: agentRow
                                anchors.fill: parent
                                anchors.margins: 12
                                anchors.leftMargin: 16
                                spacing: 12
                                Image {
                                    Layout.preferredWidth: 28; Layout.preferredHeight: 28
                                    source: agentCard.modelData.iconUrl || ""
                                    sourceSize: Qt.size(56, 56)
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    RowLayout {
                                        Label { text: agentCard.modelData.name; color: "white"; font.weight: Font.DemiBold }
                                        StatePill {
                                            text: agentCard.modelData.installed ? "installed" : "not installed"
                                            on: agentCard.modelData.installed
                                        }
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: agentCard.modelData.command + (agentCard.modelData.cwd ? "  in " + agentCard.modelData.cwd : "")
                                              + (!agentCard.modelData.installed && agentCard.modelData.install ? "  · installs with: " + agentCard.modelData.install : "")
                                        color: "#74747d"
                                        font.family: "monospace"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                                Switch {
                                    text: "Tab shown"
                                    checked: agentCard.modelData.shown
                                    focusPolicy: Qt.NoFocus
                                    onToggled: dock.setAgentShown(agentCard.modelData.id, checked)
                                }
                                Button { text: "Edit"; flat: true; focusPolicy: Qt.NoFocus; onClicked: page.editing = agentCard.index }
                                Button { text: "Remove"; flat: true; focusPolicy: Qt.NoFocus; enabled: dock.agents.length > 1; onClicked: dock.removeAgent(agentCard.index) }
                            }
                        }
                    }

                    // Adding or editing one agent.
                    Card {
                        id: editor
                        visible: page.editing !== -2
                        Layout.fillWidth: true
                        implicitHeight: form.implicitHeight + 32
                        border.color: theme.accent
                        readonly property var agent: page.editing >= 0 ? dock.agents[page.editing] : ({})
                        onAgentChanged: {
                            agentId.text = agent.id || ""; agentName.text = agent.name || "";
                            agentCommand.text = agent.command || ""; agentIcon.text = agent.icon || "";
                            agentInstall.text = agent.install || ""; agentCwd.text = agent.cwd || "";
                        }
                        GridLayout {
                            id: form
                            anchors.fill: parent
                            anchors.margins: 16
                            columns: 2
                            columnSpacing: 12
                            rowSpacing: 8
                            SectionLabel { Layout.columnSpan: 2; text: page.editing === -1 ? "New agent" : "Edit agent" }
                            Label { text: "Id"; color: "#d6d6da" }
                            TextField { id: agentId; Layout.fillWidth: true; placeholderText: "codex"; font.family: "monospace" }
                            Label { text: "Name"; color: "#d6d6da" }
                            TextField { id: agentName; Layout.fillWidth: true; placeholderText: "Codex" }
                            Label { text: "Command"; color: "#d6d6da" }
                            TextField { id: agentCommand; Layout.fillWidth: true; placeholderText: "codex"; font.family: "monospace" }
                            Label { text: "Icon"; color: "#d6d6da" }
                            TextField { id: agentIcon; Layout.fillWidth: true; placeholderText: "/path/to/icon.svg, or icons/x.svg inside the plugin"; font.family: "monospace" }
                            Label { text: "Install with"; color: "#d6d6da" }
                            TextField { id: agentInstall; Layout.fillWidth: true; placeholderText: "omarchy pkg add codex (offered when it's missing)"; font.family: "monospace" }
                            Label { text: "Folder"; color: "#d6d6da" }
                            TextField { id: agentCwd; Layout.fillWidth: true; placeholderText: "~/Work (the start folder when empty)"; font.family: "monospace" }
                            RowLayout {
                                Layout.columnSpan: 2
                                Layout.alignment: Qt.AlignRight
                                Button { text: "Cancel"; flat: true; focusPolicy: Qt.NoFocus; onClicked: page.editing = -2 }
                                AccentButton {
                                    text: "Save agent"
                                    enabled: agentId.text.trim() !== "" && agentCommand.text.trim() !== ""
                                    onClicked: {
                                        dock.saveAgent(page.editing, { id: agentId.text, name: agentName.text, command: agentCommand.text,
                                                                       icon: agentIcon.text, install: agentInstall.text, cwd: agentCwd.text });
                                        page.editing = -2;
                                    }
                                }
                            }
                        }
                    }
                    Item { implicitHeight: 4 }
                }
            }
        }
    }
}
