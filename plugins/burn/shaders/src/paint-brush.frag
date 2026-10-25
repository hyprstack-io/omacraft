// Paint Brush: broad strokes of paint wipe the window away, row by row.
vec4 effect() {
    vec2 uv = winUv();
    const float bands = 7.0;
    float b = floor(clamp(uv.y, 0.0, 0.9999) * bands);
    float within = fract(uv.y * bands);
    float start = b / bands * 0.55;
    float t = clamp((progress - start) / 0.45, 0.0, 1.0);
    float dir = mod(b, 2.0) == 0.0 ? uv.x : 1.0 - uv.x;
    // Bristles: the stroke edge is ragged along its width.
    float bristle = noise(vec2(within * 40.0, b * 3.0)) * 0.12 + fbm(vec2(dir * 3.0, within * 8.0 + b)) * 0.08;
    float ragged = 1.0 - smoothstep(0.8, 1.0, abs(within - 0.5) * 2.0) * noise(vec2(dir * 60.0, b));
    float edge = t * 1.3 - bristle + (1.0 - ragged) * 0.15;
    float painted = max(smoothstep(edge - 0.01, edge, dir), step(t, 0.0));
    vec4 w = win(uv);
    vec4 col = w * painted;
    // The wet paint at the tip of the stroke.
    float tip = (1.0 - smoothstep(0.0, 0.05 * intensity, abs(dir - edge))) * step(0.001, t) * step(t, 0.999) * ragged;
    return glow(col, color.rgb, tip * 0.8 * float(inside(uv)));
}
