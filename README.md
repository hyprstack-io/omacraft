# OMAcraft

One app for the skll Omarchy plugins. It installs, enables and places each
one in the Omarchy shell, and holds all of their settings, beside the
HyprCraft configurator and the hyprbuildz ISO builder.

| Page | What it covers | Where it comes from |
| --- | --- | --- |
| Plugins | Install, remove, enable, disable, and place on the bar (left, centre, right) | `omarchy plugin` and `omarchy bar` |
| Animations | Hyprland animation presets, speed, on/off, the Lua each one writes, your own presets | `skll.animations` (its `omarchy-animations` script) |
| Agent Dock | Edge, monitor, gap, icon size, opacity, panel width, reserved space, start folder; dock apps, spacers, dividers and commands; agents and their tabs | `skll.agentdock` |
| Bar | omabar16's themes (looks, JaKooLit, base16, yours), preset layouts, screen edge, transparency, widgets per lane, and the style keys | `omabar16` |
| Boot ASCII | omascii's designer: FIGlet, TheDraw, system fonts and images; layout, image, colour and style options; intro effects with a live player; your library; apply to boot | `skll.omascii` (its `omascii` command) |
| HyprCraft | The full HyprCraft configurator | HyprCraft's built web app |
| ISO Builder | Everything hyprbuildz does: live installer, minimal or "this desktop" ISOs, packages, folders, edited files, USB writing | built in |

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
  `omascii`, `omarchy-shell omabar16 …` (with omabar16's undo history), and
  `omarchy-shell agentdock set …`. When the dock isn't running, OMAcraft writes
  its `state.json` itself. omabar16's themes and layouts are read from its own
  `data/Presets.js`, so both list the same things.
- **HyprCraft** runs in a web view, served from its build through a private
  `hyprcraft://` scheme. OMAcraft uses the installed plugin's `app/` folder,
  then `~/Projects/HyprCraft/omarchy-plugin/app`, then the copy the package
  carries. Exports are saved to `~/Downloads/HyprCraft`.
- **The ISO builder** is hyprbuildz's code, and keeps its settings in
  `~/.config/hyprbuildz/config.json`.

The Agent Dock needs one shell restart after updating it, so its new `set`
IPC call loads (*Restart shell* in the sidebar).

Every page follows the Omarchy theme's accent and updates when the plugins'
files change.

## Shortcuts

| Key | Action |
| --- | --- |
| `1` … `7`, `Ctrl 1` … `Ctrl 7` | Switch pages |
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
| Arrows, `Space` | Choose a preset, apply it |
| `T` | Animations off, or back on |
| `+` `-` `0` | Faster, slower, preset speed |
| `Ctrl Z` / `Ctrl Shift Z` | Undo / redo |
| **Agent Dock** | |
| `G` `I` `A` | General, Items, Agents |
| `Space` / `S` | Show or hide the dock / its own settings card |
| **Bar** | |
| `T` `L` `M` `S` | Themes, Layout, Modules, Style |
| `O` | omabar16's own customizer |
| `Ctrl Z` / `Ctrl Shift Z` | Undo / redo |
| **Boot ASCII** | |
| `↑` `↓` | Browse fonts, using each one |
| `Ctrl F` | Search |
| `Ctrl P` | Play the intro |
| `Ctrl S` | Save to My boot screens |
| `Ctrl Enter` | Apply to the boot screen |
| **ISO Builder** | hyprbuildz's keys: `Space` build, `P` profile, `F` write to USB, and the rest under `?` |

`omacraft <page>` opens on a page: `plugins`, `animations`, `dock`, `bar`,
`ascii`, `hyprcraft` or `iso`.

## Development

```sh
bin/build     # build/omacraft
bin/test      # Qt Test, offscreen
bin/install   # makepkg -fsi, so it shows up in the launcher
```

`OMACRAFT_SCREENSHOT=out.png build/omacraft bar` saves the window after it
settles (or after `OMACRAFT_SCREENSHOT_DELAY` ms) and quits. With
`QT_QPA_PLATFORM=offscreen` it works without a display. The HyprCraft web
view only draws on a real one.
