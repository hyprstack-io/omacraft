# HyprCraft — Omarchy bar plugin (`omacraft.hyprcraft`)

Hyprland / Waybar / Rofi / SwayNC / GTK·Qt / terminal customizer that drops
down from the Omarchy bar and can be popped out into its own window.

## Install

From the project root:

```bash
./omarchy-plugin/install.sh            # builds the web app if needed, installs, adds the icon to the bar
./omarchy-plugin/install.sh --rebuild  # after changing anything under src/
```

It copies this folder to `~/.config/omarchy/plugins/omacraft.hyprcraft/` and runs
`omarchy bar put omacraft.hyprcraft --section right --before omarchy.tray`. Move it
with `omarchy bar move omacraft.hyprcraft --section <left|center|right>`.

Requires `python-pyqt6-webengine` (the installer adds it with `omarchy pkg add` if missing).

## Using it

| Action | Result |
|---|---|
| Click the bar icon | Open / close the dropdown under the icon |
| **Pop out** button (top-right of the app) or right-click the icon | Detach into a normal floating window |
| **Dock to bar** button | Return to the dropdown |
| `Esc` (dropdown only) or the ✕ button | Hide |
| Middle-click the icon | Quit the host process |

Your in-progress edits survive pop-out, dock and hide: it's the same live page
moved between windows. Exports and downloads are saved to `~/Downloads/HyprCraft/`
and a notification is shown.

## Settings (`~/.config/omarchy/shell.json`, on the widget's layout entry)

| Key | Default | Meaning |
|---|---|---|
| `width` / `height` | `1280` / `840` | Dropdown size, clamped to the monitor |
| `hideOnBlur` | `false` | Hide the dropdown when it loses focus. Off by default because Omarchy focuses on hover (`follow_mouse = 1`) |
| `preload` | `false` | Start the host with the shell so the first open is instant (~150 MB RAM kept resident) |

e.g. `omarchy bar set omacraft.hyprcraft width 1440`

## How it works

Quickshell (the Omarchy shell) crashes if it embeds QtWebEngine
([quickshell#298](https://github.com/quickshell-mirror/quickshell/issues/298)),
so the plugin is split:

- `BarWidget.qml` is a native bar icon. On click it computes the dropdown
  rectangle directly under the icon (top/bottom/left/right bars), then runs `bin/hyprcraft`.
- `bin/hyprcraft` is a single-instance PyQt6 WebEngine host. It serves `app/`
  (the Vite build) on `127.0.0.1` and owns two windows, `HyprCraft Dropdown`
  and `HyprCraft`, and it reparents one `QWebEngineView` between them.
  Before each show it installs a dynamic Hyprland rule with `hyprctl eval`
  (`float`, `pin`, `size`, `move`, `monitor`), so the dropdown maps exactly
  under the icon. Your Hyprland config files are not modified.
- The React app detects `?host=` in its URL (`src/host/omarchyHost.ts`) and
  shows the Pop out / Dock / Close controls (`src/components/HostControls.tsx`),
  which POST back to the host with a per-session token.

Host CLI: `hyprcraft toggle|show|popout|dock|hide|quit|start`. Run it with
`HYPRCRAFT_DEBUG=1` to log every command and `hyprctl` call to stderr.
