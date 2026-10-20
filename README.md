# OMAcraft

One app for the skll Omarchy plugins. It installs, enables and places each
one in the Omarchy shell, and holds all of their settings, beside the
HyprLAUNCH launcher's styles, the HyprFIGZ configurator and HyprBUILDZ, the
hyprbuildz ISO builder.

| Page | What it covers | Where it comes from |
| --- | --- | --- |
| Plugins | Install, remove, enable, disable, and place on the bar (left, centre, right) | `omarchy plugin` and `omarchy bar` |
| Wallpaper | Browse wallhaven.cc (search, filters, API key), your downloaded library (right-click a wallpaper to delete it), your own folders, and ♥ favourites; set one with or without its colours; build the Omarchy theme from the wallpaper with the Material, matugen, wallbash, pywal or flavours scheme (the real `matugen`, `wal` and `flavours` when installed), mode, style, contrast, accent, which parts follow, fit and auto-change | `omacraft.studio` (its `hyprskin` command) |
| Animations | A live stage that plays the preset in use (or the one under the pointer) the way Hyprland would: a window opening, a workspace switch, the window closing, in its border, with the preset's own durations, curves and styles at your speed. **Presets** (each tile draws its curve and plays on hover), **Motion** (window and workspace shapes, each playing, and the speed), **Borders** (gradient borders, spinning or not) and **Lua** (what each preset writes); your own presets | `omacraft.animations` (its `omarchy-animations` script) |
| Window FX | Window open and close effects after the GNOME extension Burn My Windows: 27 of its effects plus two of our own, each tile playing the real shader; closing and opening lists picked at random, speed, intensity, colour, windows to leave alone, and the SUPER+W / SUPER+Q keys | `omacraft.burn` (its `effects.json` and shaders) |
| HyprDOCKN | A live stage with the dock drawn on its edge, magnifying under the pointer, and a peek at the agents panel. **Looks**: whole looks to hover and apply, every shape choice drawn, colours as swatches, magnify; **Items**: apps, commands, spacers and dividers, dragged into order, with the picked one's details; **Agents**: a card per agent with its tab switch, edited beside them; **Placement**: edge, monitor, gap, icon size, opacity, panel width, reserved space, start folder | `omacraft.agentdock` |
| Bar | All of omabar16, edited in the app, with no customizer overlay. A live stage shows the bar on its screen edge; hovering any tile previews it there. **Themes**: complete themes (originals, JaKooLit, HANCORE, base16, yours), or a *look* (shape, fill, spacing) and a *colour scheme* picked separately and mixed, or shuffled; save, import, export. **Layout**: a screen-edge picker, the three lanes with widgets dragged between them or in from the shelf, each widget's own icon, colours, fonts, opacity, clock format or spacer width, and preset layouts drawn as the bar they make. **Style**: every style key, shapes drawn, the palette colour by colour. **Folders**: folder trays on any bar, each opening into a row of the apps (or commands) you pick, on click or hover | `omabar16`, `omacraft.folders` |
| HyprLAUNCH | The launcher's layouts (live sketches in the current colours), colour schemes, how it opens (14 transitions, each with a playing demo), its speed, and gliding between layouts and colours | `omacraft.studio` (its `LauncherStyles.js`) |
| HyprSPLASH | omascii's designer: FIGlet, TheDraw, system fonts and images; layout, image, colour, palette and style options; intro effects grouped as core, more ttfx, the screensaver's own and presets of them, and omascii's originals, with a live player; your library; apply to boot | `omacraft.omascii` (its `omascii` command) |
| HyprFIGZ | The full HyprFIGZ configurator, generating for Omarchy (its Lua config, an Omarchy theme, the shell's bar, launcher and notifications) or for plain Hyprland; an Omarchy bundle downloaded here can be installed from the page | HyprFIGZ's built web app |
| HyprBUILDZ | Everything hyprbuildz does, with the build as a stage: profile → packages → files → options → ISO → USB, each step opening the tab that sets it, the Build button and its progress. **Profile** (live installer, minimal or "this desktop", and what comes along), **Contents** (name, hostname, packages, folders, edited files), **Options**, **Build log**; USB writing | built in |
| HyprKEYZ | The Alienware x15's per-key lighting: designs drawn with the keys, animations, painting key by key, colours of their own or the theme's (following every wallpaper), brightness, vividness, speed, and the lid logo and ring | AlienFlare (`alienflare` and its `alienflare.service`) |

## How it works

The bar and the dock have to live inside the Omarchy shell, so they stay
shell plugins. OMAcraft manages them from the outside, through the same
routes the plugins and Omarchy already offer:

- **Installing** links a plugin's code into `~/.config/omarchy/plugins`, or
  brings back one OMAcraft set aside. **Removing** disables it, then removes
  the link, or moves a real folder to `~/.local/share/omacraft/stash`.
  Nothing is ever deleted. Where each plugin's code lives is under *Code
  location* on its card, saved in `~/.config/omacraft/sources.json`.
- **Enabling, disabling and placing** run `omarchy plugin enable|disable` and
  `omarchy bar use|reset|put|move`, so the shell stays the one that writes
  `shell.json`.
- **Settings** go through each plugin's own command or IPC: `omarchy-animations`,
  `omascii` and `omarchy-shell agentdock set …`. When the dock isn't running,
  OMAcraft writes its `state.json` itself. HyprLAUNCH's style goes to
  `launcher-style.json`, rewritten in place so the launcher's file watcher
  stays on it.
- **The bar** is edited by OMAcraft itself. omabar16 draws whatever
  `shell.json`'s `bar` section says and follows that file, so OMAcraft keeps
  its own copy of the section (position, transparency, centre anchor, layout,
  style), changes it, and writes it back in place a moment after each edit,
  touching nothing else in the file. Undo, redo and Revert (to the bar as it
  was when OMAcraft opened) are OMAcraft's. Imported themes keep only
  omabar16's style keys. The themes and layouts are read from Studio's
  `bar/data/Presets.js` when it's there (it adds HANCORE), otherwise from
  omabar16's `data/Presets.js`; your themes stay in
  `~/.config/omarchy/omabar16/themes.json` and exports go to its `exports/`.
- **Window FX** writes `~/.config/omarchy/burn-my-windows.json` in place, which
  the shell plugin follows live, and draws its previews with the plugin's own
  compiled shaders. "Play on this window" asks the shell (`omarchy-shell burn
  preview`) to run the effect on OMAcraft's window; the close keys are switched
  with the plugin's `omarchy-burn keys on|off`.
- **Wallpaper** runs the Studio plugin's `hyprskin` for everything (search,
  library, favourites, colours, settings), so OMAcraft and the Studio hub
  always agree; the shell's Studio service draws the wallpaper.
