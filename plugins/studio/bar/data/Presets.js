.pragma library
.import "Hancore.js" as Hancore

// Presets and colour maths shared by the omabar16 customizer and its previews.
// A "theme" is a look (shape, colours); a "layout" is which widgets go where;
// a "position" is the screen edge. They are independent and can be mixed.

// Arrays that arrive through a Repeater's modelData are QVariantLists rather than
// real JS arrays, so the built-in array test fails for them. Duck-type instead.
function isList(v) {
  return v !== null && v !== undefined && typeof v === "object" && typeof v.length === "number"
}

// ------------------------------------------------------------------ themes

var THEMES = [
  { id: "omarchy-powerline", label: "Powerline", desc: "Solid chevrons in your Omarchy theme colours",
    style: { shape: "arrow", solid: true, colors: "cycle", gap: 1, flatEnds: true, depth: 0.42 } },
  { id: "omarchy-tint", label: "Powerline Tint", desc: "Chevrons washed into the bar background",
    style: { shape: "arrow", solid: false, tint: 0.34, colors: "cycle", gap: 1, flatEnds: true, depth: 0.4 } },
  { id: "slant", label: "Slant", desc: "Leaning parallelograms with clear gaps",
    style: { shape: "slant", solid: true, colors: "cycle", gap: 3, inset: 2, edge: 6 } },
  { id: "pills", label: "Pills", desc: "Floating rounded pills",
    style: { shape: "round", solid: false, tint: 0.36, colors: "cycle", gap: 6, inset: 2, edge: 4, float: 6 } },
  { id: "blocks", label: "Blocks", desc: "Tight tinted tiles",
    style: { shape: "block", solid: false, tint: 0.28, colors: "cycle", gap: 3, inset: 3, edge: 6 } },
  { id: "ribbon", label: "Ribbon", desc: "Two-tone accent chevrons",
    style: { shape: "arrow", solid: true, colors: "mono", gap: 0, flatEnds: true, depth: 0.5 } },
  { id: "classic", label: "Classic", desc: "The stock Omarchy bar, unstyled",
    style: { shape: "none" } },

  { id: "neon-tokyo", label: "Neon Tokyo", desc: "Night-city neon on ink",
    style: { shape: "arrow", solid: true, colors: "cycle", gap: 1, flatEnds: true,
             palette: ["#7aa2f7", "#bb9af7", "#7dcfff", "#9ece6a", "#e0af68", "#f7768e"],
             bg: "#16161e", fg: "#16161e", accent: "#7aa2f7" } },
  { id: "sunset", label: "Sunset Strip", desc: "Warm slants, orange into magenta",
    style: { shape: "slant", solid: true, colors: "cycle", gap: 3, inset: 2, edge: 6,
             palette: ["#ff9e64", "#ff7a93", "#e0af68", "#c678dd", "#f7768e"],
             bg: "#1a1116", fg: "#1a1116", accent: "#ff9e64" } },
  { id: "mint-chip", label: "Mint Chip", desc: "Cool green pills on deep green-black",
    style: { shape: "round", solid: false, tint: 0.4, colors: "cycle", gap: 6, inset: 2, edge: 4, float: 6,
             palette: ["#7ee0b5", "#5ac8a8", "#a5e6c8", "#3fb8af"],
             bg: "#0d1512", fg: "#d8f5e8", accent: "#7ee0b5" } },
  { id: "mono-ink", label: "Mono Ink", desc: "Paper-white chevrons on black",
    style: { shape: "arrow", solid: true, colors: "mono", gap: 0, flatEnds: true, depth: 0.5,
             palette: ["#e8e8e8"], bg: "#000000", fg: "#000000", accent: "#ffffff" } },
  { id: "amber-crt", label: "Amber CRT", desc: "Phosphor amber tiles",
    style: { shape: "block", solid: false, tint: 0.3, colors: "cycle", gap: 2, inset: 3, edge: 6,
             palette: ["#ffb000", "#ff8c00", "#ffd166"], bg: "#0f0a00", fg: "#ffb000", accent: "#ffb000" } },
  { id: "vapor", label: "Vapor", desc: "Pink and cyan slants on purple",
    style: { shape: "slant", solid: true, colors: "cycle", gap: 3, inset: 2, edge: 6,
             palette: ["#ff71ce", "#01cdfe", "#05ffa1", "#b967ff", "#fffb96"],
             bg: "#1a0b2e", fg: "#1a0b2e", accent: "#ff71ce" } },
  { id: "graphite", label: "Graphite", desc: "Quiet grey pills",
    style: { shape: "round", solid: false, tint: 0.3, colors: "cycle", gap: 6, inset: 2, edge: 4, float: 6,
             palette: ["#8b949e", "#6e7681", "#a5b4c2"], bg: "#0d1117", fg: "#c9d1d9", accent: "#a5b4c2" } },

  // Newer shapes: hexagons, back slants, trapezoids, leaves, tabs and underlines.
  { id: "honeycomb", label: "Honeycomb", desc: "Amber hexagon cells on dark honey",
    style: { shape: "hex", solid: true, colors: "cycle", gap: 3, inset: 2, edge: 6, depth: 0.5,
             palette: ["#ffb000", "#ffc94d", "#e09400", "#ffd98a"], bg: "#1a1200", fg: "#1a1200", accent: "#ffb000" } },
  { id: "hex-theme", label: "Hex", desc: "Hexagons in your Omarchy theme colours",
    style: { shape: "hex", solid: false, tint: 0.4, colors: "cycle", gap: 3, inset: 2, edge: 6, depth: 0.5 } },
  { id: "backslash", label: "Backslash", desc: "Segments leaning the other way",
    style: { shape: "backslant", solid: true, colors: "cycle", gap: 3, inset: 2, edge: 6 } },
  { id: "synthwave", label: "Synthwave", desc: "Hot pink and cyan back slants on midnight",
    style: { shape: "backslant", solid: true, colors: "cycle", gap: 3, inset: 2, edge: 6,
             palette: ["#ff2a6d", "#05d9e8", "#d300c5", "#fdf500", "#ff6c11"], bg: "#0d0221", fg: "#0d0221", accent: "#ff2a6d" } },
  { id: "hanging-tabs", label: "Hanging Tabs", desc: "Trapezoids that hang from the top edge",
    style: { shape: "trapezoid", solid: false, tint: 0.38, colors: "cycle", gap: 4, inset: 0, edge: 8 } },
  { id: "circuit", label: "Circuit", desc: "Green trapezoid tags on board black",
    style: { shape: "trapezoid", solid: true, colors: "cycle", gap: 4, inset: 0, edge: 8,
             palette: ["#39ff14", "#00c853", "#64dd17", "#b2ff59"], bg: "#020a02", fg: "#020a02", accent: "#39ff14" } },
  { id: "leaves", label: "Leaves", desc: "Leaf-shaped tiles in your theme colours",
    style: { shape: "leaf", solid: false, tint: 0.36, colors: "cycle", gap: 5, inset: 3, edge: 6 } },
  { id: "sakura", label: "Sakura", desc: "Cherry-blossom leaves on plum",
    style: { shape: "leaf", solid: true, colors: "cycle", gap: 5, inset: 3, edge: 6,
             palette: ["#ffb7c5", "#ff8fab", "#fb6f92", "#ffc2d1", "#e5989b"], bg: "#2b1020", fg: "#2b1020", accent: "#ff8fab" } },
  { id: "browser-tabs", label: "Browser Tabs", desc: "Rounded-top tabs resting on the bar",
    style: { shape: "tab", solid: false, tint: 0.32, colors: "cycle", gap: 3, inset: 0, edge: 8, radius: 10 } },
  { id: "ocean-tabs", label: "Ocean Tabs", desc: "Deep-sea tabs in blues and teals",
    style: { shape: "tab", solid: true, colors: "cycle", gap: 3, inset: 0, edge: 8, radius: 10,
             palette: ["#4fc3f7", "#26a69a", "#0288d1", "#80deea", "#00acc1"], bg: "#011627", fg: "#011627", accent: "#4fc3f7" } },
  { id: "underline", label: "Underline", desc: "A coloured line under each module, nothing else",
    style: { shape: "underline", solid: true, colors: "cycle", gap: 10, inset: 3, edge: 10 } },
  { id: "neon-underline", label: "Neon Underline", desc: "Glowing neon underlines on black",
    style: { shape: "underline", solid: true, colors: "cycle", gap: 12, inset: 3, edge: 10, shadow: 0.6,
             palette: ["#ff00e6", "#00f0ff", "#39ff14", "#fffb00"], bg: "#000000", fg: "#e8e8e8", accent: "#00f0ff" } },
  { id: "aurora", label: "Aurora", desc: "Northern-light pills drifting from green to violet",
    style: { shape: "round", solid: true, colors: "cycle", gap: 6, inset: 2, edge: 4, float: 6,
             palette: ["#00ff87", "#60efff", "#0061ff", "#b16cea"], bg: "#06121f", fg: "#06121f", accent: "#60efff" } },
  { id: "lava", label: "Lava", desc: "Molten chevrons, yellow to deep red",
    style: { shape: "arrow", solid: true, colors: "cycle", gap: 1, flatEnds: true, depth: 0.45,
             palette: ["#ffd36e", "#ff9a00", "#ff4d00", "#c81d25"], bg: "#1a0505", fg: "#1a0505", accent: "#ff4d00" } },
  { id: "pastel", label: "Pastel", desc: "Soft candy blocks",
    style: { shape: "block", solid: true, colors: "cycle", gap: 3, inset: 3, edge: 6, radius: 6,
             palette: ["#ffadad", "#ffd6a5", "#fdffb6", "#caffbf", "#9bf6ff", "#a0c4ff", "#bdb2ff", "#ffc6ff"],
             bg: "#1f1d2b", fg: "#1f1d2b", accent: "#bdb2ff" } },
  { id: "frost", label: "Frost", desc: "Icy outlined pills on slate",
    style: { shape: "round", solid: false, tint: 0.22, colors: "cycle", gap: 6, inset: 2, edge: 4, float: 6, outline: 1,
             outlineColor: "#9ad9ff", palette: ["#d6f3ff", "#9ad9ff", "#5ab8f5"], bg: "#0f1a24", fg: "#e6f6ff", accent: "#9ad9ff" } }
]

