import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import ".."

// The Wallhaven account behind the API key: its browsing filters and its
// collections, opened like a search. Wallhaven's API returns a key's
// collections but not the account name, and needs that name to list what is
// in one, so it is asked for once and checked against the key.
ColumnLayout {
  id: page

  property var hub
  property var store
  property var launcher

  spacing: Style.space(12)

  readonly property bool hasKey: !!page.store.cfg.apiKey
  readonly property string username: page.store.cfg.username || ""
  readonly property var acct: page.store.account.settings || {}
  readonly property var verified: page.store.account.verified

  function list(values) {
    return (values || []).filter(function(v) { return v !== "" }).join(", ")
  }

  // Load once the key (or a changed username) has been saved.
  property string loadedFor: ""
  function maybeLoad() {
    if (!page.visible || !page.hasKey || page.store.accountLoading) return
    var wanted = "key|" + page.username
    if (page.loadedFor === wanted) return
    page.loadedFor = wanted
    page.store.refreshAccount()
  }
  onVisibleChanged: maybeLoad()
  onHasKeyChanged: maybeLoad()
  onUsernameChanged: maybeLoad()

  PageHeader {
    Layout.fillWidth: true
    title: "My Wallhaven"
    subtitle: "The account your API key belongs to: its filters and your collections. Left-click a wallpaper to apply it, ♥ to favorite it, right-click for more."
    foreground: page.hub.fg
    fontFamily: page.hub.fontFamily

    Button {
      text: page.store.accountLoading ? "Loading…" : "Refresh"
      iconText: String.fromCodePoint(0xF0450)
      iconSpinning: page.store.accountLoading
      fontSize: Style.font.bodySmall
      foreground: page.hub.fg
      fontFamily: page.hub.fontFamily
      bordered: true
      enabled: page.hasKey
      onClicked: {
        page.store.refreshAccount()
        if (page.store.collectionId) page.store.openCollection(page.store.collectionId)
      }
    }
  }

  // ---------------------------------------------------------- credentials
  Rectangle {
    Layout.fillWidth: true
    implicitHeight: credentials.implicitHeight + Style.space(20)
    radius: Style.cornerRadius > 0 ? Style.space(8) : 0
    color: Util.alpha(page.hub.fg, 0.04)

    ColumnLayout {
      id: credentials
      anchors.fill: parent
      anchors.margins: Style.space(10)
      spacing: Style.space(8)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        Text {
          Layout.preferredWidth: Style.space(90)
          text: "API key"
          color: page.hub.dim
          font.family: page.hub.fontFamily
          font.pixelSize: Style.font.caption
        }
        TextField {
          Layout.preferredWidth: Style.space(300)
          password: true
          placeholderText: page.hasKey ? "Saved · type to replace, Enter to save" : "Paste it from wallhaven.cc/settings/account · Enter"
          foreground: page.hub.fg
          font.family: page.hub.fontFamily
          font.pixelSize: Style.font.caption
          onAccepted: {
            page.store.setOption("apiKey", text.trim())
            page.loadedFor = ""
            text = ""
          }
        }

        Item { Layout.preferredWidth: Style.space(12) }

        Text {
          text: "Username"
          color: page.hub.dim
          font.family: page.hub.fontFamily
          font.pixelSize: Style.font.caption
        }
        TextField {
          id: userField
          Layout.preferredWidth: Style.space(200)
          text: page.username
          placeholderText: "wallhaven.cc username · Enter"
          foreground: page.hub.fg
          font.family: page.hub.fontFamily
          font.pixelSize: Style.font.caption
          onAccepted: page.store.setOption("username", text.trim())
        }
        Text {
          visible: page.username !== "" && page.verified !== undefined && page.verified !== null
          text: page.verified ? "✓ matches your key" : "✗ that account doesn't own this key's collections"
          color: page.verified ? page.hub.accent : Commons.Color.urgent
          font.family: page.hub.fontFamily
          font.pixelSize: Style.font.caption
        }
        Item { Layout.fillWidth: true }
        Button {
          text: "Open on wallhaven.cc"
          iconText: String.fromCodePoint(0xF0337)
          fontSize: Style.font.caption
          foreground: page.hub.fg
          fontFamily: page.hub.fontFamily
          bordered: true
          onClicked: page.store.openUrl(page.username ? "https://wallhaven.cc/user/" + page.username + "/favorites"
                                                      : "https://wallhaven.cc/settings/account")
        }
      }

      // Account filters, as Wallhaven stores them.
      RowLayout {
        Layout.fillWidth: true
        visible: page.acct.purity !== undefined
        spacing: Style.space(8)

        Text {
          Layout.fillWidth: true
          wrapMode: Text.Wrap
          text: "Your filters:  " + page.list(page.acct.purity) + "  ·  " + page.list(page.acct.categories)
            + "  ·  toplist " + (page.acct.toplist_range || "—")
            + (page.list(page.acct.resolutions) ? "  ·  " + page.list(page.acct.resolutions) : "")
            + ((page.acct.tag_blacklist || []).length ? "  ·  " + page.acct.tag_blacklist.length + " blacklisted tags" : "")
          color: page.hub.dim
          font.family: page.hub.fontFamily
          font.pixelSize: Style.font.caption
        }
        Button {
          text: "Use for search"
          iconText: String.fromCodePoint(0xF0349)
          tooltipText: "Copy purity, categories, toplist range and the smallest resolution into Studio's Wallhaven search"
          fontSize: Style.font.caption
          foreground: page.hub.fg
          fontFamily: page.hub.fontFamily
          bordered: true
          onClicked: page.store.useAccountFilters()
        }
      }
    }
  }

  // ---------------------------------------------------------- collections
  Flow {
    Layout.fillWidth: true
    spacing: Style.space(8)
    visible: page.store.collections.length > 0

    Repeater {
      model: page.store.collections
      Button {
        required property var modelData
        text: (modelData.public ? "" : "🔒 ") + modelData.label + "  " + modelData.count
        iconText: String.fromCodePoint(0xF024B)
        fontSize: Style.font.bodySmall
        foreground: page.hub.fg
        fontFamily: page.hub.fontFamily
        bordered: true
        active: page.store.collectionId === modelData.id
        tooltipText: page.username ? "" : "Enter your username above to open collections"
        onClicked: page.store.openCollection(modelData.id)
      }
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: Style.space(160)

    Text {
      anchors.centerIn: parent
      width: parent.width * 0.8
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      visible: page.store.collectionResults.length === 0
      text: page.store.accountError !== "" ? "⚠  " + page.store.accountError
        : !page.hasKey ? "Add your Wallhaven API key above (wallhaven.cc › Settings › Account) to see your account here."
        : page.store.accountLoading ? "Loading your account…"
        : page.store.collectionLoading ? "Opening the collection…"
        : page.store.collections.length === 0 ? "This account has no collections yet."
        : !page.username ? "Wallhaven's API needs your username to list what's in a collection. Type it above and press Enter."
        : "Pick a collection above."
      color: page.store.accountError !== "" ? Commons.Color.urgent : page.hub.dim
      font.family: page.hub.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    GridView {
      id: collView
      anchors.fill: parent
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      cellWidth: width / page.hub.gridColumns(width)
      cellHeight: Math.round(cellWidth * 2 / 3)
      cacheBuffer: cellHeight
      model: page.visible ? page.store.collectionResults : []
      onContentYChanged: if (contentHeight > 0 && contentY + height >= contentHeight - cellHeight * 1.5) page.store.collectionLoadMore()

      delegate: Item {
        id: collCell
        required property var modelData
        width: collView.cellWidth
        height: collView.cellHeight

        WallpaperTile {
          id: collTile
          anchors.fill: parent
          anchors.margins: Style.space(3)
          source: collCell.modelData.thumb || ""
          caption: collCell.modelData.resolution + (collCell.modelData.favorites ? "  ♥ " + collCell.modelData.favorites : "")
          swatches: collCell.modelData.colors || []
          foreground: page.hub.fg
          fontFamily: page.hub.fontFamily
          busy: page.store.applying && page.store.busyTarget === collCell.modelData.full
          current: page.store.isCurrent(collCell.modelData.full)
          favorite: page.store.isFavorite(collCell.modelData.id)
          tooltip: "Left: apply · Right: menu"
          onActivated: page.store.apply(collCell.modelData.full)
          onFavoriteToggled: page.store.toggleFavorite(collCell.modelData.id, collCell.modelData)
          onSecondary: function(x, y) { page.hub.remoteMenu(collTile, x, y, collCell.modelData) }
        }
      }
    }
  }

  Text {
    Layout.fillWidth: true
    text: page.store.collectionResults.length === 0 ? ""
      : page.store.collectionResults.length + " of " + page.store.collectionTotal + " wallpapers"
        + (page.store.collectionMore ? " · loading more…" : "")
    color: page.hub.dim
    font.family: page.hub.fontFamily
    font.pixelSize: Style.font.caption
  }
}
