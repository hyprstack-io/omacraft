import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "BarStyle.js" as S

// Every style key omabar16 reads, in one place: the segment shape (each
// drawn), fill, spacing, the bar itself, every colour down to the palette,
// hover, type and readability.
ScrollView {
    id: tab
    property var page

    readonly property var st: bar.style
    readonly property var res: S.resolve(st, bar.themeColors)
    readonly property bool twoColumns: availableWidth > 940
    function num(key, fallback) { return st[key] === undefined ? fallback : st[key]; }

    contentWidth: availableWidth
    clip: true

    GridLayout {
        width: tab.availableWidth
        columns: tab.twoColumns ? 2 : 1
        columnSpacing: 14
        rowSpacing: 14

        // --- shape, each one drawn ---
        Card {
            Layout.fillWidth: true
            Layout.columnSpan: tab.twoColumns ? 2 : 1
            implicitHeight: shapeColumn.implicitHeight + 28
            ColumnLayout {
                id: shapeColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                SectionLabel { text: "Segment shape" }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: S.SHAPES
                        Rectangle {
                            id: shapeTile
                            required property var modelData
                            readonly property bool on: (tab.st.shape || "none") === modelData.id
                            readonly property color tone: Qt.color(theme.accent)
                            width: 132
                            height: 70
                            radius: 9
                            color: on ? Qt.rgba(tone.r, tone.g, tone.b, 0.12) : shapeHover.hovered ? theme.hover : theme.inset
                            border.color: on ? theme.accent : theme.border
                            border.width: on ? 2 : 1
                            Rectangle {
                                x: 8; y: 8
                                width: parent.width - 16
                                height: 32
                                radius: 5
                                color: tab.res.bg
                                clip: true
                                Row {
                                    anchors.centerIn: parent
                                    Repeater {
                                        model: 3
                                        BarSegment {
                                            required property int index
                                            kind: shapeTile.modelData.id
                                            h: 20
                                            fontPx: 10
                                            mode: "right"
                                            flatEdge: index === 0 && tab.st.flatEnds !== false
                                            gap: shapeTile.modelData.id === "none" ? 0 : Math.max(1, tab.num("gap", 1))
                                            depthFactor: tab.num("depth", 0.42)
                                            blockRadius: tab.num("radius", 4) * 20 / 30
                                            glyph: ["\u{f0954}", "\u{f057e}", "\u{f05a9}"][index]
                                            fill: shapeTile.modelData.id === "none" ? "transparent" : S.segmentFill(tab.res, tab.res.palette[index % tab.res.palette.length], false)
                                            textColor: shapeTile.modelData.id === "none" || shapeTile.modelData.id === "underline" ? tab.res.barText : tab.res.text
                                        }
                                    }
                                }
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 7
                                text: shapeTile.modelData.name
                                color: shapeTile.on ? theme.accent : theme.textSoft
                                font.pixelSize: 11
                            }
                            HoverHandler { id: shapeHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: bar.setStyle("shape", shapeTile.modelData.id) }
                        }
                    }
                }
            }
        }

        // --- fill ---
        Card {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            implicitHeight: fillColumn.implicitHeight + 28
            ColumnLayout {
                id: fillColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                SectionLabel { text: "Fill" }
                RowLayout {
                    spacing: 6
                    Label { Layout.preferredWidth: 120; text: "Colours"; color: theme.textSoft }
                    Chip { text: "Cycle the palette"; chosen: tab.st.colors !== "mono"; onClicked: bar.setStyle("colors", "cycle") }
                    Chip { text: "One colour"; chosen: tab.st.colors === "mono"; onClicked: bar.setStyle("colors", "mono") }
                }
                SwitchRow {
                    label: "Solid"
                    hint: "Off washes each segment into the bar's background by the tint."
                    checked: tab.st.solid !== false
                    onToggled: on => bar.setStyle("solid", on)
                }
                SliderRow { label: "Tint"; enabled: tab.st.solid === false; from: 0; to: 1; value: tab.num("tint", 0.3); onMoved: v => bar.setStyle("tint", Number(v.toFixed(2))) }
                SliderRow { label: "Segment opacity"; from: 0.1; to: 1; value: tab.num("segmentOpacity", 1); onMoved: v => bar.setStyle("segmentOpacity", Number(v.toFixed(2))) }
                SliderRow {
                    label: "Point depth"
                    enabled: ["arrow", "hex"].indexOf(tab.st.shape) >= 0
                    from: 0.1; to: 1; value: tab.num("depth", 0.42)
                    onMoved: v => bar.setStyle("depth", Number(v.toFixed(2)))
                }
                SwitchRow {
                    label: "Flat ends"
                    hint: "Square off the outer ends of chevron runs."
                    checked: tab.st.flatEnds !== false
                    onToggled: on => bar.setStyle("flatEnds", on)
                }
                SliderRow { label: "Outline"; from: 0; to: 6; stepSize: 1; decimals: 0; suffix: " px"; value: tab.num("outline", 0); onMoved: v => bar.setStyle("outline", Math.round(v)) }
                SliderRow { label: "Shadow"; from: 0; to: 1; value: tab.num("shadow", 0); onMoved: v => bar.setStyle("shadow", Number(v.toFixed(2))) }
            }
        }

        // --- spacing and the bar ---
        Card {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            implicitHeight: frameColumn.implicitHeight + 28
            ColumnLayout {
                id: frameColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                SectionLabel { text: "Size and spacing" }
                SliderRow { label: "Thickness"; from: 16; to: 56; stepSize: 1; decimals: 0; suffix: " px"; value: tab.num("size", 26); onMoved: v => bar.setStyle("size", Math.round(v)) }
                SliderRow { label: "Corner radius"; from: 0; to: 24; stepSize: 1; decimals: 0; suffix: " px"; value: tab.num("radius", 0); onMoved: v => bar.setStyle("radius", Math.round(v)) }
                SliderRow { label: "Gap"; from: 0; to: 16; stepSize: 1; decimals: 0; suffix: " px"; value: tab.num("gap", 1); onMoved: v => bar.setStyle("gap", Math.round(v)) }
                SliderRow { label: "Inset"; from: 0; to: 12; stepSize: 1; decimals: 0; suffix: " px"; value: tab.num("inset", 0); onMoved: v => bar.setStyle("inset", Math.round(v)) }
                SliderRow { label: "Padding"; from: 0; to: 24; stepSize: 1; decimals: 0; suffix: " px"; value: tab.num("pad", 3); onMoved: v => bar.setStyle("pad", Math.round(v)) }
                SliderRow { label: "Edge padding"; from: 0; to: 32; stepSize: 1; decimals: 0; suffix: " px"; value: tab.num("edge", 0); onMoved: v => bar.setStyle("edge", Math.round(v)) }
                SliderRow { label: "Float"; from: 0; to: 24; stepSize: 1; decimals: 0; suffix: " px"; value: tab.num("float", 0); onMoved: v => bar.setStyle("float", Math.round(v)) }
                SliderRow { label: "Bar opacity"; from: 0; to: 1; value: tab.num("barOpacity", 1); onMoved: v => bar.setStyle("barOpacity", Number(v.toFixed(2))) }
                SliderRow { label: "Backdrop"; from: 0; to: 1; value: tab.num("backdrop", 0); onMoved: v => bar.setStyle("backdrop", Number(v.toFixed(2))) }
                SwitchRow {
                    label: "Transparent"
                    hint: "The wallpaper shows through; omabar16 fits the text to it."
                    checked: bar.transparent
                    onToggled: on => bar.setTransparent(on)
                }
            }
        }

        // --- colours ---
        Card {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            implicitHeight: colourColumn.implicitHeight + 28
            ColumnLayout {
                id: colourColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    SectionLabel { text: "Colours"; Layout.fillWidth: true }
                    Button {
                        text: "Follow Omarchy for all"
                        flat: true
                        focusPolicy: Qt.NoFocus
                        onClicked: bar.setWholeStyle(S.lookOf(tab.st))
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        ToolTip.text: "Drop every colour override; the bar follows the theme and wallpaper"
                    }
                }
                BarColorRow { label: "Background"; value: tab.st.bg || ""; shown: tab.res.bg; onPicked: hex => bar.setColor("bg", hex); onCleared: bar.clearColor("bg") }
                BarColorRow {
                    label: (tab.st.shape || "none") === "underline" || (tab.st.shape || "none") === "none" ? "Text" : "Ink on segments"
                    value: tab.st.fg || ""; shown: tab.res.text
                    onPicked: hex => bar.setColor("fg", hex); onCleared: bar.clearColor("fg")
                }
                BarColorRow { label: "Accent"; value: tab.st.accent || ""; shown: tab.res.accent; onPicked: hex => bar.setColor("accent", hex); onCleared: bar.clearColor("accent") }
                BarColorRow {
                    label: "Outline"; value: tab.st.outlineColor || ""; shown: Qt.darker(tab.res.bg, 1.6)
                    onPicked: hex => bar.setColor("outlineColor", hex); onCleared: bar.clearColor("outlineColor")
                }
                SectionLabel { text: "Lanes"; Layout.topMargin: 4 }
                Repeater {
                    model: ["left", "center", "right"]
                    BarColorRow {
                        required property string modelData
                        label: tab.page.laneNames[modelData] + " lane"
                        value: (tab.st.regions || {})[modelData] || ""
                        shown: S.segmentBase(tab.res, modelData, 0, 1, "")
                        followsText: "palette"
                        onPicked: hex => bar.setColor("region:" + modelData, hex)
                        onCleared: bar.clearColor("region:" + modelData)
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    SectionLabel { text: "Palette"; Layout.fillWidth: true }
                    Button {
                        text: "Theme's palette"
                        flat: true
                        enabled: tab.st.palette !== undefined
                        focusPolicy: Qt.NoFocus
                        onClicked: bar.clearColor("pal:0")
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: tab.res.palette.slice(0, 8)
                        Rectangle {
                            id: palSwatch
                            required property string modelData
                            required property int index
                            width: 40; height: 30; radius: 7
                            color: modelData
                            border.color: theme.borderStrong
                            Label { anchors.centerIn: parent; text: palSwatch.index + 1; font.pixelSize: 10; color: S.luminance(palSwatch.modelData) > 0.4 ? "#111" : "#fff" }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: palWheel.openWith(palSwatch.modelData) }
                            ColorPicker {
                                id: palWheel
                                title: "Palette colour " + (palSwatch.index + 1)
                                onPicked: hex => bar.setColor("pal:" + palSwatch.index, hex)
                            }
                        }
                    }
                    Rectangle {
                        width: 40; height: 30; radius: 7
                        color: addHover.hovered ? theme.hover : theme.inset
                        border.color: theme.border
                        visible: tab.res.palette.length < 8
                        Label { anchors.centerIn: parent; text: "+"; color: theme.textMuted }
                        HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: addWheel.openWith(tab.res.accent) }
                        ColorPicker {
                            id: addWheel
                            title: "Add a palette colour"
                            onPicked: hex => bar.setColor("pal:" + tab.res.palette.length, hex)
                        }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    text: "Segments take the palette in turn. Picking a widget on the stage gives it a colour of its own."
                    color: theme.textFaint
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }
            }
        }

        // --- hover, type, readability ---
        Card {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            implicitHeight: moreColumn.implicitHeight + 28
            ColumnLayout {
                id: moreColumn
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10
                SectionLabel { text: "Hover" }
                BarColorRow {
                    label: "Colour"; value: tab.st.hoverColor || ""; shown: tab.res.barText; followsText: "text colour"
                    onPicked: hex => bar.setColor("hoverColor", hex); onCleared: bar.clearColor("hoverColor")
                }
                SliderRow {
                    label: "Strength"; from: 0; to: 1
                    value: tab.num("hoverOpacity", (tab.st.shape || "none") === "none" ? 0.14 : 0.35)
                    onMoved: v => bar.setStyle("hoverOpacity", Number(v.toFixed(2)))
                }
                SectionLabel { text: "Type"; Layout.topMargin: 4 }
                FontField { label: "Text font"; labelWidth: 120; value: tab.st.fontFamily || ""; placeholder: "The shell's font"; onPicked: f => bar.setStyle("fontFamily", f) }
                FontField { label: "Icon font"; labelWidth: 120; value: tab.st.iconFont || ""; placeholder: "The text font"; onPicked: f => bar.setStyle("iconFont", f) }
                SectionLabel { text: "Readability"; Layout.topMargin: 4 }
                SliderRow {
                    label: "Minimum contrast"; from: 1; to: 10; stepSize: 0.5; decimals: 1; suffix: ":1"
                    value: tab.num("minContrast", 4.5)
                    onMoved: v => bar.setStyle("minContrast", Number(v.toFixed(1)))
                }
                Label {
                    Layout.fillWidth: true
                    text: "omabar16 nudges a segment's colour until its ink reaches this contrast. 4.5 is WCAG AA; 1 turns it off."
                    color: theme.textFaint
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }
            }
        }
        Item { implicitHeight: 4 }
    }
}
