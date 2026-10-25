# OmaCraft

One app for the skll Omarchy plugins. It installs, enables and places each
one in the Omarchy shell, and holds all of their settings, beside the
Launcher launcher's styles, the Dotfile Generator configurator and OmaBuilds, the
hyprbuildz ISO builder.

| Page | What it covers | Where it comes from |
| --- | --- | --- |
| Plugin Suite | The landing page, under OmaCraft's name in animated TheDraw block art: every plugin as a module to install, switch on or off and open, run from OmaCraft rather than from icons on the bar (*Move into OmaCraft* takes any that are still there off it); an inspector for the picked one's code location and removal; the built-in tools | `shell.json` (`plugins[]`, `disabledPlugins[]`), `omarchy bar use|reset` |
| Wallpapers | Browse wallhaven.cc (search, filters, API key), your downloaded library (right-click a wallpaper to delete it), your own folders, and ♥ favourites; set one with or without its colours; build the Omarchy theme from the wallpaper with the Material, matugen, wallbash, pywal or flavours scheme (the real `matugen`, `wal` and `flavours` when installed), mode, style, contrast, accent, which parts follow, fit and auto-change | `omacraft.studio` (its `hyprskin` command) |
| Window Transitions | A live stage that plays the preset in use (or the one under the pointer) the way Hyprland would: a window opening, a workspace switch, the window closing, in its border, with the preset's own durations, curves and styles at your speed. **Presets** (each tile draws its curve and plays on hover), **Motion** (window and workspace shapes, each playing, and the speed), **Borders** (gradient borders, spinning or not) and **Lua** (what each preset writes); your own presets | `omacraft.animations` (its `omarchy-animations` script) |
| Burn My Windows | Window open and close effects after the GNOME extension of the same name: 27 of its effects plus two of our own, each tile playing the real shader; closing and opening lists picked at random, speed, intensity, colour, windows to leave alone, and the SUPER+W / SUPER+Q keys | `omacraft.burn` (its `effects.json` and shaders) |
| Side Dock | A live stage with the dock drawn on its edge, magnifying under the pointer, and a peek at the agents panel. **Looks**: whole looks to hover and apply, every shape choice drawn, colours as swatches, magnify; **Items**: apps, commands, spacers and dividers, dragged into order, with the picked one's details; **Agents**: a card per agent with its tab switch, edited beside them; **Placement**: edge, monitor, gap, icon size, opacity, panel width, reserved space, start folder | `omacraft.agentdock` |
| Main Bar | All of omabar16, edited in the app, with no customizer overlay. A live stage shows the bar on its screen edge; hovering any tile previews it there, and its widgets can be dragged along it. **Themes**: complete themes (originals, JaKooLit, HANCORE, base16, yours) in their own colours or in the active Omarchy theme's (following every theme change), or a *look* (shape, fill, spacing) and a *colour scheme* picked separately and mixed, or shuffled; save, import, export. **Widgets**: the edge, transparency, float and padding in one strip, the three lanes with widgets dragged between them, onto the stage or in from the shelf, widgets hidden from the bar without touching their plugins (and shown again where they were, or dragged back), each widget's own icon, colours, fonts, opacity, clock format or spacer width, and preset layouts drawn as the bar they make. **Style**: every style key, shapes drawn, the palette colour by colour. **Folders**: folder trays on any bar, each opening into a row of the apps (or commands) you pick, on click or hover | `omabar16`, `omacraft.folders` |
| Launcher | The launcher's layouts (live sketches in the current colours), colour schemes, how it opens (14 transitions, each with a playing demo), its speed, and gliding between layouts and colours | `omacraft.studio` (its `LauncherStyles.js`) |
| ROFIoma | A studio for rofi-styled popups and swaync's notifications, each drawn live as rofi or swaync will draw it. **Power**: lock, logout, suspend, hibernate, reboot and shutdown after hyprdots' wlogout style 1 (or as a grid, list or pill), with each button's icon, name, command, letter and yes/no question; **Menus**: popups of your own, as lists, grids or rows of commands; **Emoji & Glyphs**: hyprdots-style pickers (search, recent first, Enter copies or types it) and an in-app mapper of every emoji and Nerd Font glyph; **Keybinds**: a cheatsheet read live from Hyprland; **Notifications**: swaync's position, sizes, timeouts and control-centre widgets, and handing notifications from the Omarchy shell to swaync and back; **Look**: the theme's colours or your own, font, corners, border and opacity. Each popup can have a key | `~/.config/omacraft/rofioma.json`, generating `~/.config/omacraft/rofioma/` (`.rasi` and `.sh` per popup), `~/.config/swaync/`, and `~/.config/hypr/omacraft_rofioma.lua`; needs `rofi`, `jq`, `wl-clipboard`, `wtype` and `swaync` |
| Boot Splash | omascii's designer: FIGlet, TheDraw, system fonts and images; layout, image, colour, palette and style options; intro effects grouped as core, more ttfx, the screensaver's own and presets of them, and omascii's originals, with a live player; your library; apply to boot | `omacraft.omascii` (its `omascii` command) |
| Screensaver | The Omarchy screensaver: its word or art (designed with omascii's FIGlet, TheDraw, system fonts or an image, Omarchy's logo, or the text as it is), Omarchy's own random effects or ones you pick from the same sets as the boot intros (ttfx, the screensaver presets, omascii's originals) with order, frame rate and rest, a live preview, on/off and the idle time. It never touches the boot screen | `~/.config/omarchy/branding/screensaver.txt`, `idle` in `shell.json`, and Screensaver's runner through a hook at `/usr/local/bin/omarchy-screensaver` (only for picked effects) |
| Dotfile Generator | The full Dotfile Generator configurator, generating for Omarchy (its Lua config, an Omarchy theme, the shell's bar, launcher and notifications) or for plain Hyprland; an Omarchy bundle downloaded here can be installed from the page | Dotfile Generator's built web app |
| OmaBuilds | Everything hyprbuildz does, with the build as a stage: profile → packages → files → options → ISO → USB, each step opening the tab that sets it, the Build button and its progress. **Profile** (live installer, minimal or "this desktop", and what comes along), **Contents** (name, hostname, packages, folders, edited files), **Options** (including compression: zstd, LZ4 for a faster build, or xz for the smallest ISO), **Build log**; USB writing. A copy of this desktop checks the space it needs first and names the biggest home folders to leave out | built in |
| Alienflare | The Alienware x15's per-key lighting: designs drawn with the keys, 29 animations (comets, fireflies, lava lamp, plasma, pong, a ghost typist and more), painting key by key, colours of their own or, with *Theme colours* on, only colours found in the active wallpaper (following every wallpaper), brightness, vividness, speed, and the lid logo and ring | AlienFlare (`alienflare` and its `alienflare.service`) |

## Install

On Omarchy (or any Arch system with the Omarchy shell):

```sh
git clone https://github.com/SK33M/omacraft.git
cd omacraft
bin/install
```

`bin/install` builds OmaCraft and installs it as the `omacraft` package with
`makepkg -si`, so pacman downloads everything it needs to run: Qt 6 and its
web view, Python with Pillow, Node.js, archiso and squashfs-tools, and the
smaller tools the pages call. It then shows up in the app launcher as
OmaCraft.

The package carries every plugin OmaCraft manages, in
`/usr/share/omacraft/plugins`: omabar16, Studio (the Launcher and hyprskin,
behind the Wallpapers page), Side Dock, Burn My Windows, Window Transitions,
omascii, Folder trays, the Wallpaper picker and Dotfile Generator. Nothing
else has to be cloned: *Install* on a plugin's card links it into the shell
from there, and the plugins update with the package. A plugin whose project
is checked out where its *Code location* points is linked from there instead,
for working on it.

Some extras are optional and come from elsewhere; their pages offer to
install them or say what's missing:

| For | Package |
| --- | --- |
| The animated boot splash intros | `ttfx` (Omarchy repo) |
| The boot screen | `plymouth` |
| The matugen, pywal and flavours wallpaper schemes | `matugen`; `python-pywal16` and `flavours` (AUR) |
| Alienware keyboard lights | AlienFlare (`alienflare` and its service) |
| ROFIoma | `rofi`, `jq`, `wl-clipboard`, `wtype`, `swaync` |

## How it works

The bar and the dock have to live inside the Omarchy shell, so they stay
shell plugins. OmaCraft manages them from the outside, through the same
routes the plugins and Omarchy already offer:

- **Installing** links a plugin's code into `~/.config/omarchy/plugins`: its
  project when it is checked out, else the copy the package carries. Or it
  brings back one OmaCraft set aside. **Removing** disables it, then removes
  the link, or moves a real folder to `~/.local/share/omacraft/stash`.
  Nothing is ever deleted. Where each plugin's code lives is under *Code
  location* on its card, saved in `~/.config/omacraft/sources.json`.
- **Switching on and off** happens in OmaCraft, not through icons on the bar.
  The shell loads a plugin whenever `shell.json` names it, so switching one on
  lists it in `plugins[]` and takes its own icon off the bar, and switching it
  off lists it in `disabledPlugins[]`. `omarchy plugin enable` would put a bar
  widget back on the bar, so OmaCraft makes these edits itself, in place,
  touching only that plugin's entries. What belongs on the bar stays there:
  folder trays, and Studio's launcher button (your Omarchy menu). The bar
  itself is switched with `omarchy bar use|reset`.
- **Settings** go through each plugin's own command or IPC: `omarchy-animations`,
  `omascii` and `omarchy-shell agentdock set …`. When the dock isn't running,
  OmaCraft writes its `state.json` itself. Launcher's style goes to
  `launcher-style.json`, rewritten in place so the launcher's file watcher
  stays on it.
- **The bar** is edited by OmaCraft itself. omabar16 draws whatever
  `shell.json`'s `bar` section says and follows that file, so OmaCraft keeps
  its own copy of the section (position, transparency, centre anchor, layout,
  style), changes it, and writes it back in place a moment after each edit,
  touching nothing else in the file. Undo, redo and Revert (to the bar as it
  was when OmaCraft opened) are OmaCraft's. Imported themes keep only
  omabar16's style keys. The themes and layouts are read from Studio's
  `bar/data/Presets.js` when it's there (it adds HANCORE), otherwise from
  omabar16's `data/Presets.js`; your themes stay in
  `~/.config/omarchy/omabar16/themes.json` and exports go to its `exports/`.
- **Burn My Windows** writes `~/.config/omarchy/burn-my-windows.json` in place, which
  the shell plugin follows live, and draws its previews with the plugin's own
  compiled shaders. "Play on this window" asks the shell (`omarchy-shell burn
  preview`) to run the effect on OmaCraft's window; the close keys are switched
  with the plugin's `omarchy-burn keys on|off`.
- **Wallpaper** runs the Studio plugin's `hyprskin` for everything (search,
  library, favourites, colours, settings), so OmaCraft and the Studio hub
  always agree; the shell's Studio service draws the wallpaper.
