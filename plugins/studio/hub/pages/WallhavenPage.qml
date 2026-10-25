import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".."

// Search Wallhaven. Pages of 24 keep loading in the background (within the
// rate limit) while this page is open; left-click applies, right-click
// applies without recoloring the desktop.
ColumnLayout {
  id: page

  property var hub
  property var store
  property var launcher

  spacing: Style.space(12)

  function focusSearch() { queryField.forceActiveFocus() }

  Connections {
    target: page.store
    function onSearchRestarted() { resultsView.positionViewAtBeginning() }
  }

  PageHeader {
    Layout.fillWidth: true
    title: "Wallhaven"
    subtitle: "Search tags, @user, id:123 or like:abc123. Left-click a wallpaper to apply it, ♥ to favorite it, right-click for more."
    foreground: page.hub.fg
    fontFamily: page.hub.fontFamily
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.space(8)

    TextField {
      id: queryField
      Layout.fillWidth: true
      text: page.store.query
      placeholderText: "Search Wallhaven…  ( / to focus )"
      foreground: page.hub.fg
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.bodySmall
      onTextEdited: page.store.query = text
      onAccepted: page.store.search(1)
    }

    Button {
      text: page.store.searching ? "Searching…" : "Search"
      iconText: String.fromCodePoint(0xF0349)
      fontSize: Style.font.bodySmall
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      bordered: true
      active: true
      onClicked: page.store.search(1)
    }
  }

  // Filters
  Flow {
    Layout.fillWidth: true
    spacing: Style.space(8)

    Dropdown {
      width: Style.space(150)
      showLabel: false
      options: [
        { value: "toplist", label: "Top list" },
        { value: "hot", label: "Hot" },
        { value: "date_added", label: "Latest" },
        { value: "random", label: "Random" },
        { value: "views", label: "Most viewed" },
        { value: "favorites", label: "Favorites" },
        { value: "relevance", label: "Relevance" }
      ]
      value: page.store.sorting
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      onChanged: function(v) { page.store.sorting = v; page.store.search(1) }
    }

    Dropdown {
      width: Style.space(120)
      showLabel: false
      visible: page.store.sorting === "toplist"
      options: [
        { value: "1d", label: "Today" }, { value: "3d", label: "3 days" },
        { value: "1w", label: "Week" }, { value: "1M", label: "Month" },
        { value: "3M", label: "3 months" }, { value: "6M", label: "6 months" },
        { value: "1y", label: "Year" }
      ]
      value: page.store.topRange
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      onChanged: function(v) { page.store.topRange = v; page.store.search(1) }
    }

    Dropdown {
      width: Style.space(130)
      showLabel: false
      options: [
        { value: "", label: "Any size" }, { value: "1920x1080", label: "≥ 1080p" },
        { value: "2560x1440", label: "≥ 1440p" }, { value: "3440x1440", label: "≥ UW 1440" },
        { value: "3840x2160", label: "≥ 4K" }
      ]
      value: page.store.atleast
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      onChanged: function(v) { page.store.atleast = v; page.store.search(1) }
    }

    Dropdown {
      width: Style.space(130)
      showLabel: false
      options: [
        { value: "", label: "Any ratio" }, { value: "16x9", label: "16:9" },
        { value: "16x10", label: "16:10" }, { value: "21x9", label: "21:9" },
        { value: "32x9", label: "32:9" }, { value: "landscape", label: "Landscape" },
        { value: "portrait", label: "Portrait" }
      ]
      value: page.store.ratios
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      onChanged: function(v) { page.store.ratios = v; page.store.search(1) }
    }

    Item { width: Style.space(6); height: 1 }

    Repeater {
      model: [
        { kind: "categories", index: 0, label: "General" },
        { kind: "categories", index: 1, label: "Anime" },
        { kind: "categories", index: 2, label: "People" },
        { kind: "purity", index: 0, label: "SFW" },
        { kind: "purity", index: 1, label: "Sketchy" },
        { kind: "purity", index: 2, label: "NSFW" }
      ]

      Button {
        required property var modelData
        text: modelData.label
        fontSize: Style.font.caption
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        bordered: true
        active: String(page.store[modelData.kind]).charAt(modelData.index) === "1"
        tooltipText: modelData.label === "NSFW" ? "Needs a Wallhaven API key (below)" : ""
        onClicked: {
          page.store[modelData.kind] = page.store.toggleBit(page.store[modelData.kind], modelData.index)
          if (page.store.searched) page.store.search(1)
        }
      }
    }
  }

  // Results
  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: Style.space(160)

    Text {
      anchors.centerIn: parent
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      visible: page.store.results.length === 0
      text: page.store.searching ? "Searching Wallhaven…"
        : (page.store.searched ? "No wallpapers matched" : "Press Enter to search, or just hit Search for the top list")
      color: page.hub.dim
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    GridView {
      id: resultsView
      anchors.fill: parent
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      cellWidth: width / page.hub.gridColumns(width)
      cellHeight: Math.round(cellWidth * 2 / 3)
      // One row above and below the viewport stays built for smooth scrolling.
      cacheBuffer: cellHeight
      model: page.store.results
      onContentYChanged: if (contentHeight > 0 && contentY + height >= contentHeight - cellHeight * 1.5) page.store.loadMore()

      delegate: Item {
        id: cell
        required property var modelData
        width: resultsView.cellWidth
        height: resultsView.cellHeight

        WallpaperTile {
          id: resultTile
          anchors.fill: parent
          anchors.margins: Style.space(3)
          source: cell.modelData.thumb || ""
          caption: cell.modelData.resolution + (cell.modelData.favorites ? "  ♥ " + cell.modelData.favorites : "")
          swatches: cell.modelData.colors || []
          foreground: page.hub.fg
          fontFamily: page.hub.fontFamily
          busy: page.store.applying && page.store.busyTarget === cell.modelData.full
          current: page.store.isCurrent(cell.modelData.full)
          favorite: page.store.isFavorite(cell.modelData.id)
          tooltip: "Left: apply · Right: menu"
          onActivated: page.store.apply(cell.modelData.full)
          onFavoriteToggled: page.store.toggleFavorite(cell.modelData.id, cell.modelData)
          onSecondary: function(x, y) { page.hub.remoteMenu(resultTile, x, y, cell.modelData) }
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.space(10)

    Text {
      Layout.fillWidth: true
      text: page.store.results.length === 0 ? ""
        : page.store.results.length.toLocaleString() + " of " + page.store.total.toLocaleString() + " wallpapers"
          + (page.store.moreAvailable ? " · loading more…"
            : (page.store.pageNumber >= page.store.lastPage ? " · end of results" : " · showing the first " + page.store.maxPages + " pages"))
      color: page.hub.dim
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      text: "API key"
      color: page.hub.dim
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.caption
    }
    TextField {
      id: apiKeyField
      Layout.preferredWidth: Style.space(300)
      password: true
      placeholderText: page.store.cfg.apiKey ? "Saved · type to replace, Enter to save" : "Optional, needed for NSFW · Enter to save"
      foreground: page.hub.fg
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.caption
      onAccepted: {
        page.store.setOption("apiKey", text.trim())
        text = ""
      }
    }
  }
}
