.pragma library

// Layouts and color schemes for the menu, after adi1090x/rofi's launcher
// types and color files. The active pair lives in
// ~/.config/omarchy/launcher-style.json ({"layout": ..., "scheme": ...}).
//
// kind decides the renderer:
//   classic  the stock Omarchy card, untouched
//   list     a vertical list of rows (sidebar, spotlight, split)
//   grid     a grid of large icons (launchpad, grid)
//   strip    a horizontal row of items (dock, topbar)
//
// A preset with a base reuses that layout's look and only changes where the
// card sits and how big it is:
//   side      "left" | "right"         sidebar
//   floating  true                     sidebar, inset from the edges at width x height
//   edge      "top" | "bottom"         dock, topbar
//   top       0..1 of the screen, or "center"   spotlight
//   width, height (logical px, or "full"), columns (grid max)
//   anchor    "top-left" | "top" | "top-right" | "left" | "right" |
//             "bottom-left" | "bottom" | "bottom-right"   spotlight, split, grid
//   inset     px from the anchored edges (20)
var layouts = [
  { id: "classic",   name: "Classic",   icon: "󰍜", kind: "classic", description: "The stock Omarchy card" },
  { id: "sidebar",   name: "Sidebar",   icon: "󰘖", kind: "list",    description: "Full-height drawer docked to the left edge" },
  { id: "spotlight", name: "Spotlight", icon: "󰍉", kind: "list",    description: "Wide search popup in the upper middle of the screen" },
  { id: "split",     name: "Split",     icon: "󰕰", kind: "list",    description: "Centered card with a wallpaper preview pane" },
  { id: "launchpad", name: "Launchpad", icon: "󰀻", kind: "grid",    description: "Fullscreen grid of big icons over a blurred wallpaper" },
  { id: "grid",      name: "Grid",      icon: "󰕮", kind: "grid",    description: "Centered card with an icon grid" },
  { id: "dock",      name: "Dock",      icon: "󱂩", kind: "strip",   description: "Horizontal icon dock along the bottom" },
  { id: "topbar",    name: "Top bar",   icon: "󰖯", kind: "strip",   description: "dmenu-style strip across the top of the screen" },

  { id: "drawer-right", name: "Right drawer", icon: "󰘕", kind: "list", base: "sidebar", side: "right",
    description: "Full-height drawer docked to the right edge" },
  { id: "panel",     name: "Floating panel", icon: "󰕬", kind: "list", base: "sidebar", floating: true, width: 380, height: 720,
    description: "Sidebar look in a rounded card, inset from the left" },
  { id: "panel-right", name: "Floating panel right", icon: "󰕬", kind: "list", base: "sidebar", side: "right", floating: true, width: 380, height: 720,
    description: "Sidebar look in a rounded card, inset from the right" },
  { id: "palette",   name: "Command palette", icon: "󰘳", kind: "list", base: "spotlight", width: 620, top: 0.07,
    description: "Narrow search box near the top, editor-style" },
  { id: "compact",   name: "Compact",   icon: "󰍉", kind: "list", base: "spotlight", width: 480, top: 0.3,
    description: "Small search popup a third of the way down" },
  { id: "center",    name: "Center",    icon: "󰘷", kind: "list", base: "spotlight", width: 760, top: "center",
    description: "Wide search popup in the middle of the screen" },
  { id: "wide-split", name: "Wide split", icon: "󰕰", kind: "list", base: "split", width: 1200, height: 660,
    description: "Bigger list with a large wallpaper preview" },
  { id: "mini-grid", name: "Compact grid", icon: "󰕮", kind: "grid", base: "grid", width: 660, height: 470, columns: 4,
    description: "Small card with four columns of icons" },
  { id: "wide-grid", name: "Wide grid", icon: "󰕮", kind: "grid", base: "grid", width: 1240, height: 720, columns: 8,
    description: "Large card with up to eight columns of icons" },
  { id: "top-dock",  name: "Top dock",  icon: "󱂩", kind: "strip", base: "dock", edge: "top",
    description: "Horizontal icon dock under the top of the screen" },
  { id: "bottombar", name: "Bottom bar", icon: "󰖯", kind: "strip", base: "topbar", edge: "bottom",
    description: "dmenu-style strip across the bottom of the screen" },

  // Anchored to a corner or an edge.
  { id: "start-menu", name: "Start menu", icon: "󰀻", kind: "grid", base: "grid", anchor: "bottom-left", width: 560, height: 640, columns: 4,
    description: "Icon grid in the bottom-left corner, where a taskbar's start menu opens" },
  { id: "corner-search", name: "Corner search", icon: "󰍉", kind: "list", base: "spotlight", anchor: "top-left", width: 460,
    description: "Small search tucked under the bar's left end, by the Omarchy menu" },
  { id: "tray-pop", name: "Tray pop", icon: "󰕮", kind: "grid", base: "grid", anchor: "top-right", width: 420, height: 440, columns: 3,
    description: "Three columns of icons popping out under the bar's right end" },
  { id: "hud", name: "HUD", icon: "󰍉", kind: "list", base: "spotlight", anchor: "bottom", width: 680, inset: 48,
    description: "Heads-up search that rises from the bottom of the screen" },
  { id: "pocket", name: "Pocket", icon: "󰍉", kind: "list", base: "spotlight", anchor: "bottom-right", width: 400,
    description: "A tiny search in the bottom-right corner" },
  { id: "app-column", name: "App column", icon: "󰘕", kind: "grid", base: "grid", anchor: "right", width: 300, height: "full", columns: 2,
    description: "A full-height column of big icons down the right side" },
  { id: "app-shelf", name: "App shelf", icon: "󱂩", kind: "grid", base: "grid", anchor: "bottom", width: "full", height: 300, columns: 10,
    description: "A wide shelf of icons along the bottom, like an app library" },
  { id: "billboard", name: "Billboard", icon: "󰖯", kind: "grid", base: "grid", anchor: "top", width: "full", height: 340, columns: 10,
    description: "Icons in a banner across the top of the screen" },
  { id: "theatre", name: "Theatre", icon: "󰕰", kind: "list", base: "split", anchor: "bottom", width: "full", height: 460,
    description: "Cinema-wide list and wallpaper preview along the bottom" },
  { id: "command-deck", name: "Command deck", icon: "󰕰", kind: "list", base: "split", anchor: "top-right", width: 820, height: 560,
    description: "List and wallpaper preview in the top-right corner" }
]

