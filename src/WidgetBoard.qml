import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The control centre, built by dragging. The panel holds swaync's widgets top
// to bottom: drag a row to reorder it, or out of the panel to take it away.
// The library holds what's installed and not yet used: drag one in, or press
// its plus. The store and pack files add to the library.
ColumnLayout {
    id: board
    spacing: 10

    // A pack file that's been read and wants a yes, with what it would run.
    signal reviewPack(var pack)

    readonly property var chosen: (rofioma.config.notify || {}).widgets || []
    readonly property var library: rofioma.widgetLibrary
    function info(id) { return library.find(w => w.id === id) || { id: id, name: id, glyph: "", description: "" }; }
    readonly property var unused: library.filter(w => chosen.indexOf(w.id) < 0)

    // The drag: what's held, where from (-1 for the library), and where it
    // would land.
    property string dragId: ""
    property int dragFrom: -1
    property int dropAt: -1
    property bool overPanel: false
    readonly property int rowStep: 46
    readonly property bool dragging: dragId !== ""

    function drag(id, from, item, mouse) {
        const p = item.mapToItem(board, mouse.x, mouse.y);
        ghost.x = p.x - ghost.width / 2;
        ghost.y = p.y - ghost.height / 2;
        const inPanel = item.mapToItem(panel, mouse.x, mouse.y);
        overPanel = inPanel.x >= -12 && inPanel.x <= panel.width + 12 && inPanel.y >= -24 && inPanel.y <= panel.height + 24;
        dropAt = Math.max(0, Math.min(chosen.length, Math.floor((inPanel.y - 10 + rowStep / 2) / rowStep)));
        dragId = id;
        dragFrom = from;
    }
    function drop() {
        const id = dragId, from = dragFrom, at = dropAt, over = overPanel;
        dragId = "";
        dragFrom = -1;
        dropAt = -1;
        overPanel = false;
        if (id === "") return;
        if (from < 0) {
            if (over) rofioma.placeWidget(id, at);
        } else if (!over) {
            rofioma.removeWidget(id);
        } else {
            rofioma.moveWidget(from, at > from ? at - 1 : at);
        }
    }

    // Follows the pointer, holding the widget.
    component Dragger: MouseArea {
        id: dragArea
        property string widgetId
        property int from: -1
        property point pressed_
        anchors.fill: parent
        preventStealing: true
        cursorShape: board.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: mouse => pressed_ = Qt.point(mouse.x, mouse.y)
        onPositionChanged: mouse => {
            // Hover moves arrive here too, and only a held button drags.
            if (!dragArea.pressed) return;
            if (board.dragging || Math.hypot(mouse.x - pressed_.x, mouse.y - pressed_.y) > 6)
                board.drag(widgetId, from, dragArea, mouse);
        }
        onReleased: board.drop()
        onCanceled: { board.dragId = ""; board.dropAt = -1; }
    }

    component Mini: Rectangle {
        id: mini
        property string glyph
        property string hint
        property bool danger: false
        signal clicked()
        implicitWidth: 28
        implicitHeight: 28
        radius: 7
        opacity: enabled ? 1 : 0.3
        color: miniHover.hovered && enabled ? theme.hover : "transparent"
        Label {
            anchors.centerIn: parent
            text: mini.glyph
            color: mini.danger && miniHover.hovered ? theme.danger : theme.textSoft
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }
        HoverHandler { id: miniHover; cursorShape: mini.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: mini.enabled; onTapped: mini.clicked() }
        ToolTip.visible: miniHover.hovered && hint !== ""
        ToolTip.delay: 400
        ToolTip.text: hint
    }

    Label {
        visible: (rofioma.config.notify || {}).manage !== true
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: theme.warningText
        font.pixelSize: 12
        text: "Turn on “Write swaync's style and config” above for this layout to reach swaync."
    }

    // ---- the panel
    SectionLabel { text: "In the panel, top to bottom" }
    Rectangle {
        id: panel
        objectName: "panel"
        Layout.fillWidth: true
        implicitHeight: Math.max(board.chosen.length, 1) * board.rowStep + 14
        radius: 10
        color: theme.sunken
        border.width: board.dragging && board.overPanel ? 2 : 1
        border.color: board.dragging && board.overPanel ? theme.accent : theme.border
        Behavior on implicitHeight { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Label {
            visible: board.chosen.length === 0
            anchors.centerIn: parent
            text: "Drag a widget here"
            color: theme.textFaint
        }
        Column {
            x: 7; y: 7
            width: parent.width - 14
            spacing: 6
            Repeater {
                model: board.chosen
                Rectangle {
                    id: row
                    required property string modelData
                    required property int index
                    readonly property var widget: board.info(modelData)
                    objectName: "row-" + modelData
                    readonly property bool held: board.dragFrom === index && board.dragging
                    width: parent.width
                    height: 40
                    radius: 8
                    color: rowDrag.containsMouse && !board.dragging ? theme.hover : theme.inset
                    border.color: theme.border
                    opacity: held ? (board.overPanel ? 0.35 : 0.15) : 1
                    Behavior on opacity { NumberAnimation { duration: 100 } }

                    Dragger { id: rowDrag; widgetId: row.modelData; from: row.index; hoverEnabled: true }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        spacing: 8
                        Label { text: "\u{f01dd}"; color: theme.textFaint; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                        Label {
                            Layout.preferredWidth: 20
                            horizontalAlignment: Text.AlignHCenter
                            text: row.widget.glyph || "\u{f0431}"
                            color: theme.accent
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 15
                        }
                        Label { Layout.fillWidth: true; text: row.widget.name; textFormat: Text.PlainText; color: theme.text; elide: Text.ElideRight }
                        Mini { glyph: "\u{f005d}"; hint: "Move up"; enabled: row.index > 0; onClicked: rofioma.moveWidget(row.index, row.index - 1) }
                        Mini { glyph: "\u{f0045}"; hint: "Move down"; enabled: row.index < board.chosen.length - 1; onClicked: rofioma.moveWidget(row.index, row.index + 1) }
                        Mini { glyph: "\u{f0156}"; hint: "Take it out"; danger: true; onClicked: rofioma.removeWidget(row.modelData) }
                    }
                }
            }
        }
        // Where it would land.
        Rectangle {
            visible: board.dragging && board.overPanel
            x: 10
            y: 7 + board.dropAt * board.rowStep - 4
            width: parent.width - 20
            height: 2
            radius: 1
            color: theme.accent
            Behavior on y { NumberAnimation { duration: 80 } }
        }
    }
    Label {
        Layout.fillWidth: true
        visible: board.dragFrom >= 0 && board.dragging && !board.overPanel
        text: "Let go to take it out of the panel."
        color: theme.warningText
        font.pixelSize: 11
    }

    // ---- the library
    SectionLabel { text: "Library"; Layout.topMargin: 4 }
    Label {
        Layout.fillWidth: true
        visible: board.unused.length === 0
        text: "Everything installed is in the panel. Add more from the store."
        color: theme.textFaint
        font.pixelSize: 12
    }
    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: board.unused
            Rectangle {
                id: tile
                required property var modelData
                objectName: "tile-" + modelData.id
                implicitWidth: tileRow.implicitWidth + 16
                width: implicitWidth
                height: 36
                radius: 8
                color: tileDrag.containsMouse ? theme.hover : theme.inset
                border.color: tile.modelData.custom ? theme.borderStrong : theme.border
                opacity: board.dragId === modelData.id ? 0.3 : 1
                ToolTip.visible: tileDrag.containsMouse && !board.dragging
                ToolTip.delay: 500
                ToolTip.text: modelData.description || modelData.name

                Dragger { id: tileDrag; widgetId: tile.modelData.id; hoverEnabled: true }
                Row {
                    id: tileRow
                    anchors.centerIn: parent
                    spacing: 6
                    Label { anchors.verticalCenter: parent.verticalCenter; text: tile.modelData.glyph || "\u{f0431}"; color: theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
                    Label { anchors.verticalCenter: parent.verticalCenter; text: tile.modelData.name; textFormat: Text.PlainText; color: theme.textSoft; font.pixelSize: 12 }
                    Mini { anchors.verticalCenter: parent.verticalCenter; implicitWidth: 24; implicitHeight: 24; glyph: "\u{f0415}"; hint: "Add to the panel"; onClicked: rofioma.placeWidget(tile.modelData.id, -1) }
                    Mini { visible: tile.modelData.custom === true; anchors.verticalCenter: parent.verticalCenter; implicitWidth: 24; implicitHeight: 24; glyph: "\u{f0a7a}"; danger: true; hint: "Uninstall"; onClicked: rofioma.uninstallWidget(tile.modelData.id) }
                }
            }
        }
    }

    // ---- the store
    SectionLabel { text: "Install more"; Layout.topMargin: 4 }
    GridLayout {
        Layout.fillWidth: true
        columns: board.width > 460 ? 2 : 1
        rowSpacing: 6
        columnSpacing: 6
        Repeater {
            model: rofioma.widgetStore
            Rectangle {
                id: item
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 54
                radius: 8
                color: theme.inset
                border.color: theme.border
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 8
                    Label { text: item.modelData.glyph; color: theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 17 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label { Layout.fillWidth: true; text: item.modelData.name; color: theme.text; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        Label { Layout.fillWidth: true; text: item.modelData.description; color: theme.textDim; font.pixelSize: 10; elide: Text.ElideRight
                            ToolTip.visible: storeHover.hovered && truncated
                            ToolTip.text: text
                            HoverHandler { id: storeHover }
                        }
                    }
                    Mini {
                        glyph: item.modelData.installed ? "\u{f012c}" : "\u{f01da}"
                        enabled: !item.modelData.installed
                        hint: item.modelData.installed ? "" : "Install"
                        onClicked: rofioma.installWidget(item.modelData.id)
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Rectangle {
            id: packDrop
            Layout.fillWidth: true
            implicitHeight: 38
            radius: 8
            color: fileDrop.containsDrag ? theme.hover : theme.sunken
            border.color: fileDrop.containsDrag ? theme.accent : theme.border
            TextInput {
                id: packPath
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: theme.text
                selectionColor: theme.accent
                selectedTextColor: theme.accentForeground
                font.pixelSize: 12
                onAccepted: board.readPack(text)
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.text === ""
                    text: "Path to a widget pack .json, or drop one here"
                    color: theme.textFaint
                    font.pixelSize: 12
                }
            }
            DropArea {
                id: fileDrop
                anchors.fill: parent
                keys: ["text/uri-list"]
                onDropped: drop => {
                    if (drop.urls.length > 0) {
                        packPath.text = drop.urls[0].toString();
                        board.readPack(packPath.text);
                    }
                }
            }
        }
        Button { text: "Install pack"; flat: true; focusPolicy: Qt.NoFocus; enabled: packPath.text !== ""; onClicked: board.readPack(packPath.text) }
        Button { text: "Make one"; flat: true; focusPolicy: Qt.NoFocus; onClicked: maker.open() }
    }
    Label {
        id: packProblem
        visible: text !== ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: theme.danger
        font.pixelSize: 12
        textFormat: Text.PlainText
    }
    function readPack(path) {
        const pack = rofioma.readWidgetPack(path);
        packProblem.text = pack.error || "";
        if (!pack.error) {
            packPath.text = "";
            reviewPack(pack);
        }
    }

    // What's being dragged.
    Rectangle {
        id: ghost
        parent: board
        visible: board.dragging
        Layout.preferredWidth: 0
        Layout.preferredHeight: 0
        z: 100
        width: ghostRow.implicitWidth + 24
        height: 38
        radius: 9
        color: theme.raised
        border.color: theme.accent
        border.width: 2
        Row {
            id: ghostRow
            anchors.centerIn: parent
            spacing: 8
            Label { text: board.info(board.dragId).glyph || "\u{f0431}"; color: theme.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15 }
            Label { text: board.info(board.dragId).name; textFormat: Text.PlainText; color: theme.text; font.weight: Font.DemiBold }
        }
    }

    // ---- making your own
    Popup {
        id: maker
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(520, (parent ? parent.width : 520) - 40)
        modal: true
        focus: true
        padding: 18
        property string kind: "buttons"
        background: Rectangle { radius: 12; color: theme.raised; border.color: theme.borderStrong }
        onOpened: { makerName.text = ""; makerText.text = ""; makerGetter.text = ""; makerSetter.text = ""; makerGlyph.text = ""; }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            Label { text: "Make a widget"; color: theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
            Segmented {
                model: [{ id: "buttons", name: "Buttons" }, { id: "label", name: "Text" }, { id: "slider", name: "Slider" }]
                current: maker.kind
                onPicked: id => maker.kind = id
            }
            RowLayout {
                Layout.fillWidth: true
                TextField { id: makerName; Layout.fillWidth: true; placeholderText: "Name" }
                TextField { id: makerGlyph; Layout.preferredWidth: 70; placeholderText: maker.kind === "slider" ? "Label" : "Icon"; font.family: "JetBrainsMono Nerd Font" }
            }
            TextArea {
                id: makerText
                visible: maker.kind !== "slider"
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                wrapMode: TextEdit.Wrap
                font.family: maker.kind === "buttons" ? "monospace" : ""
                placeholderText: maker.kind === "buttons" ? "One button a line:\nTerminal = omarchy-launch-terminal\nFiles = nautilus" : "What it says"
            }
            TextField { id: makerGetter; visible: maker.kind === "slider"; Layout.fillWidth: true; font.family: "monospace"; placeholderText: "Command that prints the value" }
            TextField { id: makerSetter; visible: maker.kind === "slider"; Layout.fillWidth: true; font.family: "monospace"; placeholderText: "Command that sets it, using $value" }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button { text: "Cancel"; flat: true; focusPolicy: Qt.NoFocus; onClicked: maker.close() }
                AccentButton {
                    text: "Add to library"
                    enabled: makerName.text.trim() !== ""
                    onClicked: {
                        const id = rofioma.createWidget(maker.kind, makerName.text.trim(),
                            { text: makerText.text, glyph: makerGlyph.text, label: makerGlyph.text, getter: makerGetter.text, setter: makerSetter.text });
                        if (id !== "") maker.close();
                    }
                }
            }
        }
    }
}
