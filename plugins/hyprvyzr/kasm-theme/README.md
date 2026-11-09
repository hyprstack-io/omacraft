# HyprVYZR: Kasm's dashboard in OmaCraft's look

A theme for Kasm Workspaces' admin and workspace dashboards. It has two parts:

- **Colours**: the current Omarchy theme's, the same colours OmaCraft draws
  in. `build.py` reads `~/.local/state/omarchy/current/theme/colors.toml`.
  - accent-2 is the accent turned 50° round the hue wheel, the suite's rule.
  - The dashboard stays dark: a light Omarchy theme lends its hues, and its
    ink becomes the background.
  - Every hue is lightened until it reaches WCAG AA against that background.
  - `--palette duckbones` brings back the original scheme (zenbones.nvim).
- **The HyprStack look**: JetBrains Mono, square windows with a 2px accent
  gradient border that turns while focused, a dark backdrop with soft glows
  and a faint grid, and a HYPRVYZR wordmark in FIGlet ANSI Shadow.

`theme.css` is written in Duckbones' colours. `build.py` swaps each one for
the same role in the chosen palette, so the hand-written layer needs no
changes when the theme does. Rebuild and install again after changing the
Omarchy theme. OmaCraft › HyprVYZR › Look & dashboard does both.

Kasm keeps working exactly as before. Its own HTML, scripts and files are
untouched. The proxy only adds one stylesheet and one small script to the
dashboard page.

## How it works

| File | What |
| --- | --- |
| `build.py` | Writes `dist/duckbones.css` and `dist/wordmark.svg` (stdlib only) |
| `vendor/kasm-1.19.0-index.css` | Kasm 1.19's own stylesheet, the input |
| `theme.css` | The hand-written layer: Kasm's variables in Duckbones, then the HyprStack look |
| `duckbones.js` | Starts Kasm in its dark mode and marks the page (`html.hyprvyze`) |
| `wordmark.txt` | "HyprVyze" in ANSI Shadow, rendered with omascii's figlet |
| `nginx/hyprvyze-theme.conf` | The proxy rule that adds the stylesheet and script |
| `install.sh` | Build, upload, `nginx -t`, reload; `--remove` takes it out |

`dist/duckbones.css` (the name is kept so installed proxies need no change) has two parts:

1. **Kasm's colours on Duckbones.** Every rule in Kasm's stylesheet that
   sets a colour is written out again with only its colour declarations,
   each colour moved to the Duckbones colour that plays the same part.
   This covers CoreUI, Bootstrap, the `tw-` Tailwind utilities that draw
   the app grid, and Kasm's variables.
   - Neutrals go on a ramp from Duckbones' blue-black to its cream. Kasm's
     navies and blue-greys count as neutrals.
   - Hues go to rose, wood, leaf, water or blossom, keeping how light or
     dark they were.
   - Selectors, order and media queries are unchanged, so Kasm's own
     light/dark, hover and active logic still decides what wins.
2. **`theme.css`**, which covers:
   - the app grid: each workspace tile is a window with a gradient border
     on hover, and Kasm's slide-away icon effect is kept;
   - the header bar with its gradient underline;
   - side panels, modals in gradient frames, dropdowns, inputs and buttons
     (leaf primary with dark ink);
   - notifications as dark windows with a coloured edge;
   - the login page, with the wordmark masking the turning gradient;
   - `prefers-reduced-motion`.

Every text colour passes WCAG AA against its background (5.2:1 to 15.9:1).

Duckbones is a dark scheme, so `duckbones.js` sets Kasm's `themecolor` to
Dark on every load. Kasm's own Light/Dark switch in user settings has no
lasting effect while the theme is installed.

Kasm's stock backgrounds (`img/login_splash.jpg`,
`img/backgrounds/background*.jpg`) give way to the backdrop. A login splash
or launcher background set in Kasm's Admin › Branding is kept. The page
title, favicon and logos can still be set there too.

## On the VPS

`install.sh` adds only these, under `/opt/kasm/current/conf/nginx` (the
folder kasm_proxy mounts as `/etc/nginx/conf.d`):

- `services.d/hyprvyze-theme.conf`:
  - `location = /` and `location = /index.html` add the stylesheet and
    script before `</head>` (nginx `sub_filter`) and send the page
    `no-cache`;
  - `location ^~ /hyprvyze/` serves the theme files.
- `hyprvyze/`: `duckbones.css`, `duckbones.js`, `wordmark.svg`.

Each install stamps the files with a content hash (`?v=`), so browsers pick
up changes at once. If `nginx -t` fails, the files are taken out again and
nginx keeps its old config.

```sh
HYPRVYZR_SSH="-i <key>" ./install.sh [user@host]   # install or update on a server
HYPRVYZR_SSH="-i <key>" ./install.sh --remove      # stock Kasm again
./install.sh --local [--remove]                     # the Kasm on this machine (sudo)
```

- **After a Kasm upgrade** (a new `/opt/kasm/<version>`), run `install.sh`
  again.
- **If Kasm's stylesheet changes,** save the new `index.css` into `vendor/`
  and point `build.py` at it.

The PWA path (`/workspace/<id>/…`) is served by Kasm's own `location /`
and isn't themed.

## Checked

**Live on reqt.net:**
- the login page at 1440×900 and at 390 px (2×), with no sideways scroll;
- a failed login: the form posts, and Kasm's error shows in the themed
  notification;
- the theme files return 200, the folder index returns 403, and
  traversal attempts return 404;
- the API health check still answers.

**App grid:** checked offline only. That's a harness using Kasm's real
stylesheet and its tile markup from the 1.19 bundle (sample Chrome/Tor
tiles), at desktop and phone width, including hover. The signed-in
dashboard itself hasn't been seen with the theme.
