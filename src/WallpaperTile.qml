import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

// One wallpaper in a grid: its preview, a heart, and what's on it. A click
// sets it (with its colours unless they're off); right-click has the rest.
Rectangle {
    id: tile
    // target: what hyprskin applies (a Wallhaven id or a file).
    property string target
    property string thumb
    property string caption
    property string detail
    property string url
    property string file
    // Search results carry their Wallhaven data, which a favourite keeps.
    property var meta: ({})
    property bool inLibrary: false
    property bool missing: false
    property bool current: false

    signal deleteRequested(string path)

    readonly property bool favorite: wallpaper.favoriteKeys[favoriteKeyOf(target)] === true
    readonly property bool busy: wallpaper.busyTarget === target
    readonly property color tone: Qt.color(theme.accent)

    // Matches Wallpaper::favoriteKey for the cases a tile can hold.
    function favoriteKeyOf(t) {
        const name = String(t).substring(String(t).lastIndexOf("/") + 1);
        const m = name.match(/^wallhaven-([a-z0-9]+)\.\w+$/);
        if (m) return m[1];
        return t;
    }

    radius: 9
    color: theme.inset
    border.color: current ? theme.accent : hover.hovered ? theme.borderStrong : theme.border
    border.width: current ? 2 : 1
    clip: true

    Image {
        id: image
        anchors.fill: parent
        anchors.margins: tile.border.width
        source: tile.thumb === "" ? "" : tile.thumb.indexOf("://") > 0 ? tile.thumb : "file://" + tile.thumb
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: 360
        opacity: tile.missing ? 0.3 : 1
    }
    Label {
        anchors.centerIn: parent
        visible: image.status !== Image.Ready
        text: tile.missing ? "Missing" : image.status === Image.Error ? "No preview" : ""
        color: theme.textFaint
        font.pixelSize: 11
    }

    // Caption strip.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: tile.border.width
        height: 24
        color: "#cc0b0b0d"
        visible: hover.hovered || tile.current
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            Label {
                Layout.fillWidth: true
                text: tile.caption
                color: "white"
                font.pixelSize: 11
                elide: Text.ElideMiddle
            }
            Label { text: tile.detail; color: theme.textMuted; font.pixelSize: 10 }
        }
    }

    // Heart.
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        width: 26; height: 26; radius: 13
        color: "#aa0b0b0d"
        visible: tile.favorite || hover.hovered
        Label {
            anchors.centerIn: parent
            text: tile.favorite ? "♥" : "♡"
            color: tile.favorite ? theme.accent : "white"
            font.pixelSize: 14
        }
        TapHandler { onTapped: wallpaper.toggleFavorite(tile.target, tile.meta) }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    Rectangle {
        visible: tile.current
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 6
        width: nowLabel.implicitWidth + 12; height: 20; radius: 5
        color: theme.accent
        Label { id: nowLabel; anchors.centerIn: parent; text: "Now"; color: theme.accentForeground; font.pixelSize: 10; font.weight: Font.DemiBold }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: tile.busy
        visible: running
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        acceptedButtons: Qt.LeftButton
        enabled: !tile.missing
        onTapped: wallpaper.apply(tile.target, true)
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (eventPoint) => menu.popup()
    }

    Menu {
        id: menu
        MenuItem { text: "Set with its colours"; enabled: !tile.missing && !wallpaper.applying; onTriggered: wallpaper.apply(tile.target, true) }
        MenuItem { text: "Set, keep the current colours"; enabled: !tile.missing && !wallpaper.applying; onTriggered: wallpaper.apply(tile.target, false) }
        MenuSeparator {}
        MenuItem { text: tile.favorite ? "Remove from favourites" : "Add to favourites"; onTriggered: wallpaper.toggleFavorite(tile.target, tile.meta) }
        MenuItem { text: "Open on Wallhaven"; visible: tile.url !== ""; height: visible ? implicitHeight : 0; onTriggered: wallpaper.openUrl(tile.url) }
        MenuItem { text: "Show in files"; visible: tile.file !== ""; height: visible ? implicitHeight : 0; onTriggered: wallpaper.showInFiles(tile.file) }
        MenuSeparator { visible: tile.inLibrary; height: visible ? implicitHeight : 0 }
        MenuItem {
            text: "Delete from library…"
            visible: tile.inLibrary
            height: visible ? implicitHeight : 0
            Material.foreground: theme.danger
            onTriggered: tile.deleteRequested(tile.file)
        }
    }
}
