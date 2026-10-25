# Agent Dock (`omacraft.agentdock`)

A floating dock pill on the screen edge, only as tall as the icons it holds.
Expanded, it becomes a resizable floating side panel with one tab per AI agent: Claude Code and Gemini by default. Each
agent runs in its own terminal (foot) that the plugin floats and pins into the
panel. While the dock is collapsed, the agent tabs are hidden, but their
sessions keep running on the hidden `special:agentdock` workspace.

## Use

- **Toggle:** Super+Alt+A, the robot icon in the bar, or the chevron at the top of the dock.
- **Tabs:** click to switch, middle-click or the × to end a session. Clicking the
  active tab brings its terminal back if it was moved.
- **Resize:** drag the panel's edge (the side away from the dock). Double-click the edge to reset to 520px.
  The width is saved in `~/.local/state/skll-agentdock/state.json`.
- **Dock icons:** click to launch. Drag to reorder, or drag off the dock and
  release to remove. Right-click for Open / Move up / Move down / Remove.
- **Add apps:** drag an app from the launcher (Studio) onto the dock. The
  launcher fades while you drag, and the drop lands where the pointer is.
  Dropping a `.desktop` file from a file manager works too.
- **Settings:** the gear at the bottom of the dock opens a card with four tabs:
  - *General*: position (left/right), floating gap, icon size, opacity,
    reserved space, reset icons / width.
  - *Look*: magnify on hover (the macOS effect: the icon under the pointer
    grows to the chosen size and its neighbours grow less, over 1-4 icons
    either side), the dock's shape (rounded, pill, soft, square, or attached
    to the screen edge), icon tile shape (rounded, circle, squircle, square,
    diamond) and when tiles show, the dock and accent colours, and the border.
  - *Items*: add a spacer or divider, search installed apps and add or
    remove them, or add a custom command (name, glyph, command).
  - *Agents*: which agent tabs are shown, and the start folder for new sessions.
- Spacers and dividers drag, reorder and remove like icons.

Dock icons and settings live in `~/.local/state/skll-agentdock/state.json`.

Gemini CLI isn't installed by default. Its tab offers "Install & start", which
runs `omarchy pkg add gemini-cli` in the tab (it asks for your sudo password).

## Configure

Create `~/.config/omarchy/agentdock.json` (it reloads on save):

```json
{
  "monitor": "eDP-1",
  "agents": [
    { "id": "claude", "name": "Claude Code", "icon": "icons/claude.svg", "command": "claude", "cwd": "~/Work" },
    { "id": "gemini", "name": "Gemini", "icon": "icons/gemini.svg", "command": "gemini",
      "install": "omarchy pkg add gemini-cli" },
    { "id": "codex", "name": "Codex", "icon": "/path/to/codex.svg", "command": "codex" }
  ]
}
```

## IPC

```
omarchy-shell shell toggle omacraft.agentdock '{}'     # or '{"tab":"gemini"}'
omarchy-shell agentdock toggle|expand|collapse|state
omarchy-shell agentdock tab gemini
omarchy-shell agentdock width 640
omarchy-shell agentdock settings                    # toggle the settings card
omarchy-shell agentdock addApp chromium             # desktop id
omarchy-shell agentdock move 0 2 | removeApp 3
omarchy-shell agentdock addSpacer | addDivider
omarchy-shell agentdock settingsTab look            # general | look | items | agents
omarchy-shell agentdock set gap 6                   # any saved setting, value as JSON
```

`set` takes `position`, `gap`, `iconSize`, `opacity`, `reserveCollapsed`,
`reserveExpanded`, `hiddenAgents`, `cwd`, `dock`, `width`, and the look:
`magnify` (true/false), `magnifyScale` (1.1-2.4), `magnifyRange` (1-4),
`dockShape`, `iconShape`, `iconPlate` (hover, always, outline), `dockColor`
and `accentColor` (`theme`, a name, or `"#rrggbb"`) and `dockBorder`
(subtle, accent, none). OMAcraft uses
it to change the dock while it runs, since the dock only reads `state.json`
when it loads.

The launcher talks to the dock with `dragStart <desktop-id>` and `dragEnd`.
The launcher holds the pointer grab during the drag, so the dock reads the
pointer position itself (`bin/agentdock cursor`).

## Notes

- The panel is a keepLoaded shell panel, so changes to its QML need `omarchy restart shell`.
- It sits on the overlay layer so that the bar reserves its space first and
  keeps its full width. It hides while the active workspace has a fullscreen window.
- `bin/agentdock` does the Hyprland work (launch, place, stash and close the
  terminals). Each show or hide is one batched `hyprctl eval`, and agent
  windows get `no_anim` so only the dock's own card animates.
- Expand: the surface widens, the card slides in, then the terminal is placed.
  Collapse: the terminal is stashed first, then the card slides out, then the
  surface and reserved space shrink.
