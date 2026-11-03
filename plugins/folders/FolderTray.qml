import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A folder of apps on the bar. The folder icon opens into a row of the apps
// picked for it (a column on a side bar), sliding out the way the system
// tray's drawer does, and folds back up on a second click, after a launch,
// or on its own. Each bar entry is one folder, all of it inline in
// shell.json, so a bar can carry as many as it likes:
//
//   { "id": "omacraft.folders", "name": "Games", "icon": "󰊗",
//     "apps": ["steam", "org.prismlauncher.PrismLauncher",
//              { "name": "Lutris log", "icon": "utilities-terminal", "command": "alacritty -e journalctl -f" }],
//     "open": "click", "side": "auto", "closeOnLaunch": true, "showLabel": false, "autoClose": 0 }
//
// Apps are desktop ids (the .desktop file name, with or without .desktop),
// or a { name, icon, command } object for anything that has none.
// OmaCraft's Bar page makes, edits and places folders.
BarWidget {
  id: root
  moduleName: "omacraft.folders"

  // nf-md-folder / nf-md-folder_open
  readonly property string folderGlyph: String.fromCodePoint(0xF024B)
  readonly property string openGlyph: String.fromCodePoint(0xF0770)

  readonly property string folderName: String(setting("name", "Apps"))
  readonly property string icon: String(setting("icon", folderGlyph))
  readonly property var appList: settings && Array.isArray(settings.apps) ? settings.apps : []
  readonly property bool openOnHover: String(setting("open", "click")) === "hover"
  readonly property string side: String(setting("side", "auto"))
  readonly property bool closeOnLaunch: setting("closeOnLaunch", true) !== false
  readonly property bool showLabel: setting("showLabel", false) === true
  readonly property int autoClose: Math.max(0, Number(setting("autoClose", 0)) || 0)

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property bool expanded: false
  property bool menuOpen: false
  // Which way the apps slide out; settled each time the folder opens, so
  // "auto" can look at where the folder sits.
  property bool opensBefore: side === "before"

  // The apps as the bar draws them. Re-read when desktop entries change,
  // so an app installed later turns up without a restart.
  readonly property var items: {
    var known = DesktopEntries.applications.values || []
    void known.length
    var out = []
    for (var i = 0; i < appList.length; i++) {
      var app = appList[i]
      if (typeof app === "string") {
        var id = app.replace(/\.desktop$/, "")
        var entry = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)
        out.push({
          key: "d:" + id,
          name: entry ? entry.name : id,
          icon: iconUrl(entry ? entry.icon : id),
          desktopId: entry ? entry.id : id,
          command: "",
          missing: !entry
        })
      } else if (app && typeof app === "object" && app.command) {
        out.push({
          key: "c:" + i,
          name: String(app.name || app.command),
          icon: iconUrl(String(app.icon || "application-x-executable")),
          desktopId: "",
          command: String(app.command),
          missing: false
        })
      }
    }
    return out
  }

  readonly property int slot: Style.bar.iconSlot
  readonly property int appExtent: items.length * slot
  property real progress: expanded ? 1 : 0
  readonly property real revealed: appExtent * progress

  Behavior on progress {
    NumberAnimation { duration: Style.duration(420); easing.type: Easing.OutCubic }
  }

  function iconUrl(name) {
    var value = String(name || "")
    if (value === "") return Quickshell.iconPath("application-x-executable", true)
    if (value.indexOf("://") > 0) return value
    if (value.charAt(0) === "/") return "file://" + value
    var themed = Quickshell.iconPath(value, true)
    return themed !== "" ? themed : Quickshell.iconPath("application-x-executable", true)
  }

  // A glyph (one or two code points) or an icon name or file.
  readonly property bool iconIsGlyph: Array.from(icon).length <= 2

  function settleSide() {
    if (side !== "auto") {
      opensBefore = side === "before"
      return
    }
    // Towards the middle of the bar: a folder right of centre opens left.
    var win = root.QsWindow ? root.QsWindow.window : null
    if (!win) return
    var p = root.mapToItem(null, root.width / 2, root.height / 2)
    opensBefore = root.vertical ? p.y > win.height / 2 : p.x > win.width / 2
  }

  function toggle() {
    if (!expanded) settleSide()
    expanded = !expanded
  }

  function launch(item) {
    if (item.desktopId !== "") {
      // As the shell's own launcher does: gtk-launch resolves the entry,
      // uwsm-app keeps the app out of the compositor's service.
      Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", item.desktopId + ".desktop"])
    } else if (item.command !== "") {
      Quickshell.execDetached(["uwsm-app", "--", "sh", "-c", item.command])
    }
    if (closeOnLaunch) expanded = false
    menuOpen = false
  }

  // PopupCard closes through its owner.
  function close() {
    menuOpen = false
  }

  function openEditor() {
    menuOpen = false
    Quickshell.execDetached(["omacraft", "bar", "folders"])
  }

  implicitWidth: vertical ? barSize : button.width + (vertical ? 0 : revealed)
  implicitHeight: vertical ? button.height + revealed : barSize
  clip: false

  // Folds up on its own once the pointer has left it for autoClose seconds.
  Timer {
    interval: root.autoClose * 1000
    running: root.autoClose > 0 && root.expanded && !hover.hovered && !root.menuOpen
    onTriggered: root.expanded = false
  }

  HoverHandler {
    id: hover
    onHoveredChanged: {
      if (!root.openOnHover) return
      if (hovered && !root.expanded) root.toggle()
      else if (!hovered && root.expanded) root.expanded = false
    }
  }

  // The folder itself.
  BarIconButton {
    id: button
    bar: root.bar
    x: root.vertical ? 0 : (root.opensBefore ? root.revealed : 0)
    y: root.vertical ? (root.opensBefore ? root.revealed : 0) : 0
    width: root.vertical ? root.barSize : (root.showLabel ? implicitWidth + nameLabel.implicitWidth + Style.space(6) : implicitWidth)
    height: root.vertical ? implicitHeight : root.barSize
    text: root.iconIsGlyph ? (root.expanded && root.icon === root.folderGlyph ? root.openGlyph : root.icon) : ""
    iconComponent: root.iconIsGlyph ? null : imageIcon
    active: root.expanded
    useActiveColor: false
    tooltipText: root.items.length === 0 ? root.folderName + " (empty: right-click to edit)" : root.folderName
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.menuOpen = !root.menuOpen
      else if (mouseButton === Qt.MiddleButton) root.openEditor()
      else if (!root.openOnHover || !root.expanded) root.toggle()
      else root.expanded = false
    }

    Text {
      id: nameLabel
      visible: root.showLabel && !root.vertical
      anchors.verticalCenter: parent.verticalCenter
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      text: root.folderName
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  Component {
    id: imageIcon
    Image {
      fillMode: Image.PreserveAspectFit
      sourceSize.width: Math.round(width * Screen.devicePixelRatio)
      sourceSize.height: Math.round(height * Screen.devicePixelRatio)
      source: root.iconUrl(root.icon)
    }
  }

  // The apps, inside a clip that grows as the folder opens.
  Item {
    id: drawer
    x: root.vertical ? 0 : (root.opensBefore ? 0 : button.width)
    y: root.vertical ? (root.opensBefore ? 0 : button.height) : 0
    width: root.vertical ? root.barSize : root.revealed
    height: root.vertical ? root.revealed : root.barSize
    clip: true
    visible: root.revealed > 0.5

    Grid {
      // Anchored to the folder's side, so the apps slide out from under it.
      x: root.vertical ? 0 : (root.opensBefore ? drawer.width - width : 0)
      y: root.vertical ? (root.opensBefore ? drawer.height - height : 0) : 0
      rows: root.vertical ? -1 : 1
      columns: root.vertical ? 1 : -1
      opacity: root.progress

      Repeater {
        model: root.items
        delegate: Item {
          id: app
          required property var modelData
          width: root.vertical ? root.barSize : root.slot
          height: root.vertical ? root.slot : root.barSize

          Rectangle {
            anchors.centerIn: parent
            width: root.slot - Style.space(4)
            height: width
            radius: Style.space(5)
            color: root.foreground
            opacity: appMouse.containsMouse ? 0.14 : 0
            Behavior on opacity { NumberAnimation { duration: Style.duration(120) } }
          }
          Image {
            anchors.centerIn: parent
            width: Style.bar.iconCanvas + Style.space(2)
            height: width
            fillMode: Image.PreserveAspectFit
            sourceSize.width: Math.round(width * Screen.devicePixelRatio)
            sourceSize.height: Math.round(height * Screen.devicePixelRatio)
            source: app.modelData.icon
            opacity: app.modelData.missing ? 0.35 : 1
            scale: appMouse.pressed ? 0.88 : 1
            Behavior on scale { NumberAnimation { duration: Style.duration(90) } }
          }
          MouseArea {
            id: appMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: root.launch(app.modelData)
          }
          PanelToolTip {
            visible: appMouse.containsMouse
            text: app.modelData.missing ? app.modelData.name + " (not installed)" : app.modelData.name
          }
        }
      }
    }
  }

  // Right-click: the same apps with their names, and a way to edit them.
  PopupCard {
    id: menu
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.menuOpen
    contentWidth: menu.fittedContentWidth(Style.space(240))
    contentHeight: menu.fittedContentHeight(menuColumn.implicitHeight)

    Column {
      id: menuColumn
      anchors.fill: parent
      spacing: Style.space(2)

      Text {
        text: root.folderName
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        bottomPadding: Style.space(6)
      }

      Repeater {
        model: root.items
        delegate: Rectangle {
          id: row
          required property var modelData
          width: menuColumn.width
          height: Style.space(30)
          radius: Style.space(5)
          color: rowMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1) : "transparent"
          Image {
            id: rowIcon
            anchors.left: parent.left
            anchors.leftMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(18)
            height: width
            fillMode: Image.PreserveAspectFit
            sourceSize.width: Math.round(width * Screen.devicePixelRatio)
            sourceSize.height: Math.round(height * Screen.devicePixelRatio)
            source: row.modelData.icon
          }
          Text {
            anchors.left: rowIcon.right
            anchors.leftMargin: Style.space(10)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.missing ? row.modelData.name + " (not installed)" : row.modelData.name
            color: root.foreground
            opacity: row.modelData.missing ? 0.5 : 1
            elide: Text.ElideRight
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.launch(row.modelData)
          }
        }
      }

      Text {
        visible: root.items.length === 0
        text: "No apps yet."
        color: root.foreground
        opacity: 0.6
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        bottomPadding: Style.space(6)
      }

      Rectangle {
        width: menuColumn.width
        height: Style.space(30)
        radius: Style.space(5)
        color: editMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1) : "transparent"
        Text {
          anchors.centerIn: parent
          text: "Edit folders in OmaCraft"
          color: Commons.Color.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
        MouseArea {
          id: editMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openEditor()
        }
      }
    }
  }
}
