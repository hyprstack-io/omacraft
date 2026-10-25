# Animations (omacraft.animations)

Bar widget that switches Hyprland animation presets and scales their speed.

- **Left click** opens the panel: a grid of presets, a speed slider (0.25× to 3×,
  where higher is faster) and a 1× reset button. Arrow keys plus Enter work too.
- **Right click** moves to the next preset.
- **Middle click** switches animations off, or back to the last preset.

## How it works

`bin/omarchy-animations` renders the chosen preset into
`~/.config/hypr/animation_preset.lua`, saves the choice in
`~/.config/omarchy/animation-preset.json`, then runs `hyprctl reload` and
checks `hyprctl configerrors`. `~/.config/hypr/hyprland.lua` loads the file
after `looknfeel.lua` and before Omarchy's toggles, so toggles such as game
mode still take priority.

Each reload starts again from Omarchy's defaults, so switching presets never
leaves settings behind. The stock `specialWorkspace` (qconsole) slide is never changed.

## CLI

```
python3 ~/.config/omarchy/plugins/omacraft.animations/bin/omarchy-animations --help
  list | status [--json]
  apply <preset> [--speed X]
  speed <X>
  next | prev | toggle
  preview <preset> [--speed X]     # print the Lua, change nothing
  style windows|workspaces <style|preset>
  border <id|theme> [--loop|--no-loop] [--border-speed N]
  borders [--json]
```

`style` swaps the shape of every preset's window or workspace animation
(`popin 30%`, `gnomed`, `slide top`, `slidefadevert 20%`, …; `preset` puts the
preset's own back) while keeping its timing. `border` paints the active window
border with a colour run (`rainbow`, `sunset`, `synthwave`, `aurora`, `ocean`,
`ice`, `fire`, `forest`, `neon`, `candy`, `gold`, `mono`, `dracula`,
`catppuccin`, `tokyonight`), and `--loop` spins it, one turn every
`--border-speed` seconds (1-10). `theme` leaves the Omarchy theme's border alone.
Add your own runs under `"borders"` in `animation-presets.json`.

Example keybindings for `~/.config/hypr/bindings.lua`:

```lua
local anim = "python3 " .. os.getenv("HOME") .. "/.config/omarchy/plugins/omacraft.animations/bin/omarchy-animations"
o.bind("SUPER + ALT + A", "Next animation preset", anim .. " next")
o.bind("SUPER + ALT + SHIFT + A", "Toggle animations", anim .. " toggle")
```

## Presets

Omarchy, Off, Snappy, Minimal, Smooth, Fluid, Springy, Bouncy, Jelly, Elastic,
Slide, Vertical, Gnome, Dreamy, Arcade, Zen, Snap, Pop, Zoom, Drop, Rise, Sweep,
Curtain, Drift, Warp, Cascade, Glide, Flip, Hyper, Cinema, Rubber.

## Custom presets

Create `~/.config/omarchy/animation-presets.json` with the same shape as
`presets.json`. A preset with the same `id` as a stock preset replaces it.
Custom presets are marked with ✦ in the grid.

```json
{
  "curves": {
    "mySpring": { "type": "spring", "mass": 1, "stiffness": 220, "dampening": 18 }
  },
  "presets": [
    {
      "id": "mine",
      "name": "Mine",
      "description": "My own take",
      "animations": {
        "windowsIn": [4, "mySpring", "popin 75%"],
        "windowsOut": [2, "linear", "popin 75%"],
        "workspaces": [5, "mySpring", "slidefade 20%"]
      }
    }
  ]
}
```

Each animation is `[speed, curve, style?]`, or `false` to disable that leaf.
Speed is Hyprland's duration in deciseconds, so lower is faster. A curve is
either one of Omarchy's built-ins (`default`, `easeOutQuint`,
`easeInOutCubic`, `linear`, `almostLinear`, `quick`) or a named entry in
`curves`, written as a `bezier` with `points` or a `spring` with
`mass`, `stiffness` and `dampening`.
