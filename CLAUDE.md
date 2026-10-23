# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

OmaCraft is a single C++20 / Qt 6 Quick desktop app for Omarchy (Hyprland). It installs, enables and places the skll Omarchy shell plugins, edits their settings, and also hosts the Dotfile Generator (HyprCraft, a web app in a WebEngine view), OmaBuilds (the hyprbuildz ISO builder), Boot Splash/Screensaver (omascii) and Alienflare (Alienware per-key lighting). README.md describes every page, its shortcuts and which files or commands it writes to. Read it before changing a page's behaviour.

## Commands

```sh
bin/build     # qmake6 + make into build/omacraft
bin/test      # builds tests/omacraft_tests.pro into build/tests and runs it with QT_QPA_PLATFORM=offscreen
bin/install   # bin/build, then makepkg -fsi in pkgbuild/ (installs the Arch package)
```

- Run a single test: build with `bin/test` first, then run `cd build/tests && QT_QPA_PLATFORM=offscreen ./omacraft_tests <slotName>`, e.g. `barEditsShellJsonInPlaceWithUndo`. `tests/main.cpp` runs two suites (`OmacraftTests` in `omacraft_tests.cpp`, the ISO suite in `iso_tests.cpp`) in one binary, so a slot name that only one suite has will make the other suite complain. Use the `runIsoTests`/`runOmacraftTests` split if that gets in the way.
- Run on a page: `build/omacraft <page> [tab]`, where page is `plugins`, `wallpaper`, `animations`, `effects`, `dock`, `bar`, `launcher`, `ascii`, `hyprcraft` or `iso`.
- Screenshot without a display: `QT_QPA_PLATFORM=offscreen OMACRAFT_SCREENSHOT=out.png build/omacraft bar` (optional `OMACRAFT_SCREENSHOT_DELAY` in ms). This also skips the single-instance handoff. The HyprCraft web view only draws on a real display.
- Other entry points: `omacraft --sync-colors` is the headless theme-set hook (`ThemeSync::syncNow`), and `omacraft pick [tab]` toggles the wallpicker shell overlay.

## Build bookkeeping (easy to miss)

- **New C++ files** must be added to both `omacraft.pro` and `tests/omacraft_tests.pro`. The test binary compiles every `src/*.cpp` except `main.cpp`.
- **New QML/JS/data files** must be listed in `src/resources.qrc` with an alias. Everything is loaded from `qrc:/`.
- Both builds link `-lLayerShellQtInterface`, which the edge tab needs.
- `pkgbuild/PKGBUILD` builds from the working tree (`$startdir/..`), not from a source tarball. It also bundles `plymouth/hyprstack-boot` and, when `~/Projects/HyprCraft/omarchy-plugin/app` exists (or `$HYPRCRAFT_APP`), a copy of the HyprCraft build.

## Architecture

**Backends as context properties.** `src/main.cpp` creates one QObject backend per area (`Theme`, `Plugins`, `Animations`, `AgentDock`, `Bar`, `Launcher`, `Burn`, `Omascii`, `BootSplash`, `Screensaver`, `HyprCraft`, `IsoBuilder`, `Wallpaper`, `WallPicker`, `Folders`, `ThemeSync`, `Lights`, `EdgeTab`). It exposes each one to QML as a root context property (`theme`, `plugins`, `bar`, `dock`, `saver`, …), not as a registered type. Only `SyntaxHighlighter` and `AsciiView` are registered types (`import Omacraft 1.0`). Each backend is built with lambdas such as `[&plugins]{ return plugins.pluginDir("omacraft.burn"); }`, so it always resolves the plugin's *current* location. `Plugins::changed` is connected to each backend's `reload`/`refresh`.

**Pages.** `src/Main.qml` holds a `pages` array (`id`, `name`, `glyph`, required `plugin`, `file`) and loads each page into a `StackLayout` through a `Loader`. When a page's plugin isn't installed it shows `NotInstalled.qml`. Page order sets the number keys and the `omacraft <page>` ids. Shared UI pieces (`Card`, `Segmented`, `SliderRow`, `Stage`, `PageHeader`, …) are plain QML files in `src/`.