// The layout whose renderer a preset uses.
function baseOf(def) {
  return (def && def.base) || (def && def.id) || "classic"
}

// bg, alt (raised surfaces), fg, sel (selection/accent), active, urgent.
// "omarchy" is a placeholder: its colors follow the current Omarchy theme.
var schemes = [
  { id: "omarchy",    name: "Omarchy theme" },
  { id: "catppuccin", name: "Catppuccin", bg: "#1e1d2f", alt: "#282839", fg: "#d9e0ee", sel: "#7aa2f7", active: "#abe9b3", urgent: "#f28fad" },
  { id: "dracula",    name: "Dracula",    bg: "#1e1f29", alt: "#282a36", fg: "#ffffff", sel: "#bd93f9", active: "#50fa7b", urgent: "#ff5555" },
  { id: "nord",       name: "Nord",       bg: "#2e3440", alt: "#383e4a", fg: "#e5e9f0", sel: "#81a1c1", active: "#a3be8c", urgent: "#bf616a" },
  { id: "gruvbox",    name: "Gruvbox",    bg: "#282828", alt: "#353535", fg: "#ebdbb2", sel: "#83a598", active: "#b8bb26", urgent: "#fb4934" },
  { id: "onedark",    name: "One Dark",   bg: "#1e2127", alt: "#282b31", fg: "#ffffff", sel: "#61afef", active: "#98c379", urgent: "#e06c75" },
  { id: "tokyonight", name: "Tokyo Night", bg: "#15161e", alt: "#1a1b26", fg: "#c0caf5", sel: "#33467c", active: "#414868", urgent: "#f7768e" },
  { id: "everforest", name: "Everforest", bg: "#323d43", alt: "#3c474d", fg: "#dad1be", sel: "#7fbbb3", active: "#a7c080", urgent: "#e67e80" },
  { id: "lovelace",   name: "Lovelace",   bg: "#1d1f28", alt: "#282a36", fg: "#fdfdfd", sel: "#79e6f3", active: "#5adecd", urgent: "#f37f97" },
  { id: "cyberpunk",  name: "Cyberpunk",  bg: "#000b1e", alt: "#0a1528", fg: "#0abdc6", sel: "#0abdc6", active: "#00ff00", urgent: "#ff0000" },
  { id: "navy",       name: "Navy",       bg: "#021b21", alt: "#0c252b", fg: "#f2f1b9", sel: "#44b5b1", active: "#7cbf9e", urgent: "#c2454e" },
  { id: "black",      name: "Black",      bg: "#000000", alt: "#101010", fg: "#ffffff", sel: "#62aeef", active: "#98c379", urgent: "#e06b74" },
  { id: "paper",      name: "Paper",      bg: "#f1f1f1", alt: "#e0e0e0", fg: "#252525", sel: "#008ec4", active: "#10a778", urgent: "#c30771" },
  { id: "yousai",     name: "Yousai",     bg: "#f5e7de", alt: "#ebdcd2", fg: "#34302d", sel: "#d97742", active: "#bf8f60", urgent: "#b23636" },
  { id: "rosepine",   name: "Rosé Pine",  bg: "#191724", alt: "#1f1d2e", fg: "#e0def4", sel: "#c4a7e7", active: "#9ccfd8", urgent: "#eb6f92" },
  { id: "kanagawa",   name: "Kanagawa",   bg: "#1f1f28", alt: "#2a2a37", fg: "#dcd7ba", sel: "#7e9cd8", active: "#98bb6c", urgent: "#e46876" },
  { id: "solarized",  name: "Solarized",  bg: "#002b36", alt: "#073642", fg: "#eee8d5", sel: "#268bd2", active: "#859900", urgent: "#dc322f" },
  { id: "monokai",    name: "Monokai",    bg: "#272822", alt: "#34352d", fg: "#f8f8f2", sel: "#f92672", active: "#a6e22e", urgent: "#fd971f" },
  { id: "synthwave",  name: "Synthwave",  bg: "#1a0b2e", alt: "#261447", fg: "#f6f0ff", sel: "#ff2a6d", active: "#05d9e8", urgent: "#fdf500" },
  { id: "sakura",     name: "Sakura",     bg: "#2b1020", alt: "#3a1830", fg: "#ffe4ec", sel: "#ff8fab", active: "#ffc2d1", urgent: "#fb6f92" },
  { id: "matrix",     name: "Matrix",     bg: "#000000", alt: "#031503", fg: "#a8ffb0", sel: "#00ff41", active: "#00c853", urgent: "#ff3333" },
  { id: "amber",      name: "Amber CRT",  bg: "#0f0a00", alt: "#1c1300", fg: "#ffcf70", sel: "#ffb000", active: "#ffd166", urgent: "#ff5f1f" }
]

