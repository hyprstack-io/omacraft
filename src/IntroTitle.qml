import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Omacraft

// The Plugin Suite's title: "OMACRAFT" played through the Boot Splash
// page's intro effects (introReel renders them with omascii). It starts on a
// random one each launch and, with autoplay (on unless it's switched off),
// moves on to the next each time one finishes, round all of them in a loop.
// The arrows step through them; a click on the art plays it again.
ColumnLayout {
    id: title

    property bool running: true
    property bool autoplay: true
    property int frame: 0

    readonly property var frames: introReel.frames
    // The intro, then its finished art held for the reel's hold frames.
    readonly property int length: frames.length + introReel.hold
    readonly property string shown: frames.length > 0 ? frames[Math.min(frame, frames.length - 1)] : introReel.still

    spacing: 8

    Connections {
        target: introReel
        function onFramesChanged() { title.frame = 0; }
    }

    Timer {
        interval: Math.max(10, Math.round(1000 / introReel.fps))
        repeat: true
        running: title.running && title.visible && title.frames.length > 0
        onTriggered: {
            if (title.frame + 1 < title.length) {
                title.frame++;
                return;
            }
            // Finished: the next one when autoplaying (once it's ready),
            // otherwise this one again.
            title.frame = 0;
            if (title.autoplay && !introReel.loading)
                introReel.next();
        }
    }

    component Arrow: Rectangle {
        id: arrow
        property string glyph
        signal clicked()
        width: 30; height: 30; radius: 15
        color: arrowHover.hovered ? theme.hover : "transparent"
        border.color: arrowHover.hovered ? theme.accent : theme.border
        opacity: introReel.available ? 1 : 0.3
        Label {
            anchors.centerIn: parent
            text: arrow.glyph
            color: arrowHover.hovered ? theme.accent : theme.textMuted
            font.pixelSize: 18
        }
        HoverHandler { id: arrowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: introReel.available; onTapped: arrow.clicked() }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        spacing: 14

        Arrow {
            glyph: "‹"
            Layout.alignment: Qt.AlignVCenter
            onClicked: introReel.previous()
        }

        // Tall enough for the tallest frame seen, so the arrows don't jump.
        Item {
            id: stage
            Layout.fillWidth: true
            Layout.maximumWidth: art.naturalWidth * 1.4
            property real tallest: 0
            readonly property real fit: Math.min(1.4, width / Math.max(1, art.naturalWidth))
            implicitHeight: Math.max(60, tallest)
            onFitChanged: tallest = art.naturalHeight * fit

            AsciiView {
                id: art
                anchors.centerIn: parent
                html: title.shown
                color: theme.text
                fontFamily: "monospace"
                pixelSize: 14
                zoom: stage.fit
                onNaturalHeightChanged: stage.tallest = Math.max(stage.tallest, naturalHeight * stage.fit)
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: title.frame = 0 }
        }

        Arrow {
            glyph: "›"
            Layout.alignment: Qt.AlignVCenter
            onClicked: introReel.next()
        }
    }

    // Which intro this is, and autoplay.
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 10
        visible: introReel.available

        Label {
            text: (introReel.loading ? "building " : "") + introReel.effect
                  + "  " + (introReel.index + 1) + "/" + introReel.effects.length
            color: theme.textDim
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
        }
        Rectangle {
            id: autoButton
            implicitWidth: autoRow.implicitWidth + 20
            implicitHeight: 24
            radius: 12
            color: title.autoplay ? Qt.rgba(tone.r, tone.g, tone.b, 0.16) : autoHover.hovered ? theme.hover : "transparent"
            border.color: title.autoplay ? theme.accent : theme.border
            readonly property color tone: Qt.color(theme.accent)
            RowLayout {
                id: autoRow
                anchors.centerIn: parent
                spacing: 6
                Label {
                    text: title.autoplay ? "\u{f03e4}" : "\u{f040a}"
                    color: title.autoplay ? theme.accent : theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }
                Label {
                    text: title.autoplay ? "Autoplay on" : "Autoplay"
                    color: title.autoplay ? theme.accent : theme.textMuted
                    font.pixelSize: 11
                }
            }
            HoverHandler { id: autoHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: title.autoplay = !title.autoplay }
        }

        // The title's font, to try any of omascii's for fun. Only this title
        // changes: the boot splash and everything else keep theirs.
        Rectangle {
            id: fontButton
            objectName: "titleFontButton"
            readonly property color tone: Qt.color(theme.accent)
            implicitWidth: Math.min(260, fontRow.implicitWidth + 22)
            implicitHeight: 24
            radius: 12
            color: fontPopup.opened ? Qt.rgba(tone.r, tone.g, tone.b, 0.16) : fontHover.hovered ? theme.hover : "transparent"
            border.color: fontPopup.opened || introReel.customFont ? theme.accent : theme.border
            RowLayout {
                id: fontRow
                anchors.centerIn: parent
                width: Math.min(implicitWidth, fontButton.width - 22)
                spacing: 6
                Label {
                    text: "\u{f0b34}"
                    color: introReel.customFont ? theme.accent : theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }
                Label {
                    Layout.fillWidth: true
                    text: introReel.font
                    color: introReel.customFont ? theme.accent : theme.textMuted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Label {
                    text: "\u{f0140}"
                    color: theme.textMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    rotation: fontPopup.opened ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: 160 } }
                }
            }
            HoverHandler { id: fontHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: fontPopup.opened ? fontPopup.close() : fontPopup.open() }
            ToolTip.visible: fontHover.hovered && !fontPopup.opened
            ToolTip.delay: 400
            ToolTip.text: "Try the title in another font (only here)"
        }
    }

    // Remembered in OmaCraft's own window settings, nowhere else.
    Settings {
        id: saved
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/omacraft/window.ini"
        category: "title"
        property string font: ""
    }
    Component.onCompleted: if (saved.font !== "") introReel.setFont(saved.font)
    Connections {
        target: introReel
        function onFontChanged() { saved.font = introReel.customFont ? introReel.font : ""; }
    }

    function pickFont(name) {
        introReel.setFont(name);
        title.frame = 0;
    }

    Popup {
        id: fontPopup
        parent: fontButton
        x: Math.round((fontButton.width - width) / 2)
        y: fontButton.height + 6
        width: 340
        height: 400
        padding: 10
        // Never past the window's edges: above the button when there's
        // no room below it.
        margins: 10
        onAboutToShow: {
            const window = fontButton.Window.window;
            const bottom = fontButton.mapToItem(null, 0, fontButton.height).y;
            y = window && bottom + 6 + height + 10 > window.height ? -height - 6 : fontButton.height + 6;
        }
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        property string set: "all"
        readonly property var shown: {
            const needle = fontSearch.text.trim().toLowerCase();
            return introReel.fonts.filter(f => (set === "all" || f.set === set)
                && (needle === "" || f.name.toLowerCase().indexOf(needle) >= 0 || String(f.detail).toLowerCase().indexOf(needle) >= 0));
        }

        onOpened: {
            introReel.loadFonts();
            fontSearch.text = "";
            fontSearch.forceActiveFocus();
            const at = shown.findIndex(f => f.name === introReel.font);
            fontList.currentIndex = at;
            if (at >= 0) fontList.positionViewAtIndex(at, ListView.Center);
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
                NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 180; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 100 } }

        background: Rectangle {
            radius: 12
            color: theme.raised
            border.color: theme.border
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                SearchBox {
                    id: fontSearch
                    Layout.fillWidth: true
                    placeholderText: introReel.fonts.length > 0 ? "Search " + introReel.fonts.length + " fonts" : "Search fonts"
                    Keys.onDownPressed: fontList.incrementCurrentIndex()
                    Keys.onUpPressed: fontList.decrementCurrentIndex()
                    Keys.onReturnPressed: if (fontList.currentIndex >= 0) title.pickFont(fontPopup.shown[fontList.currentIndex].name)
                    Keys.onEnterPressed: if (fontList.currentIndex >= 0) title.pickFont(fontPopup.shown[fontList.currentIndex].name)
                    onTextChanged: fontList.currentIndex = fontPopup.shown.length > 0 ? 0 : -1
                }
                // A random one from what's listed.
                Rectangle {
                    id: dice
                    width: 30; height: 30; radius: 8
                    color: diceHover.hovered ? theme.hover : "transparent"
                    border.color: theme.border
                    Label {
                        id: diceGlyph
                        anchors.centerIn: parent
                        text: "\u{f076e}"
                        color: diceHover.hovered ? theme.accent : theme.textMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        RotationAnimation on rotation { id: roll; running: false; from: 0; to: 360; duration: 420; easing.type: Easing.OutBack }
                    }
                    HoverHandler { id: diceHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        enabled: fontPopup.shown.length > 0
                        onTapped: {
                            const at = Math.floor(Math.random() * fontPopup.shown.length);
                            fontList.currentIndex = at;
                            fontList.positionViewAtIndex(at, ListView.Center);
                            roll.restart();
                            title.pickFont(fontPopup.shown[at].name);
                        }
                    }
                    ToolTip.visible: diceHover.hovered
                    ToolTip.text: "Surprise me"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [{ id: "all", name: "All" }, { id: "FIGlet", name: "FIGlet" }, { id: "TheDraw", name: "TheDraw" }]
                    Chip {
                        required property var modelData
                        text: modelData.name
                        chosen: fontPopup.set === modelData.id
                        onClicked: fontPopup.set = modelData.id
                    }
                }
                Item { Layout.fillWidth: true }
                Label {
                    visible: introReel.customFont
                    text: "Default"
                    color: defaultHover.hovered ? theme.accent : theme.textMuted
                    font.pixelSize: 11
                    font.underline: defaultHover.hovered
                    HoverHandler { id: defaultHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: title.pickFont("") }
                }
            }

            ListView {
                id: fontList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: fontPopup.shown
                highlightMoveDuration: 0
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    id: fontItem
                    required property var modelData
                    required property int index
                    readonly property bool chosen: modelData.name === introReel.font
                    readonly property color tone: Qt.color(theme.accent)
                    width: ListView.view.width
                    height: 30
                    radius: 6
                    color: chosen ? Qt.rgba(tone.r, tone.g, tone.b, 0.16)
                         : fontList.currentIndex === index || itemHover.hovered ? theme.hover : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8
                        Label {
                            Layout.fillWidth: true
                            text: fontItem.modelData.name
                            color: fontItem.chosen ? theme.accent : theme.text
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Label {
                            text: fontItem.modelData.detail || fontItem.modelData.set
                            color: theme.textFaint
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.maximumWidth: 120
                        }
                        Label {
                            visible: fontItem.chosen && introReel.loading
                            text: "drawing…"
                            color: theme.accent
                            font.pixelSize: 10
                        }
                    }
                    HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            fontList.currentIndex = fontItem.index;
                            title.pickFont(fontItem.modelData.name);
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: fontList.count === 0
                    text: introReel.loadingFonts ? "Reading omascii's fonts…"
                        : introReel.fonts.length === 0 ? "omascii isn't installed" : "No font matches"
                    color: theme.textMuted
                }
            }
        }
    }
}