// ------------------------------------------------------------------ JaKooLit

// Looks borrowed from the waybar styles in JaKooLit's Hyprland-Dots
// (github.com/JaKooLit/Hyprland-Dots, config/waybar/style). Palettes come from
// each stylesheet; the Wallust ones recolour with the wallpaper there, so here
// they follow the Omarchy theme instead.
var JAKOOLIT = [
  { id: "jk-neon-circuit", label: "Neon Circuit", desc: "JaKooLit · lavender and rosewater pills",
    style: { shape: "round", solid: false, tint: 0.32, colors: "cycle", gap: 6, inset: 2, edge: 4, float: 6,
             palette: ["#b4befe", "#f5e0dc", "#f38ba8", "#cba6f7", "#89b4fa"],
             bg: "#1e1e2e", fg: "#cdd6f4", accent: "#b4befe" } },
  { id: "jk-golden-noir", label: "Golden Noir", desc: "JaKooLit · gold on near-black",
    style: { shape: "round", solid: false, tint: 0.22, colors: "mono", gap: 5, inset: 3, edge: 6,
             palette: ["#ffd700"], bg: "#11111b", fg: "#ffd700", accent: "#ffd700" } },
  { id: "jk-golden-eclipse", label: "Golden Eclipse", desc: "JaKooLit · solid amber tiles on black",
    style: { shape: "block", solid: true, colors: "mono", gap: 4, inset: 3, edge: 6,
             palette: ["#fcba03"], bg: "#000000", fg: "#000000", accent: "#ffeb8a" } },
  { id: "jk-aurora", label: "Aurora", desc: "JaKooLit · teal and violet",
    style: { shape: "round", solid: true, colors: "cycle", gap: 5, inset: 3, edge: 6,
             palette: ["#95e6cb", "#d2a6ff", "#c6a0f6", "#89dceb"], bg: "#11111b", fg: "#11111b", accent: "#95e6cb" } },
  { id: "jk-aurora-blossom", label: "Aurora Blossom", desc: "JaKooLit · purple, periwinkle, sapphire",
    style: { shape: "round", solid: true, colors: "cycle", gap: 5, inset: 3, edge: 6,
             palette: ["#8839ef", "#7287fd", "#209fb5"], bg: "#11111b", fg: "#eff1f5", accent: "#7287fd" } },
  { id: "jk-crimson", label: "Crimson", desc: "JaKooLit · oxblood blocks",
    style: { shape: "block", solid: true, colors: "cycle", gap: 3, inset: 3, edge: 6,
             palette: ["#6c1212", "#470e0e", "#8b1a1a"], bg: "#240303", fg: "#d8dee9", accent: "#f53c3c" } },
  { id: "jk-purpl", label: "Purpl", desc: "JaKooLit · mauve on plum",
    style: { shape: "round", solid: false, tint: 0.45, colors: "mono", gap: 5, inset: 3, edge: 6,
             palette: ["#cba6f7"], bg: "#20052a", fg: "#cba6f7", accent: "#cba6f7" } },
  { id: "jk-mauve", label: "Mauve", desc: "JaKooLit · solid mauve on charcoal",
    style: { shape: "round", solid: true, colors: "mono", gap: 5, inset: 3, edge: 6,
             palette: ["#cba6f7"], bg: "#1e1e1e", fg: "#1e1e2e", accent: "#cba6f7" } },
  { id: "jk-rainbow-spectrum", label: "Rainbow Spectrum", desc: "JaKooLit · every Catppuccin hue",
    style: { shape: "round", solid: true, colors: "cycle", gap: 4, inset: 3, edge: 6,
             palette: ["#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#89dceb", "#b4befe", "#cba6f7", "#f5c2e7"],
             bg: "#3a3b3c", fg: "#313244", accent: "#b4befe" } },
  { id: "jk-arrow", label: "Arrow", desc: "JaKooLit · gruvbox powerline",
    style: { shape: "arrow", solid: true, colors: "cycle", gap: 0, flatEnds: true, depth: 0.5,
             palette: ["#fb4934", "#b8bb26", "#fabd2f", "#83a598", "#d3869b", "#8ec07c"],
             bg: "#282828", fg: "#1d2021", accent: "#fabd2f" } },
  { id: "jk-half-moon", label: "Half-Moon", desc: "JaKooLit · Ayu pills on deep navy",
    style: { shape: "round", solid: true, colors: "cycle", gap: 6, inset: 2, edge: 4, float: 6,
             palette: ["#59c2ff", "#d2a6ff", "#95e6cb", "#e6b673", "#f07178"], bg: "#0f1419", fg: "#0f1419", accent: "#59c2ff" } },
  { id: "jk-oglo-chicklets", label: "Oglo Chicklets", desc: "JaKooLit · forest-green chiclets",
    style: { shape: "block", solid: true, colors: "cycle", gap: 3, inset: 3, edge: 6,
             palette: ["#778f52", "#5d743e", "#2a5c45", "#ca4853"], bg: "#2d353b", fg: "#ffffff", accent: "#66cc99" } },
  { id: "jk-everforest", label: "EverForest", desc: "JaKooLit · warm Everforest tiles",
    style: { shape: "block", solid: true, colors: "cycle", gap: 3, inset: 3, edge: 6,
             palette: ["#a7c080", "#7fbbb3", "#d699b6", "#dbbc7f", "#e69875", "#e67e80"], bg: "#2d353b", fg: "#2d353b", accent: "#a7c080" } },
  { id: "jk-simple-pink", label: "Simple Pink", desc: "JaKooLit · rose pills",
    style: { shape: "round", solid: true, colors: "mono", gap: 6, inset: 3, edge: 6,
             palette: ["#ba5663"], bg: "#11111b", fg: "#ffffff", accent: "#c42a60" } },
  { id: "jk-monochrome", label: "Monochrome", desc: "JaKooLit · black and white",
    style: { shape: "round", solid: false, tint: 0.18, colors: "mono", gap: 5, inset: 3, edge: 6,
             palette: ["#cdd6f4"], bg: "#000000", fg: "#cdd6f4", accent: "#ffffff" } },
  { id: "jk-prismatic-glow", label: "Prismatic Glow", desc: "JaKooLit · pink-to-cyan neon slants",
    style: { shape: "slant", solid: true, colors: "cycle", gap: 3, inset: 2, edge: 6,
             palette: ["#fa8bff", "#2bd2ff", "#00eeff"], bg: "#000000", fg: "#000000", accent: "#2bd2ff" } },
  { id: "jk-retro", label: "Retro", desc: "JaKooLit · gruvbox tiles, square and simple",
    style: { shape: "block", solid: false, tint: 0.3, colors: "cycle", gap: 2, inset: 3, edge: 6,
             palette: ["#fb4934", "#b8bb26", "#fabd2f", "#ebdbb2"], bg: "#1d2021", fg: "#ebdbb2", accent: "#fabd2f" } },
  { id: "jk-rgb-bordered", label: "RGB", desc: "JaKooLit · indigo, magenta, aqua",
    style: { shape: "block", solid: false, tint: 0.38, colors: "cycle", gap: 3, inset: 3, edge: 6,
             palette: ["#3c00b3", "#ea00ff", "#00f7c6"], bg: "#0a0614", fg: "#ffffff", accent: "#00f7c6" } },
  { id: "jk-chroma-tally", label: "Chroma Tally", desc: "JaKooLit (Wallust) · tinted tiles in your theme colours",
    style: { shape: "block", solid: false, tint: 0.32, colors: "cycle", gap: 3, inset: 3, edge: 6 } },
  { id: "jk-ml4w-modern", label: "ML4W Modern", desc: "JaKooLit (Wallust) · floating solid pills in your theme colours",
    style: { shape: "round", solid: true, colors: "cycle", gap: 6, inset: 2, edge: 4, float: 6 } },
  { id: "jk-crystal-clear", label: "Crystal Clear", desc: "JaKooLit (Wallust) · faint glass pills",
    style: { shape: "round", solid: false, tint: 0.14, colors: "mono", gap: 6, inset: 2, edge: 4, float: 6, palette: ["foreground"] } }
]

