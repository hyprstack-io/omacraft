import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".."

// Wallpapers downloaded from Wallhaven (~/Pictures/Wallhaven by default).
ColumnLayout {
  id: page

  property var hub
  property var store
  property var launcher

  spacing: Style.space(12)

  PageHeader {
    Layout.fillWidth: true
    title: "Library"
    subtitle: "Every Wallhaven wallpaper you have applied is kept here. Left-click to apply; right-click for favorites, apply without recoloring, or delete."
    foreground: page.hub.fg
    fontFamily: page.hub.fontFamily

    Button {
      text: "Shuffle from library"
      iconText: String.fromCodePoint(0xF049D)
      tooltipText: "Apply a random wallpaper from the library"
      fontSize: Style.font.bodySmall
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      bordered: true
      enabled: page.store.library.length > 0
      onClicked: {
        var lib = page.store.library
        if (lib.length) page.store.apply(lib[Math.floor(Math.random() * lib.length)].path)
      }
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: Style.space(160)

    Text {
      anchors.centerIn: parent
      visible: page.store.library.length === 0
      text: "Nothing downloaded yet. Wallpapers you apply from Wallhaven are kept in ~/Pictures/Wallhaven."
      color: page.hub.dim
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    // Virtualized: only tiles near the viewport decode a file.
    GridView {
      id: libView
      anchors.fill: parent
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      cellWidth: width / page.hub.gridColumns(width)
      cellHeight: Math.round(cellWidth * 2 / 3)
      cacheBuffer: cellHeight
      model: page.visible ? page.store.library : []

      delegate: Item {
        id: libCell
        required property var modelData
        width: libView.cellWidth
        height: libView.cellHeight

        WallpaperTile {
          id: libTile
          anchors.fill: parent
          anchors.margins: Style.space(3)
          source: libCell.modelData.path
          local: true
          caption: libCell.modelData.name
          foreground: page.hub.fg
          fontFamily: page.hub.fontFamily
          busy: page.store.applying && page.store.busyTarget === libCell.modelData.path
          current: page.store.isCurrent(libCell.modelData.path, libCell.modelData.name)
          favorite: page.store.isFavorite(libCell.modelData.path)
          tooltip: "Left: apply · Right: menu"
          onActivated: page.store.apply(libCell.modelData.path)
          onFavoriteToggled: page.store.toggleFavorite(libCell.modelData.path, null)
          onSecondary: function(x, y) { page.hub.localMenu(libTile, x, y, libCell.modelData.path, true) }
        }
      }
    }
  }

  Text {
    Layout.fillWidth: true
    text: page.store.library.length + " wallpapers · ♥ to favorite · right-click for more, including delete"
    color: page.hub.dim
    font.family: page.hub.fontFamily
    font.pixelSize: Style.font.caption
  }
}
