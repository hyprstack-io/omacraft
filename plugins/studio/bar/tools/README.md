# Regenerating the HANCORE presets

`bar/data/Hancore.js` is generated from
[HANCORE-linux/waybar-themes](https://github.com/HANCORE-linux/waybar-themes) (MIT).
To pick up new themes from that repo:

    tmp=$(mktemp -d)
    git clone --depth 1 https://github.com/HANCORE-linux/waybar-themes "$tmp/repo"
    python3 -I convert_hancore.py "$tmp/repo" "$tmp/hancore.json"
    python3 -I emit_hancore.py "$tmp/hancore.json" ../data/Hancore.js

The converter only reads the repo's `config.jsonc` and `.css` files as text;
nothing from it is executed. It maps waybar modules to Omarchy widgets
(`MODULE_MAP` in convert_hancore.py; unmapped ones are listed in the JSON
under "dropped") and reduces each stylesheet to omabar16 style keys, leaving
colours the theme takes from Omarchy unset so they follow the theme.