// ------------------------------------------------------------------ base16

// Thirty base16-style schemes: [label, background, foreground, red, orange,
// yellow, green, cyan, blue, purple]. Each becomes a solid chevron theme.
var BASE16_DATA = [
  ["Ayu Dark", "#0b0e14", "#bfbdb6", "#f07178", "#ff8f40", "#e6b450", "#aad94c", "#95e6cb", "#59c2ff", "#d2a6ff"],
  ["Catppuccin Frappé", "#303446", "#c6d0f5", "#e78284", "#ef9f76", "#e5c890", "#a6d189", "#81c8be", "#8caaee", "#ca9ee6"],
  ["Catppuccin Latte", "#eff1f5", "#4c4f69", "#d20f39", "#fe640b", "#df8e1d", "#40a02b", "#179299", "#1e66f5", "#8839ef"],
  ["Catppuccin Macchiato", "#24273a", "#cad3f5", "#ed8796", "#f5a97f", "#eed49f", "#a6da95", "#8bd5ca", "#8aadf4", "#c6a0f6"],
  ["Catppuccin Mocha", "#1e1e2e", "#cdd6f4", "#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#94e2d5", "#89b4fa", "#cba6f7"],
  ["Default Dark", "#181818", "#d8d8d8", "#ab4642", "#dc9656", "#f7ca88", "#a1b56c", "#86c1b9", "#7cafc2", "#ba8baf"],
  ["Dracula", "#282a36", "#f8f8f2", "#ff5555", "#ffb86c", "#f1fa8c", "#50fa7b", "#8be9fd", "#bd93f9", "#ff79c6"],
  ["Eighties", "#2d2d2d", "#cccccc", "#f2777a", "#f99157", "#ffcc66", "#99cc99", "#66cccc", "#6699cc", "#cc99cc"],
  ["Everforest Dark", "#2d353b", "#d3c6aa", "#e67e80", "#e69875", "#dbbc7f", "#a7c080", "#83c092", "#7fbbb3", "#d699b6"],
  ["GitHub Dark", "#0d1117", "#c9d1d9", "#ff7b72", "#ffa657", "#e3b341", "#7ee787", "#a5d6ff", "#79c0ff", "#d2a8ff"],
  ["Gruvbox Dark Hard", "#1d2021", "#ebdbb2", "#fb4934", "#fe8019", "#fabd2f", "#b8bb26", "#8ec07c", "#83a598", "#d3869b"],
  ["Gruvbox Dark Medium", "#282828", "#ebdbb2", "#fb4934", "#fe8019", "#fabd2f", "#b8bb26", "#8ec07c", "#83a598", "#d3869b"],
  ["Gruvbox Light", "#fbf1c7", "#3c3836", "#9d0006", "#af3a03", "#b57614", "#79740e", "#427b58", "#076678", "#8f3f71"],
  ["Horizon Dark", "#1c1e26", "#cbced0", "#e95678", "#fab795", "#fac29a", "#29d398", "#59e1e3", "#26bbd9", "#ee64ac"],
  ["Kanagawa", "#1f1f28", "#dcd7ba", "#c34043", "#ffa066", "#c0a36e", "#76946a", "#6a9589", "#7e9cd8", "#957fb8"],
  ["Material", "#263238", "#eeffff", "#f07178", "#f78c6c", "#ffcb6b", "#c3e88d", "#89ddff", "#82aaff", "#c792ea"],
  ["Material Palenight", "#292d3e", "#a6accd", "#f07178", "#f78c6c", "#ffcb6b", "#c3e88d", "#89ddff", "#82aaff", "#c792ea"],
  ["Monokai", "#272822", "#f8f8f2", "#f92672", "#fd971f", "#f4bf75", "#a6e22e", "#a1efe4", "#66d9ef", "#ae81ff"],
  ["Nord", "#2e3440", "#d8dee9", "#bf616a", "#d08770", "#ebcb8b", "#a3be8c", "#88c0d0", "#81a1c1", "#b48ead"],
  ["Nova", "#3c4c55", "#c5d4dd", "#df8c8c", "#f2c38f", "#dada93", "#a8ce93", "#7fc1ca", "#83afe5", "#9a93e1"],
  ["Oceanic Next", "#1b2b34", "#cdd3de", "#ec5f67", "#f99157", "#fac863", "#99c794", "#5fb3b3", "#6699cc", "#c594c5"],
  ["One Dark", "#282c34", "#abb2bf", "#e06c75", "#d19a66", "#e5c07b", "#98c379", "#56b6c2", "#61afef", "#c678dd"],
  ["One Light", "#fafafa", "#383a42", "#ca1243", "#d75f00", "#c18401", "#50a14f", "#0184bc", "#4078f2", "#a626a4"],
  ["Rosé Pine", "#191724", "#e0def4", "#eb6f92", "#f6c177", "#ebbcba", "#31748f", "#9ccfd8", "#c4a7e7", "#c4a7e7"],
  ["Seti UI", "#151718", "#d6d6d6", "#cd3f45", "#db7b55", "#e6cd69", "#9fca56", "#55dbbe", "#55b5db", "#a074c4"],
  ["Solarized Dark", "#002b36", "#93a1a1", "#dc322f", "#cb4b16", "#b58900", "#859900", "#2aa198", "#268bd2", "#6c71c4"],
  ["Solarized Light", "#fdf6e3", "#586e75", "#dc322f", "#cb4b16", "#b58900", "#859900", "#2aa198", "#268bd2", "#6c71c4"],
  ["Tokyo Night", "#1a1b26", "#c0caf5", "#f7768e", "#ff9e64", "#e0af68", "#9ece6a", "#7dcfff", "#7aa2f7", "#bb9af7"],
  ["Tomorrow Night", "#1d1f21", "#c5c8c6", "#cc6666", "#de935f", "#f0c674", "#b5bd68", "#8abeb7", "#81a2be", "#b294bb"],
  ["Zenburn", "#383838", "#dcdccc", "#dca3a3", "#dfaf8f", "#e0cf9f", "#5f7f5f", "#93e0e3", "#7cb8bb", "#dc8cc3"],
  ["Synthwave 84", "#262335", "#ffffff", "#fe4450", "#f97e72", "#fede5d", "#72f1b8", "#36f9f6", "#2ee2fa", "#ff7edb"],
  ["Night Owl", "#011627", "#d6deeb", "#ef5350", "#f78c6c", "#ffcb8b", "#22da6e", "#7fdbca", "#82aaff", "#c792ea"],
  ["Oxocarbon", "#161616", "#f2f4f8", "#ee5396", "#ff7eb6", "#ffe97b", "#42be65", "#3ddbd9", "#78a9ff", "#be95ff"],
  ["Nightfox", "#192330", "#cdcecf", "#c94f6d", "#f4a261", "#dbc074", "#81b29a", "#63cdcf", "#719cd6", "#9d79d6"],
  ["Moonfly", "#080808", "#bdbdbd", "#ff5454", "#de935f", "#e3c78a", "#8cc85f", "#79dac8", "#80a0ff", "#cf87e8"],
  ["Cyberdream", "#16181a", "#ffffff", "#ff6e5e", "#ffbd5e", "#f1ff5e", "#5eff6c", "#5ef1ff", "#5ea1ff", "#bd5eff"],
  ["Vesper", "#101010", "#ffffff", "#f5a191", "#ffc799", "#e6b99d", "#90b99f", "#99ffe4", "#aca1cf", "#e29eca"],
  ["Matrix", "#000000", "#00ff41", "#ff3333", "#c0ff00", "#e6ff00", "#00ff41", "#00e5a0", "#00b3ff", "#9d4dff"]
]

