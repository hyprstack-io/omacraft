#!/bin/bash
# Screensaver's screensaver, written by OmaCraft: Omarchy's screensaver with the
# effects picked on OmaCraft's Screensaver page. It plays the same art
# (~/.config/omarchy/branding/screensaver.txt) and leaves the same way, on any
# key or when its window loses focus. It only ever runs as the screensaver;
# nothing here touches the boot screen.

config="$HOME/.config/omacraft/omasavr.json"
art="$HOME/.config/omarchy/branding/screensaver.txt"
colors="$HOME/.local/state/omarchy/current/theme/colors.toml"
here=$(dirname "$(readlink -f "$0")")

# No effects picked, or no settings: Omarchy's own screensaver.
mapfile -t effects < <(jq -r '.applied.effects[]? // empty' "$config" 2>/dev/null)
((${#effects[@]})) || exec /usr/bin/omarchy-screensaver "$@"
order=$(jq -r '.applied.order // "random"' "$config")
rate=$(jq -r '.applied.frameRate // 120' "$config")
pause=$(jq -r '.applied.pause // 0' "$config")
lib=$(jq -r '.applied.omasciiLib // empty' "$config")
player=

screensaver_in_focus() {
  hyprctl activewindow -j | jq -e '.class == "org.omarchy.screensaver"' >/dev/null 2>&1
}

exit_screensaver() {
  hyprctl eval 'hl.config({ cursor = { invisible = false } })' &>/dev/null || hyprctl keyword cursor:invisible false &>/dev/null || true
  # Only our own player: other ttfx runs (an omascii build, say) carry on.
  [[ -n $player ]] && kill "$player" 2>/dev/null
  pkill -f '[o]rg.omarchy.screensaver' 2>/dev/null
  exit 0
}

trap exit_screensaver SIGINT SIGTERM SIGHUP SIGQUIT

# A theme colour by name as hex without the #, the accent when the theme has
# no such colour, so the presets follow the theme as omascii's do.
color() {
  local name value
  for name in "$@"; do
    value=$(sed -n "s/^$name *= *\"#\{0,1\}\([0-9a-fA-F]\{6\}\)\".*/\1/p" "$colors" 2>/dev/null | head -n 1)
    [[ -z $value ]] && value=$(sed -n 's/^accent *= *"#\{0,1\}\([0-9a-fA-F]\{6\}\)".*/\1/p' "$colors" 2>/dev/null | head -n 1)
    printf '%s\n' "${value:-ffffff}"
  done
}

# The ttfx effect and its arguments for a pick: omascii's screensaver presets
# are ttfx effects tuned like screensaver scenes (its build.py).
setup() {
  base=$1
  args=()
  case $1 in
  matrix-theme) base=matrix args=(--rain-time 3 --highlight-color $(color bright_foreground) --rain-color-gradient $(color accent primary_container selection)) ;;
  matrix-binary) base=matrix args=(--rain-time 3 --rain-symbols 0 1) ;;
  synthgrid-neon) base=synthgrid args=(--grid-gradient-stops ff2a6d d300c5 05d9e8 --text-gradient-stops fdf500 $(color foreground)) ;;
  thunderstorm-violet) base=thunderstorm args=(--storm-time 3 --lightning-color c9a0ff --glowing-text-color e0c3ff --spark-glow-color b16cea) ;;
  colorshift-rainbow) base=colorshift args=(--no-loop --cycles 2 --gradient-stops $(color red yellow green cyan blue magenta)) ;;
  fireworks-neon) base=fireworks args=(--firework-colors 39ff14 00f0ff ff00e6 fffb00 ff6b35) ;;
  burn-inferno) base=burn args=(--starting-color 3d0c11 --burn-colors ffffff fff200 ff9a00 ff4d00 c81d25 3d0c11) ;;
  beams-aurora) base=beams args=(--beam-gradient-stops ffffff 00ff87 60efff 0061ff b16cea) ;;
  rain-storm) base=rain args=(--rain-symbols │ ╎ ┆ : "'" --movement-speed 0.4-0.9 --rain-colors $(color blue cyan bright_blue bright_cyan light_foreground)) ;;
  decrypt-green) base=decrypt args=(--typing-speed 8 --ciphertext-colors 008000 00cb00 00ff00) ;;
  colorshift) args=(--no-loop) ;;
  esac
}

printf '\033]11;rgb:00/00/00\007' # Set background color to black

hyprctl eval 'hl.config({ cursor = { invisible = true } })' &>/dev/null || hyprctl keyword cursor:invisible true &>/dev/null

tty=$(tty 2>/dev/null)

# As Omarchy's: ttfx measures the terminal once, so wait for the window's
# real size before the first effect.
wait_for_terminal_resize() {
  local deadline=$((SECONDS + 2))
  while ((SECONDS < deadline)) && [[ $(stty size 2>/dev/null) == "24 80" ]]; do
    sleep 0.02
  done
}

wait_for_terminal_resize

i=0
failures=0
while true; do
  if [[ $order == sequence ]]; then
    effect=${effects[i % ${#effects[@]}]}
    ((i++))
  else
    effect=${effects[RANDOM % ${#effects[@]}]}
  fi

  started=$SECONDS
  case $effect in
  ripple | starfield | neon | tetris | spiral | crt | plasma | tunein | helix)
    python3 -I "$here/omasavr-native.py" "$effect" "$art" "$lib" &
    ;;
  *)
    setup "$effect"
    ttfx -i "$art" \
      --frame-rate "$rate" --canvas-width 0 --canvas-height 0 --reuse-canvas --anchor-canvas c --anchor-text c \
      --no-eol --no-restore-cursor "$base" "${args[@]}" &
    ;;
  esac
  player=$!

  while kill -0 "$player" 2>/dev/null; do
    if read -rsn1 -t 1 || ! screensaver_in_focus; then
      exit_screensaver
    fi
  done
  wait "$player"
  status=$?
  player=

  # An effect that can't play (omascii gone, say) shouldn't spin: after a few
  # quick failures in a row, hand over to Omarchy's screensaver.
  if ((status != 0 && SECONDS - started < 2)); then
    ((++failures >= 5)) && exec /usr/bin/omarchy-screensaver "$@"
    continue
  fi
  failures=0

  # Rest on the art between effects.
  if ((pause > 0)) && { read -rsn1 -t "$pause" || ! screensaver_in_focus; }; then
    exit_screensaver
  fi
done