- **Wallpaper colours reach OmaCraft's parts.** hyprskin's theme recolours
  whatever reads the Omarchy theme. The parts that keep colours of their own
  follow it once switched to their theme mode, under *OmaCraft's parts that
  follow too* on the Wallpapers page's colours tab: omabar16's style
  (hyprskin's `colorizeBar`), the window border (a `wallpaper` gradient
  OmaCraft writes to `animation-presets.json` from the theme's accent and
  hues), Side Dock and Burn My Windows (`theme`), Launcher (the `omarchy`
  scheme) and Boot Splash (the theme's colour names). Turning wallpaper colours
  on makes them all follow. Each part's own colours are kept in
  `~/.config/omacraft/theme-sync.json` and come back when it stops following.
  OmaCraft installs a `theme-set` hook (`70-omacraft-colors`) that runs
  `omacraft --sync-colors` after every theme switch, so the border gradient
  follows each new wallpaper while OmaCraft is closed.
- **An underlined bar** leaves its text on the bar, but omabar16 draws it in
  `fg`, the dark segment ink in most of its themes. After a theme, shape or
  background change (and after every theme switch, through the hook) OmaCraft
  sets `fg` to a colour that reads on the bar when the old one doesn't. A text
  colour you set yourself is left alone.
- **Folder trays** are entries of the `omacraft.folders` bar widget in
  `shell.json`, one per folder, with its apps inline. `omarchy bar put` keeps a
  single copy of a widget, so OmaCraft adds, edits and removes folder entries
  in `shell.json` itself, rewritten in place so the shell reloads the bar. It
  touches nothing else there. The plugin's code is in `plugins/folders/`.
- **Dotfile Generator** (HyprCraft) runs in a web view, served from its build through a private
  `hyprcraft://` scheme. OmaCraft uses the installed plugin's `app/` folder,
  then `~/Projects/HyprCraft/omarchy-plugin/app`, then the copy the package
  carries. Exports are saved to `~/Downloads/HyprCraft`.
- **OmaBuilds** is hyprbuildz's code, and keeps its settings in
  `~/.config/hyprbuildz/config.json`.

Side Dock needs one shell restart after updating it, so its new `set`
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
| Arrows | Choose a plugin |
| `Space` | Switch it on or off |
| `I` / `Del` | Install / remove it |
| `B` | Move every plugin's bar icon into OmaCraft |
| `Enter` | Open its page |
| Click the title | Play it again |
| **Window Transitions** | |
| `P` `M` `B` `L` | Presets, Motion, Borders, Lua |
| Arrows, `Space` | Choose a preset (it plays on the stage), apply it |
| `T` | Animations off, or back on |
| `+` `-` `0` | Faster, slower, preset speed |
| `Ctrl Z` / `Ctrl Shift Z` | Undo / redo |
| **Burn My Windows** | |
| `C` / `O` | Edit the closing / opening effects |
| `P` | Play the picked effect on OmaCraft's own window |
| `R` | Any effect, at random |
| `E` | All window effects on or off |
| **Side Dock** | |
| `L` `I` `A` `P` | Looks, Items, Agents, Placement |
| `Delete` | Take the picked item off the dock |
| `Space` / `S` | Show or hide the dock / its own settings card |
| **Wallpapers** | |
| `W` `L` `F` `D` `C` | Wallhaven, Library, Favourites, Folders, Colours |
| `N` | Next wallpaper |
| `T` | Rebuild Omarchy's colours from the wallpaper |
| `Ctrl F` | Search Wallhaven |
| Right-click | A wallpaper's options: keep colours, favourite, delete from the library |
| **Main Bar** | |
| `T` `W` `S` `F` | Themes, Widgets, Style, Folders |
| `H` | Hide the picked widget from the bar (its plugin stays on) |
| `R` | Shuffle: a random look in random colours |
| `Delete` | Take the picked widget off the bar |
| `Ctrl Z` / `Ctrl Shift Z` | Undo / redo |
| **Launcher** | |
| `L` / `Shift L` | Next / previous layout |
| `C` / `Shift C` | Next / previous colour scheme |
| `T` / `Shift T` | Next / previous transition |
| `R` | A random layout and scheme |
| `O` | Open the launcher |
| **ROFIoma** | |
| `T` / `Shift T` | Next / previous tab |
| `O` | Open the tab's popup (Notifications: send test notifications) |
| **Boot Splash** | |
| `↑` `↓` | Browse fonts, using each one |
| `Ctrl F` | Search |
| `Ctrl P` | Play the intro |
| `Ctrl S` | Save to My boot screens |
| `Ctrl Enter` | Apply to the boot screen |
| **OmaBuilds** | hyprbuildz's keys: `Space` build, `P` profile, `F` write to USB, and the rest under `?` |

`omacraft pick [tab]` opens the wallpaper picker (below) without the window.
`omacraft <page> [tab]` opens on a page: `plugins`, `wallpaper`, `animations`,
`effects`, `dock`, `bar`, `launcher`, `rofioma`, `ascii`, `hyprcraft` or `iso`; e.g.
`omacraft wallpaper colors` or `omacraft bar folders` (the bar also takes
`looks`, `colours`, `widgets`, `hidden`, `presets` and `style`; Window Transitions `motion`,
`borders` and `lua`; ROFIoma `power`, `menus`, `symbols`, `keybinds`, `notify` and `look`; the dock `items`, `agents` and `placement`; OmaBuilds
`contents`, `options` and `log`). Pages past the ninth
are reached with `Ctrl PgUp` / `Ctrl PgDn`.

### The wallpaper picker

`omacraft.wallpicker` is a shell overlay: Omarchy's background switcher
(the slanted previews of `SUPER CTRL W`) holding OmaCraft's wallpapers, in
four tabs: **Theme** (the theme's backgrounds, as Omarchy lists them),
**Search Wallhaven**, **Library** and **Favorites**. Its data is hyprskin's, the
same as Wallpapers: it opens on OmaCraft's last search, and its hearts and
downloads show on the page and the other way round. Picking one runs
`hyprskin apply`, which downloads a Wallhaven pick into the library, sets
it and, while wallpaper colours are on, rebuilds the theme for the rest of
Omarchy (and, through the theme-set hook, OmaCraft's own parts). The
OmaCraft window is never opened or unfolded.

Install it, enable it and give it a key on Wallpapers (*Picker key*;
`SUPER ALT W` by default). The key goes in `~/.config/hypr/omacraft_wallpicker.lua`,
which `hyprland.lua` loads. It also opens with `omacraft pick [tab]` or
`omarchy-shell shell toggle omacraft.wallpicker '{"tab":"wallhaven"}'`.

| Key | In the picker |
| --- | --- |
| `←` `→`, `Tab`, wheel | Browse |
| `↑` `↓`, `Ctrl Tab`, `Ctrl 1`–`4` | Switch tabs |
| typing | Filter the tab; on Wallhaven, the search (it runs as you pause, or on `Enter`) |
| `Enter`, click the front card | Set it, with its colours when wallpaper colours are on |
| `Shift Enter` | Set it and keep the theme |
| `Ctrl F`, click the heart | Favourite |
| `Ctrl R` | Read the tab again |
| `Esc` | Clear the typing, then close |

Closing or minimising OmaCraft folds it into a small tab on the screen's
edge (bottom centre at first). Drag the tab anywhere round the edge and it
stays there, across runs (`~/.config/omacraft/edge-tab.json`); click it, or
launch OmaCraft again, to bring the window back. `Q`, `Ctrl Q` or the tab's
own button quit. Only one OmaCraft runs: launching it again with a page opens
that page in the one already running.

## Development

```sh
bin/build     # build/omacraft
bin/test      # Qt Test, offscreen
bin/install   # makepkg -fsi, so it shows up in the launcher
bin/sync-plugins          # copy each plugin's project into plugins/ for the package
bin/sync-plugins --check  # say which copies are behind their projects
```

Each plugin is worked on in its own project (Burn in `~/Work/omacraft-burn`,
Studio in `~/Work/skll-studio`, omascii in `~/Projects/omascii`, and so on;
the list is in `bin/sync-plugins`). Run `bin/sync-plugins` before committing
or packaging, so `plugins/` holds what the package ships.

`OMACRAFT_SCREENSHOT=out.png build/omacraft bar` saves the window after it
settles (or after `OMACRAFT_SCREENSHOT_DELAY` ms) and quits. With
`QT_QPA_PLATFORM=offscreen` it works without a display. The Dotfile Generator web
view only draws on a real one.

## License and credits

OmaCraft and its plugins are © 2026 skll, under the MIT license in
[`LICENSE`](LICENSE). The theme watcher and portal file picker are adapted from
[Omacut](https://github.com/omacom/omacut) (MIT, David Heinemeier Hansson), and
the whole app follows how [Omarchy](https://github.com/omacom/omarchy)'s own
apps are built. omascii bundles [figlet.js](https://github.com/patorjk/figlet.js)
and its fonts (MIT), Studio's bar presets include themes converted from
[HANCORE waybar-themes](https://github.com/HANCORE-linux/waybar-themes) (MIT),
and the Burn My Windows page follows the ideas of Simon Schneegans'
[Burn My Windows](https://github.com/Schneegans/Burn-My-Windows), with every
shader written from scratch. Everything OmaCraft includes, adapts, runs or
was inspired by is listed, with its license, in
[`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).