var BASE16 = BASE16_DATA.map(function(d) {
  return {
    id: "base16-" + d[0].toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""),
    label: d[0],
    desc: "base16 · " + d[1],
    base16: true,
    style: { shape: "arrow", solid: true, colors: "cycle", gap: 1, flatEnds: true, depth: 0.42,
             palette: [d[7], d[8], d[6], d[5], d[4], d[3]], bg: d[1], fg: d[1], accent: d[7] }
  }
}).sort(function(a, b) { return a.label < b.label ? -1 : (a.label > b.label ? 1 : 0) })

// ------------------------------------------------------------------ import / export

var STYLE_KEYS = ["shape", "solid", "tint", "colors", "palette", "gap", "inset", "depth", "edge", "flatEnds",
  "float", "pad", "size", "radius", "fontFamily", "bg", "fg", "accent", "regions", "modules",
  "minContrast", "outline", "outlineColor", "shadow", "backdrop",
  "barOpacity", "segmentOpacity", "hoverColor", "hoverOpacity", "iconFont"]

// Keep only known style keys so an imported file cannot smuggle in other config.
function sanitizeStyle(style) {
  var out = {}
  if (!style || typeof style !== "object") return out
  for (var i = 0; i < STYLE_KEYS.length; i++) {
    var k = STYLE_KEYS[i], v = style[k]
    if (v === undefined || v === null) continue
    if (k === "bg" || k === "fg" || k === "accent" || k === "outlineColor" || k === "hoverColor") { if (isHex(v)) out[k] = v }
    else if (k === "palette") { if (isList(v)) out[k] = Array.prototype.slice.call(v).map(String) }
    else if (k === "regions" || k === "modules") { if (typeof v === "object") out[k] = JSON.parse(JSON.stringify(v)) }
    else if (k === "shape" || k === "colors" || k === "fontFamily" || k === "iconFont") out[k] = String(v)
    else if (k === "solid" || k === "flatEnds") out[k] = v === true
    else if (typeof v === "number" && isFinite(v)) out[k] = v
  }
  return out
}

