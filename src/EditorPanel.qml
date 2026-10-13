import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Omacraft 1.0

// Edits files for the ISO: any file in the live system, or the archiso
// profile's own (pacman.conf, the boot menus). A file is only on the ISO once
// it's saved; until then it shows what the profile, or this machine, has.
Rectangle {
    id: panel
    color: "#cc000000"

    property color accent
    property color accentForeground
    property color line

    property string currentPath: ""
    property string savedText: ""
    property string languageOverride: ""
    property string pathError: ""
    // A switch or close waiting on "save changes?".
    property string pendingPath: ""
    property bool closing: false
    property bool confirmVisible: false

    readonly property bool dirty: currentPath !== "" && editor.text !== savedText
    readonly property bool edited: iso.editedFiles.some(f => f.path === currentPath)
    readonly property string language: languageOverride !== "" ? languageOverride : iso.fileLanguage(currentPath, editor.text.substring(0, 64))
    readonly property string displayName: currentPath.startsWith("profile:") ? "Profile · " + currentPath.substring(8) : currentPath

    signal closeRequested()

    function openFile(path) {
        pathError = "";
        if (path === currentPath)
            return;
        if (dirty) {
            pendingPath = path;
            closing = false;
            confirmVisible = true;
            return;
        }
        load(path);
    }

    function load(path) {
        currentPath = path;
        savedText = iso.fileContent(path);
        editor.text = savedText;
        editor.cursorPosition = 0;
        flick.contentX = 0;
        flick.contentY = 0;
        languageOverride = "";
        editor.forceActiveFocus();
    }

    function openTyped() {
        const path = iso.normalizeFilePath(pathField.text);
        const problem = iso.filePathProblem(path);
        if (problem !== "") {
            pathError = problem;
            return;
        }
        pathField.text = "";
        openFile(path);
    }

    function save() {
        if (currentPath === "")
            return;
        iso.saveFile(currentPath, editor.text);
        savedText = editor.text;
    }

    function revertToStock() {
        editor.text = iso.stockFileContent(currentPath);
    }

    function removeFromIso() {
        iso.removeFile(currentPath);
        savedText = iso.fileContent(currentPath);
        editor.text = savedText;
    }

    function requestClose() {
        if (dirty) {
            pendingPath = "";
            closing = true;
            confirmVisible = true;
        } else {
            closeRequested();
        }
    }

    // Esc: leave the question, else close.
    function handleEscape() {
        if (confirmVisible)
            confirmVisible = false;
        else
            requestClose();
    }

    function proceed(saveFirst) {
        if (saveFirst)
            save();
        else
            editor.text = savedText;
        confirmVisible = false;
        if (closing) {
            closing = false;
            closeRequested();
        } else if (pendingPath !== "") {
            const next = pendingPath;
            pendingPath = "";
            load(next);
        }
    }

    onVisibleChanged: {
        if (!visible)
            return;
        pathError = "";
        if (currentPath === "" && iso.editedFiles.length > 0)
            load(iso.editedFiles[0].path);
        else if (currentPath === "")
            pathField.forceActiveFocus();
        else
            editor.forceActiveFocus();
    }

    Shortcut { sequence: "Ctrl+S"; context: Qt.ApplicationShortcut; enabled: panel.visible && panel.currentPath !== ""; onActivated: panel.save() }
    Shortcut { sequence: "Ctrl+P"; context: Qt.ApplicationShortcut; enabled: panel.visible && !panel.confirmVisible; onActivated: pathField.forceActiveFocus() }
    Shortcut {
        sequences: ["Return", "Enter"]
        context: Qt.ApplicationShortcut
        enabled: panel.visible && panel.confirmVisible
        onActivated: panel.proceed(true)
    }

    MouseArea { anchors.fill: parent; onClicked: panel.requestClose() }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 1180)
        height: parent.height - 48
        radius: 12
        color: "#151518"
        border.color: panel.line
        clip: true

        MouseArea { anchors.fill: parent }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // --- files ---
            ColumnLayout {
                Layout.preferredWidth: Math.min(270, Math.max(190, card.width * 0.26))
                Layout.maximumWidth: Layout.preferredWidth
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 10

                Label { text: "Configuration files"; color: "white"; font.pixelSize: 16; font.weight: Font.DemiBold }
                Label {
                    Layout.fillWidth: true
                    text: "Files on the live system, or the profile's own with <b>profile:</b> in front."
                    textFormat: Text.StyledText
                    color: "#74747d"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    TextField {
                        id: pathField
                        Layout.fillWidth: true
                        placeholderText: "/etc/motd"
                        font.family: "monospace"
                        font.pixelSize: 12
                        onAccepted: panel.openTyped()
                        onTextChanged: panel.pathError = ""
                    }
                    KeyCap { text: "Ctrl P" }
                }
                Label {
                    visible: panel.pathError !== ""
                    Layout.fillWidth: true
                    text: panel.pathError
                    color: "#ff8a8a"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                ScrollView {
                    id: sideScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    clip: true

                    ColumnLayout {
                        width: sideScroll.availableWidth
                        spacing: 4

                        component SectionLabel: Label {
                            Layout.topMargin: 8
                            color: "#8a8a93"
                            font.pixelSize: 11
                            font.letterSpacing: 1.2
                            font.weight: Font.DemiBold
                        }

                        component FileRow: Rectangle {
                            id: row
                            property string path
                            property string name
                            property string detail
                            readonly property bool current: path === panel.currentPath
                            Layout.fillWidth: true
                            implicitHeight: rowText.implicitHeight + 12
                            radius: 6
                            color: current ? Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.12)
                                           : rowHover.hovered ? "#1c1c1f" : "transparent"
                            border.color: current ? Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.5) : "transparent"
                            ColumnLayout {
                                id: rowText
                                anchors.fill: parent
                                anchors.margins: 6
                                anchors.leftMargin: 8
                                spacing: 1
                                Label {
                                    Layout.fillWidth: true
                                    text: row.name
                                    color: row.current ? panel.accent : "white"
                                    font.family: "monospace"
                                    font.pixelSize: 12
                                    elide: Text.ElideMiddle
                                }
                                Label {
                                    visible: row.detail !== ""
                                    Layout.fillWidth: true
                                    text: row.detail
                                    color: "#74747d"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                            HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: panel.openFile(row.path) }
                        }

                        SectionLabel { visible: iso.editedFiles.length > 0; text: "ON THE ISO" }
                        Repeater {
                            model: iso.editedFiles
                            delegate: FileRow {
                                required property var modelData
                                path: modelData.path
                                name: modelData.short
                                detail: (modelData.inProfile ? "Profile · " : "") + modelData.lines + (modelData.lines === 1 ? " line" : " lines") + " · " + modelData.language
                            }
                        }

                        SectionLabel { visible: iso.fileSuggestions.length > 0; text: "START FROM" }
                        Repeater {
                            model: iso.fileSuggestions
                            delegate: FileRow {
                                required property var modelData
                                path: modelData.path
                                name: modelData.short
                                detail: (modelData.inProfile ? "Profile · " : "") + modelData.detail
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: panel.line }

            // --- the file ---
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Label {
                        Layout.fillWidth: true
                        text: panel.currentPath === "" ? "No file open" : panel.displayName + (panel.dirty ? "  ●" : "")
                        color: panel.currentPath === "" ? "#74747d" : "white"
                        font.family: "monospace"
                        font.pixelSize: 14
                        elide: Text.ElideMiddle
                    }
                    Button {
                        text: "Close"
                        flat: true
                        focusPolicy: Qt.NoFocus
                        onClicked: panel.requestClose()
                    }
                    KeyCap { text: "Esc" }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: panel.currentPath !== ""
                    spacing: 8
                    ComboBox {
                        id: languageBox
                        visible: panel.currentPath !== ""
                        implicitWidth: 120
                        focusPolicy: Qt.NoFocus
                        model: ["shell", "ini", "json", "lua", "css", "packages", "plain"]
                        currentIndex: model.indexOf(panel.language)
                        onActivated: index => panel.languageOverride = model[index]
                    }
                    Button {
                        visible: panel.currentPath !== ""
                        text: "Revert to stock"
                        flat: true
                        focusPolicy: Qt.NoFocus
                        onClicked: panel.revertToStock()
                    }
                    Button {
                        visible: panel.edited
                        text: "Remove from ISO"
                        flat: true
                        focusPolicy: Qt.NoFocus
                        onClicked: panel.removeFromIso()
                    }
                    Item { Layout.fillWidth: true }
                    Button {
                        enabled: panel.dirty || !panel.edited
                        text: panel.edited ? "Save" : "Add to ISO"
                        focusPolicy: Qt.NoFocus
                        Material.background: panel.accent
                        Material.foreground: panel.accentForeground
                        onClicked: panel.save()
                    }
                    KeyCap { text: "Ctrl S" }
                }

                // The editor: line numbers and text scroll together.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8
                    color: "#0b0b0d"
                    border.color: editor.activeFocus ? Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.6) : panel.line

                    Flickable {
                        id: flick
                        anchors.fill: parent
                        anchors.margins: 1
                        visible: panel.currentPath !== ""
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        contentWidth: Math.max(width, editor.x + editor.implicitWidth)
                        contentHeight: Math.max(height, editor.implicitHeight)
                        ScrollBar.vertical: ScrollBar {}
                        ScrollBar.horizontal: ScrollBar {}

                        function ensureVisible(r) {
                            if (contentX >= r.x - gutter.width)
                                contentX = Math.max(0, r.x - gutter.width - 8);
                            else if (contentX + width <= r.x + r.width + 8)
                                contentX = r.x + r.width + 8 - width;
                            if (contentY >= r.y)
                                contentY = Math.max(0, r.y - 4);
                            else if (contentY + height <= r.y + r.height)
                                contentY = r.y + r.height + 4 - height;
                        }

                        TextEdit {
                            id: editor
                            x: gutter.width + 10
                            width: Math.max(flick.width - x, implicitWidth)
                            height: Math.max(flick.height, implicitHeight)
                            topPadding: 8
                            bottomPadding: 8
                            rightPadding: 12
                            color: "#d6d6da"
                            selectionColor: Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.35)
                            selectedTextColor: "white"
                            font.family: "monospace"
                            font.pixelSize: 13
                            textFormat: TextEdit.PlainText
                            wrapMode: TextEdit.NoWrap
                            selectByMouse: true
                            persistentSelection: true
                            tabStopDistance: metrics.advanceWidth("    ")
                            onCursorRectangleChanged: flick.ensureVisible(Qt.rect(x + cursorRectangle.x, cursorRectangle.y,
                                                                                  cursorRectangle.width, cursorRectangle.height))
                        }

                        FontMetrics { id: metrics; font: editor.font }

                        // Stays at the left edge while the text scrolls sideways.
                        Rectangle {
                            id: gutter
                            x: flick.contentX
                            width: Math.max(36, numbers.implicitWidth + 20)
                            height: Math.max(flick.height, editor.implicitHeight)
                            color: "#111113"
                            Text {
                                id: numbers
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                topPadding: 8
                                horizontalAlignment: Text.AlignRight
                                font: editor.font
                                color: "#4a4a52"
                                text: {
                                    const lines = [];
                                    for (let i = 1; i <= Math.max(1, editor.lineCount); ++i)
                                        lines.push(i);
                                    return lines.join("\n");
                                }
                            }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        width: parent.width - 60
                        visible: panel.currentPath === ""
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                        color: "#5f5f68"
                        text: "Choose a file on the left, or type a path such as /etc/motd or profile:pacman.conf.\n"
                              + "It starts from the profile's copy, or this machine's, so you only change what you need."
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: panel.currentPath !== ""
                    spacing: 14
                    Label {
                        text: {
                            const before = editor.text.substring(0, editor.cursorPosition);
                            const line = before.split("\n").length;
                            const column = editor.cursorPosition - before.lastIndexOf("\n");
                            return "Ln " + line + ", Col " + column + " · " + editor.lineCount + " lines · " + panel.language;
                        }
                        color: "#74747d"
                        font.family: "monospace"
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: panel.edited ? (panel.dirty ? "Unsaved changes" : "Saved to the ISO's settings")
                                           : "Not on the ISO until you add it"
                        color: panel.dirty || !panel.edited ? "#e6c06a" : "#74747d"
                        font.pixelSize: 11
                    }
                }
            }
        }

        SyntaxHighlighter {
            document: editor.textDocument
            language: panel.language
            accent: panel.accent
        }

        // --- save changes? ---
        Rectangle {
            anchors.fill: parent
            visible: panel.confirmVisible
            color: "#000000aa"
            MouseArea { anchors.fill: parent; onClicked: panel.confirmVisible = false }
            Rectangle {
                anchors.centerIn: parent
                width: 420
                height: confirmColumn.implicitHeight + 40
                radius: 12
                color: "#1c1c1f"
                border.color: "#2a2a30"
                MouseArea { anchors.fill: parent }
                ColumnLayout {
                    id: confirmColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12
                    Label { text: "Save your changes?"; color: "white"; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Label {
                        Layout.fillWidth: true
                        text: panel.displayName + " has changes that aren't saved yet."
                        color: "#b4b4bc"
                        wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Button { text: "Discard"; flat: true; focusPolicy: Qt.NoFocus; onClicked: panel.proceed(false) }
                        Item { Layout.fillWidth: true }
                        Button { text: "Keep editing"; flat: true; focusPolicy: Qt.NoFocus; onClicked: panel.confirmVisible = false }
                        KeyCap { text: "Esc" }
                        Button {
                            text: "Save"
                            focusPolicy: Qt.NoFocus
                            Material.background: panel.accent
                            Material.foreground: panel.accentForeground
                            onClicked: panel.proceed(true)
                        }
                        KeyCap { text: "Enter" }
                    }
                }
            }
        }
    }
}
