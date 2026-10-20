import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "BarStyle.js" as S

// The picked widget: where it sits, and everything omabar16 lets one widget
// have of its own (icon, fonts, colours, opacity, a clock's format, a
// spacer's width).
ColumnLayout {
    id: insp
    property var page

    readonly property var entry: page.selEntry || ({ id: "" })
    readonly property string lane: page.selLane
    readonly property int index: page.selIndex
    readonly property int count: (bar.layout[lane] || []).length
    readonly property var order: ["left", "center", "right"]
    readonly property int laneIndex: order.indexOf(lane)
    readonly property var res: S.resolve(bar.style, bar.themeColors)
    readonly property string segmentHex: S.segmentBase(res, lane, index, count, entry.id)

    function set(key, value) { bar.setEntry(lane, index, key, value); }
    // Moves the widget and keeps it picked where it lands.
    function moveTo(toLane, toIndex) {
        const from = lane, at = index;
        const landing = toLane === from ? Math.min(toIndex > at ? toIndex - 1 : toIndex, count - 1)
                                        : Math.min(toIndex, (bar.layout[toLane] || []).length);
        bar.moveWidget(from, at, toLane, toIndex);
        page.select(toLane, Math.max(0, landing));
    }

    spacing: 8

    // --- what and where ---
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Rectangle {
            width: 38; height: 38; radius: 9
            color: insp.segmentHex
            Label {
                anchors.centerIn: parent
                text: insp.entry.icon || insp.page.glyphFor(insp.entry.id)
                color: S.isHex(insp.entry.color) ? insp.entry.color : insp.res.text
                font.family: insp.entry.iconFont || "JetBrainsMono Nerd Font"
                font.pixelSize: 18
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label { Layout.fillWidth: true; text: insp.page.widgetName(insp.entry.id); color: theme.text; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Label { Layout.fillWidth: true; text: insp.entry.id; color: theme.textFaint; font.pixelSize: 10; font.family: "monospace"; elide: Text.ElideMiddle }
        }
        ToolButton {
            text: "\u{f0a7a}"
            font.pixelSize: 15
            focusPolicy: Qt.NoFocus
            onClicked: { bar.removeWidget(insp.lane, insp.index); insp.page.clearSelection(); }
            ToolTip.visible: hovered
            ToolTip.text: "Take off the bar (Delete)"
        }
        ToolButton {
            text: "\u{f0156}"
            font.pixelSize: 15
            focusPolicy: Qt.NoFocus
            onClicked: insp.page.clearSelection()
            ToolTip.visible: hovered
            ToolTip.text: "Done (Esc)"
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Label { text: insp.page.laneNames[insp.lane] + ", " + (insp.index + 1) + " of " + insp.count; color: theme.textMuted; font.pixelSize: 11; Layout.fillWidth: true }
        ToolButton {
            text: insp.page.vertical ? "\u{f005d}" : "\u{f004d}"; enabled: insp.laneIndex > 0; focusPolicy: Qt.NoFocus; implicitWidth: 30
            onClicked: insp.moveTo(insp.order[insp.laneIndex - 1], 9999)
            ToolTip.visible: hovered; ToolTip.text: "To the " + (insp.laneIndex > 0 ? insp.page.laneNames[insp.order[insp.laneIndex - 1]].toLowerCase() : "") + " lane"
        }
        ToolButton {
            text: insp.page.vertical ? "\u{f0143}" : "\u{f0141}"; enabled: insp.index > 0; focusPolicy: Qt.NoFocus; implicitWidth: 30
            onClicked: insp.moveTo(insp.lane, insp.index - 1)
            ToolTip.visible: hovered; ToolTip.text: "Earlier"
        }
        ToolButton {
            text: insp.page.vertical ? "\u{f0140}" : "\u{f0142}"; enabled: insp.index < insp.count - 1; focusPolicy: Qt.NoFocus; implicitWidth: 30
            onClicked: insp.moveTo(insp.lane, insp.index + 2)
            ToolTip.visible: hovered; ToolTip.text: "Later"
        }
        ToolButton {
            text: insp.page.vertical ? "\u{f0045}" : "\u{f0054}"; enabled: insp.laneIndex < 2; focusPolicy: Qt.NoFocus; implicitWidth: 30
            onClicked: insp.moveTo(insp.order[insp.laneIndex + 1], 0)
            ToolTip.visible: hovered; ToolTip.text: "To the " + (insp.laneIndex < 2 ? insp.page.laneNames[insp.order[insp.laneIndex + 1]].toLowerCase() : "") + " lane"
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

    ScrollView {
        id: scroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: scroll.availableWidth - 2
            spacing: 10

            // Folder trays have their own editor.
            ColumnLayout {
                visible: insp.entry.id === "omacraft.folders"
                Layout.fillWidth: true
                Label { Layout.fillWidth: true; text: "A folder tray. Its name, icon and apps are on the Folders tab."; color: theme.textMuted; wrapMode: Text.WordWrap; font.pixelSize: 12 }
                Button { text: "Open Folders"; flat: true; focusPolicy: Qt.NoFocus; onClicked: insp.page.tab = 3 }
            }

            SwitchRow {
                visible: insp.lane === "center"
                label: "Dead centre"
                hint: "The rest of the centre lane flows out from this widget."
                checked: bar.centerAnchor === insp.entry.id
                onToggled: on => bar.setCenterAnchor(on ? insp.entry.id : "")
            }

            // --- clock ---
            ColumnLayout {
                visible: insp.entry.id === "omarchy.clock"
                Layout.fillWidth: true
                spacing: 6
                SectionLabel { text: "Format" }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: S.CLOCK_FORMATS
                        Chip {
                            required property var modelData
                            text: modelData.label
                            chosen: (insp.entry.format || "dddd HH:mm") === modelData.format
                            onClicked: insp.set("format", modelData.format)
                            ToolTip.visible: false
                        }
                    }
                }
                TextField {
                    Layout.fillWidth: true
                    text: insp.entry.format || ""
                    placeholderText: "Qt format, e.g. ddd d MMM HH:mm"
                    font.family: "monospace"
                    onEditingFinished: if (text !== (insp.entry.format || "")) insp.set("format", text)
                }
                Label { text: "Shows: " + S.clockSample(insp.entry.format || "dddd HH:mm"); color: theme.textDim; font.pixelSize: 11 }
                TextField {
                    Layout.fillWidth: true
                    text: insp.entry.formatAlt || ""
                    placeholderText: "On click, e.g. d MMMM 'W'ww yyyy"
                    font.family: "monospace"
                    onEditingFinished: if (text !== (insp.entry.formatAlt || "")) insp.set("formatAlt", text)
                }
            }

            // --- spacer ---
            SliderRow {
                visible: insp.entry.id === "omarchy.spacer"
                label: "Width"; from: 2; to: 80; stepSize: 1; decimals: 0; suffix: " px"
                value: insp.entry.size || 12
                onMoved: v => insp.set("size", Math.round(v))
            }

            // --- icon ---
            ColumnLayout {
                visible: S.iconable(insp.entry.id)
                Layout.fillWidth: true
                spacing: 6
                SectionLabel { text: "Icon" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    TextField {
                        id: glyphField
                        Layout.preferredWidth: 70
                        text: insp.entry.icon || ""
                        placeholderText: "own"
                        horizontalAlignment: Text.AlignHCenter
                        font.family: insp.entry.iconFont || "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        onEditingFinished: if (text !== (insp.entry.icon || "")) insp.set("icon", text)
                        ToolTip.visible: hovered
                        ToolTip.text: "Paste any glyph, or pick one below"
                    }
                    Button {
                        text: "Widget's own"
                        flat: true
                        enabled: (insp.entry.icon || "") !== ""
                        focusPolicy: Qt.NoFocus
                        onClicked: insp.set("icon", "")
                    }
                    Item { Layout.fillWidth: true }
                }
                Label {
                    Layout.fillWidth: true
                    visible: ["omarchy.audio", "omarchy.network", "omarchy.bluetooth", "omarchy.microphone", "omarchy.power", "omarchy.battery"].indexOf(insp.entry.id) >= 0
                    text: "This widget's icon changes with its state; a custom one shows all the time."
                    color: theme.textDim
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }
                RowLayout {
                    visible: bar.hasIcons
                    Layout.fillWidth: true
                    spacing: 4
                    Chip { text: "Font Awesome"; chosen: iconGrid.set === "fa"; onClicked: iconGrid.set = "fa" }
                    Chip { text: "Octicons"; chosen: iconGrid.set === "oct"; onClicked: iconGrid.set = "oct" }
                    TextField { id: iconSearch; Layout.fillWidth: true; placeholderText: "Search icons" }
                }
                GridView {
                    id: iconGrid
                    visible: bar.hasIcons
                    property string set: "fa"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    clip: true
                    cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 34)))
                    cellHeight: 34
                    boundsBehavior: Flickable.StopAtBounds
                    model: insp.visible && bar.hasIcons && S.iconable(insp.entry.id) ? bar.icons(set, iconSearch.text, 600) : []
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Rectangle {
                        required property var modelData
                        width: iconGrid.cellWidth - 2
                        height: 32
                        radius: 6
                        readonly property bool on: insp.entry.icon === modelData.glyph
                        color: on ? theme.accent : iconHover.hovered ? theme.hover : "transparent"
                        Label {
                            anchors.centerIn: parent
                            text: parent.modelData.glyph
                            color: parent.on ? theme.accentForeground : theme.text
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 15
                        }
                        ToolTip.visible: iconHover.hovered
                        ToolTip.delay: 400
                        ToolTip.text: modelData.name
                        HoverHandler { id: iconHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: insp.set("icon", parent.modelData.glyph) }
                    }
                }
            }

            // --- colours ---
            SectionLabel { text: "Colours" }
            BarColorRow {
                label: "Segment"
                labelWidth: 78
                value: (bar.style.modules || {})[insp.entry.id] || ""
                shown: insp.segmentHex
                followsText: "palette"
                onPicked: hex => bar.setColor("module:" + insp.entry.id, hex)
                onCleared: bar.clearColor("module:" + insp.entry.id)
            }
            BarColorRow {
                label: "Icon & text"
                labelWidth: 78
                value: insp.entry.color || ""
                shown: insp.res.text
                followsText: "bar's text"
                onPicked: hex => insp.set("color", hex)
                onCleared: insp.set("color", "")
            }
            BarColorRow {
                label: "Hover"
                labelWidth: 78
                value: insp.entry.hoverColor || ""
                shown: S.isHex(bar.style.hoverColor) ? bar.style.hoverColor : insp.res.barText
                followsText: "bar's hover"
                onPicked: hex => insp.set("hoverColor", hex)
                onCleared: insp.set("hoverColor", "")
            }
            SliderRow {
                label: "Opacity"; from: 0.1; to: 1; stepSize: 0.05
                value: insp.entry.opacity === undefined ? 1 : insp.entry.opacity
                onMoved: v => insp.set("opacity", v >= 0.999 ? "" : Number(v.toFixed(2)))
            }

            // --- fonts ---
            SectionLabel { text: "Fonts" }
            FontField {
                label: "Text"
                value: insp.entry.font || ""
                placeholder: "The bar's font"
                onPicked: f => insp.set("font", f)
            }
            FontField {
                visible: S.iconable(insp.entry.id)
                label: "Icon"
                value: insp.entry.iconFont || ""
                placeholder: "The bar's icon font"
                onPicked: f => insp.set("iconFont", f)
            }
            Label {
                Layout.fillWidth: true
                text: "Fonts and the icon & text colour reach widgets drawn as one button; opacity and hover work on all of them."
                color: theme.textFaint
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
            Item { implicitHeight: 4 }
        }
    }
}