function slug(label) {
  return String(label || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
}

// Accepts an export file, a bare theme, or an array of themes.
// Returns [{label, desc, style}] (possibly empty).
function parseImport(text) {
  var data
  try { data = JSON.parse(text) } catch (e) { return [] }
  var list = data && data.themes ? data.themes : (Array.isArray(data) ? data : [data])
  var out = []
  for (var i = 0; i < list.length; i++) {
    var t = list[i]
    if (!t || typeof t !== "object" || !t.style) continue
    var label = String(t.label || t.name || "Imported").slice(0, 32)
    out.push({ label: label, desc: "Imported", style: sanitizeStyle(t.style) })
  }
  return out
}

function exportJson(themes) {
  return JSON.stringify({ omabar16: 1, themes: themes.map(function(t) {
    return { label: t.label, desc: t.desc, style: t.style }
  }) }, null, 2)
}

// ------------------------------------------------------------------ layouts

function w(id, extra) {
  var o = { id: id }
  if (extra) for (var k in extra) o[k] = extra[k]
  return o
}

function clock(fmt) {
  return { id: "omarchy.clock", format: fmt || "dddd HH:mm", formatAlt: "d MMMM 'W'ww yyyy", verticalFormat: "HH\n—\nmm" }
}

var LAYOUTS = [
  { id: "default", label: "Default", desc: "Menu and workspaces left, clock centre, status right", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.menu"), w("omarchy.workspaces")],
              center: [w("omarchy.indicators"), clock(), w("omarchy.keyboard-layout"), w("omarchy.weather"), w("omarchy.system-update")],
              right: [w("omarchy.tray"), w("omarchy.agents"), w("omarchy.bluetooth"), w("omarchy.network"), w("omarchy.audio"), w("omarchy.monitor"), w("omarchy.power")] } },
  { id: "minimal", label: "Minimal", desc: "Only what you glance at", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.menu"), w("omarchy.workspaces")], center: [clock("HH:mm")],
              right: [w("omarchy.network"), w("omarchy.audio"), w("omarchy.power")] } },
  { id: "full", label: "Full", desc: "Everything, media included", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.menu"), w("omarchy.workspaces"), w("omarchy.active-window")],
              center: [w("omarchy.indicators"), w("omarchy.media"), clock(), w("omarchy.weather"), w("omarchy.keyboard-layout"), w("omarchy.system-update")],
              right: [w("omarchy.tray"), w("omarchy.agents"), w("omarchy.microphone"), w("omarchy.bluetooth"), w("omarchy.network"), w("omarchy.audio"), w("omarchy.monitor"), w("omarchy.power")] } },
  { id: "dev", label: "Dev", desc: "Window title next to workspaces, agents and display on the right", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.menu"), w("omarchy.workspaces"), w("omarchy.active-window")], center: [clock("ddd HH:mm")],
              right: [w("omarchy.tray"), w("omarchy.agents"), w("omarchy.monitor"), w("omarchy.network"), w("omarchy.power")] } },
  { id: "dock", label: "Dock", desc: "One centred cluster, empty flanks", anchor: "omarchy.clock",
    layout: { left: [], center: [w("omarchy.menu"), w("omarchy.workspaces"), clock("HH:mm"), w("omarchy.network"), w("omarchy.audio"), w("omarchy.power")], right: [] } },
  { id: "split", label: "Split", desc: "Clock moves right, weather left", anchor: "",
    layout: { left: [w("omarchy.menu"), w("omarchy.workspaces"), w("omarchy.weather")], center: [],
              right: [w("omarchy.tray"), w("omarchy.bluetooth"), w("omarchy.network"), w("omarchy.audio"), clock("HH:mm"), w("omarchy.power")] } },
  { id: "focus", label: "Focus", desc: "Workspaces and a clock. Nothing else.", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.workspaces")], center: [clock("HH:mm")], right: [] } },

  // More arrangements. A preset with a position also moves the bar to that edge.
  { id: "centred-workspaces", label: "Centred Workspaces", desc: "Menu left, workspaces in the middle, clock with the status icons", anchor: "omarchy.workspaces",
    layout: { left: [w("omarchy.menu"), w("omarchy.active-window")], center: [w("omarchy.workspaces")],
              right: [w("omarchy.tray"), w("omarchy.network"), w("omarchy.audio"), clock("HH:mm"), w("omarchy.power")] } },
  { id: "menubar", label: "Menubar", desc: "Menu and window title left, status and a long date right", anchor: "",
    layout: { left: [w("omarchy.menu"), w("omarchy.active-window")], center: [],
              right: [w("omarchy.tray"), w("omarchy.indicators"), w("omarchy.bluetooth"), w("omarchy.network"), w("omarchy.audio"),
                      clock("ddd d MMM HH:mm"), w("omarchy.power")] } },
  { id: "gnome", label: "Activities", desc: "Workspaces left, date and time centred, a short status corner", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.workspaces")], center: [clock("ddd d MMM HH:mm")],
              right: [w("omarchy.tray"), w("omarchy.network"), w("omarchy.audio"), w("omarchy.power")] } },
  { id: "mirrored", label: "Mirrored", desc: "Status on the left, menu and workspaces on the right", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.power"), w("omarchy.audio"), w("omarchy.network"), w("omarchy.bluetooth"), w("omarchy.tray")],
              center: [clock()], right: [w("omarchy.workspaces"), w("omarchy.menu")] } },
  { id: "media-centre", label: "Media Centre", desc: "Now playing in the middle, clock beside the volume", anchor: "omarchy.media",
    layout: { left: [w("omarchy.menu"), w("omarchy.workspaces")], center: [w("omarchy.media")],
              right: [w("omarchy.audio"), w("omarchy.network"), clock("HH:mm"), w("omarchy.power")] } },
  { id: "monitor", label: "Monitor", desc: "Window title left, every status icon on the right", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.workspaces"), w("omarchy.active-window")], center: [clock()],
              right: [w("omarchy.indicators"), w("omarchy.system-update"), w("omarchy.monitor"), w("omarchy.bluetooth"),
                      w("omarchy.network"), w("omarchy.microphone"), w("omarchy.audio"), w("omarchy.power")] } },
  { id: "streamer", label: "Streamer", desc: "Recording, mic and media in the middle, where you can see them", anchor: "",
    layout: { left: [w("omarchy.workspaces"), w("omarchy.active-window")],
              center: [w("omarchy.indicators"), w("omarchy.microphone"), w("omarchy.media")],
              right: [w("omarchy.audio"), w("omarchy.network"), clock("HH:mm"), w("omarchy.power")] } },
  { id: "world-clock", label: "World Clock", desc: "Your clock and other time zones side by side", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.menu"), w("omarchy.workspaces")], center: [clock(), w("omarchy.elsewhen")],
              right: [w("omarchy.tray"), w("omarchy.network"), w("omarchy.audio"), w("omarchy.power")] } },
  { id: "zen", label: "Zen", desc: "Only the time, in the middle", anchor: "omarchy.clock",
    layout: { left: [], center: [clock("HH:mm")], right: [] } },
  { id: "taskbar", label: "Taskbar", desc: "Bottom bar: menu and windows left, tray and time right", anchor: "", position: "bottom",
    layout: { left: [w("omarchy.menu"), w("omarchy.workspaces"), w("omarchy.active-window")], center: [],
              right: [w("omarchy.tray"), w("omarchy.network"), w("omarchy.audio"), clock("HH:mm"), w("omarchy.power")] } },
  { id: "bottom-dock", label: "Bottom Dock", desc: "Bottom bar with one centred cluster", anchor: "omarchy.workspaces", position: "bottom",
    layout: { left: [], center: [w("omarchy.menu"), w("omarchy.workspaces"), clock("HH:mm"), w("omarchy.audio"), w("omarchy.power")], right: [] } },
  { id: "rail-left", label: "Left Rail", desc: "Side bar on the left: menu on top, clock in the middle, controls at the bottom", anchor: "omarchy.clock", position: "left",
    layout: { left: [w("omarchy.menu"), w("omarchy.workspaces")], center: [clock()],
              right: [w("omarchy.tray"), w("omarchy.network"), w("omarchy.audio"), w("omarchy.power")] } },
  { id: "rail-right", label: "Right Rail", desc: "The same rail on the right edge", anchor: "omarchy.clock", position: "right",
    layout: { left: [w("omarchy.menu"), w("omarchy.workspaces")], center: [clock()],
              right: [w("omarchy.tray"), w("omarchy.network"), w("omarchy.audio"), w("omarchy.power")] } },

  // Arrangements from JaKooLit's waybar configs (Hyprland-Dots, config/waybar/configs),
  // with each waybar module swapped for its nearest Omarchy widget.
  { id: "jk-default", label: "JaKooLit Default", desc: "Media and title left, launcher-workspaces-clock-weather centre", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.media"), w("omarchy.active-window")],
              center: [w("omarchy.menu"), w("omarchy.indicators"), w("omarchy.workspaces"), clock(), w("omarchy.weather")],
              right: [w("omarchy.tray"), w("omarchy.network"), w("omarchy.monitor"), w("omarchy.audio"), w("omarchy.power")] } },
  { id: "jk-simple", label: "JaKooLit Simple", desc: "Workspaces and media left, window title right", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.workspaces"), w("omarchy.tray"), w("omarchy.media")],
              center: [clock(), w("omarchy.indicators")],
              right: [w("omarchy.active-window"), w("omarchy.audio"), w("omarchy.power")] } },
  { id: "jk-sleek", label: "Sleek", desc: "Launcher, workspaces and media left, clock between indicators", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.menu"), w("omarchy.workspaces"), w("omarchy.media"), w("omarchy.tray")],
              center: [w("omarchy.indicators"), clock()],
              right: [w("omarchy.active-window"), w("omarchy.audio"), w("omarchy.monitor"), w("omarchy.power")] } },
  { id: "jk-minimal-short", label: "Minimal Short", desc: "Clock and weather left, workspaces centred", anchor: "",
    layout: { left: [clock(), w("omarchy.weather")],
              center: [w("omarchy.workspaces")],
              right: [w("omarchy.menu"), w("omarchy.tray"), w("omarchy.indicators"), w("omarchy.media"), w("omarchy.network"),
                      w("omarchy.bluetooth"), w("omarchy.monitor"), w("omarchy.audio"), w("omarchy.power")] } },
  { id: "jk-minimal-long", label: "Minimal Long", desc: "Everything left, a lone clock, essentials right", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.menu"), w("omarchy.workspaces"), w("omarchy.media"), w("omarchy.indicators"), w("omarchy.tray")],
              center: [clock()],
              right: [w("omarchy.monitor"), w("omarchy.power"), w("omarchy.audio")] } },
  { id: "jk-camellia", label: "Camellia", desc: "Window title centred, clock among the status icons", anchor: "",
    layout: { left: [w("omarchy.workspaces"), w("omarchy.media"), w("omarchy.indicators"), w("omarchy.tray")],
              center: [w("omarchy.active-window")],
              right: [w("omarchy.monitor"), w("omarchy.audio"), w("omarchy.power"), clock(), w("omarchy.network")] } },
  { id: "jk-peony", label: "Peony", desc: "Workspaces and media left, clock alone in the middle", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.workspaces"), w("omarchy.media"), w("omarchy.indicators"), w("omarchy.tray")],
              center: [clock()],
              right: [w("omarchy.power"), w("omarchy.monitor"), w("omarchy.audio"), w("omarchy.network")] } },
  { id: "jk-gardenia", label: "Gardenia", desc: "Clock first, workspaces centred, a short right side", anchor: "",
    layout: { left: [clock(), w("omarchy.media"), w("omarchy.tray"), w("omarchy.indicators")],
              center: [w("omarchy.workspaces")],
              right: [w("omarchy.audio"), w("omarchy.monitor"), w("omarchy.power")] } },
  { id: "jk-0-ja-0", label: "0-Ja-0", desc: "Clock and title left, launcher with workspaces centred", anchor: "",
    layout: { left: [w("omarchy.indicators"), w("omarchy.tray"), clock(), w("omarchy.active-window")],
              center: [w("omarchy.menu"), w("omarchy.workspaces")],
              right: [w("omarchy.monitor"), w("omarchy.audio"), w("omarchy.media"), w("omarchy.power")] } },
  { id: "jk-arrow", label: "Arrow", desc: "Two-sided powerline, clock at the far right", anchor: "",
    layout: { left: [w("omarchy.workspaces"), w("omarchy.active-window")],
              center: [],
              right: [w("omarchy.audio"), w("omarchy.network"), w("omarchy.monitor"), w("omarchy.power"), w("omarchy.tray"),
                      w("omarchy.indicators"), clock()] } },
  { id: "jk-everforest", label: "Everforest", desc: "Launcher and workspaces left, system cluster right", anchor: "omarchy.clock",
    layout: { left: [w("omarchy.menu"), w("omarchy.workspaces"), w("omarchy.indicators"), w("omarchy.tray")],
              center: [clock(), w("omarchy.system-update")],
              right: [w("omarchy.monitor"), w("omarchy.power"), w("omarchy.audio")] } },
  { id: "jk-simpliest", label: "Simpliest", desc: "Workspaces, a centred title, indicators", anchor: "",
    layout: { left: [w("omarchy.workspaces"), w("omarchy.tray"), w("omarchy.media")],
              center: [w("omarchy.active-window")],
              right: [w("omarchy.indicators")] } },
  { id: "jk-westwing", label: "WestWing", desc: "Made for a side bar: clock on top, controls at the bottom", anchor: "",
    layout: { left: [clock()],
              center: [w("omarchy.workspaces")],
              right: [w("omarchy.media"), w("omarchy.tray"), w("omarchy.indicators"), w("omarchy.monitor"),
                      w("omarchy.microphone"), w("omarchy.audio"), w("omarchy.power"), w("omarchy.menu")] } }
]

