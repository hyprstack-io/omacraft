#!/bin/bash
# Turns the HyprStack logo video into the Plymouth theme's frame sequence:
# 24 fps, cropped to the logo, faded out to an oval so the frames sit on the
# theme's plain background (#202629, the video's own backdrop), then
# palette-compressed with pngquant.
#
#   plymouth/make-frames.sh VIDEO [OUTDIR]
#
# OUTDIR defaults to the theme's frames/ beside this script. Needs ffmpeg and
# pngquant. If the video's length changes, update frame_count in
# hyprstack-boot.script to match.
set -euo pipefail

video=${1:?usage: make-frames.sh VIDEO [OUTDIR]}
out=${2:-$(dirname "$0")/hyprstack-boot/frames}

# Fully opaque inside two thirds of the oval, smoothstepped to clear at its edge.
alpha="'st(0,hypot((X-W/2)/(W/2),(Y-H/2)/(H/2)));st(1,clip((1-ld(0))/(1-0.66),0,1));255*ld(1)*ld(1)*(3-2*ld(1))'"
filter="crop=840:720:220:0,scale=630:540:flags=lanczos,format=rgba,geq=r='r(X,Y)':g='g(X,Y)':b='b(X,Y)':a=$alpha"

rm -rf "$out"
mkdir -p "$out"
ffmpeg -v error -i "$video" -an -vf "$filter" -fps_mode passthrough -start_number 0 "$out/%d.png"
find "$out" -name '*.png' -print0 | xargs -0 -P "$(nproc)" -n 8 pngquant --quality=60-85 --speed 1 --strip --ext .png --force

echo "$(find "$out" -name '*.png' | wc -l) frames, $(du -sh "$out" | cut -f1), in $out"