- **Wallpaper colours reach OMAcraft's parts.** hyprskin's theme recolours
  whatever reads the Omarchy theme. The parts that keep colours of their own
  follow it once switched to their theme mode, under *OMAcraft's parts that
  follow too* on the Wallpaper page's colours tab: omabar16's style
  (hyprskin's `colorizeBar`), the window border (a `wallpaper` gradient
  OMAcraft writes to `animation-presets.json` from the theme's accent and
  hues), HyprDOCKN and Window FX (`theme`), HyprLAUNCH (the `omarchy`
  scheme) and HyprSPLASH (the theme's colour names). Turning wallpaper colours
  on makes them all follow. Each part's own colours are kept in
  `~/.config/omacraft/theme-sync.json` and come back when it stops following.
  OMAcraft installs a `theme-set` hook (`70-omacraft-colors`) that runs
  `omacraft --sync-colors` after every theme switch, so the border gradient
  follows each new wallpaper while OMAcraft is closed.
- **An underlined bar** leaves its text on the bar, but omabar16 draws it in
  `fg`, the dark segment ink in most of its themes. After a theme, shape or
  background change (and after every theme switch, through the hook) OMAcraft
  sets `fg` to a colour that reads on the bar when the old one doesn't. A text
  colour you set yourself is left alone.
- **Folder trays** are entries of the `omacraft.folders` bar widget in
  `shell.json`, one per folder, with its apps inline. `omarchy bar put` keeps a
  single copy of a widget, so OMAcraft adds, edits and removes folder entries
  in `shell.json` itself, rewritten in place so the shell reloads the bar. It
  touches nothing else there. The plugin's code is in `plugins/folders/`.
- **HyprFIGZ** (HyprCraft) runs in a web view, served from its build through a private
  `hyprcraft://` scheme. OMAcraft uses the installed plugin's `app/` folder,
  then `~/Projects/HyprCraft/omarchy-plugin/app`, then the copy the package
  carries. Exports are saved to `~/Downloads/HyprCraft`.
- **HyprBUILDZ** is hyprbuildz's code, and keeps its settings in
  `~/.config/hyprbuildz/config.json`.

HyprDOCKN needs one shell restart after updating it, so its new `set`
IPC call loads (*Restart shell* in the sidebar).

Every page follows the Omarchy theme's accent and updates when the plugins'
files change.

## Shortcuts

| Key | Action |
| --- | --- |
| `1` … `9`, `Ctrl 1` … `Ctrl 9` | Switch to the first nine pages |
| `Ctrl PgUp` / `Ctrl PgDn` | Previous / next page |
| `Ctrl R` | Restart the Omarchy shell |
| `Esc` | Close, dismiss, or leave a field |
| `Q`, `Ctrl Q` | Quit (asks first while an ISO builds) |
| `?` | Show the shortcuts, with the page's own |
| **Plugins** | |
| `↑` `↓` | Choose a plugin |
| `Space` | Enable or disable it |
| `I` / `Del` | Install / remove it |
| `L` `C` `R` | Place it on the left, centre or right of the bar |
| `Enter` | Open its settings |
| **Animations** | |
| `P` `M` `B` `L` | Presets, Motion, Borders, Lua |
| Arrows, `Space` | Choose a preset (it plays on the stage), apply it |
| `T` | Animations off, or back on |
| `+` `-` `0` | Faster, slower, preset speed |
| `Ctrl Z` / `Ctrl Shift Z` | Undo / redo |
| **Window FX** | |
| `C` / `O` | Edit the closing / opening effects |
| `P` | Play the picked effect on OMAcraft's own window |
| `R` | Any effect, at random |
| `E` | All window effects on or off |
| **HyprDOCKN** | |
| `L` `I` `A` `P` | Looks, Items, Agents, Placement |
| `Delete` | Take the picked item off the dock |
| `Space` / `S` | Show or hide the dock / its own settings card |
| **Wallpaper** | |
| `W` `L` `F` `D` `C` | Wallhaven, Library, Favourites, Folders, Colours |
| `N` | Next wallpaper |
| `T` | Rebuild Omarchy's colours from the wallpaper |
| `Ctrl F` | Search Wallhaven |
| Right-click | A wallpaper's options: keep colours, favourite, delete from the library |
| **Bar** | |
| `T` `L` `S` `F` | Themes, Layout, Style, Folders |
| `R` | Shuffle: a random look in random colours |
| `Delete` | Take the picked widget off the bar |
| `Ctrl Z` / `Ctrl Shift Z` | Undo / redo |
| **HyprLAUNCH** | |
| `L` / `Shift L` | Next / previous layout |
| `C` / `Shift C` | Next / previous colour scheme |
| `T` / `Shift T` | Next / previous transition |
| `R` | A random layout and scheme |
| `O` | Open the launcher |
| **HyprSPLASH** | |
| `↑` `↓` | Browse fonts, using each one |
| `Ctrl F` | Search |
| `Ctrl P` | Play the intro |
| `Ctrl S` | Save to My boot screens |
| `Ctrl Enter` | Apply to the boot screen |
| **HyprBUILDZ** | hyprbuildz's keys: `Space` build, `P` profile, `F` write to USB, and the rest under `?` |

`omacraft <page> [tab]` opens on a page: `plugins`, `wallpaper`, `animations`,
`effects`, `dock`, `bar`, `launcher`, `ascii`, `hyprcraft` or `iso`; e.g.
`omacraft wallpaper colors` or `omacraft bar folders` (the bar also takes
`looks`, `colours`, `layout`, `presets` and `style`; Animations `motion`,
`borders` and `lua`; the dock `items`, `agents` and `placement`; HyprBUILDZ
`contents`, `options` and `log`). Pages past the ninth
are reached with `Ctrl PgUp` / `Ctrl PgDn`.

## Development

```sh
bin/build     # build/omacraft
bin/test      # Qt Test, offscreen
bin/install   # makepkg -fsi, so it shows up in the launcher
```

`OMACRAFT_SCREENSHOT=out.png build/omacraft bar` saves the window after it
settles (or after `OMACRAFT_SCREENSHOT_DELAY` ms) and quits. With
`QT_QPA_PLATFORM=offscreen` it works without a display. The HyprFIGZ web
view only draws on a real one.