// Looks and arrangements converted from HANCORE-linux/waybar-themes (see Hancore.js).
var HANCORE = Hancore.THEMES
var HANCORE_LAYOUTS = Hancore.LAYOUTS
var ALL_LAYOUTS = LAYOUTS.concat(HANCORE_LAYOUTS)

var POSITIONS = [
  { id: "top", label: "Top" },
  { id: "bottom", label: "Bottom" },
  { id: "left", label: "Left" },
  { id: "right", label: "Right" }
]

// ------------------------------------------------------------------ modules

var GLYPHS = {
  "omarchy.menu": "\u{F01C9}", "omarchy.workspaces": "\u{F0570}", "omarchy.active-window": "\u{F05B2}",
  "omarchy.clock": "\u{F0954}", "omarchy.weather": "\u{F0599}", "omarchy.bluetooth": "\u{F00AF}",
  "omarchy.network": "\u{F05A9}", "omarchy.audio": "\u{F057E}", "omarchy.microphone": "\u{F036C}",
  "omarchy.power": "\u{F0079}", "omarchy.monitor": "\u{F0379}", "omarchy.keyboard-layout": "\u{F030C}",
  "omarchy.media": "\u{F0386}", "omarchy.tray": "\u{F003B}", "omarchy.agents": "\u{F06A9}",
  "omarchy.indicators": "\u{F0026}", "omarchy.system-update": "\u{F06B0}", "omarchy.spacer": "\u{F01D8}",
  "omarchy.tailscale": "\u{F0483}", "omarchy.dropbox": "\u{F01E3}", "xyzlab.alienware": "\u{F08AE}",
  "robzolkos.agent-usage": "\u{F06A9}"
}

