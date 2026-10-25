# omabar16

A bar you can rebuild without touching JSON. One plugin, two parts:

- **Bar** (`kind: bar`): the status bar itself. Segment shapes (chevron, slant,
  back slant, trapezoid, hexagon, pill, block, leaf, tab, underline), colours taken from the active Omarchy theme, and per-part colour
  overrides. Derived from `omarchy.bar`.
- **Customizer** (`kind: overlay`): the editor. Every change is applied to the
  live bar as you make it.

## Open it

    SUPER + SHIFT + ALT + SPACE            keybinding
    Omarchy menu > Style > Bar customizer
    omarchy-shell shell toggle omabar16 '{}'
    omarchy-shell shell summon omabar16 '{"tab":"studio","part":"module:omarchy.clock"}'

## Tabs

| Tab | What it does |
|---|---|
| Modules | Drag chips between the left / center / right lanes, in from AVAILABLE (searchable), or onto AVAILABLE to remove. Right-click a chip to remove it. |
| Layout | Screen edge (top / bottom / left / right), float, edge padding, transparency, and twenty preset layouts (seven originals plus thirteen from JaKooLit). Applying a layout moves widgets but keeps their settings, such as clock format or a custom icon. |
| Themes | Fourteen preset looks, 21 JaKooLit looks, 30 base16 schemes (A to Z), import/export, and your own saved themes. Some follow your Omarchy theme, others carry their own palette. |
| Studio | Pick a part of the bar (or click it in the preview) and set its colour with the hex picker; per-module options (clock format, spacer width); bar thickness, corner radius, padding and font; tune shape, fill, gap, inset, depth; save the result as a theme. |

Undo / redo: `Ctrl+Z`, `Ctrl+Shift+Z` (or the sidebar buttons). Revert (bottom left) restores the bar as it was when the customizer opened.

## Scripting

While the plugin is loaded: `omarchy-shell omabar16 <function> ...`

    tab <name>                         move <fromLane> <i> <toLane> <j>
    add <id> <lane> <index>            remove <lane> <index>
    theme <id>    layout <id>          position <top|bottom|left|right>
    color <part> <#hex>                revert    undo    redo
    exportTheme <id|"">   importTheme <json|path>
    style <key> <value>                state

Parts: `bg`, `fg`, `accent`, `region:left|center|right`, `pal:<n>`, `module:<id>`.

## Files

    Bar.qml                 the bar renderer
    Customizer.qml          the overlay + all state and mutations
    components/             pages, colour picker, preview bar, controls
    data/Presets.js         themes, layouts, glyphs, colour maths
    scripts/apply.sh        merges the config into shell.json (atomic write)
    scripts/save-themes.sh  persists your themes to ~/.config/omarchy/omabar16/themes.json

## Style keys (`bar.style` in shell.json)

`shape` arrow|slant|backslant|trapezoid|hex|round|block|leaf|tab|underline|none, `solid`, `tint`, `colors` cycle|mono,
`palette` (theme colour names or `#hex`), `gap`, `inset`, `depth`, `edge`,
`flatEnds`, `float`, `size` (bar thickness), `radius`, `pad`, `fontFamily`, and the overrides `bg`, `fg`, `accent`,
`regions {left,center,right}`, `modules {<id>: <hex>}`.

Hover and opacity: `hoverColor` (#hex), `hoverOpacity` (0-1), `segmentOpacity` (0.1-1),
`barOpacity` (0-1), and `iconFont` for custom icons.

## Per-module keys (on a layout entry, beside `id`)

`icon` (glyph replacing the widget's own), `iconFont`, `font` (text font),
`color` (text and icon colour), `hoverColor`, `opacity` (0.1-1). Font and colour
reach widgets drawn as a single button; opacity and hover work on every widget.

## Credits

The JAKOOLIT themes and the `jk-*` layouts are adapted from the waybar styles and
configs in [JaKooLit/Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots) (GPL-3.0).
Only colour palettes and module arrangements are borrowed; waybar modules are mapped
to their nearest Omarchy widgets, and the Wallust styles follow the Omarchy theme.

The HANCORE themes and `hc-*` layouts in Studio (omacraft.studio, `bar/data/Hancore.js`) are
converted from [HANCORE-linux/waybar-themes](https://github.com/HANCORE-linux/waybar-themes)
(MIT, (c) 2025 drdeltree): module arrangements mapped to Omarchy widgets, and each
stylesheet reduced to omabar16 style keys. Colours those themes take from the Omarchy
theme are left to follow it.
