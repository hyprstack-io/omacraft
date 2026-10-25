# Third-party notices

OmaCraft and the plugins it carries are © 2026 skll, under the MIT licence in
[`LICENSE`](LICENSE). They contain, adapt or follow other people's work, listed
here with each project's licence. Where code or data was copied or adapted, its
licence and copyright notice go along with it, below and in the files named.
Where only an idea or a look was followed (marked *inspiration*), no code was
copied, and the project is credited because OmaCraft owes it the idea.

## Code and data included in OmaCraft

| Work | Author | Licence | What OmaCraft uses | Where |
| --- | --- | --- | --- | --- |
| [Omacut](https://github.com/omacom/omacut) | David Heinemeier Hansson | MIT | The theme watcher, the portal file picker and its interface, adapted | `src/theme.cpp`, `src/palette.cpp`, `src/portalfilepicker.*`, `src/filepicker.h` |
| [Omarchy](https://github.com/omacom/omarchy) | David Heinemeier Hansson | MIT | The Plymouth boot theme the HyprStack boot animation and omascii's boot script and dialogue assets are adapted from; the plugin, bar and theme interfaces every plugin follows | `plymouth/hyprstack-boot`, `plugins/omascii/assets` |
| [figlet.js](https://github.com/patorjk/figlet.js) | Patrick Gillespie and contributors | MIT | The FIGlet engine and its fonts, bundled with their licence | `plugins/omascii/vendor/figlet` (see its `LICENSE.txt`) |
| FIGlet fonts | Their authors, named in each `.flf` header | As stated in each font (mostly free use; some WTFPL v2) | The fonts figlet.js ships | `plugins/omascii/vendor/figlet/fonts` |
| [HANCORE waybar-themes](https://github.com/HANCORE-linux/waybar-themes) | drdeltree | MIT | Bar themes and layouts, converted into omabar16 presets | `plugins/studio/bar/data/Hancore.js`, `plugins/studio/bar/tools` |
| [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) glyph names | Ryan L McIntyre and the icon sets' authors | MIT (names list); each icon set its own (Material Design Icons Apache-2.0, Font Awesome CC BY 4.0 / OFL, Codicons CC BY 4.0, Octicons MIT, Devicons MIT, Weather Icons OFL, Seti UI MIT, Font Logos Unlicense, Powerline MIT, Pomicons OFL) | Glyph names and code points for the glyph picker and icon choosers; no font files are included | `src/data/glyphs.tsv`, `plugins/studio/bar/data/Icons.js` |
| [Unicode emoji data](https://unicode.org/emoji/) | Unicode, Inc. | Unicode License v3 | Emoji, their names and groups for the emoji picker | `src/data/emoji.tsv` |
| [React](https://react.dev) | Meta Platforms, Inc. and affiliates | MIT | Bundled in Dotfile Generator's built web app | `plugins/hyprcraft/app` |
| [Lucide](https://lucide.dev) (lucide-react) | Lucide Contributors | ISC | Icons bundled in Dotfile Generator's built web app | `plugins/hyprcraft/app` |
| [Motion](https://motion.dev), [JSZip](https://stuk.github.io/jszip/) | Matt Perry; Stuart Knightley and contributors | MIT; MIT (dual MIT/GPL-3.0, used under MIT) | Animation and zip export, bundled in Dotfile Generator's built web app | `plugins/hyprcraft/app` |

## Used while running, not included

OmaCraft runs these as separate programs or links them as system libraries; none
of their code is in this repository or the package.

| Work | Licence | Used for |
| --- | --- | --- |
| [Qt 6](https://www.qt.io) | LGPL-3.0 (linked dynamically) | The whole interface |
| [Quickshell](https://quickshell.org) | LGPL-3.0 | The Omarchy shell the plugins run in |
| [Hyprland](https://hyprland.org) | BSD-3-Clause | The compositor the transitions, borders and dotfiles set up |
| [archiso](https://gitlab.archlinux.org/archlinux/archiso) | GPL-3.0-or-later | OmaBuilds builds every ISO with `mkarchiso`, from the profiles installed on the machine |
| [ttfx](https://github.com/omacom/ttfx) | MIT (37signals / omacom-io) | The animated boot splash intros |
| [Plymouth](https://www.freedesktop.org/wiki/Software/Plymouth/) | GPL-2.0-or-later | The boot screen |
| [matugen](https://github.com/InioX/matugen) | GPL-2.0 | The matugen wallpaper scheme, when installed |
| [pywal16](https://github.com/eylles/pywal16) | MIT | The pywal wallpaper scheme, when installed |
| [flavours](https://github.com/Misterio77/flavours) | MIT | The flavours wallpaper scheme, when installed |
| [tdfiglet](https://github.com/tat3r/tdfiglet) font collection | As distributed there | TheDraw fonts omascii downloads on request into `~/.local/share/omascii/tdf`; omascii's TheDraw reader follows tdfiglet's reading of the format |
| [xero/figlet-fonts](https://github.com/xero/figlet-fonts) | As distributed there | More FIGlet fonts omascii downloads on request |
| [Wallhaven](https://wallhaven.cc) | Its [terms](https://wallhaven.cc/terms); each wallpaper belongs to its uploader | Searching and downloading wallpapers through its API; no wallpapers are included |

## Inspiration

| Work | Author | Licence | What it inspired |
| --- | --- | --- | --- |
| [Burn My Windows](https://github.com/Schneegans/Burn-My-Windows) | Simon Schneegans | GPL-3.0-or-later | The Burn My Windows page: its effects' ideas and names. Every shader in `plugins/burn` was written from scratch for Qt's `ShaderEffect`. |
| [JaKooLit Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots) | JaKooLit | GPL-3.0 | The look of some bar presets, re-created as omabar16 styles (`plugins/studio/bar/data/Presets.js`) |
| [HyDE wallbash](https://github.com/HyDE-Project/HyDE) | HyDE Project | GPL-3.0 | The idea of the wallbash colour scheme, written anew in `hyprskin` |
| [Material You / Material Color Utilities](https://github.com/material-foundation/material-color-utilities) | Google | Apache-2.0 | The Material colour roles hyprskin names, written anew |
| [Omarchy](https://github.com/omacom/omarchy), [Omacut](https://github.com/omacom/omacut) | David Heinemeier Hansson | MIT | How an Omarchy app is built: one Qt Quick binary that follows the theme live, packaged for pacman |

## Licence texts

### MIT (Omacut, Omarchy, figlet.js, HANCORE waybar-themes, Nerd Fonts names, React, Motion, JSZip, OmaCraft)

```
Copyright (c) David Heinemeier Hansson                      (Omacut, Omarchy)
Copyright (C) 2014-present Patrick Gillespie and other contributors  (figlet.js)
Copyright (c) 2025 drdeltree                                (HANCORE waybar-themes)
Copyright (c) 2014 Ryan L McIntyre                          (Nerd Fonts)
Copyright (c) Meta Platforms, Inc. and affiliates           (React)
Copyright (c) Matt Perry                                    (Motion)
Copyright (c) 2009-2016 Stuart Knightley, David Duponchel, Franz Buchinger,
  António Afonso                                            (JSZip)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### ISC (Lucide)

```
Copyright (c) for portions of Lucide are held by Cole Bemis 2013-2022 as part
of Feather (MIT). All other copyright (c) for Lucide are held by Lucide
Contributors 2022.

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.
```

### Unicode License v3 (emoji data)

```
Copyright © 1991-2025 Unicode, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of data files and any associated documentation (the "Data Files") or software
and any associated documentation (the "Software") to deal in the Data Files or
Software without restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, and/or sell copies of the Data Files
or Software, and to permit persons to whom the Data Files or Software are
furnished to do so, provided that either (a) this copyright and permission
notice appear with all copies of the Data Files or Software, or (b) this
copyright and permission notice appear in associated Documentation.

THE DATA FILES AND SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF
THIRD PARTY RIGHTS. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED
IN THIS NOTICE BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR
CONSEQUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
OF THE DATA FILES OR SOFTWARE.

Except as contained in this notice, the name of a copyright holder shall not
be used in advertising or otherwise to promote the sale, use or other dealings
in these Data Files or Software without prior written authorization of the
copyright holder.
```

The Apache-2.0, CC BY 4.0 and OFL-1.1 icon sets are referenced by name and code
point only; their fonts are not included. Their licences are at
<https://www.apache.org/licenses/LICENSE-2.0>, <https://creativecommons.org/licenses/by/4.0/>
and <https://openfontlicense.org>.
