# omascii

FIGlet, TheDraw, system-font and image ASCII art for the Omarchy Plymouth boot screen. omascii includes all 332
FIGlet fonts from patorjk.com's [Text to ASCII Art Generator](https://patorjk.com/software/taag/)
(TAAG). They come from [figlet.js](https://github.com/patorjk/figlet.js), the engine TAAG runs
on, so the art matches what TAAG draws. It also uses TheDraw (`.tdf`) colour fonts, the DOS ANSI
fonts TAAG offers as well, in their own colours. It can also draw your text in any installed
TrueType/OpenType font, or turn an image into ASCII art, then style the result with fills,
borders, shadows and gradients. The art is animated on boot by ttfx intro effects, like the
HyprStack theme, or shown still, and you can watch the intro play live in the browser before
installing it.

## Install

```bash
./install.sh            # links the plugin and ~/.local/bin/omascii, adds Style > Boot ASCII
./install.sh --remove
```

Needs `node`, `python3` with Pillow, `ttfx` and ImageMagick. TheDraw fonts also need `git`
(to download them) and optionally `unzip` (to import zipped fonts). The `omascii` launcher also finds a
node installed through mise.

## TheDraw fonts

TheDraw fonts aren't bundled. Download the collection that ships with
[tdfiglet](https://github.com/tat3r/tdfiglet) ("all known TDF fonts", about 1,070 files holding
about 3,500 colour fonts), or add your own:

```bash
omascii tdf fetch                    # git clone, keep fonts/*.tdf -> ~/.local/share/omascii/tdf
omascii tdf add ~/Downloads/fonts.zip
omascii tdf list
omascii render -f "TDF glarex" -t HyprStack
```

One `.tdf` file can hold several fonts. The ones after the first are named `TDF <file> #1`,
`#2` and so on. Colour fonts keep their DOS colours on the boot screen. Turn that off with
`--no-font-colors` or the **Font colours** switch to draw them in your theme colour instead.
Block fonts always use the theme colour. Outline fonts (TheDraw type 0) are skipped.

## More fonts

Besides TAAG's 332 FIGlet fonts and the TheDraw collection:

```bash
omascii fonts fetch                  # xero/figlet-fonts: ~50 FIGlet/toilet fonts TAAG lacks
omascii fonts add ~/Downloads/*.flf  # .flf/.tlf, .ttf/.otf or .tdf files, folders or zips
omascii fonts --ttf                  # system fonts, drawn as pixels
omascii render -f "TTF JetBrainsMono Nerd Font Bold" --ttf-rows 6 --ttf-charset braille
omascii fonts dir                    # where added fonts live
```

**System fonts** are every installed font that covers English (from fontconfig) plus any you
add. They are named `TTF <family> <style>`. omascii renders the text large, then draws it in
quadrant blocks, braille, half blocks or a character ramp, `--ttf-rows` cells tall.

## Images

```bash
omascii render -i ~/Pictures/logo.png --image-width 60 --charset braille
omascii set -i ~/Pictures/logo.png --charset halfblock      # full colour, two pixels a cell
omascii set -i photo.jpg --charset detailed --no-image-colors --contrast 1.4
```

| Charset | Draws with |
|---|---|
| `ascii`, `detailed` | Brightness ramps (10 and 70 steps) |
| `blocks` | `░▒▓█` |
| `braille` | 2×4 dots a cell, the finest detail |
| `quadrant` | 2×2 block quadrants |
| `halfblock` | `▀` over its background: two full-colour pixels a cell |
| `custom` | Your ramp, darkest first: `--chars " .:oO@"` |

Bright pixels get dense characters (they show on the dark boot screen), so dark areas and
transparency become the background and the art is cropped to what remains. `--invert` swaps
that. Images keep their colours unless `--no-image-colors`. `--dither`, `--threshold`,
`--contrast`, `--brightness` and `--no-normalize` (auto levels) tune the conversion.

## Style

These apply to any font or image:

```bash
omascii set --border rounded --padding 1 --shadow light
omascii set --color-mode gradient --color red --color2 blue --gradient diagonal
omascii set --color-mode rainbow --fill "█"
omascii set --flip horizontal
```

- `--fill STR` replaces every ink character with these characters in turn (`█`, `01`, …).
- `--flip` mirrors the art (`horizontal`, `vertical`, `both`), swapping `/` and `\`, `▀` and `▄`
  and the like so it still joins up.
- `--shadow` drops a `light`/`medium`/`dark`/`solid` shade one cell down and right, a `long`
  shade trailing off diagonally, a `left` drop, a shade `under` the ink, or rings the ink with
  an `outline` of dots or a two-step `glow`.
- `--border` frames it (`single`, `rounded`, `double`, `heavy`, `ascii`, `block`, `shade`,
  `dashed`, `heavydash`, `dotted`, `doubleside`, `bevel`, `brackets`, `corners`, `stars`,
  `wave`, `hash`, `braille`), with `--padding` rows of space inside (columns are doubled so it
  looks even).
- `--color-mode` paints a `gradient` from `--color` to `--color2`, a `rainbow` in the theme's
  own colours, or a ready-made `palette` (`--palette sunset`, `synthwave`, `vaporwave`, `aurora`,
  `ocean`, `ice`, `fire`, `lava`, `forest`, `matrix`, `neon`, `candy`, `pastel`, `gold`, `chrome`,
  `mono`, `dracula`, `nord`, `catppuccin`, `tokyonight`), all along `--gradient` (`horizontal`,
  `vertical`, `diagonal`, `radial`, `diamond`, `wave`, `angle`). `stripes` alternates `--color`
  and `--color2` row by row, and `split` paints the top half one and the bottom half the other.
  Shadows are dimmed toward the background. Colours are Omarchy palette names or `#rrggbb`.

## Use

Run `omascii open`, or pick **Style > Boot ASCII** in the Omarchy menu. The designer works in
three steps, numbered on screen:

1. **Pick the art** on the left: **★ My boot screens** (your library), **FIGlet**, **TheDraw**,
   **System** fonts or an **Image**. Clicking a font or image (or browsing with ↑ ↓) uses it
   right away. The preview on the right is what will boot.
   The bar beside the font list jumps: click or drag anywhere on it to go there. Its letters
   mark where each initial starts, and hovering shows the font at that spot. TheDraw and
   system fonts render as you reach them.
2. **Fine-tune** in the tabs under the preview (**Text layout**, **Image**, **Colour & style**,
   **Animation**). Every option is a row of chips you click, so nothing drops down out of view.
   **Animation** lists every intro effect as a checkbox, with **Select all** and **Clear**, and
   ▶ on each effect plays it in the preview.
3. **★ Save to library** (Ctrl+S) keeps the design under a name, and **③ Apply to boot**
   (Ctrl+Enter) installs it in a floating terminal (sudo).

Changes are kept as you make them, so closing never loses work. The window only closes with
**✕ Close** or Esc (Esc first stops a playing intro or clears the search). Every boot screen you
apply is also added to **My boot screens**, so you can go back to an earlier one. **Load** puts
one into the designer and **Delete** (click twice) removes it.

- **▶ Play intro / Ctrl+P**: play the intro over the art in place, at Plymouth's 50 fps, then
  the looping highlight. It follows your changes while it plays.
- **Export GIF**: build the real theme frames and open a GIF of the first intro.
- **Undo boot change**: go back to the boot theme you had before omascii.
- **TAAG link**: paste a TAAG share link on the Text layout tab to take its font, text, layouts
  and width.

From a terminal:

```bash
omascii fonts                                   # all 332 font names
omascii render -t "HyprStack" -f "ANSI Shadow"  # try without saving
omascii set --taag 'https://patorjk.com/software/taag/#p=testall&f=Graffiti&t=HyprStack&x=none&v=4&h=4&w=80&we=false'
omascii set --style static --color blue
omascii set --effects decrypt,burn,rain         # fewer effects = smaller initramfs
omascii set --effects fireworks,swarm,expand    # 21 more ttfx intros beyond the default 11
omascii set --effects matrix,thunderstorm,ripple # screensaver effects and omascii's own
omascii preview burn                            # GIFs in ~/.local/state/omascii/preview
omascii apply                                   # install + select + rebuild initramfs
omascii restore                                 # back to the previous boot theme
omascii saved                                   # your library: saved and applied boot screens
omascii saved add --name "Green graffiti"       # save the current settings under a name
omascii saved use <id>                          # load one back into the settings
omascii saved rm <id>
omascii help
```

Settings are stored in `~/.config/omascii/config.json` and the library in `~/.config/omascii/saved.json`. The built theme goes to
`~/.local/state/omascii/theme/omascii` and is installed to `/usr/share/plymouth/themes/omascii`.
To return to the stock Omarchy splash, run `omarchy plymouth reset`.

## Intro effects

The designer lists them in five groups:

| Group | Effects |
|---|---|
| Core | The default 11, themed for Omarchy: decrypt, beams, burn, slide, rain, laseretch, waves, middleout, vhstape, sweep, unstable |
| More ttfx | 21 more ttfx effects in their own colours |
| Screensaver | The rest of what Omarchy's screensaver plays: matrix, synthgrid, thunderstorm, colorshift, highlight |
| Screensaver presets | Screensaver scenes retuned: matrix-theme, matrix-binary, synthgrid-neon, thunderstorm-violet, colorshift-rainbow, fireworks-neon, burn-inferno, beams-aurora, rain-storm, decrypt-green |
| omascii originals | Drawn by omascii itself (`lib/effects.py`): ripple (rings from the centre), starfield (warp speed), neon (a sign flickering on), tetris (blocks drop and lock in), spiral (drawn inwards), crt (a monitor powering on), plasma (a colour field draining to the art), tunein (static tuning in), helix (a double helix sweeping across) |

matrix and thunderstorm are timed in seconds by ttfx, so they take a few seconds of real time
to build.

## How it works

| Piece | Job |
|---|---|
| `lib/figlet.mjs` | Renders text with the vendored figlet.js and its fonts. Also parses TAAG links. |
| `lib/tdf.mjs` | Parses TheDraw `.tdf` fonts and lays out text in coloured cells (CP437, DOS palette). |
| `lib/ttf.mjs` | Lists system and added TrueType/OpenType fonts through fontconfig. |
| `lib/image.py` | Turns images, and text in TrueType fonts, into character cells (Pillow). |
| `lib/style.mjs` | Fill, flip, shadow, border, padding and gradient colouring, on cells from any source. |
| `lib/cli.mjs` | Handles the `omascii` commands and stores the settings. |
| `lib/build.py` | Turns the art into ttfx frames, then PNGs, plus a Plymouth script. With `--preview-json` it emits one intro as rich text frames for the live preview. |
| `lib/effects.py` | omascii's own intro effects, drawn cell by cell in the same frame format. |
| `lib/install.sh` | Copies the theme into place, selects it and rebuilds the initramfs. It calls `sudo` for each step. |
| `Omascii.qml` | The shell overlay: font and image gallery, live preview and player, settings. |

Colours come from the current Omarchy theme's `colors.toml`. Re-apply after changing theme.
Anything with its own colours (TheDraw colour fonts, image colours, gradients, shadows) is
handed to ttfx as coloured text, so the intros settle on those colours. The
art is scaled to fit the largest connected monitor. Box-drawing, block, braille and other
symbol glyphs are drawn as shapes so they stay crisp at boot.

## Notes

- The **Horizontal** and **Vertical** layouts are figlet.js's five settings. TAAG links number
  them `0`–`4` (default, full, fitted, controlled smushing, universal smushing).
  "Universal smushing" squeezes one-column fonts such as Circle or WideTerm into a single
  glyph. Use "default" for those.
- **Width** wraps lines the way TAAG does (80 by default, 0 for no wrapping).
- Type `\n` in the text for a new line.

## Credits

figlet.js © Patrick Gillespie, MIT (`vendor/figlet/LICENSE.txt`). The TheDraw parser follows
[tdfiglet](https://github.com/tat3r/tdfiglet)'s reading of the format, and the fonts it
downloads are the TheDraw scene's. The FIGlet fonts are by
their many authors. Each `.flf` header carries its credits. `omascii fonts fetch` downloads
[xero/figlet-fonts](https://github.com/xero/figlet-fonts). The boot script and dialogue
assets are adapted from the HyprStack theme, which is based on the Omarchy Plymouth theme.
