.pragma library

// Bar looks and arrangements converted from HANCORE-linux/waybar-themes
// (https://github.com/HANCORE-linux/waybar-themes, MIT, (c) 2025 drdeltree).
// Generated: each waybar module is mapped to its nearest Omarchy widget
// (cpu/memory/temperature and separators have none and are dropped), and each
// style.css is reduced to omabar16 style keys. Colours the original takes from
// the Omarchy theme are left unset, so those looks keep following the theme
// and the wallpaper. Variants that convert to the same result appear once.

var THEMES = [
 {
  "id": "hc-v1",
  "label": "HANCORE V1",
  "desc": "HANCORE · theme colours, own accent · First creation of my own Waybar config",
  "style": {
   "shape": "block",
   "radius": 2,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 1,
   "float": 1,
   "size": 28,
   "accent": "#ff9b71"
  }
 },
 {
  "id": "hc-v1-1",
  "label": "HANCORE V1.1",
  "desc": "HANCORE · follows your Omarchy theme · Island version of V1.6 with VOL dynamic circle status",
  "style": {
   "shape": "block",
   "radius": 7,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 2,
   "outline": 3,
   "edge": 5
  }
 },
 {
  "id": "hc-v1-2",
  "label": "HANCORE V1.2",
  "desc": "HANCORE · follows your Omarchy theme · Split left/right modules into separate groups with full rounded…",
  "style": {
   "shape": "round",
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 2,
   "outline": 1,
   "edge": 5
  }
 },
 {
  "id": "hc-v1-3",
  "label": "HANCORE V1.3",
  "desc": "HANCORE · follows your Omarchy theme · Double Split left/right modules into separate groups with full…",
  "style": {
   "shape": "round",
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 2,
   "outline": 1
  }
 },
 {
  "id": "hc-v1-4",
  "label": "HANCORE V1.4",
  "desc": "HANCORE · own colours · New workspace style with static dark colors",
  "style": {
   "shape": "none",
   "fg": "#aeb1b4",
   "accent": "#1d1e1e"
  }
 },
 {
  "id": "hc-v1-4b",
  "label": "HANCORE V1.4b",
  "desc": "HANCORE · follows your Omarchy theme",
  "style": {
   "shape": "none"
  }
 },
 {
  "id": "hc-v1-5",
  "label": "HANCORE V1.5",
  "desc": "HANCORE · follows your Omarchy theme · V1 base evolved: numbered workspaces, ultra-minimal full-width…",
  "style": {
   "shape": "block",
   "radius": 2,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 4
  }
 },
 {
  "id": "hc-v1-6",
  "label": "HANCORE V1.6",
  "desc": "HANCORE · follows your Omarchy theme · Long bar - dynamic RAM/CPU rounded circle's",
  "style": {
   "shape": "none",
   "edge": 5
  }
 },
 {
  "id": "hc-v1-7",
  "label": "HANCORE V1.7",
  "desc": "HANCORE · follows your Omarchy theme · Short bar with text modules on right side",
  "style": {
   "shape": "block",
   "radius": 3,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 2
  }
 },
 {
  "id": "hc-v1-8",
  "label": "HANCORE V1.8",
  "desc": "HANCORE · follows your Omarchy theme · Single bars of V1.7",
  "style": {
   "shape": "block",
   "radius": 3,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 1,
   "float": 2
  }
 },
 {
  "id": "hc-v1-9a",
  "label": "HANCORE V1.9a",
  "desc": "HANCORE · follows your Omarchy theme · Single rounded island version of base config V1.7",
  "style": {
   "shape": "round",
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 1,
   "float": 2
  }
 },
 {
  "id": "hc-v1-9d",
  "label": "HANCORE V1.9d",
  "desc": "HANCORE · follows your Omarchy theme · Midbar with new workspace bars",
  "style": {
   "shape": "block",
   "radius": 0,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 2
  }
 },
 {
  "id": "hc-v2",
  "label": "HANCORE V2",
  "desc": "HANCORE · own colours · New V2 version with static Gruvbox color scheme - see color…",
  "style": {
   "shape": "block",
   "radius": 2,
   "solid": true,
   "colors": "mono",
   "palette": [
    "#3c3836"
   ],
   "gap": 3,
   "inset": 6,
   "float": 2,
   "size": 24,
   "edge": 5,
   "fg": "#ebdbb2",
   "accent": "#fabd2f"
  }
 },
 {
  "id": "hc-v2-1",
  "label": "HANCORE V2.1",
  "desc": "HANCORE · own colours",
  "style": {
   "shape": "block",
   "radius": 0,
   "solid": true,
   "colors": "mono",
   "palette": [
    "#191724"
   ],
   "gap": 3,
   "inset": 0,
   "float": 3,
   "outline": 1,
   "outlineColor": "#e0def4",
   "size": 24,
   "edge": 5,
   "fg": "#f6c177",
   "accent": "#eb6f92"
  }
 },
 {
  "id": "hc-v2-1-1",
  "label": "HANCORE V2.1-1",
  "desc": "HANCORE · own colours",
  "style": {
   "shape": "block",
   "radius": 0,
   "solid": true,
   "colors": "mono",
   "palette": [
    "#1f1d2e"
   ],
   "gap": 0,
   "inset": 0,
   "float": 4,
   "edge": 10,
   "fg": "#e0def4",
   "accent": "#eb6f92"
  }
 },
 {
  "id": "hc-v2-1-2",
  "label": "HANCORE V2.1-2",
  "desc": "HANCORE · own colours · New version with static Rose Pine Dark color scheme",
  "style": {
   "shape": "round",
   "solid": true,
   "colors": "mono",
   "palette": [
    "#191724"
   ],
   "gap": 0,
   "inset": 0,
   "float": 4,
   "outline": 1,
   "outlineColor": "#e0def4",
   "edge": 5,
   "fg": "#e0def4",
   "accent": "#f6c177"
  }
 },
 {
  "id": "hc-v2-1-3",
  "label": "HANCORE V2.1-3",
  "desc": "HANCORE · own colours · New version with static Rose Pine Dark color scheme",
  "style": {
   "shape": "none",
   "fg": "#6e6a86",
   "accent": "#f6c177"
  }
 },
 {
  "id": "hc-v2-1a",
  "label": "HANCORE V2.1a",
  "desc": "HANCORE · own colours · [Oxocarbon-Theme](https://github.com/HANCORE-linux/omarchy-oxoca…",
  "style": {
   "shape": "round",
   "solid": true,
   "colors": "mono",
   "palette": [
    "#161616"
   ],
   "gap": 0,
   "inset": 2,
   "float": 2,
   "outline": 2,
   "outlineColor": "#8a8a8d",
   "size": 27,
   "fg": "#f2f4f8",
   "accent": "#ee5396"
  }
 },
 {
  "id": "hc-v2-1b",
  "label": "HANCORE V2.1b",
  "desc": "HANCORE · own colours · [Oxocarbon-Theme](https://github.com/HANCORE-linux/omarchy-oxoca…",
  "style": {
   "shape": "block",
   "radius": 0,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 1,
   "size": 27,
   "fg": "#33b1ff",
   "accent": "#ee5396"
  }
 },
 {
  "id": "hc-v2-1c",
  "label": "HANCORE V2.1c",
  "desc": "HANCORE · own colours · Monochrome waybar - static colors - inspired by OldJobobo…",
  "style": {
   "shape": "block",
   "radius": 4,
   "solid": true,
   "colors": "mono",
   "palette": [
    "#222222"
   ],
   "gap": 0,
   "inset": 2,
   "float": 2,
   "outline": 2,
   "outlineColor": "#111111",
   "size": 27,
   "fg": "#ffffff",
   "accent": "#ffffff"
  }
 },
 {
  "id": "hc-v2-2",
  "label": "HANCORE V2.2",
  "desc": "HANCORE · follows your Omarchy theme · Multiple groups creations",
  "style": {
   "shape": "block",
   "radius": 4,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 3,
   "float": 2,
   "outline": 2,
   "size": 20,
   "edge": 5
  }
 },
 {
  "id": "hc-v2-2b",
  "label": "HANCORE V2.2b",
  "desc": "HANCORE · follows your Omarchy theme",
  "style": {
   "shape": "block",
   "radius": 4,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 3,
   "float": 1,
   "outline": 1,
   "size": 20,
   "edge": 5
  }
 },
 {
  "id": "hc-v2-3",
  "label": "HANCORE V2.3",
  "desc": "HANCORE · follows your Omarchy theme · Base config v2.2 - all rounded and shadow boxed",
  "style": {
   "shape": "round",
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 2,
   "outline": 1,
   "size": 27,
   "edge": 5
  }
 },
 {
  "id": "hc-v2-4",
  "label": "HANCORE V2.4",
  "desc": "HANCORE · follows your Omarchy theme · Base config V2.3 - minimal concept",
  "style": {
   "shape": "round",
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 2,
   "outline": 1,
   "edge": 10
  }
 },
 {
  "id": "hc-v2-5",
  "label": "HANCORE V2.5",
  "desc": "HANCORE · own colours · Black background with jap workspace buttons",
  "style": {
   "shape": "block",
   "radius": 5,
   "solid": true,
   "colors": "mono",
   "palette": [
    "#27272a"
   ],
   "gap": 2,
   "inset": 3,
   "float": 3,
   "size": 24,
   "edge": 5,
   "bg": "#131315",
   "fg": "#e6d8ba",
   "accent": "#ff9b71"
  }
 },
 {
  "id": "hc-v2-5a",
  "label": "HANCORE V2.5a",
  "desc": "HANCORE · own colours · Static quartz color",
  "style": {
   "shape": "block",
   "radius": 5,
   "solid": true,
   "colors": "mono",
   "palette": [
    "#aea99c"
   ],
   "gap": 2,
   "inset": 2,
   "float": 2,
   "fg": "#2d2d2d",
   "accent": "#aea99c"
  }
 },
 {
  "id": "hc-v2-5b",
  "label": "HANCORE V2.5b",
  "desc": "HANCORE · follows your Omarchy theme",
  "style": {
   "shape": "block",
   "radius": 5,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 2,
   "inset": 2,
   "float": 2
  }
 },
 {
  "id": "hc-v2-5c",
  "label": "HANCORE V2.5c",
  "desc": "HANCORE · own colours · Static colors based of my new Theme…",
  "style": {
   "shape": "block",
   "radius": 2,
   "solid": true,
   "colors": "mono",
   "palette": [
    "#525e5a"
   ],
   "gap": 1,
   "inset": 2,
   "float": 2,
   "fg": "#ffffff",
   "accent": "#df6124"
  }
 },
 {
  "id": "hc-v2-7",
  "label": "HANCORE V2.7",
  "desc": "HANCORE · follows your Omarchy theme · Base config V2 - now with dynamic colors according to theme…",
  "style": {
   "shape": "block",
   "radius": 2,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 2,
   "inset": 2,
   "float": 2,
   "edge": 5
  }
 },
 {
  "id": "hc-v2-7b",
  "label": "HANCORE V2.7b",
  "desc": "HANCORE · follows your Omarchy theme · Waybar V2.7b (based on V2.7): Right-side modules moved into a…",
  "style": {
   "shape": "block",
   "radius": 2,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 2,
   "inset": 2,
   "float": 2
  }
 },
 {
  "id": "hc-v2-8",
  "label": "HANCORE V2.8",
  "desc": "HANCORE · follows your Omarchy theme · Similar to V2.6 , less borders and the lowest possible height…",
  "style": {
   "shape": "block",
   "radius": 4,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 1,
   "outline": 1
  }
 },
 {
  "id": "hc-v2-9b",
  "label": "HANCORE V2.9b",
  "desc": "HANCORE · theme colours, own accent · Top bar version of V2.9a - shipped with some text based modules…",
  "style": {
   "shape": "none",
   "accent": "#df6124"
  }
 },
 {
  "id": "hc-v2-9c",
  "label": "HANCORE V2.9c",
  "desc": "HANCORE · theme colours, own accent · Top bar version with custom omarchy.svg logo as home button",
  "style": {
   "shape": "none",
   "accent": "#353839"
  }
 },
 {
  "id": "hc-v2-9d",
  "label": "HANCORE V2.9d",
  "desc": "HANCORE · theme colours, own accent",
  "style": {
   "shape": "block",
   "radius": 5,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 3,
   "outline": 1,
   "outlineColor": "#363636",
   "edge": 5,
   "accent": "#df6124"
  }
 },
 {
  "id": "hc-v2-9e",
  "label": "HANCORE V2.9e",
  "desc": "HANCORE · own colours · Another top bar version with custom omarchy.svg logo as home…",
  "style": {
   "shape": "block",
   "radius": 2,
   "solid": true,
   "colors": "mono",
   "palette": [
    "#df6124"
   ],
   "gap": 0,
   "inset": 0,
   "float": 2,
   "fg": "#000000",
   "accent": "#df6124"
  }
 },
 {
  "id": "hc-v2-a",
  "label": "HANCORE V2.a",
  "desc": "HANCORE · own colours · New V2.a see…",
  "style": {
   "shape": "block",
   "radius": 2,
   "solid": true,
   "colors": "mono",
   "palette": [
    "#1a1a1a"
   ],
   "gap": 0,
   "inset": 0,
   "float": 2,
   "outline": 4,
   "outlineColor": "#000000",
   "size": 24,
   "edge": 2,
   "fg": "#e6e1d3",
   "accent": "#e5a359"
  }
 },
 {
  "id": "hc-v3",
  "label": "HANCORE V3",
  "desc": "HANCORE · follows your Omarchy theme · New waybar Style (without red accents)",
  "style": {
   "shape": "none",
   "size": 32
  }
 },
 {
  "id": "hc-v3-1b",
  "label": "HANCORE V3.1b",
  "desc": "HANCORE · theme colours, own accent",
  "style": {
   "shape": "round",
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 2,
   "float": 2,
   "outline": 1,
   "accent": "#df6124"
  }
 },
 {
  "id": "hc-v3-1c",
  "label": "HANCORE V3.1c",
  "desc": "HANCORE · own colours · Waybar for my theme…",
  "style": {
   "shape": "round",
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 5,
   "float": 2,
   "outline": 1,
   "outlineColor": "#c9aff0",
   "fg": "#82eeff",
   "accent": "#b388eb"
  }
 },
 {
  "id": "hc-v3-1d",
  "label": "HANCORE V3.1d",
  "desc": "HANCORE · follows your Omarchy theme · Stock fg & bg color support - no extra colors - base config…",
  "style": {
   "shape": "round",
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 5,
   "float": 2,
   "outline": 1
  }
 },
 {
  "id": "hc-v3-5",
  "label": "HANCORE V3.5",
  "desc": "HANCORE · follows your Omarchy theme · Minimal setup (cpu, memory, tempature, hyprland/window are…",
  "style": {
   "shape": "none",
   "size": 28
  }
 },
 {
  "id": "hc-v3-6",
  "label": "HANCORE V3.6",
  "desc": "HANCORE · follows your Omarchy theme · Minimal setup (memory, tempature, hyprland/window are excluded)",
  "style": {
   "shape": "block",
   "radius": 0,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 1,
   "outline": 1,
   "size": 28
  }
 },
 {
  "id": "hc-v3-7",
  "label": "HANCORE V3.7",
  "desc": "HANCORE · follows your Omarchy theme · \"Gnome\" style with Omarchy theme set module (set your \"home\"…",
  "style": {
   "shape": "round",
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 3,
   "float": 2,
   "size": 24
  }
 },
 {
  "id": "hc-v4",
  "label": "HANCORE V4",
  "desc": "HANCORE · follows your Omarchy theme",
  "style": {
   "shape": "round",
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 4,
   "float": 2,
   "outline": 2,
   "size": 32
  }
 },
 {
  "id": "hc-v4-3",
  "label": "HANCORE V4.3",
  "desc": "HANCORE · follows your Omarchy theme · Enhancement release (Minimal build, mpris animation, wttrbar…",
  "style": {
   "shape": "round",
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 1,
   "outline": 2,
   "size": 25
  }
 },
 {
  "id": "hc-v5",
  "label": "HANCORE V5",
  "desc": "HANCORE · follows your Omarchy theme",
  "style": {
   "shape": "block",
   "radius": 4,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 2,
   "outline": 2
  }
 },
 {
  "id": "hc-v5-b",
  "label": "HANCORE V5.b",
  "desc": "HANCORE · follows your Omarchy theme",
  "style": {
   "shape": "block",
   "radius": 3,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 2,
   "inset": 1,
   "float": 2
  }
 },
 {
  "id": "hc-v5-c",
  "label": "HANCORE V5.c",
  "desc": "HANCORE · follows your Omarchy theme",
  "style": {
   "shape": "block",
   "radius": 2,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 2,
   "outline": 2
  }
 },
 {
  "id": "hc-v5-d",
  "label": "HANCORE V5.d",
  "desc": "HANCORE · follows your Omarchy theme · Centered workspaces",
  "style": {
   "shape": "block",
   "radius": 2,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 2,
   "outline": 1
  }
 },
 {
  "id": "hc-v5-e",
  "label": "HANCORE V5.e",
  "desc": "HANCORE · follows your Omarchy theme",
  "style": {
   "shape": "block",
   "radius": 2,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 1,
   "inset": 1,
   "float": 2,
   "outline": 1
  }
 },
 {
  "id": "hc-v6-a",
  "label": "HANCORE V6.a",
  "desc": "HANCORE · own colours · Top-min bar - static colors - recommended for dark themes",
  "style": {
   "shape": "block",
   "radius": 0,
   "solid": true,
   "colors": "mono",
   "palette": [
    "#1e1e1e"
   ],
   "gap": 0,
   "inset": 2,
   "float": 2,
   "fg": "#b4b4b4",
   "accent": "#b4b4b4"
  }
 },
 {
  "id": "hc-v6-aa",
  "label": "HANCORE V6.aa",
  "desc": "HANCORE · own colours · Left-min bar - static colors - recommended for dark themes",
  "style": {
   "shape": "block",
   "radius": 0,
   "solid": true,
   "colors": "mono",
   "palette": [
    "#1e1e1e"
   ],
   "gap": 0,
   "inset": 0,
   "float": 2,
   "fg": "#b4b4b4",
   "accent": "#b4b4b4"
  }
 },
 {
  "id": "hc-v6-ab",
  "label": "HANCORE V6.ab",
  "desc": "HANCORE · follows your Omarchy theme",
  "style": {
   "shape": "none",
   "edge": 15
  }
 },
 {
  "id": "hc-v6-c",
  "label": "HANCORE V6.c",
  "desc": "HANCORE · follows your Omarchy theme · Long but minimal Style",
  "style": {
   "shape": "block",
   "radius": 2,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 3,
   "float": 3,
   "size": 28
  }
 },
 {
  "id": "hc-v6-ca",
  "label": "HANCORE V6.ca",
  "desc": "HANCORE · follows your Omarchy theme · Just waybar (no mpris, no hyprland/window) - bluetooth…",
  "style": {
   "shape": "block",
   "radius": 0,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 2,
   "inset": 2
  }
 },
 {
  "id": "hc-v6-cb",
  "label": "HANCORE V6.cb",
  "desc": "HANCORE · follows your Omarchy theme · Bottom waybar - with alot of workspaces - Thanks to Astraeya…",
  "style": {
   "shape": "block",
   "radius": 0,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 0,
   "float": 1
  }
 },
 {
  "id": "hc-v6-ce",
  "label": "HANCORE V6.ce",
  "desc": "HANCORE · follows your Omarchy theme · Short version of V6.cd - moved power-profile, backlight…",
  "style": {
   "shape": "block",
   "radius": 0,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 2,
   "inset": 0,
   "float": 2
  }
 },
 {
  "id": "hc-v6-d",
  "label": "HANCORE V6.d",
  "desc": "HANCORE · follows your Omarchy theme · Base config V6.c - tried to have less informations for…",
  "style": {
   "shape": "block",
   "radius": 0,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 5,
   "inset": 5,
   "float": 1,
   "size": 24
  }
 },
 {
  "id": "hc-v6-fa",
  "label": "HANCORE V6.fa",
  "desc": "HANCORE · follows your Omarchy theme",
  "style": {
   "shape": "block",
   "radius": 2,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 1,
   "float": 2
  }
 },
 {
  "id": "hc-v7",
  "label": "HANCORE V7",
  "desc": "HANCORE · follows your Omarchy theme · Base Waybar config/style derived from Omarchy by DHH – custom…",
  "style": {
   "shape": "block",
   "radius": 4,
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 2,
   "inset": 5,
   "float": 2,
   "outline": 1,
   "size": 26
  }
 },
 {
  "id": "hc-v7-1",
  "label": "HANCORE V7.1",
  "desc": "HANCORE · follows your Omarchy theme",
  "style": {
   "shape": "round",
   "solid": false,
   "colors": "mono",
   "palette": [
    "foreground"
   ],
   "tint": 0.12,
   "gap": 0,
   "inset": 5,
   "float": 2,
   "size": 26
  }
 },
 {
  "id": "hc-v7-2",
  "label": "HANCORE V7.2",
  "desc": "HANCORE · own colours · Top bar inspired by…",
  "style": {
   "shape": "none",
   "fg": "#df6124",
   "accent": "#df6124"
  }
 }
]