// How the launcher arrives. "auto" uses each layout's own entrance (drawers
// slide from their edge, docks rise, popups settle), the rest apply to every
// layout. scale/x/y/angle are where the card starts, as fractions or
// degrees; ease names a Qt easing curve; ms is the duration at 1x speed.
var transitions = [
  { id: "auto",        name: "Layout's own",  icon: "󰁨", description: "Each layout's natural entrance" },
  { id: "fade",        name: "Fade",          icon: "󰘳", ms: 200, ease: "OutCubic",  description: "A plain cross-fade" },
  { id: "zoom",        name: "Zoom",          icon: "󰍉", ms: 230, ease: "OutCubic",  scale: 0.86, description: "Grows in from slightly smaller" },
  { id: "pop",         name: "Pop",           icon: "󰋘", ms: 320, ease: "OutBack",   scale: 0.55, description: "Springs out with a little overshoot" },
  { id: "from-top",    name: "Drop",          icon: "󰁅", ms: 280, ease: "OutCubic",  y: -0.6, description: "Slides down from above" },
  { id: "from-bottom", name: "Rise",          icon: "󰁝", ms: 280, ease: "OutCubic",  y: 0.6, description: "Slides up from below" },
  { id: "from-left",   name: "From the left", icon: "󰁍", ms: 280, ease: "OutCubic",  x: -0.6, description: "Slides in from the left" },
  { id: "from-right",  name: "From the right", icon: "󰁔", ms: 280, ease: "OutCubic", x: 0.6, description: "Slides in from the right" },
  { id: "bounce",      name: "Bounce",        icon: "󰔟", ms: 520, ease: "OutBounce", y: -0.5, description: "Falls in and bounces to rest" },
  { id: "unfold",      name: "Unfold",        icon: "󰡏", ms: 260, ease: "OutCubic",  yScale: 0.04, description: "Opens out from its middle line" },
  { id: "swing",       name: "Swing",         icon: "󰑓", ms: 420, ease: "OutBack",   angle: -70, axis: "x", description: "Swings down from its top edge" },
  { id: "flip",        name: "Flip",          icon: "󰯌", ms: 380, ease: "OutCubic",  angle: 90, axis: "y", description: "Turns around to face you" },
  { id: "spin",        name: "Spin",          icon: "󰑐", ms: 380, ease: "OutCubic",  angle: -12, axis: "z", scale: 0.8, description: "A quick twist into place" },
  { id: "none",        name: "Instant",       icon: "󰜎", ms: 1, ease: "Linear", description: "No animation at all" }
]

