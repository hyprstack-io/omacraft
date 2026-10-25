import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".."

// Wallpapers already on this computer, from the folders you add here.
ColumnLayout {
  id: page

  property var hub
  property var store
  property var launcher

  spacing: Style.space(12)

  Connections {
    target: page.store
    function onLocalRestarted() { localView.positionViewAtBeginning() }
  }

  // Filter as you type, without a scan per keystroke.
  Timer {
    id: debounce
    interval: 300
    onTriggered: page.store.localSearch(1)
  }

  PageHeader {
    Layout.fillWidth: true
    title: "Local folders"
    subtitle: "Pictures from your own folders. Type to filter by file or folder name, or type a path such as ~/Wallpapers and press Enter to add it."
    foreground: page.hub.fg
    fontFamily: page.hub.fontFamily
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.space(8)

    TextField {
      id: localField
      Layout.fillWidth: true
      text: page.store.localQuery
      placeholderText: "Filter, or a path to add (~/Wallpapers) + Enter"
      foreground: page.hub.fg
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.bodySmall
      onTextEdited: {
        page.store.localQuery = text
        if (!/^[~\/]/.test(text)) debounce.restart()
      }
      onAccepted: {
        var t = text.trim()
        if (/^[~\/]/.test(t)) {
          page.store.folderAction("add", t)
          page.store.localQuery = ""
          text = ""
        } else {
          page.store.localSearch(1)
        }
      }
    }

    Dropdown {
      Layout.preferredWidth: Style.space(120)
      showLabel: false
      options: [
        { value: "newest", label: "Newest" }, { value: "oldest", label: "Oldest" },
        { value: "name", label: "Name" }, { value: "random", label: "Shuffle" }
      ]
      value: page.store.localSort
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      onChanged: function(v) {
        page.store.localSort = v
        page.store.setOption("local.sort", v)
        page.store.localSearch(1)
      }
    }

    Button {
      text: page.store.scanning ? "Scanning…" : "Rescan"
      iconText: String.fromCodePoint(0xF0450)
      tooltipText: "Look for new or removed images in your folders"
      fontSize: Style.font.bodySmall
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      bordered: true
      onClicked: page.store.localSearch(1, true)
    }
  }

  // Folder chips: click to show only that folder, right-click to remove it.
  Flow {
    Layout.fillWidth: true
    spacing: Style.space(6)

    Repeater {
      model: page.store.localFolders

      Button {
        required property string modelData
        text: String.fromCodePoint(0xF024B) + "  " + modelData
        tooltipText: "Click: show only this folder · Right-click: remove it"
        fontSize: Style.font.caption
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        bordered: true
        active: page.store.localQuery.trim() === modelData
        onClicked: {
          page.store.localQuery = page.store.localQuery.trim() === modelData ? "" : modelData
          localField.text = page.store.localQuery
          // A folder path in the filter matches everything inside it.
          page.store.localSearch(1)
        }
        onRightClicked: page.store.folderAction("remove", modelData)
      }
    }

    Button {
      text: "+ Add folder…"
      tooltipText: "Choose a folder with the file picker"
      fontSize: Style.font.caption
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      bordered: true
      onClicked: page.store.pickFolder()
    }

    Button {
      text: "Whole home folder"
      tooltipText: "Search every picture under ~ (hidden folders are skipped)"
      visible: page.store.localFolders.indexOf("~") === -1
      fontSize: Style.font.caption
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      bordered: true
      onClicked: page.store.folderAction("add", "~")
    }

    Button {
      text: Number(page.store.localCfg.minWidth) > 0 ? "Wallpaper-sized only" : "All image sizes"
      tooltipText: "Toggle hiding images narrower than 1280px (icons, thumbnails)"
      fontSize: Style.font.caption
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      bordered: true
      active: Number(page.store.localCfg.minWidth) > 0
      onClicked: {
        var next = Number(page.store.localCfg.minWidth) > 0 ? 0 : 1280
        if (page.store.cfg.local) page.store.cfg.local.minWidth = next
        page.store.setOption("local.minWidth", next)
        page.store.localSearch(1)
      }
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: Style.space(160)

    Text {
      anchors.centerIn: parent
      visible: page.store.localResults.length === 0
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      text: page.store.scanning ? "Scanning your folders…"
        : (page.store.localFolders.length === 0 ? "Add a folder to browse your own wallpapers"
          : (page.store.localSearched ? "No images matched" : ""))
      color: page.hub.dim
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    GridView {
      id: localView
      anchors.fill: parent
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      cellWidth: width / page.hub.gridColumns(width)
      cellHeight: Math.round(cellWidth * 2 / 3)
      cacheBuffer: cellHeight
      model: page.store.localResults
      onAtYEndChanged: if (atYEnd) page.store.localLoadMore()

      delegate: Item {
        id: localCell
        required property var modelData
        width: localView.cellWidth
        height: localView.cellHeight

        WallpaperTile {
          id: localTile
          anchors.fill: parent
          anchors.margins: Style.space(3)
          source: localCell.modelData.thumb || ""
          caption: localCell.modelData.resolution + "  " + localCell.modelData.dir + "/" + localCell.modelData.name
          foreground: page.hub.fg
          fontFamily: page.hub.fontFamily
          busy: page.store.applying && page.store.busyTarget === localCell.modelData.path
          current: page.store.isCurrent(localCell.modelData.path, localCell.modelData.name)
          favorite: page.store.isFavorite(localCell.modelData.path)
          tooltip: "Left: apply · Right: menu"
          onActivated: page.store.apply(localCell.modelData.path)
          onFavoriteToggled: page.store.toggleFavorite(localCell.modelData.path, null)
          onSecondary: function(x, y) { page.hub.localMenu(localTile, x, y, localCell.modelData.path, false) }
        }
      }
    }
  }

  Text {
    Layout.fillWidth: true
    text: page.store.localResults.length === 0 ? ""
      : page.store.localResults.length.toLocaleString() + " of " + page.store.localTotal.toLocaleString() + " images"
        + (page.store.localMore ? " · loading more…" : "")
    color: page.hub.dim
    font.family: page.hub.fontFamily
    font.pixelSize: Style.font.caption
  }
}
