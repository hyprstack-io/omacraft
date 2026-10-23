import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "BarStyle.js" as S

// Themes three ways. A complete theme is a look and its colours together,
// or, with "Omarchy theme" colours, its look in whatever Omarchy theme is
// active (and every one after it). Looks are the shapes and spacing alone,
// drawn in your colours; colour schemes are the palettes alone, drawn on
// your look. Pick one of each from anywhere, or shuffle. Every tile
// previews on the stage while hovered.
Item {
    id: tab
    property var page

    property string mode: startTab === "looks" || startTab === "colours" ? startTab : "complete"    // complete | looks | colours
    property string group: "All"
    readonly property bool dialogOpen: saveDialog.opened || importDialog.opened
    function closeDialogs() {
        if (!dialogOpen) return false;
        saveDialog.close();
        importDialog.close();
        return true;
    }
    function acceptDialog() {
        if (saveDialog.opened) saveDialog.accept();
        else if (importDialog.opened) importDialog.accept();
    }

    readonly property var themes: bar.themes
    readonly property var current: bar.style
    // Complete themes in their own colours, or in the Omarchy theme's. It
    // starts on whichever the bar has: no colours of its own follows Omarchy.
    property string colourSource: S.colourSignature(bar.style) === "" && Object.keys(bar.style).length > 0 ? "omarchy" : "own"
    readonly property bool followOmarchy: mode === "complete" && colourSource === "omarchy"

    // Every distinct look, named after the first theme that has it.
    readonly property var looks: {
        const seen = {}, out = [];
        for (const t of themes) {
            const look = S.lookOf(t.style);
            const sig = S.signature(look);
            if (seen[sig]) continue;
            seen[sig] = true;
            out.push({ id: "look:" + t.id, label: t.label, group: S.shapeFamily(look.shape), source: t.group, look: look });
        }
        return out;
    }
    // Every distinct colour scheme, the Omarchy theme's own first.
    readonly property var colourSchemes: {
        const out = [
            { id: "c:theme", label: "Omarchy theme", group: "Follow Omarchy", source: "follows every theme and wallpaper", colours: {} },
            { id: "c:theme-mono", label: "Omarchy accent", group: "Follow Omarchy", source: "the accent, alternating", colours: { colors: "mono" } },
            { id: "c:theme-ink", label: "Omarchy neutral", group: "Follow Omarchy", source: "text colour only", colours: { colors: "mono", palette: ["foreground"] } }
        ];
        const seen = {};
        out.forEach(c => seen[S.colourSignature(c.colours)] = true);
        for (const t of themes) {
            const colours = S.coloursOf(t.style);
            delete colours.regions;
            delete colours.modules;
            const sig = S.colourSignature(colours);
            if (seen[sig]) continue;
            seen[sig] = true;
            out.push({ id: "c:" + t.id, label: t.label, group: S.isHex(colours.bg) ? t.group : "Follow Omarchy",
                       source: t.group === "base16" ? "base16" : t.group, colours: colours });
        }
        return out;
    }

    readonly property var groups: mode === "complete" ? ["All", "Originals", "Omarchy", "JaKooLit", "HANCORE", "base16", "Yours"].filter(g => g === "All" || themes.some(t => t.group === g))
        : mode === "looks" ? ["All"].concat(S.SHAPES.map(s => s.family).filter((f, i, a) => a.indexOf(f) === i && looks.some(l => l.group === f)))
        : ["All", "Follow Omarchy", "Originals", "Omarchy", "JaKooLit", "HANCORE", "base16", "Yours"].filter(g => g === "All" || colourSchemes.some(c => c.group === g))
    onModeChanged: group = "All"

    function matches(item) {
        const q = search.text.trim().toLowerCase();
        return (group === "All" || item.group === group)
            && (q === "" || (item.label + " " + (item.desc || "") + " " + (item.source || "")).toLowerCase().indexOf(q) >= 0);
    }

    // What each mode lists. Only the filters change the list, so the grid
    // keeps its place as themes are applied; each tile works out its own
    // style (a look in your colours, colours on your look) and whether it's
    // what the bar has now.
    readonly property var items: mode === "looks" ? looks.filter(matches)
                               : mode === "colours" ? colourSchemes.filter(matches)
                               : themes.filter(t => matches(Object.assign({ source: t.group }, t)))
    function styleOf(item) {
        if (mode === "looks") return S.compose(item.look, current);
        if (mode === "colours") return S.compose(current, item.colours);
        // No colours of its own: the bar takes the Omarchy theme's, live.
        if (followOmarchy) return S.compose(item.style, {});
        return item.style;
    }
    function isCurrent(item) {
        if (mode === "looks") return S.lookSignature(item.look) === S.lookSignature(current);
        if (mode === "colours") return S.colourSignature(item.colours) === S.colourSignature(current);
        if (followOmarchy) return S.colourSignature(current) === "" && S.lookSignature(item.style) === S.lookSignature(current);
        return bar.currentTheme === item.id;
    }
    function subtitleOf(item) {
        if (mode === "looks") return S.SHAPES.find(s => s.id === (item.look.shape || "none")).name + (item.look.solid === false ? ", tinted" : "");
        return mode === "colours" ? "" : (item.desc || "");
    }

    function apply(item) {
        page.endPreview(item.label);
        if (mode === "complete" && !followOmarchy) bar.applyTheme(item.id);
        else bar.setWholeStyle(styleOf(item));
    }

    // A random look in random colours, never the one you have.
    function shuffle() {
        if (looks.length === 0) return;
        let style = current;
        for (let tries = 0; tries < 8 && S.signature(style) === S.signature(current); tries++) {
            const look = looks[Math.floor(Math.random() * looks.length)].look;
            const scheme = colourSchemes[Math.floor(Math.random() * colourSchemes.length)].colours;
            style = S.compose(look, scheme);
        }
        bar.setWholeStyle(style);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            // Which of the three.
            Segmented {
                model: [{ id: "complete", name: "Complete themes" }, { id: "looks", name: "Looks" }, { id: "colours", name: "Colours" }]
                current: tab.mode
                onPicked: id => tab.mode = id
            }
            // Where a complete theme's colours come from.
            Label {
                visible: tab.mode === "complete"
                Layout.leftMargin: 10
                text: "COLOURS"
                color: theme.textFaint
                font.pixelSize: 10
                font.letterSpacing: 1.2
                font.weight: Font.DemiBold
            }
            Segmented {
                visible: tab.mode === "complete"
                model: [{ id: "own", name: "Theme's own" }, { id: "omarchy", name: "\u{f03d8}  Omarchy theme" }]
                current: tab.colourSource
                onPicked: id => tab.colourSource = id
            }
            Label {
                Layout.leftMargin: 8
                Layout.fillWidth: true
                text: tab.mode === "looks" ? "Shape, fill and spacing; your colours stay."
                    : tab.mode === "colours" ? "Palettes only; your look stays."
                    : tab.followOmarchy ? "Each look in your Omarchy theme's colours, following every theme change."
                    : "A look and its colours, together."
                color: theme.textDim
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Button {
                text: "\u{f049d}  Shuffle"
                flat: true
                focusPolicy: Qt.NoFocus
                onClicked: tab.shuffle()
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "A random look in random colours (R). Undo goes back."
            }
            ToolButton {
                id: moreButton
                text: "\u{f01d8}"
                font.pixelSize: 16
                focusPolicy: Qt.NoFocus
                onClicked: moreMenu.open()
                ToolTip.visible: hovered && !moreMenu.visible
                ToolTip.delay: 500
                ToolTip.text: "Save, import and export themes"
                Menu {
                    id: moreMenu
                    y: moreButton.height
                    MenuItem { text: "Save the bar as a theme…"; onTriggered: saveDialog.open() }
                    MenuItem { text: "Import themes…"; onTriggered: importDialog.open() }
                    MenuItem { text: "Export the bar's look"; onTriggered: bar.exportTheme("") }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: tab.groups
                Chip {
                    required property string modelData
                    text: modelData
                    chosen: tab.group === modelData
                    onClicked: tab.group = modelData
                }
            }
            Item { Layout.fillWidth: true }
            Label { text: tab.items.length; color: theme.textFaint; font.pixelSize: 11 }
            SearchBox {
                id: search
                placeholderText: tab.mode === "colours" ? "Search colours" : tab.mode === "looks" ? "Search looks" : "Search themes"
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            readonly property int columns: Math.max(2, Math.floor(width / 250))
            cellWidth: Math.floor(width / columns)
            cellHeight: 120
            model: tab.items
            ScrollBar.vertical: ScrollBar {}
            delegate: Item {
                id: cell
                required property var modelData
                readonly property var style: tab.styleOf(modelData)
                readonly property bool chosen: tab.isCurrent(modelData)
                width: grid.cellWidth
                height: grid.cellHeight
                BarTile {
                    anchors.fill: parent
                    anchors.margins: 5
                    title: cell.modelData.label
                    tag: tab.mode === "complete" ? cell.modelData.group : (cell.modelData.source || "")
                    subtitle: tab.subtitleOf(cell.modelData)
                    swatches: tab.mode === "looks" ? [] : tab.mode === "colours" ? S.swatches(cell.modelData.colours, bar.themeColors)
                                                                                 : S.swatches(cell.style, bar.themeColors).slice(1)
                    chosen: cell.chosen
                    removable: cell.modelData.user === true
                    exportable: tab.mode === "complete"
                    cfg: ({ position: "top", layout: S.sample(bar.config, 3).layout, centerAnchor: bar.centerAnchor, style: cell.style })
                    // What the bar already has needs no preview.
                    onPreviewWanted: on => on && !cell.chosen ? tab.page.preview(cell.modelData.label, cell.style, null)
                                                             : tab.page.endPreview(cell.modelData.label)
                    onPicked: tab.apply(cell.modelData)
                    onRemoveRequested: bar.deleteTheme(cell.modelData.id)
                    onExportRequested: bar.exportTheme(cell.modelData.id)
                }
            }
            Label {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: "Nothing matches."
                color: theme.textDim
            }
        }
    }

    // --- save the look as your own theme ---
    Dialog {
        id: saveDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "Save the bar's look"
        standardButtons: Dialog.Save | Dialog.Cancel
        width: 380
        onOpened: { nameField.text = ""; nameField.forceActiveFocus(); }
        onAccepted: bar.saveTheme(nameField.text)
        ColumnLayout {
            anchors.fill: parent
            spacing: 8
            Label { Layout.fillWidth: true; text: "It's kept under Yours, beside omabar16's themes."; color: theme.textMuted; wrapMode: Text.WordWrap }
            TextField { id: nameField; Layout.fillWidth: true; placeholderText: "Name"; onAccepted: saveDialog.accept() }
        }
    }

    // --- bring themes in ---
    Dialog {
        id: importDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "Import bar themes"
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: 480
        onOpened: { importField.text = ""; importField.forceActiveFocus(); }
        onAccepted: if (importField.text.trim() !== "") bar.importThemes(importField.text)
        ColumnLayout {
            anchors.fill: parent
            spacing: 8
            Label {
                Layout.fillWidth: true
                text: "Paste an exported theme (JSON), or the path of an export file. Only omabar16's style keys are kept."
                color: theme.textMuted
                wrapMode: Text.WordWrap
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 160
                TextArea {
                    id: importField
                    font.family: "monospace"
                    font.pixelSize: 12
                    wrapMode: TextEdit.WrapAnywhere
                    placeholderText: "~/.config/omarchy/omabar16/exports/my-bar.json"
                }
            }
        }
    }
}
