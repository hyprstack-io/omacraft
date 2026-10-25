import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// How the wallpaper's colours become the scheme: which scheme reads them,
// light or dark, style, contrast and accent. One card, shown both on the
// Wallpapers page (Colours) and the Plugin Suite page, so either changes it.
Card {
    id: card

    readonly property var paletteCfg: (wallpaper.status.settings || {}).palette || ({})
    readonly property var colors: wallpaper.status.palette || ({})
    readonly property var tools: wallpaper.status.tools || ({})

    // A row of chips for one setting.
    component ChipRow: RowLayout {
        id: row
        property string label
        property var choices: []        // [{ value, label }]
        property var value
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
                    chosen: row.value === modelData.value
                    onClicked: row.picked(modelData.value)
                }
            }
        }
    }

    Layout.fillWidth: true
    implicitHeight: schemeColumn.implicitHeight + 32
    ColumnLayout {
        id: schemeColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            SectionLabel { text: "Colour scheme" }
            Label {
                Layout.fillWidth: true
                text: card.colors.engineNote || ""
                color: theme.warning
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(2, Math.floor(width / 230))
            rowSpacing: 8
            columnSpacing: 8
            Repeater {
                model: [
                    { id: "material", name: "Material", tool: "", text: "Material You roles from tonal palettes of the wallpaper's key colour. Calm, even, always readable." },
                    { id: "matugen", name: "Matugen", tool: "matugen", text: "matugen's tonal-spot scheme: Material 3 surfaces, containers and on-colours straight from matugen." },
                    { id: "wallbash", name: "Wallbash", tool: "", text: "HyDE's wallbash: the image's own main colours carry into surfaces and accents, with its dcol_* sets for templates." },
                    { id: "pywal", name: "Pywal", tool: "wal", text: "Terminal colours taken almost straight from the image, as pywal does; runs wal itself when it is installed." },
                    { id: "flavours", name: "Flavours", tool: "flavours", text: "A base16 scheme generated from the image by flavours, mapped onto every Omarchy colour." },
                    { id: "classic", name: "Classic", tool: "", text: "The original Studio palette: neutral surfaces, a single accent." }
                ]
                delegate: Rectangle {
                    id: scheme
                    required property var modelData
                    readonly property bool chosen: (card.paletteCfg.scheme || "material") === modelData.id
                    readonly property bool hasTool: modelData.tool !== ""
                    readonly property bool installed: hasTool && (card.tools[modelData.id] || "") !== ""
                    readonly property color tone: Qt.color(theme.accent)
                    Layout.fillWidth: true
                    implicitHeight: schemeText.implicitHeight + 24
                    radius: 9
                    color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.14) : shover.hovered ? theme.hover : theme.inset
                    border.color: chosen ? theme.accent : theme.border
                    border.width: chosen ? 2 : 1
                    ColumnLayout {
                        id: schemeText
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: scheme.modelData.name; color: scheme.chosen ? theme.accent : theme.text; font.weight: Font.DemiBold }
                            Item { Layout.fillWidth: true }
                            Label {
                                visible: scheme.hasTool
                                text: scheme.installed ? (card.paletteCfg.engine === "builtin" ? "built-in" : "uses " + scheme.modelData.tool) : "built-in"
                                color: scheme.installed ? theme.accent : theme.textDim
                                font.pixelSize: 10
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: scheme.modelData.text
                            color: theme.textMuted
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                        Label {
                            visible: scheme.hasTool && !scheme.installed
                            text: "<a href='#'>Install " + scheme.modelData.tool + "</a> to use the real thing"
                            color: theme.textMuted
                            linkColor: theme.accent
                            font.pixelSize: 11
                            onLinkActivated: wallpaper.installTool(scheme.modelData.id)
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                    HoverHandler { id: shover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: wallpaper.setOption("palette.scheme", scheme.modelData.id, true) }
                }
            }
        }
        SwitchRow {
            label: "Use pywal, matugen and flavours themselves when installed"
            hint: "Off: OmaCraft's built-in versions of those schemes, even when the programs are there. Either way the colours are held to the contrast below."
            checked: card.paletteCfg.engine !== "builtin"
            onToggled: on => wallpaper.setOption("palette.engine", on ? "auto" : "builtin", true)
        }
        ChipRow {
            label: "Mode"
            value: card.paletteCfg.mode || "auto"
            choices: [{ value: "dark", label: "Dark" }, { value: "light", label: "Light" }, { value: "auto", label: "Auto: bright wallpapers go light" }]
            onPicked: v => wallpaper.setOption("palette.mode", v, true)
        }
        ChipRow {
            label: "Style"
            value: card.paletteCfg.style || "balanced"
            choices: [{ value: "balanced", label: "Balanced" }, { value: "vibrant", label: "Vibrant" }, { value: "pastel", label: "Pastel" }, { value: "muted", label: "Muted" }, { value: "mono", label: "Mono" }]
            onPicked: v => wallpaper.setOption("palette.style", v, true)
        }
        ChipRow {
            label: "Contrast"
            value: card.paletteCfg.contrast || "normal"
            choices: [{ value: "soft", label: "Soft 3:1" }, { value: "normal", label: "Normal 4.5:1" }, { value: "high", label: "High 7:1" }]
            onPicked: v => wallpaper.setOption("palette.contrast", v, true)
        }
        ChipRow {
            label: "Accent"
            value: card.paletteCfg.accent || "auto"
            choices: [{ value: "auto", label: "From the image" }].concat((wallpaper.targetInfo.accentRoles || []).map(r => ({ value: r, label: r })))
            onPicked: v => wallpaper.setOption("palette.accent", v, true)
        }
    }
}
