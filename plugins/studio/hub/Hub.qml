import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../LauncherStyles.js" as Styles
import "../bar"
import "pages"

// The Studio window: a centered card with grouped pages in a sidebar.
//
//   Overview
//   WALLPAPERS  Wallhaven · Local folders · Library · Favorites · My Wallhaven · Auto-change
//   LOOK        Transitions · Animations · Colors · Apply to
//   LAUNCHER    Layout · Colors
//   BAR         Modules · Layout · Themes · Studio   (the omabar16 customizer)
Item {
  id: hub

  property var launcher: null
  property bool opened: false
  property string page: "overview"

  signal closeRequested()
  signal previewLauncherRequested()
  // Something outside the window (bar customizer scripting) wants a page shown.
  signal openPageRequested(string page)

  // Theme tokens shared by every page.
  readonly property color fg: Commons.Color.menu.text
  readonly property color dim: Util.alpha(Commons.Color.menu.text, 0.6)
  readonly property color accent: Commons.Color.accent
  readonly property string fontFamily: Style.font.menuFamily

  readonly property var pages: [
    { id: "overview", label: "Overview", group: "", glyph: "◈",
      description: "Current wallpaper, palette and launcher style" },
    { id: "wallhaven", label: "Wallhaven", group: "Wallpapers", glyph: String.fromCodePoint(0xF0349),
      description: "Search and apply wallpapers from wallhaven.cc" },
    { id: "local", label: "Local folders", group: "Wallpapers", glyph: String.fromCodePoint(0xF024B),
      description: "Wallpapers from folders on this computer" },
    { id: "library", label: "Library", group: "Wallpapers", glyph: String.fromCodePoint(0xF0E09),
      description: "Wallpapers you downloaded from Wallhaven" },
    { id: "favorites", label: "Favorites", group: "Wallpapers", glyph: "♥",
      description: "Wallpapers you hearted, from anywhere in Studio" },
    { id: "account", label: "My Wallhaven", group: "Wallpapers", glyph: String.fromCodePoint(0xF0004),
      description: "Your Wallhaven account and collections, from your API key" },
    { id: "autochange", label: "Auto-change", group: "Wallpapers", glyph: "⏱",
      description: "Change the wallpaper on a timer" },
    { id: "transitions", label: "Transitions", group: "Look", glyph: "◐",
      description: "How wallpapers animate in, and how they fill the screen" },
    { id: "animations", label: "Animations", group: "Look", glyph: "≋",
      description: "Hyprland presets for windows, workspaces and fades" },
    { id: "colors", label: "Colors", group: "Look", glyph: String.fromCodePoint(0xF03D8),
      description: "Theme the whole desktop from the wallpaper" },
    { id: "targets", label: "Apply to", group: "Look", glyph: "◧",
      description: "Pick which parts follow the wallpaper's colors" },
    { id: "launcher-layout", label: "Layout", group: "Launcher", glyph: "",
      description: "Nineteen layouts: drawers, palettes, grids, docks and strips" },
    { id: "launcher-colors", label: "Colors", group: "Launcher", glyph: "◑",
      description: "Follow the theme, or a fixed rofi-style scheme" },
    { id: "bar-modules", label: "Modules", group: "Bar", glyph: "▤",
      description: "Drag widgets between the bar's left, center and right" },
    { id: "bar-layout", label: "Layout", group: "Bar", glyph: "▭",
      description: "Edge, float, padding and thirty-plus preset arrangements" },
    { id: "bar-themes", label: "Themes", group: "Bar", glyph: "◆",
      description: "Preset, JaKooLit and base16 looks, and your own" },
    { id: "bar-studio", label: "Studio", group: "Bar", glyph: "✎",
      description: "Color any part of the bar, tune its shape, save a theme" }
  ]

  readonly property var currentPage: {
    for (var i = 0; i < pages.length; i++) if (pages[i].id === page) return pages[i]
    return pages[0]
  }

  function pageIds() {
    return pages.map(function(p) { return p.id })
  }

  function go(id) {
    if (pageIds().indexOf(String(id)) !== -1) hub.page = String(id)
  }

  function step(delta) {
    var ids = pageIds()
    var i = ids.indexOf(hub.page)
    hub.page = ids[(i + delta + ids.length) % ids.length]
  }

  // Aliases so people can type what they think of.
  function resolvePage(id) {
    var aliases = {
      "": "", "search": "wallhaven", "wallpapers": "wallhaven", "settings": "transitions",
      "rotation": "autochange", "favourites": "favorites", "hearts": "favorites",
      "me": "account", "collections": "account", "user": "account", "anims": "animations", "motion": "animations",
      "apply": "targets", "parts": "targets", "accent": "colors", "launcher": "launcher-layout", "layout": "launcher-layout",
      "scheme": "launcher-colors", "schemes": "launcher-colors",
      "bar": "bar-modules", "customizer": "bar-modules", "omabar16": "bar-modules",
      "modules": "bar-modules", "themes": "bar-themes", "studio": "bar-studio"
    }
    var key = String(id || "")
    return aliases[key] !== undefined ? aliases[key] : key
  }

  function show(id) {
    var target = resolvePage(id)
    if (target) go(target)
    hub.opened = true
  }

  function hide() {
    hub.opened = false
  }

  readonly property bool onBarPage: hub.page.indexOf("bar-") === 0

  // The bar customizer reads shell.json once per session: the first time a
  // Bar page shows after Studio opens. Revert goes back to that moment.
  function syncBarSession() {
    if (!hub.opened) { if (barCtl.opened) barCtl.close(); return }
    if (!hub.onBarPage) return
    var tab = hub.page.substr(4)
    if (!barCtl.opened) barCtl.open(JSON.stringify({ tab: tab }))
    else barCtl.setTab(tab)
  }
  onPageChanged: { syncBarSession(); tileMenu.close() }
  onOpenedChanged: syncBarSession()

  BarCustomizer {
    id: barCtl
    onPageRequested: function(tab) { hub.openPageRequested("bar-" + tab) }
  }

  // ------------------------------------------------------- tile menus

  function openMenu(source, x, y, entries) {
    tileMenu.open(source, x, y, entries)
  }

  function favoriteEntry(target, meta) {
    var on = store.isFavorite(target)
    return { label: on ? "Remove from favorites" : "Add to favorites", glyph: on ? "♡" : "♥",
             action: function() { store.toggleFavorite(target, meta) } }
  }

  // A Wallhaven search or collection result.
  function remoteMenu(source, x, y, r) {
    openMenu(source, x, y, [
      { label: "Apply", glyph: String.fromCodePoint(0xF0E09), action: function() { store.apply(r.full) } },
      { label: "Apply without recoloring", glyph: "◐", action: function() { store.apply(r.full, ["--no-theme"]) } },
      favoriteEntry(r.id, r),
      { label: "Open on wallhaven.cc", glyph: String.fromCodePoint(0xF0337), action: function() { store.openUrl(r.url) } }
    ])
  }

  // A file on disk; library files can also be deleted.
  function localMenu(source, x, y, path, inLibrary) {
    var entries = [
      { label: "Apply", glyph: String.fromCodePoint(0xF0E09), action: function() { store.apply(path) } },
      { label: "Apply without recoloring", glyph: "◐", action: function() { store.apply(path, ["--no-theme"]) } },
      favoriteEntry(path, null)
    ]
    if (inLibrary) entries.push({ label: "Delete from library", glyph: String.fromCodePoint(0xF01B4), danger: true,
                                  confirm: "Click again to delete the file",
                                  action: function() { store.deleteFromLibrary(path) } })
    openMenu(source, x, y, entries)
  }

  // Columns for the wallpaper grids: about 230px per tile.
  function gridColumns(width) {
    return Math.max(2, Math.round(width / Style.space(230)))
  }

  // A launcher scheme as plain colors; "omarchy" follows the live theme.
  function schemeColors(id) {
    var s = Styles.scheme(id)
    if (s.id !== "omarchy") return s
    return {
      bg: String(Commons.Color.menu.background), alt: String(Qt.lighter(Commons.Color.menu.background, 1.35)),
      fg: String(Commons.Color.menu.text), sel: String(Commons.Color.accent),
      active: String(Commons.Color.accent), urgent: String(Commons.Color.urgent)
    }
  }

  WallpaperStore {
    id: store
    active: hub.opened
    page: hub.page
  }

  OverlayWindow {
    id: window
    shown: hub.opened
    WlrLayershell.namespace: "skll-studio"

    Shortcut { sequence: "Escape"; enabled: !tileMenu.shown; onActivated: hub.closeRequested() }
    Shortcut { sequence: "Ctrl+Tab"; onActivated: hub.step(1) }
    Shortcut { sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab"]; onActivated: hub.step(-1) }
    Shortcut { sequence: "Ctrl+F"; onActivated: { hub.go("wallhaven"); wallhavenPage.focusSearch() } }
    Shortcut { sequence: "Ctrl+N"; onActivated: store.runAction(["next"]) }
    Shortcut { sequence: "Ctrl+R"; onActivated: store.runAction(["theme"]) }
    Shortcut { sequence: "Ctrl+Z"; enabled: hub.onBarPage; onActivated: barCtl.undo() }
    Shortcut { sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]; enabled: hub.onBarPage; onActivated: barCtl.redo() }
    Repeater {
      model: Math.min(10, hub.pages.length)
      Item {
        required property int index
        Shortcut {
          sequence: "Ctrl+" + ((parent.index + 1) % 10)
          onActivated: hub.page = hub.pages[parent.index].id
        }
      }
    }

    // Scrim: click outside the card to close.
    Rectangle {
      anchors.fill: parent
      color: Util.alpha("#000000", 0.4)
      MouseArea { anchors.fill: parent; onClicked: hub.closeRequested() }
    }

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: Math.min(Style.space(1280), window.width - Style.space(80))
      height: Math.min(Style.space(860), window.height - Style.space(80))
      radius: Style.cornerRadius > 0 ? Style.space(12) : 0
      color: Util.alpha(Commons.Color.menu.background, 1)
      border.width: Math.max(1, Style.space(2))
      border.color: Commons.Color.menu.border
      clip: true

      // Swallow clicks so they do not reach the scrim.
      MouseArea { anchors.fill: parent }

      // ------------------------------------------------------------ sidebar
      Rectangle {
        id: sidebar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: card.border.width
        width: Style.space(232)
        color: Util.alpha(hub.fg, 0.035)

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.space(12)
          spacing: Style.space(2)

          // Brand
          RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Style.space(12)
            Layout.leftMargin: Style.space(6)
            spacing: Style.space(10)

            Rectangle {
              Layout.preferredWidth: Style.space(36)
              Layout.preferredHeight: Style.space(36)
              radius: Style.cornerRadius > 0 ? Style.space(9) : 0
              color: Util.alpha(hub.accent, 0.18)
              Text {
                anchors.centerIn: parent
                text: String.fromCodePoint(0xF03D8)
                color: hub.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.title + 4
              }
            }
            Column {
              Layout.fillWidth: true
              Text {
                text: "Studio"
                color: hub.fg
                font.family: hub.fontFamily
                font.pixelSize: Style.font.title + 2
                font.bold: true
              }
              Text {
                text: "Make the desktop yours"
                color: hub.dim
                font.family: hub.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: navColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

          Column {
            id: navColumn
            width: parent.width

          Repeater {
            model: hub.pages

            Column {
              id: navEntry
              required property var modelData
              required property int index
              readonly property bool startsGroup: modelData.group !== ""
                && (index === 0 || hub.pages[index - 1].group !== modelData.group)
              width: navColumn.width
              spacing: 0

              Text {
                visible: navEntry.startsGroup
                topPadding: Style.space(12)
                bottomPadding: Style.space(4)
                leftPadding: Style.space(14)
                text: navEntry.modelData.group.toUpperCase()
                color: Util.alpha(hub.fg, 0.45)
                font.family: hub.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.5
              }

              NavItem {
                width: navEntry.width
                glyph: navEntry.modelData.glyph
                label: navEntry.modelData.label
                hint: navEntry.index < 10 ? "^" + ((navEntry.index + 1) % 10) : ""
                current: hub.page === navEntry.modelData.id
                foreground: hub.fg
                accent: hub.accent
                fontFamily: hub.fontFamily
                onClicked: hub.page = navEntry.modelData.id
              }
            }
          }
          }
          }

          // Wallpaper strip: what is on the desktop right now.
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(54)
            radius: Style.cornerRadius > 0 ? Style.space(8) : 0
            color: Util.alpha(hub.fg, 0.05)

            Row {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Column {
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)
                Text {
                  width: parent.width
                  text: store.applying ? "Applying…" : (store.basename(store.status.current) || "No wallpaper")
                  elide: Text.ElideMiddle
                  color: hub.fg
                  font.family: hub.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Row {
                  spacing: 2
                  Repeater {
                    model: store.swatchKeys
                    Rectangle {
                      required property string modelData
                      width: Style.space(14)
                      height: Style.space(10)
                      color: store.colors[modelData] || "transparent"
                    }
                  }
                }
              }
            }
          }
        }
      }

      Rectangle {
        anchors.left: sidebar.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Util.alpha(hub.fg, 0.1)
      }

      // ------------------------------------------------------------ content
      Item {
        id: content
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.leftMargin: Style.space(24)
        anchors.rightMargin: Style.space(24)
        anchors.topMargin: Style.space(14)

        // Top bar: breadcrumb, quick actions, close.
        RowLayout {
          id: topBar
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: Style.space(8)

          Text {
            Layout.fillWidth: true
            text: (hub.currentPage.group ? hub.currentPage.group + "  ›  " : "") + hub.currentPage.label
            color: hub.dim
            font.family: hub.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }

          Button {
            text: "Next wallpaper"
            iconText: String.fromCodePoint(0xF0F27)
            tooltipText: "Random wallpaper from the auto-change source (Ctrl+N)"
            fontSize: Style.font.caption
            foreground: hub.fg
            fontFamily: hub.fontFamily
            bordered: true
            iconSpinning: store.applying && store.busyTarget === "next"
            onClicked: store.runAction(["next"])
          }
          Button {
            text: "Recolor"
            iconText: String.fromCodePoint(0xF03D8)
            tooltipText: "Build and apply a theme from the current wallpaper (Ctrl+R)"
            fontSize: Style.font.caption
            foreground: hub.fg
            fontFamily: hub.fontFamily
            bordered: true
            iconSpinning: store.applying && store.busyTarget === "theme"
            onClicked: store.runAction(["theme"])
          }
          Button {
            iconText: "✕"
            tooltipText: "Close (Esc)"
            fontSize: Style.font.caption
            foreground: hub.fg
            fontFamily: hub.fontFamily
            bordered: true
            onClicked: hub.closeRequested()
          }
        }

        StackLayout {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: topBar.bottom
          anchors.bottom: parent.bottom
          anchors.topMargin: Style.space(14)
          currentIndex: hub.pageIds().indexOf(hub.page)

          OverviewPage { hub: hub; store: store; launcher: hub.launcher }
          WallhavenPage { id: wallhavenPage; hub: hub; store: store; launcher: hub.launcher }
          LocalPage { hub: hub; store: store; launcher: hub.launcher }
          LibraryPage { hub: hub; store: store; launcher: hub.launcher }
          FavoritesPage { hub: hub; store: store; launcher: hub.launcher }
          AccountPage { hub: hub; store: store; launcher: hub.launcher }
          AutoChangePage { hub: hub; store: store; launcher: hub.launcher }
          TransitionsPage { hub: hub; store: store; launcher: hub.launcher }
          AnimationsPage { hub: hub; store: store; launcher: hub.launcher }
          ColorsPage { hub: hub; store: store; launcher: hub.launcher }
          TargetsPage { hub: hub; store: store; launcher: hub.launcher }
          LauncherLayoutPage { hub: hub; store: store; launcher: hub.launcher }
          LauncherColorsPage { hub: hub; store: store; launcher: hub.launcher }
          BarPage { hub: hub; store: store; launcher: hub.launcher; ctl: barCtl; kind: "modules" }
          BarPage { hub: hub; store: store; launcher: hub.launcher; ctl: barCtl; kind: "layout" }
          BarPage { hub: hub; store: store; launcher: hub.launcher; ctl: barCtl; kind: "themes" }
          BarPage { hub: hub; store: store; launcher: hub.launcher; ctl: barCtl; kind: "studio" }
        }
      }

      // ------------------------------------------------------------ footer
      TileMenu {
        id: tileMenu
        anchors.fill: parent
        z: 100
        foreground: hub.fg
        background: Util.alpha(Commons.Color.menu.background, 1)
        accent: hub.accent
        fontFamily: hub.fontFamily
      }

      Rectangle {
        id: footer
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: card.border.width
        height: Style.space(34)
        color: store.error !== "" ? Util.alpha(Commons.Color.urgent, 0.14) : "transparent"

        Rectangle {
          anchors.top: parent.top
          width: parent.width
          height: 1
          color: Util.alpha(hub.fg, 0.08)
        }

        Text {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: Style.space(24)
          anchors.rightMargin: Style.space(24)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          elide: Text.ElideRight
          text: store.error !== "" ? "⚠  " + store.error
            : (hub.onBarPage
              ? "Esc close   ·   Ctrl+Z undo   ·   Ctrl+Shift+Z redo   ·   drag chips between lanes   ·   right-click a chip to remove it   ·   Ctrl+Tab next page"
              : "Esc close   ·   Ctrl+Tab next page   ·   Ctrl+1…0 jump to a page   ·   Ctrl+F search Wallhaven   ·   Ctrl+N next wallpaper   ·   Ctrl+R recolor")
          color: store.error !== "" ? Commons.Color.urgent : Util.alpha(hub.fg, 0.45)
          font.family: hub.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
