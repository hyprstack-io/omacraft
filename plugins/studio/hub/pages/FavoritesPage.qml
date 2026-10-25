import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".."

// Wallpapers you hearted anywhere in Studio: Wallhaven results, collection
// entries, library files and local pictures. Studio keeps the list itself
// (~/.local/share/hyprskin/favorites.json); Wallhaven's API cannot write to
// your account's collections.
ColumnLayout {
  id: page

  property var hub
  property var store
  property var launcher

  spacing: Style.space(12)

  PageHeader {
    Layout.fillWidth: true
    title: "Favorites"
    subtitle: "Click ♥ on any wallpaper to keep it here. Left-click to apply, right-click for more. Auto-change can rotate through these."
    foreground: page.hub.fg
    fontFamily: page.hub.fontFamily

    Button {
      text: "Shuffle favorites"
      iconText: String.fromCodePoint(0xF049D)
      tooltipText: "Apply a random favorite"
      fontSize: Style.font.bodySmall
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      bordered: true
      enabled: page.store.favorites.length > 0
      onClicked: {
        var usable = page.store.favorites.filter(function(f) { return !f.missing })
        if (usable.length) page.store.apply(usable[Math.floor(Math.random() * usable.length)].target)
      }
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: Style.space(160)

    Text {
      anchors.centerIn: parent
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      visible: page.store.favorites.length === 0
      text: "No favorites yet. Hover a wallpaper on any page and click ♡, or right-click › Add to favorites."
      color: page.hub.dim
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    GridView {
      id: favView
      anchors.fill: parent
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      cellWidth: width / page.hub.gridColumns(width)
      cellHeight: Math.round(cellWidth * 2 / 3)
      cacheBuffer: cellHeight
      model: page.visible ? page.store.favorites : []

      delegate: Item {
        id: favCell
        required property var modelData
        readonly property bool remote: !!favCell.modelData.id
        width: favView.cellWidth
        height: favView.cellHeight

        WallpaperTile {
          id: favTile
          anchors.fill: parent
          anchors.margins: Style.space(3)
          source: favCell.modelData.thumb || ""
          local: !!favCell.modelData.local
          caption: (favCell.modelData.missing ? "missing · " : "")
            + (favCell.remote ? "wallhaven " + favCell.modelData.id + (favCell.modelData.resolution ? "  " + favCell.modelData.resolution : "")
                              : page.store.basename(favCell.modelData.target))
          swatches: favCell.modelData.colors || []
          foreground: page.hub.fg
          fontFamily: page.hub.fontFamily
          favorite: true
          busy: page.store.applying && page.store.busyTarget === favCell.modelData.target
          current: page.store.favoriteKey(page.store.status.current) === favCell.modelData.key
          tooltip: "Left: apply · Right: menu"
          onActivated: if (!favCell.modelData.missing) page.store.apply(favCell.modelData.target)
          onFavoriteToggled: page.store.toggleFavorite(favCell.modelData.key, null)
          onSecondary: function(x, y) {
            var d = favCell.modelData
            var entries = [
              { label: "Apply", glyph: String.fromCodePoint(0xF0E09), action: function() { page.store.apply(d.target) } },
              { label: "Apply without recoloring", glyph: "◐", action: function() { page.store.apply(d.target, ["--no-theme"]) } },
              { label: "Remove from favorites", glyph: "♡", action: function() { page.store.toggleFavorite(d.key, null) } }
            ]
            if (d.url) entries.push({ label: "Open on wallhaven.cc", glyph: String.fromCodePoint(0xF0337),
                                      action: function() { page.store.openUrl(d.url) } })
            page.hub.openMenu(favTile, x, y, entries)
          }
        }
      }
    }
  }

  Text {
    Layout.fillWidth: true
    text: page.store.favorites.length + " favorites · Wallhaven favorites download when you first apply them"
    color: page.hub.dim
    font.family: page.hub.fontFamily
    font.pixelSize: Style.font.caption
  }
}
