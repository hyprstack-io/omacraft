import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// Folder trays: folders on the bar that open into a row of chosen apps.
// The list of folders on the left, the chosen one's settings and apps on
// the right, and every installed app to add from. Changes reach the bar at
// once (folders.cpp writes the folder entries in shell.json).
Item {
    id: panel

    property int selected: 0
    property string search: ""
    property bool confirmDelete: false
    readonly property var current: folders.folders[selected] || null
    readonly property var lanes: [{ id: "left", name: "Left" }, { id: "center", name: "Centre" }, { id: "right", name: "Right" }]
    readonly property var pluginInfo: plugins.plugins.find(p => p.id === "omacraft.folders") || ({})
    readonly property string folderGlyph: String.fromCodePoint(0xF024B)
    // folder, folder open, gamepad, music, code, console, web, chat,
    // briefcase, image, video, cog, star, heart
    readonly property var glyphs: [
        0xF024B, 0xF0770, 0xF0297, 0xF075A, 0xF0169, 0xF018D, 0xF059F, 0xF0B79,
        0xF00D6, 0xF02E9, 0xF0567, 0xF0493, 0xF04CE, 0xF02D1
    ].map(c => String.fromCodePoint(c))

    // Keeps the same folder chosen when the list changes under it.
    function selectWhere(section, index) {
        for (let i = 0; i < folders.folders.length; i++)
            if (folders.folders[i].section === section && folders.folders[i].index === index) {
                selected = i;
                return;
            }
        selected = Math.max(0, Math.min(selected, folders.folders.length - 1));
    }
    function update(changes) {
        if (current) folders.update(current.section, current.index, changes);
    }
    function appLabel(app) {
        if (typeof app !== "string") return app.name || app.command;
        const found = folders.apps.find(a => a.id === app);
        return found ? found.name : app;
    }
    function appIcon(app) {
        const name = typeof app === "string" ? ((folders.apps.find(a => a.id === app) || {}).icon || app) : (app.icon || "utilities-terminal");
        return "image://icon/" + name;
    }
    function hasApp(id) {
        return current !== null && (current.apps || []).indexOf(id) >= 0;
    }
    function isGlyph(icon) {
        return Array.from(String(icon || "")).length <= 2;
    }
    readonly property var filteredApps: {
        const q = search.trim().toLowerCase();
        const all = folders.apps;
        if (q === "") return all;
        return all.filter(a => a.name.toLowerCase().indexOf(q) >= 0 || a.id.toLowerCase().indexOf(q) >= 0
                               || String(a.comment || "").toLowerCase().indexOf(q) >= 0);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        NotInstalled {
            visible: panel.pluginInfo.installed !== true
            pluginId: "omacraft.folders"
            what: "Folder trays are drawn on the bar by the omacraft.folders shell plugin."
        }

        MessageBar {
            error: folders.error
            notice: folders.notice
            onDismissed: folders.dismissMessages()
        }

        RowLayout {
            visible: panel.pluginInfo.installed === true
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // ---- The folders
            Card {
                Layout.preferredWidth: 260
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    SectionLabel { text: "Folders on the bar" }
                    RowLayout {
                        Layout.fillWidth: true
                        TextField {
                            id: newName
                            Layout.fillWidth: true
                            placeholderText: "New folder name"
                            onAccepted: addButton.clicked()
                        }
                        AccentButton {
                            id: addButton
                            text: "Add"
                            onClicked: {
                                const index = folders.add(newName.text, "right");
                                newName.text = "";
                                if (index >= 0) panel.selectWhere("right", index);
                            }
                        }
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        model: folders.folders
                        delegate: Rectangle {
                            id: folderRow
                            required property var modelData
                            required property int index
                            readonly property bool chosen: panel.selected === index
                            readonly property color tone: Qt.color(theme.accent)
                            width: ListView.view.width
                            height: 46
                            radius: 8
                            color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.14) : rowHover.hovered ? theme.hover : "transparent"
                            border.color: chosen ? theme.accent : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10
                                Item {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    Label {
                                        anchors.centerIn: parent
                                        visible: panel.isGlyph(folderRow.modelData.icon)
                                        text: folderRow.modelData.icon || panel.folderGlyph
                                        color: folderRow.chosen ? theme.accent : theme.textSoft
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 17
                                    }
                                    Image {
                                        anchors.fill: parent
                                        visible: !panel.isGlyph(folderRow.modelData.icon)
                                        source: visible ? "image://icon/" + folderRow.modelData.icon : ""
                                        sourceSize: Qt.size(44, 44)
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Label { Layout.fillWidth: true; text: folderRow.modelData.name; color: theme.text; elide: Text.ElideRight }
                                    Label {
                                        text: (folderRow.modelData.apps || []).length + " apps · " + ({ left: "left", center: "centre", right: "right" })[folderRow.modelData.section]
                                        color: theme.textDim
                                        font.pixelSize: 11
                                    }
                                }
                            }
                            HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: panel.selected = folderRow.index }
                        }
                    }
                    Label {
                        visible: folders.folders.length === 0
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "No folders yet. Name one and press Add: it appears at the right end of the bar, ready for apps."
                        color: theme.textDim
                        font.pixelSize: 12
                    }
                }
            }

            // ---- The chosen folder
            ScrollView {
                id: editScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true
                visible: panel.current !== null

                ColumnLayout {
                    width: editScroll.availableWidth
                    spacing: 12

                    // A sketch of it on the bar, open.
                    Card {
                        Layout.fillWidth: true
                        implicitHeight: 64
                        Rectangle {
                            anchors.centerIn: parent
                            width: sketchRow.implicitWidth + 16
                            height: 34
                            radius: 8
                            color: theme.sidebar
                            border.color: theme.border
                            Row {
                                id: sketchRow
                                anchors.centerIn: parent
                                spacing: 2
                                layoutDirection: panel.current && panel.current.side === "before" ? Qt.RightToLeft : Qt.LeftToRight
                                Item {
                                    width: 30; height: 30
                                    Label {
                                        anchors.centerIn: parent
                                        visible: panel.current && panel.isGlyph(panel.current.icon)
                                        text: panel.current ? (panel.current.icon === panel.folderGlyph ? String.fromCodePoint(0xF0770) : (panel.current.icon || panel.folderGlyph)) : ""
                                        color: theme.accent
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 16
                                    }
                                    Image {
                                        anchors.centerIn: parent
                                        width: 18; height: 18
                                        visible: panel.current && !panel.isGlyph(panel.current.icon)
                                        source: visible ? "image://icon/" + panel.current.icon : ""
                                        sourceSize: Qt.size(36, 36)
                                    }
                                }
                                Label {
                                    visible: panel.current && panel.current.showLabel === true
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: panel.current ? panel.current.name : ""
                                    color: theme.textSoft
                                    font.pixelSize: 11
                                    rightPadding: 4
                                }
                                Repeater {
                                    model: panel.current ? panel.current.apps : []
                                    Item {
                                        required property var modelData
                                        width: 28; height: 30
                                        Image {
                                            anchors.centerIn: parent
                                            width: 18; height: 18
                                            source: panel.appIcon(parent.modelData)
                                            sourceSize: Qt.size(36, 36)
                                        }
                                        ToolTip.visible: sketchHover.hovered
                                        ToolTip.text: panel.appLabel(modelData)
                                        HoverHandler { id: sketchHover }
                                    }
                                }
                            }
                        }
                    }

                    Card {
                        Layout.fillWidth: true
                        implicitHeight: settingsColumn.implicitHeight + 28
                        ColumnLayout {
                            id: settingsColumn
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 9
                            RowLayout {
                                Layout.fillWidth: true
                                SectionLabel { text: "Folder" }
                                Item { Layout.fillWidth: true }
                                Button { text: "◀"; flat: true; focusPolicy: Qt.NoFocus; ToolTip.visible: hovered; ToolTip.text: "Move left on the bar"; onClicked: { const c = panel.current; folders.shift(c.section, c.index, -1); panel.selectWhere(c.section, Math.max(0, c.index - 1)); } }
                                Button { text: "▶"; flat: true; focusPolicy: Qt.NoFocus; ToolTip.visible: hovered; ToolTip.text: "Move right on the bar"; onClicked: { const c = panel.current; folders.shift(c.section, c.index, 1); panel.selectWhere(c.section, c.index + 1); } }
                                Button { text: "Delete…"; flat: true; focusPolicy: Qt.NoFocus; Material.foreground: theme.danger; onClicked: panel.confirmDelete = true }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Label { Layout.preferredWidth: 96; text: "Name"; color: theme.textSoft; font.pixelSize: 12 }
                                TextField {
                                    Layout.fillWidth: true
                                    text: panel.current ? panel.current.name : ""
                                    onEditingFinished: if (panel.current && text.trim() !== "" && text !== panel.current.name) panel.update({ name: text.trim() })
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Label { Layout.preferredWidth: 96; Layout.alignment: Qt.AlignTop; topPadding: 6; text: "Icon"; color: theme.textSoft; font.pixelSize: 12 }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Repeater {
                                            model: panel.glyphs
                                            Rectangle {
                                                required property string modelData
                                                readonly property bool chosen: panel.current && panel.current.icon === modelData
                                                width: 32; height: 32; radius: 6
                                                color: chosen ? Qt.rgba(Qt.color(theme.accent).r, Qt.color(theme.accent).g, Qt.color(theme.accent).b, 0.18) : glyphHover.hovered ? theme.hover : theme.inset
                                                border.color: chosen ? theme.accent : theme.border
                                                Label { anchors.centerIn: parent; text: parent.modelData; color: parent.chosen ? theme.accent : theme.textSoft; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
                                                HoverHandler { id: glyphHover; cursorShape: Qt.PointingHandCursor }
                                                TapHandler { onTapped: panel.update({ icon: parent.modelData }) }
                                            }
                                        }
                                    }
                                    TextField {
                                        Layout.fillWidth: true
                                        placeholderText: "Or any Nerd Font glyph, icon name (folder-music) or image path"
                                        onAccepted: if (text.trim() !== "") { panel.update({ icon: text.trim() }); text = ""; }
                                    }
                                }
                            }
                            component Choice: RowLayout {
                                id: choice
                                property string label
                                property var choices: []
                                property var value
                                signal picked(var value)
                                Layout.fillWidth: true
                                spacing: 10
                                Label { Layout.preferredWidth: 96; text: choice.label; color: theme.textSoft; font.pixelSize: 12 }
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Repeater {
                                        model: choice.choices
                                        Chip {
                                            required property var modelData
                                            text: modelData.label
                                            chosen: choice.value === modelData.value
                                            onClicked: choice.picked(modelData.value)
                                        }
                                    }
                                }
                            }
                            Choice {
                                label: "Place"
                                value: panel.current ? panel.current.section : "right"
                                choices: panel.lanes.map(l => ({ value: l.id, label: l.name }))
                                onPicked: v => {
                                    const c = panel.current;
                                    if (v === c.section) return;
                                    folders.moveTo(c.section, c.index, v);
                                    panel.selectWhere(v, ((folders.folders.filter(f => f.section === v).pop() || {}).index) ?? 0);
                                }
                            }
                            Choice {
                                label: "Opens on"
                                value: panel.current ? (panel.current.open || "click") : "click"
                                choices: [{ value: "click", label: "Click" }, { value: "hover", label: "Hover" }]
                                onPicked: v => panel.update({ open: v })
                            }
                            Choice {
                                label: "Opens towards"
                                value: panel.current ? (panel.current.side || "auto") : "auto"
                                choices: [{ value: "auto", label: "The middle of the bar" }, { value: "before", label: "Left / up" }, { value: "after", label: "Right / down" }]
                                onPicked: v => panel.update({ side: v })
                            }
                            Choice {
                                label: "Closes after"
                                value: panel.current ? (Number(panel.current.autoClose) || 0) : 0
                                choices: [{ value: 0, label: "Only when clicked" }, { value: 3, label: "3 s" }, { value: 5, label: "5 s" }, { value: 10, label: "10 s" }, { value: 30, label: "30 s" }]
                                onPicked: v => panel.update({ autoClose: v })
                            }
                            SwitchRow {
                                label: "Close after launching an app"
                                checked: panel.current ? panel.current.closeOnLaunch !== false : true
                                onToggled: on => panel.update({ closeOnLaunch: on })
                            }
                            SwitchRow {
                                label: "Show the name beside the icon"
                                checked: panel.current ? panel.current.showLabel === true : false
                                onToggled: on => panel.update({ showLabel: on })
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: "On the bar: click the folder to open or close it, right-click for its apps by name, middle-click to come back here."
                                color: theme.textDim
                                font.pixelSize: 11
                            }
                        }
                    }

                    // The apps in it, in order.
                    Card {
                        Layout.fillWidth: true
                        implicitHeight: inFolder.implicitHeight + 28
                        ColumnLayout {
                            id: inFolder
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6
                            SectionLabel { text: "In this folder" }
                            Label {
                                visible: panel.current && (panel.current.apps || []).length === 0
                                text: "Empty. Pick apps below."
                                color: theme.textDim
                                font.pixelSize: 12
                            }
                            Repeater {
                                model: panel.current ? panel.current.apps : []
                                delegate: RowLayout {
                                    id: member
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Image { Layout.preferredWidth: 22; Layout.preferredHeight: 22; source: panel.appIcon(member.modelData); sourceSize: Qt.size(44, 44) }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Label { Layout.fillWidth: true; text: panel.appLabel(member.modelData); color: theme.text; elide: Text.ElideRight }
                                        Label {
                                            Layout.fillWidth: true
                                            text: typeof member.modelData === "string" ? member.modelData + ".desktop" + (folders.apps.some(a => a.id === member.modelData) ? "" : " · not installed")
                                                                                        : "runs: " + member.modelData.command
                                            color: theme.textDim
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }
                                    Button { text: "↑"; flat: true; focusPolicy: Qt.NoFocus; enabled: member.index > 0; onClicked: folders.moveApp(panel.current.section, panel.current.index, member.index, -1) }
                                    Button { text: "↓"; flat: true; focusPolicy: Qt.NoFocus; enabled: member.index < panel.current.apps.length - 1; onClicked: folders.moveApp(panel.current.section, panel.current.index, member.index, 1) }
                                    Button { text: "Remove"; flat: true; focusPolicy: Qt.NoFocus; onClicked: folders.removeApp(panel.current.section, panel.current.index, member.index) }
                                }
                            }
                        }
                    }

                    // Every installed app, and anything else as a command.
                    Card {
                        Layout.fillWidth: true
                        implicitHeight: pickColumn.implicitHeight + 28
                        ColumnLayout {
                            id: pickColumn
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8
                            RowLayout {
                                Layout.fillWidth: true
                                SectionLabel { text: "Add apps" }
                                Label { Layout.fillWidth: true; text: panel.filteredApps.length + " of " + folders.apps.length + " installed apps"; color: theme.textDim; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
                                Button { text: "Rescan"; flat: true; focusPolicy: Qt.NoFocus; onClicked: folders.reloadApps() }
                            }
                            TextField {
                                Layout.fillWidth: true
                                placeholderText: "Search apps by name, id or description"
                                onTextChanged: panel.search = text
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                columns: Math.max(2, Math.floor(width / 200))
                                rowSpacing: 4
                                columnSpacing: 4
                                Repeater {
                                    // A screenful at a time keeps the page quick.
                                    model: panel.filteredApps.slice(0, 120)
                                    delegate: Rectangle {
                                        id: appTile
                                        required property var modelData
                                        readonly property bool inside: panel.hasApp(modelData.id)
                                        readonly property color tone: Qt.color(theme.accent)
                                        Layout.fillWidth: true
                                        implicitHeight: 40
                                        radius: 7
                                        color: inside ? Qt.rgba(tone.r, tone.g, tone.b, 0.12) : tileHover.hovered ? theme.hover : theme.inset
                                        border.color: inside ? theme.accent : theme.border
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8
                                            Image { Layout.preferredWidth: 22; Layout.preferredHeight: 22; source: "image://icon/" + (appTile.modelData.icon || "application-x-executable"); sourceSize: Qt.size(44, 44); asynchronous: true }
                                            Label { Layout.fillWidth: true; text: appTile.modelData.name; color: theme.textSoft; elide: Text.ElideRight; font.pixelSize: 12 }
                                            Label { text: appTile.inside ? "✓" : "+"; color: appTile.inside ? theme.accent : theme.textDim }
                                        }
                                        ToolTip.visible: tileHover.hovered && appTile.modelData.comment !== ""
                                        ToolTip.text: appTile.modelData.comment
                                        ToolTip.delay: 600
                                        HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler {
                                            onTapped: {
                                                const c = panel.current;
                                                if (appTile.inside) folders.removeApp(c.section, c.index, c.apps.indexOf(appTile.modelData.id));
                                                else folders.addApp(c.section, c.index, appTile.modelData.id);
                                            }
                                        }
                                    }
                                }
                            }
                            Label {
                                visible: panel.filteredApps.length > 120
                                text: "Showing the first 120. Search to narrow it down."
                                color: theme.textDim
                                font.pixelSize: 11
                            }
                            SectionLabel { text: "Or a command"; Layout.topMargin: 6 }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                TextField { id: cmdName; Layout.preferredWidth: 140; placeholderText: "Name" }
                                TextField { id: cmdIcon; Layout.preferredWidth: 150; placeholderText: "Icon (utilities-terminal)" }
                                TextField { id: cmdLine; Layout.fillWidth: true; placeholderText: "Command, e.g. alacritty -e btop"; onAccepted: cmdAdd.clicked() }
                                Button {
                                    id: cmdAdd
                                    text: "Add"
                                    focusPolicy: Qt.NoFocus
                                    enabled: cmdLine.text.trim() !== ""
                                    onClicked: {
                                        folders.addCommand(panel.current.section, panel.current.index, cmdName.text, cmdIcon.text, cmdLine.text);
                                        cmdName.text = ""; cmdIcon.text = ""; cmdLine.text = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                visible: panel.current === null
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    Confirm {
        visible: panel.confirmDelete
        heading: "Delete " + (panel.current ? panel.current.name : "") + "?"
        body: "It comes off the bar with its list of apps. The apps themselves stay installed."
        action: "Delete"
        onAccepted: {
            panel.confirmDelete = false;
            folders.remove(panel.current.section, panel.current.index);
            panel.selected = Math.max(0, panel.selected - 1);
        }
        onRejected: panel.confirmDelete = false
    }
}