**Theming.** `Theme` reads the Omarchy theme's `colors.toml`, follows it, and derives every surface and text colour by role. QML reads `theme.card`, `theme.textMuted` and so on, and never hardcodes UI colours (previews are the exception). `ThemeSync` makes OmaCraft's other parts (bar style, border gradient, dock, burn, launcher, boot splash, lights) follow wallpaper colours, and keeps their own colours in `~/.config/omacraft/theme-sync.json` so they can be restored.

**How changes reach the system** (the core design rule, from README "How it works"):
- The shell owns `shell.json`. Enabling, disabling and placing plugins goes through `omarchy plugin …` / `omarchy bar …`. Settings go through each plugin's own CLI or IPC (`omarchy-animations`, `omascii`, `omarchy-shell agentdock set`, `hyprskin`, `omarchy-burn`). Run commands with `Proc::run` (async, owned by a context object, which reports the tool's stderr as the message), never with blocking calls on the GUI thread.
- Where OmaCraft writes files itself (the `bar` section and the folder entries in `shell.json`, `launcher-style.json`, `burn-my-windows.json`, the dock's `state.json` while the dock is stopped), it rewrites them **in place** and touches only its own keys, so the shell's file watchers keep following them. Tests such as `*WritesInPlaceAndKeepsOtherKeys` and `barEditsShellJsonInPlaceWithUndo` enforce this. Other saves are atomic (write beside the file, then rename).
- Plugins run from OmaCraft, not from bar icons. `Plugins::switchIn` switches one on by listing it in `shell.json`'s `plugins[]` and stripping its own icons from `bar.layout` (`isBarIcon` spares folder trays and Studio's launcher-role button), and switches it off through `disabledPlugins[]`. Don't use `omarchy plugin enable` for these: it puts bar widgets back on the bar. The landing page's title art lives in `src/OmaCraftArt.js` (TheDraw font "synergy", rendered once with omascii).
- Nothing is ever deleted. Removing a plugin unlinks it or moves it to `~/.local/share/omacraft/stash`.
- `Bar` keeps its own copy of the shell.json `bar` section with undo/redo/revert, and writes it back on a short debounce. Bar presets are parsed from Studio's `bar/data/Presets.js` (or omabar16's).

**Single instance and edge tab.** `EdgeTab::passToRunning` hands a second launch's arguments to the running instance. Closing the window folds it into a layer-shell tab on the screen edge (`setQuitOnLastWindowClosed(false)`), so quitting is explicit.

**Other pieces.**
- `HyprCraft` serves the web app over a private `hyprcraft://` scheme. It must be registered before `QGuiApplication` exists, and it uses its own `QQuickWebEngineProfile`.
- `IsoBuilder`, `BuildConfig`, `Replica` and `Drives` are the hyprbuildz port. `Replica` is the "this desktop" profile, and it classifies home folders as Settings, Secret, Cache or Personal.
- `Lights`, `Scene`, `Store`, `Palette` and `Layout` are Alienflare; `Store` shares `~/.config/alienflare/state.json` with the lighting service.
- `plugins/folders` and `plugins/wallpicker` are shell plugins (QML + `manifest.json`) whose code lives in this repo.
- `src/omasavr-*` are the screensaver runner and hook scripts.

## Tests

The tests are Qt Test, offscreen. Fixtures are written into `QTemporaryDir`s, and backends take a config or home directory argument so tests never touch the real `~/.config`. `initTestCase` sets `OMACRAFT_OMARCHY_THEMES=/nonexistent`. Test slots are declared in `tests/omacraft_tests.h`, not the .cpp, because moc can't parse the raw-string fixtures. Add new slots there.

## Style

Comments and UI text are plain, user-facing English that says what something does and why ("Closing folds the window into its edge tab, so…"), and they use British spellings in UI text (colour, centre, favourite). Match this tone, and update README.md when a page's behaviour, shortcuts or files change.