var LAYOUTS = [
 {
  "id": "hc-v1",
  "label": "HANCORE V1",
  "desc": "HANCORE · First creation of my own Waybar config",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.active-window"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v1-1",
  "label": "HANCORE V1.1",
  "desc": "HANCORE · Island version of V1.6 with VOL dynamic circle status",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.audio"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v1-2",
  "label": "HANCORE V1.2",
  "desc": "HANCORE · Split left/right modules into separate groups with full rounded…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.audio"
    }
   ]
  }
 },
 {
  "id": "hc-v1-3",
  "label": "HANCORE V1.3",
  "desc": "HANCORE · Double Split left/right modules into separate groups with full…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.network"
    }
   ]
  }
 },
 {
  "id": "hc-v1-4",
  "label": "HANCORE V1.4",
  "desc": "HANCORE · New workspace style with static dark colors",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    }
   ],
   "right": [
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v1-5",
  "label": "HANCORE V1.5",
  "desc": "HANCORE · V1 base evolved: numbered workspaces, ultra-minimal full-width…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.active-window"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "right": [
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v1-6",
  "label": "HANCORE V1.6",
  "desc": "HANCORE · Long bar - dynamic RAM/CPU rounded circle's",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.audio"
    }
   ]
  }
 },
 {
  "id": "hc-v1-7",
  "label": "HANCORE V1.7",
  "desc": "HANCORE · Short bar with text modules on right side",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.active-window"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "right": [
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v1-8",
  "label": "HANCORE V1.8",
  "desc": "HANCORE · Single bars of V1.7",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.active-window"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v1-9",
  "label": "HANCORE V1.9",
  "desc": "HANCORE · More varations of base config V1.7",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.active-window"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ],
   "right": [
    {
     "id": "omarchy.media"
    }
   ]
  }
 },
 {
  "id": "hc-v1-9a",
  "label": "HANCORE V1.9a",
  "desc": "HANCORE · Single rounded island version of base config V1.7",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [],
   "center": [
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.active-window"
    },
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ],
   "right": []
  }
 },
 {
  "id": "hc-v1-9b",
  "label": "HANCORE V1.9b",
  "desc": "HANCORE · Added cpu / mem / battery bar , changes color depends on load",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ],
   "right": []
  }
 },
 {
  "id": "hc-v1-9c",
  "label": "HANCORE V1.9c",
  "desc": "HANCORE · Longbar , added cpu / mem / battery bar , changes color and…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.workspaces"
    }
   ],
   "center": [
    {
     "id": "omarchy.media"
    }
   ],
   "right": [
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v1-9d",
  "label": "HANCORE V1.9d",
  "desc": "HANCORE · Midbar with new workspace bars",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": []
  }
 },
 {
  "id": "hc-v2",
  "label": "HANCORE V2",
  "desc": "HANCORE · New V2 version with static Gruvbox color scheme - see color…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.active-window"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v2-1-2",
  "label": "HANCORE V2.1-2",
  "desc": "HANCORE · New version with static Rose Pine Dark color scheme",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.active-window"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.network"
    }
   ]
  }
 },
 {
  "id": "hc-v2-1-3",
  "label": "HANCORE V2.1-3",
  "desc": "HANCORE · New version with static Rose Pine Dark color scheme",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.active-window"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    }
   ]
  }
 },
 {
  "id": "hc-v2-1a",
  "label": "HANCORE V2.1a",
  "desc": "HANCORE · [Oxocarbon-Theme](https://github.com/HANCORE-linux/omarchy-oxoca…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    }
   ],
   "right": [
    {
     "id": "omarchy.active-window"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v2-1b",
  "label": "HANCORE V2.1b",
  "desc": "HANCORE · [Oxocarbon-Theme](https://github.com/HANCORE-linux/omarchy-oxoca…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.active-window"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v2-1c",
  "label": "HANCORE V2.1c",
  "desc": "HANCORE · Monochrome waybar - static colors - inspired by OldJobobo…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.weather"
    }
   ],
   "right": [
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v2-2",
  "label": "HANCORE V2.2",
  "desc": "HANCORE · Multiple groups creations",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.active-window"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.clock"
    }
   ]
  }
 },
 {
  "id": "hc-v2-3",
  "label": "HANCORE V2.3",
  "desc": "HANCORE · Base config v2.2 - all rounded and shadow boxed",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.active-window"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.clock"
    }
   ]
  }
 },
 {
  "id": "hc-v2-4",
  "label": "HANCORE V2.4",
  "desc": "HANCORE · Base config V2.3 - minimal concept",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.active-window"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.network"
    }
   ]
  }
 },
 {
  "id": "hc-v2-5",
  "label": "HANCORE V2.5",
  "desc": "HANCORE · Black background with jap workspace buttons",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.active-window"
    }
   ],
   "center": [
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "right": [
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v2-5a",
  "label": "HANCORE V2.5a",
  "desc": "HANCORE · Static quartz color",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.audio"
    }
   ]
  }
 },
 {
  "id": "hc-v2-5c",
  "label": "HANCORE V2.5c",
  "desc": "HANCORE · Static colors based of my new Theme…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    }
   ],
   "center": [
    {
     "id": "omarchy.media"
    }
   ],
   "right": [
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.clock"
    }
   ]
  },
  "position": "bottom"
 },
 {
  "id": "hc-v2-6",
  "label": "HANCORE V2.6",
  "desc": "HANCORE · Base config of V2.4 - short version",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.network"
    }
   ]
  }
 },
 {
  "id": "hc-v2-7",
  "label": "HANCORE V2.7",
  "desc": "HANCORE · Base config V2 - now with dynamic colors according to theme…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.active-window"
    }
   ],
   "right": [
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v2-7b",
  "label": "HANCORE V2.7b",
  "desc": "HANCORE · Waybar V2.7b (based on V2.7): Right-side modules moved into a…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [],
   "center": [
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.network"
    }
   ],
   "right": []
  }
 },
 {
  "id": "hc-v2-8",
  "label": "HANCORE V2.8",
  "desc": "HANCORE · Similar to V2.6 , less borders and the lowest possible height…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [],
   "center": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.network"
    }
   ],
   "right": []
  }
 },
 {
  "id": "hc-v2-9",
  "label": "HANCORE V2.9",
  "desc": "HANCORE · Vertical bar - text based modules",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "center": [
    {
     "id": "omarchy.media"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.clock"
    }
   ]
  },
  "position": "left"
 },
 {
  "id": "hc-v2-9a",
  "label": "HANCORE V2.9a",
  "desc": "HANCORE · Bottom bar - shipped with some text based modules + accent…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "center": [
    {
     "id": "omarchy.media"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.clock"
    }
   ]
  },
  "position": "bottom"
 },
 {
  "id": "hc-v2-9b",
  "label": "HANCORE V2.9b",
  "desc": "HANCORE · Top bar version of V2.9a - shipped with some text based modules…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    }
   ],
   "right": [
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    }
   ]
  }
 },
 {
  "id": "hc-v2-9c",
  "label": "HANCORE V2.9c",
  "desc": "HANCORE · Top bar version with custom omarchy.svg logo as home button",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    }
   ],
   "right": [
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    }
   ]
  }
 },
 {
  "id": "hc-v2-9e",
  "label": "HANCORE V2.9e",
  "desc": "HANCORE · Another top bar version with custom omarchy.svg logo as home…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.network"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.tray"
    }
   ]
  }
 },
 {
  "id": "hc-v2-a",
  "label": "HANCORE V2.a",
  "desc": "HANCORE · New V2.a see…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.active-window"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v3",
  "label": "HANCORE V3",
  "desc": "HANCORE · New waybar Style (without red accents)",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.active-window"
    }
   ],
   "center": [
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v3-1a",
  "label": "HANCORE V3.1a",
  "desc": "HANCORE · Basic top bar with some red accents effects",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.bluetooth"
    }
   ],
   "center": [
    {
     "id": "omarchy.media"
    }
   ],
   "right": [
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.tray"
    }
   ]
  }
 },
 {
  "id": "hc-v3-1c",
  "label": "HANCORE V3.1c",
  "desc": "HANCORE · Waybar for my theme…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.audio"
    }
   ],
   "right": [
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.tray"
    }
   ]
  }
 },
 {
  "id": "hc-v3-1d",
  "label": "HANCORE V3.1d",
  "desc": "HANCORE · Stock fg & bg color support - no extra colors - base config…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.tray"
    }
   ]
  }
 },
 {
  "id": "hc-v3-2",
  "label": "HANCORE V3.2",
  "desc": "HANCORE · This Theme is recommended for darker Themes",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.active-window"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v3-4",
  "label": "HANCORE V3.4",
  "desc": "HANCORE · Transparant and all shadow , waybar and tooltip",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.active-window"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v3-5",
  "label": "HANCORE V3.5",
  "desc": "HANCORE · Minimal setup (cpu, memory, tempature, hyprland/window are…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v3-6",
  "label": "HANCORE V3.6",
  "desc": "HANCORE · Minimal setup (memory, tempature, hyprland/window are excluded)",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    }
   ],
   "center": [
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v3-6a",
  "label": "HANCORE V3.6a",
  "desc": "HANCORE · Minimal setup (memory, tempature, hyprland/window are excluded)",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v3-7",
  "label": "HANCORE V3.7",
  "desc": "HANCORE · \"Gnome\" style with Omarchy theme set module (set your \"home\"…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.weather"
    }
   ],
   "right": [
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.audio"
    }
   ]
  }
 },
 {
  "id": "hc-v4-2",
  "label": "HANCORE V4.2",
  "desc": "HANCORE · Base config V4",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.active-window"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v4-2b",
  "label": "HANCORE V4.2b",
  "desc": "HANCORE · Base config V4.2 , re-simplified",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v4-3",
  "label": "HANCORE V4.3",
  "desc": "HANCORE · Enhancement release (Minimal build, mpris animation, wttrbar…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.workspaces"
    }
   ],
   "center": [
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.weather"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v4-4",
  "label": "HANCORE V4.4",
  "desc": "HANCORE · Just an \"optimized\" adjustment of V4.3 modules (integration of…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "center": [
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.weather"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.menu"
    }
   ]
  }
 },
 {
  "id": "hc-v5-d",
  "label": "HANCORE V5.d",
  "desc": "HANCORE · Centered workspaces",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.active-window"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v6-a",
  "label": "HANCORE V6.a",
  "desc": "HANCORE · Top-min bar - static colors - recommended for dark themes",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.network"
    }
   ]
  }
 },
 {
  "id": "hc-v6-aa",
  "label": "HANCORE V6.aa",
  "desc": "HANCORE · Left-min bar - static colors - recommended for dark themes",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "center": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.network"
    }
   ],
   "right": []
  },
  "position": "left"
 },
 {
  "id": "hc-v6-ab",
  "label": "HANCORE V6.ab",
  "desc": "HANCORE · Waybar layout",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.active-window"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.clock"
    }
   ]
  }
 },
 {
  "id": "hc-v6-ab2",
  "label": "HANCORE V6.ab2",
  "desc": "HANCORE · New version of double-top-min bar - dynamic colors",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [],
   "center": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": []
  }
 },
 {
  "id": "hc-v6-ac",
  "label": "HANCORE V6.ac",
  "desc": "HANCORE · Top-min bar with dynamic colors",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v6-ba",
  "label": "HANCORE V6.ba",
  "desc": "HANCORE · Hidden system icons, new workspace style",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "center": [
    {
     "id": "omarchy.media"
    }
   ],
   "right": [
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.clock"
    }
   ]
  }
 },
 {
  "id": "hc-v6-c",
  "label": "HANCORE V6.c",
  "desc": "HANCORE · Long but minimal Style",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v6-ca",
  "label": "HANCORE V6.ca",
  "desc": "HANCORE · Just waybar (no mpris, no hyprland/window) - bluetooth…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    }
   ],
   "right": [
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.network"
    }
   ]
  }
 },
 {
  "id": "hc-v6-cb",
  "label": "HANCORE V6.cb",
  "desc": "HANCORE · Bottom waybar - with alot of workspaces - Thanks to Astraeya…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "center": [
    {
     "id": "omarchy.active-window"
    }
   ],
   "right": [
    {
     "id": "omarchy.clock"
    }
   ]
  },
  "position": "bottom"
 },
 {
  "id": "hc-v6-cc",
  "label": "HANCORE V6.cc",
  "desc": "HANCORE · Lowered \"inactive\" opacity on modules, only clock and active…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.audio"
    }
   ]
  }
 },
 {
  "id": "hc-v6-cd",
  "label": "HANCORE V6.cd",
  "desc": "HANCORE · Long bar version of V6.cc - moved power-profile, backlight…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "center": [
    {
     "id": "omarchy.media"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.menu"
    }
   ]
  }
 },
 {
  "id": "hc-v6-ce",
  "label": "HANCORE V6.ce",
  "desc": "HANCORE · Short version of V6.cd - moved power-profile, backlight…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "center": [
    {
     "id": "omarchy.media"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v6-d",
  "label": "HANCORE V6.d",
  "desc": "HANCORE · Base config V6.c - tried to have less informations for…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.media"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v6-f",
  "label": "HANCORE V6.f",
  "desc": "HANCORE · Waybar layout",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.tray"
    }
   ],
   "center": [
    {
     "id": "omarchy.workspaces"
    }
   ],
   "right": [
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v7",
  "label": "HANCORE V7",
  "desc": "HANCORE · Base Waybar config/style derived from Omarchy by DHH – custom…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.active-window"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.indicators"
    }
   ],
   "right": [
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v7-1a",
  "label": "HANCORE V7.1a",
  "desc": "HANCORE · Base Waybar config/style derived from Omarchy by DHH – custom…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.active-window"
    }
   ],
   "center": [
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.indicators"
    }
   ],
   "right": [
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.power"
    }
   ]
  }
 },
 {
  "id": "hc-v7-2",
  "label": "HANCORE V7.2",
  "desc": "HANCORE · Top bar inspired by…",
  "anchor": "omarchy.clock",
  "layout": {
   "left": [
    {
     "id": "omarchy.menu"
    },
    {
     "id": "omarchy.workspaces"
    }
   ],
   "center": [
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.system-update"
    }
   ],
   "right": [
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.tray"
    }
   ]
  }
 },
 {
  "id": "hc-v7-2a",
  "label": "HANCORE V7.2a",
  "desc": "HANCORE · Extend version of V7.2a - Features gpu-usage-waybar yay -S…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.workspaces"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.monitor"
    }
   ],
   "center": [
    {
     "id": "omarchy.media"
    }
   ],
   "right": [
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.menu"
    }
   ]
  }
 },
 {
  "id": "hc-v7-2b",
  "label": "HANCORE V7.2b",
  "desc": "HANCORE · Island-pill + mpris scrolling text by…",
  "anchor": "",
  "layout": {
   "left": [
    {
     "id": "omarchy.weather"
    },
    {
     "id": "omarchy.clock"
    },
    {
     "id": "omarchy.indicators"
    },
    {
     "id": "omarchy.media"
    },
    {
     "id": "omarchy.workspaces"
    }
   ],
   "center": [],
   "right": [
    {
     "id": "omarchy.power"
    },
    {
     "id": "omarchy.monitor"
    },
    {
     "id": "omarchy.audio"
    },
    {
     "id": "omarchy.network"
    },
    {
     "id": "omarchy.bluetooth"
    },
    {
     "id": "omarchy.system-update"
    },
    {
     "id": "omarchy.tray"
    },
    {
     "id": "omarchy.menu"
    }
   ]
  }
 }
]
