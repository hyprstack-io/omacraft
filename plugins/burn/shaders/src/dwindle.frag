// Dwindle: the window splits into Hyprland's dwindle layout, each tile
// gapped and edged with a gradient border, and the tiles close one by one
// from the biggest into the spiral.
float sdRoundRect(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
vec4 effect() {
    vec2 uv = winUv();
    vec2 ws = winSize();
    // Each split keeps the first half as a tile and splits the second again,
    // across the longer side, as dwindle does.
    vec2 lo = vec2(0.0), hi = vec2(1.0);
    float level = 0.0;
    for (int k = 0; k < 5; k++) {
        vec2 span = (hi - lo) * ws;
        bool across = span.x >= span.y;
        float mid = across ? mix(lo.x, hi.x, 0.5) : mix(lo.y, hi.y, 0.5);
        float at = across ? uv.x : uv.y;
        if (at < mid) {
            if (across) hi.x = mid; else hi.y = mid;
            break;
        }
        if (across) lo.x = mid; else lo.y = mid;
        level += 1.0;
    }
    float delay = level * 0.11 + hash(lo * 31.0) * 0.06;
    float t = clamp((progress * 1.7 - delay) / 0.7, 0.0, 1.0);
    float k = 1.0 - easeIn(t) * 0.9;
    vec2 cUv = (lo + hi) * 0.5;
    vec2 halfPx = (hi - lo) * ws * 0.5;
    float gap = 7.0 * smoothstep(0.0, 0.2, t) * intensity;
    vec2 q = (uv - cUv) * ws;
    float d = sdRoundRect(q, max(halfPx * k - gap, vec2(0.0)), 8.0 * smoothstep(0.0, 0.2, t));
    // The tile's own part of the window, shrunk with it.
    vec2 s = cUv + (uv - cUv) / k;
    vec4 w = win(s) * step(d, 0.0) * float(inside(uv));
    float fade = 1.0 - smoothstep(0.75, 1.0, t);
    float edge = (1.0 - smoothstep(0.0, 2.5, abs(d))) * smoothstep(0.0, 0.08, t) * fade;
    float ang = atan(q.y, q.x) / TAU + 0.5;
    vec3 rim = mix(color.rgb, color2.rgb, 0.5 + 0.5 * sin((ang + time * 0.6) * TAU));
    return glow(w * fade, rim, edge * float(inside(uv)));
}