// The entrance "auto" picks for each base layout.
var autoTransitions = { classic: "none", sidebar: "side", spotlight: "zoom", split: "zoom", launchpad: "zoom",
                        grid: "zoom", dock: "edge", topbar: "edge" }

function transition(id) {
  var i = indexOfId(transitions, id)
  return transitions[i >= 0 ? i : 0]
}

function indexOfId(list, id) {
  for (var i = 0; i < list.length; i++) if (list[i].id === id) return i
  return -1
}

function layout(id) {
  var i = indexOfId(layouts, id)
  return layouts[i >= 0 ? i : 0]
}

function scheme(id) {
  var i = indexOfId(schemes, id)
  return schemes[i >= 0 ? i : 0]
}

function cycle(list, id, delta) {
  var i = indexOfId(list, id)
  if (i < 0) i = 0
  return list[(i + delta + list.length) % list.length].id
}

// Relative luminance, used to pick legible text on top of a selection color:
// rofi themes invert the selected row, but a dark selection (Tokyo Night)
// needs light text instead.
function luminance(hex) {
  var h = String(hex || "").replace("#", "")
  if (h.length < 6) return 0
  var c = [0, 2, 4].map(function(o) {
    var v = parseInt(h.substr(o, 2), 16) / 255
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
  })
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
}

function textOn(scheme) {
  return luminance(scheme.sel) > 0.3 ? scheme.bg : scheme.fg
}

function contrast(a, b) {
  var la = luminance(a) + 0.05
  var lb = luminance(b) + 0.05
  return la > lb ? la / lb : lb / la
}

// The selection color, unless it is too close to the background to carry a
// glyph on its own (Tokyo Night's selection is a dark blue).
function readableAccent(scheme) {
  return contrast(scheme.sel, scheme.alt) >= 3 ? scheme.sel : scheme.fg
}
