import QtQuick
import Quickshell
import Quickshell.Io
import "hub"

// Entry point for omacraft.studio. The shell gives a plugin a single panel loader,
// so this one item hosts both surfaces and routes each summon by its payload:
//
//   omarchy-shell shell summon omarchy.menu '{"menu":"root"}'        launcher
//   omarchy-shell shell summon omacraft.studio  '{"page":"wallhaven"}'   Studio hub
//
// A payload with "page" (or "studio") opens the hub; anything else goes to the
// launcher unchanged, so `omarchy-menu`, dmenu-style pickers and keybindings
// keep working. "toggle": true closes the surface instead if it is already up.
Item {
  id: root

  // Injected by omarchy-shell.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  readonly property string pluginId: (root.manifest && root.manifest.id) || "omacraft.studio"
  readonly property bool opened: launcher.opened || hub.opened

  function parse(payloadJson) {
    try { return JSON.parse(payloadJson || "{}") || {} } catch (e) { return {} }
  }

  function open(payloadJson) {
    var payload = root.parse(payloadJson)
    var wantsHub = payload.page !== undefined || payload.studio !== undefined
    if (wantsHub) {
      if (payload.toggle === true && hub.opened) { root.dismiss(); return }
      if (launcher.opened) launcher.close()
      hub.show(String(payload.page || payload.studio || ""))
    } else {
      if (payload.toggle === true && launcher.opened) { root.dismiss(); return }
      if (hub.opened) hub.hide()
      launcher.open(payloadJson)
    }
  }

  function close() {
    if (launcher.opened) launcher.close()
    if (hub.opened) hub.hide()
  }

  // Closing from inside (Esc, scrim click) goes through the shell so its
  // open-state bookkeeping stays in step.
  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }

  function refresh() { return launcher.refresh() }
  function ping() { return "ok" }

  // Opens the launcher on top of the hub so a style change can be seen.
  function previewLauncher() {
    hub.hide()
    launcher.open(JSON.stringify({ menu: "root" }))
  }

  Launcher {
    id: launcher
    omarchyPath: root.omarchyPath
    shell: root.shell
    manifest: root.manifest
  }

  Hub {
    id: hub
    launcher: launcher
    onCloseRequested: root.dismiss()
    onPreviewLauncherRequested: root.previewLauncher()
    onOpenPageRequested: function(page) { root.open(JSON.stringify({ page: page })) }
  }

  // Scriptable surface for keybindings: omarchy-shell studio <function> [args]
  IpcHandler {
    target: "studio"

    function open(page: string): string { root.open(JSON.stringify({ page: page })); return hub.page }
    function toggle(page: string): string { root.open(JSON.stringify({ page: page, toggle: true })); return hub.opened ? hub.page : "closed" }
    function close(): void { root.dismiss() }
    function pages(): string { return hub.pageIds().join(" ") }
  }
}