function glyphFor(id) {
  return GLYPHS[id] || "\u{F0B47}"
}

function shortName(id) {
  var s = String(id).replace(/^[^.]*\./, "").replace(/-/g, " ")
  return s.charAt(0).toUpperCase() + s.slice(1)
}

// ------------------------------------------------------------------ colour maths

function isHex(v) {
  return typeof v === "string" && /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/.test(v)
}

function parseHex(hex) {
  var h = String(hex).replace("#", "")
  return [parseInt(h.substr(0, 2), 16), parseInt(h.substr(2, 2), 16), parseInt(h.substr(4, 2), 16)]
}

function toHex(rgb) {
  function c(v) {
    var s = Math.max(0, Math.min(255, Math.round(v))).toString(16)
    return s.length < 2 ? "0" + s : s
  }
  return "#" + c(rgb[0]) + c(rgb[1]) + c(rgb[2])
}

function mix(a, b, t) {
  var x = parseHex(a), y = parseHex(b)
  return toHex([x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t])
}

function darker(hex, f) {
  var x = parseHex(hex)
  return toHex([x[0] / f, x[1] / f, x[2] / f])
}

function lighter(hex, f) {
  var x = parseHex(hex)
  return toHex([x[0] * f, x[1] * f, x[2] * f])
}

