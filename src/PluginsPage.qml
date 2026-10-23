import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Every plugin OmaCraft houses: installed or not, enabled or not, and where
// it sits on the bar.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    property int selected: 0
    property string removing: ""
    readonly property var current: plugins.plugins[selected] || ({})
    readonly property bool dialogOpen: removeConfirm.visible
    readonly property var shortcuts: [
        { keys: "↑ ↓", action: "Choose a plugin" },
        { keys: "Space", action: "Enable or disable it" },
        { keys: "I", action: "Install it" },
        { keys: "Del", action: "Remove it from the shell (its files are kept)" },
        { keys: "L / C / R", action: "Place it on the left, centre or right of the bar" },
        { keys: "Enter", action: "Open its settings" },
        { keys: "F5", action: "Check the shell again" },
        { keys: "Ctrl R", action: "Restart the shell" }
    ]

    function handleEscape() {
        if (removeConfirm.visible) {
            removeConfirm.visible = false;
            return true;
        }
        if (plugins.error !== "" || plugins.notice !== "") {
            plugins.dismissMessages();
            return true;
        }
        return false;
    }
    function acceptDialog() {
        removeConfirm.visible = false;
        plugins.remove(page.removing);
    }
    function askRemove(id) {
        page.removing = id;
        removeConfirm.visible = true;
    }
    function home(path) {
        return String(path || "").replace(/^\/home\/[^/]+/, "~");
    }

    readonly property bool keys: active && keysFree && !dialogOpen
    Shortcut { sequence: "Up"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.selected = Math.max(0, page.selected - 1) }
    Shortcut { sequence: "Down"; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.selected = Math.min(plugins.plugins.length - 1, page.selected + 1) }
    Shortcut {
        sequence: "Space"; context: Qt.ApplicationShortcut
        enabled: page.keys && !plugins.busy && page.current.installed === true
        onActivated: plugins.setEnabled(page.current.id, !page.current.enabled)
    }
    Shortcut { sequence: "I"; context: Qt.ApplicationShortcut; enabled: page.keys && !plugins.busy && page.current.canInstall === true; onActivated: plugins.install(page.current.id) }
    Shortcut { sequences: ["Delete", "X"]; context: Qt.ApplicationShortcut; enabled: page.keys && !plugins.busy && page.current.installed === true; onActivated: page.askRemove(page.current.id) }
    Shortcut { sequence: "L"; context: Qt.ApplicationShortcut; enabled: page.keys && !plugins.busy && page.current.barWidget === true && page.current.installed === true; onActivated: plugins.place(page.current.id, "left") }
    Shortcut { sequence: "C"; context: Qt.ApplicationShortcut; enabled: page.keys && !plugins.busy && page.current.barWidget === true && page.current.installed === true; onActivated: plugins.place(page.current.id, "center") }
    Shortcut { sequence: "R"; context: Qt.ApplicationShortcut; enabled: page.keys && !plugins.busy && page.current.barWidget === true && page.current.installed === true; onActivated: plugins.place(page.current.id, "right") }
    Shortcut { sequences: ["Return", "Enter"]; context: Qt.ApplicationShortcut; enabled: page.keys; onActivated: page.openPage(page.current.page) }
    Shortcut { sequence: "F5"; context: Qt.ApplicationShortcut; enabled: page.active; onActivated: plugins.refresh() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        PageHeader {
            title: "Plugin Suite"
            subtitle: "Install, enable and place each plugin in the Omarchy shell"
            glyph: "\u{f0ac6}"
            BusyIndicator { running: plugins.busy; visible: plugins.busy; implicitWidth: 28; implicitHeight: 28 }
            Button { text: "Check again"; flat: true; focusPolicy: Qt.NoFocus; enabled: !plugins.busy; onClicked: plugins.refresh() }
            Button { text: "Restart shell"; flat: true; focusPolicy: Qt.NoFocus; enabled: !plugins.busy; onClicked: plugins.restartShell() }
        }

        MessageBar {
            error: plugins.error
            notice: plugins.notice
            onDismissed: plugins.dismissMessages()
        }

        MessageBar {
            error: plugins.shellRunning ? "" : "The Omarchy shell isn't answering, so OmaCraft can't tell which plugins are enabled. Start it with omarchy-restart-shell, then Check again."
        }

        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                width: scroll.availableWidth
                spacing: 12

                Repeater {
                    model: plugins.plugins
                    delegate: Card {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property bool chosen: page.selected === index
                        property bool showSource: false

                        Layout.fillWidth: true
                        implicitHeight: body.implicitHeight + 32
                        border.color: chosen ? theme.accent : theme.border

                        TapHandler { onTapped: page.selected = card.index }

                        ColumnLayout {
                            id: body
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Label {
                                    text: card.modelData.name
                                    color: theme.text
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                }
                                Label {
                                    visible: card.modelData.version !== ""
                                    text: "v" + card.modelData.version
                                    color: theme.textFaint
                                    font.pixelSize: 11
                                }
                                Label {
                                    text: card.modelData.id
                                    color: theme.textFaint
                                    font.pixelSize: 11
                                    font.family: "monospace"
                                }
                                Item { Layout.fillWidth: true }
                                StatePill {
                                    text: card.modelData.state
                                    on: card.modelData.enabled
                                    warn: card.modelData.state === "Broken link" || card.modelData.state === "Not found by the shell"
                                          || card.modelData.duplicates.length > 0
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                text: card.modelData.summary
                                color: theme.textSoft
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                Layout.fillWidth: true
                                color: theme.textDim
                                font.pixelSize: 11
                                font.family: "monospace"
                                elide: Text.ElideMiddle
                                text: card.modelData.linked && card.modelData.installed
                                      ? "Linked from " + page.home(card.modelData.linkTarget)
                                      : card.modelData.installed ? "Installed in " + page.home(card.modelData.dir)
                                      : card.modelData.stashed ? "Set aside in " + page.home(card.modelData.dir) + ", ready to install again"
                                      : card.modelData.sourceExists ? "Code in " + page.home(card.modelData.source)
                                      : "Code not found" + (card.modelData.source ? " at " + page.home(card.modelData.source) : "")
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                // Not installed: install, or say where the code is.
                                AccentButton {
                                    visible: !card.modelData.installed
                                    enabled: card.modelData.canInstall && !plugins.busy
                                    text: "Install"
                                    onClicked: plugins.install(card.modelData.id)
                                }

                                // Installed: on or off, and where on the bar.
                                Switch {
                                    visible: card.modelData.installed
                                    enabled: !plugins.busy && plugins.shellRunning
                                    checked: card.modelData.enabled
                                    text: card.modelData.isBar ? "Use as the bar" : "Enabled"
                                    focusPolicy: Qt.NoFocus
                                    onToggled: plugins.setEnabled(card.modelData.id, checked)
                                }
                                Label {
                                    visible: card.modelData.installed && card.modelData.barWidget
                                    text: "On the bar:"
                                    color: theme.textMuted
                                    font.pixelSize: 12
                                    Layout.leftMargin: 8
                                }
                                Repeater {
                                    model: card.modelData.installed && card.modelData.barWidget
                                           ? [{ id: "left", name: "Left" }, { id: "center", name: "Centre" }, { id: "right", name: "Right" }] : []
                                    delegate: Chip {
                                        required property var modelData
                                        text: modelData.name
                                        chosen: card.modelData.section === modelData.id
                                        dimmed: plugins.busy || !plugins.shellRunning
                                        onClicked: if (!plugins.busy && plugins.shellRunning) plugins.place(card.modelData.id, modelData.id)
                                    }
                                }
                                Label {
                                    visible: card.modelData.installed && card.modelData.barWidget && card.modelData.enabled
                                             && card.modelData.section === ""
                                    text: "not placed"
                                    color: theme.textDim
                                    font.pixelSize: 11
                                }

                                Item { Layout.fillWidth: true }

                                Button {
                                    text: "Code location"
                                    flat: true
                                    focusPolicy: Qt.NoFocus
                                    onClicked: card.showSource = !card.showSource
                                }
                                Button {
                                    visible: card.modelData.installed
                                    enabled: !plugins.busy
                                    text: "Remove"
                                    flat: true
                                    focusPolicy: Qt.NoFocus
                                    onClicked: page.askRemove(card.modelData.id)
                                }
                                Button {
                                    text: "Settings"
                                    focusPolicy: Qt.NoFocus
                                    onClicked: page.openPage(card.modelData.page)
                                }
                            }

                            // Where the code lives, for installing it as a link.
                            RowLayout {
                                visible: card.showSource
                                Layout.fillWidth: true
                                spacing: 8
                                Label { text: "Code in"; color: theme.textMuted; font.pixelSize: 12 }
                                TextField {
                                    id: sourceField
                                    Layout.fillWidth: true
                                    text: page.home(card.modelData.source)
                                    placeholderText: "~/Projects/my-plugin (a folder with manifest.json)"
                                    font.family: "monospace"
                                    font.pixelSize: 12
                                    onEditingFinished: if (text !== page.home(card.modelData.source)) plugins.setSource(card.modelData.id, text)
                                }
                                Label {
                                    text: card.modelData.sourceExists ? "found" : "no manifest.json there"
                                    color: card.modelData.sourceExists ? theme.accent : theme.danger
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }

                // hyprbuildz isn't a shell plugin: it lives inside OmaCraft.
                Card {
                    Layout.fillWidth: true
                    implicitHeight: builtIn.implicitHeight + 32
                    ColumnLayout {
                        id: builtIn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: "OmaBuilds"; color: theme.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                            Label { text: "hyprbuildz"; color: theme.textFaint; font.pixelSize: 11; font.family: "monospace" }
                            Item { Layout.fillWidth: true }
                            StatePill { text: "Built in"; on: true }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                Layout.fillWidth: true
                                text: "Custom Arch Linux ISOs with archiso, written to USB. It's part of OmaCraft rather than a shell plugin, so there's nothing to enable. Dotfile Generator's configurator is built in too; its plugin above only adds the bar dropdown."
                                color: theme.textSoft
                                wrapMode: Text.WordWrap
                            }
                            Button { text: "Open"; focusPolicy: Qt.NoFocus; onClicked: page.openPage("iso") }
                        }
                    }
                }

                Item { implicitHeight: 4 }
            }
        }
    }

    Confirm {
        id: removeConfirm
        readonly property var target: plugins.plugins.find(p => p.id === page.removing) || ({})
        heading: "Remove " + (target.name || page.removing) + " from the shell?"
        body: target.isBar && target.enabled
              ? "The bar goes back to Omarchy's built-in one first. " + (target.linked ? "The link is removed; the code stays where it is." : "Its folder is set aside in ~/.local/share/omacraft/stash, so Install brings it back.")
              : (target.linked ? "It's disabled, then its link is removed. The code stays where it is." : "It's disabled, then its folder is set aside in ~/.local/share/omacraft/stash, so Install brings it back.")
        action: "Remove"
        keepText: "Keep it"
        onAccepted: page.acceptDialog()
        onRejected: visible = false
    }
}