function distance(a, b) {
  var x = parseHex(a), y = parseHex(b)
  return Math.sqrt(Math.pow((x[0] - y[0]) / 255, 2) + Math.pow((x[1] - y[1]) / 255, 2) + Math.pow((x[2] - y[2]) / 255, 2))
}

function luminance(hex) {
  var x = parseHex(hex)
  return (0.2126 * x[0] + 0.7152 * x[1] + 0.0722 * x[2]) / 255
}

// HSV <-> hex, used by the colour picker.
function hexToHsv(hex) {
  var c = parseHex(hex), r = c[0] / 255, g = c[1] / 255, b = c[2] / 255
  var max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min
  var h = 0
  if (d !== 0) {
    if (max === r) h = ((g - b) / d) % 6
    else if (max === g) h = (b - r) / d + 2
    else h = (r - g) / d + 4
    h /= 6
    if (h < 0) h += 1
  }
  return { h: h, s: max === 0 ? 0 : d / max, v: max }
}

function hsvToHex(h, s, v) {
  var i = Math.floor(h * 6), f = h * 6 - i
  var p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s)
  var r, g, b
  switch (((i % 6) + 6) % 6) {
    case 0: r = v; g = t; b = p; break
    case 1: r = q; g = v; b = p; break
    case 2: r = p; g = v; b = t; break
    case 3: r = p; g = q; b = v; break
    case 4: r = t; g = p; b = v; break
    default: r = v; g = p; b = q
  }
  return toHex([r * 255, g * 255, b * 255])
}

// ------------------------------------------------------------------ palette

function parseColorsToml(text) {
  var out = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*["'](#[0-9A-Fa-f]{6})["']/)
    if (m) out[m[1]] = m[2]
  }
  return out
}

var DEFAULT_PALETTE = ["accent", "blue", "magenta", "green", "yellow", "cyan"]

function themeHue(t, name) {
  var n = String(name)
  var alias = {
    accent: ["accent"], red: ["red", "color1"], green: ["green", "color2"], yellow: ["yellow", "color3"],
    blue: ["blue", "color4", "color12"], magenta: ["magenta", "color5", "color13"],
    cyan: ["cyan", "color6", "color14"], orange: ["orange", "color9"], foreground: ["foreground"]
  }
  var keys = alias[n] || [n]
  for (var i = 0; i < keys.length; i++) if (t[keys[i]]) return t[keys[i]]
  return isHex(n) ? n : null
}

// Mirrors Bar.qml's buildPalette() so previews match the real bar.
function buildPalette(themeColors, names, background) {
  var list = isList(names) && names.length > 0 ? names : DEFAULT_PALETTE
  var out = []
  for (var i = 0; i < list.length; i++) {
    var literal = isHex(String(list[i]))
    var hex = themeHue(themeColors, list[i])
    if (!hex) continue
    if (literal) { out.push(hex); continue }
    if (distance(hex, background) < 0.14) continue
    var dup = false
    for (var j = 0; j < out.length; j++) if (distance(hex, out[j]) < 0.09) dup = true
    if (!dup) out.push(hex)
  }
  if (out.length === 0) out.push(themeColors.accent || "#888888")
  var base = out[0]
  var ramp = [darker(base, 1.4), lighter(base, 1.3), darker(base, 1.8)]
  for (var k = 0; out.length < 3; k++) out.push(ramp[k % ramp.length])
  return out
}

// Resolve every colour a style would use, against the active theme.
//   defaults: { background, foreground, accent }  (the theme's bar colours)
function resolve(style, themeColors, defaults) {
  var s = style || {}
  var bg = isHex(s.bg) ? s.bg : defaults.background
  var fg = isHex(s.fg) ? s.fg : null
  var solid = s.solid !== false
  var palette = buildPalette(themeColors, s.palette, bg)
  return {
    bg: bg,
    fg: fg,
    accent: isHex(s.accent) ? s.accent : defaults.accent,
    solid: solid,
    tint: s.tint === undefined ? 0.3 : s.tint,
    text: solid ? (fg || bg) : (fg || defaults.foreground),
    palette: palette,
    style: s
  }
}

function segmentBase(res, region, idx, count, id) {
  var s = res.style
  if (s.modules && isHex(s.modules[id])) return s.modules[id]
  if (s.regions && isHex(s.regions[region])) return s.regions[region]
  var p = res.palette
  var i = idx < 0 ? 0 : idx
  if (s.colors === "mono") return i % 2 === 0 ? p[0] : mix(p[0], res.bg, 0.28)
  var k = region === "right" ? (count - 1 - i) : (region === "center" ? i + 1 : i)
  return p[((k % p.length) + p.length) % p.length]
}

function segmentFill(res, base, lit) {
  if (res.solid) return lit ? lighter(base, 1.14) : base
  return mix(res.bg, base, Math.min(1, res.tint + (lit ? 0.16 : 0)))
}

// ------------------------------------------------------------------ helpers

function clone(o) {
  return JSON.parse(JSON.stringify(o))
}

function laneOf(cfg, lane) {
  return cfg.layout && isList(cfg.layout[lane]) ? cfg.layout[lane] : []
}

function idsIn(cfg) {
  var out = []
  var lanes = ["left", "center", "right"]
  for (var i = 0; i < lanes.length; i++) {
    var l = laneOf(cfg, lanes[i])
    for (var j = 0; j < l.length; j++) out.push(l[j].id)
  }
  return out
}

var SWATCHES = [
  "#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#94e2d5", "#89b4fa", "#b4befe", "#cba6f7",
  "#ff5555", "#ff9e64", "#ffb86c", "#50fa7b", "#8be9fd", "#7aa2f7", "#bd93f9", "#ff79c6",
  "#e06c75", "#d19a66", "#e5c07b", "#98c379", "#56b6c2", "#61afef", "#c678dd", "#be5046",
  "#ffffff", "#e8e8e8", "#bdbdbd", "#8a8a8a", "#5a5a5a", "#2e2e2e", "#151515", "#000000"
]
