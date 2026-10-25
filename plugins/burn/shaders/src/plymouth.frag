// Plymouth: the window squeezes down into the boot screen's progress bar,
// the bar fills, and it fades like the splash handing over.
float sdRoundRect(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
vec4 effect() {
    vec2 uv = winUv();
    vec2 ws = winSize();
    float p = progress;
    float a = easeInOut(smoothstep(0.0, 0.4, p));
    float barH = clamp(ws.y * 0.025, 6.0, 14.0);
    vec2 hb = vec2(ws.x * mix(0.5, 0.28, a), mix(ws.y * 0.5, barH * 0.5, a));
    vec2 q = uv * ws - ws * 0.5;
    float d = sdRoundRect(q, hb, mix(0.0, hb.y, smoothstep(0.6, 1.0, a)));
    float fade = 1.0 - smoothstep(0.86, 1.0, p);
    if (d > 1.5) return vec4(0.0);
    // The window, squashed, washing out into the bar's colour.
    vec2 s = q / (hb * 2.0) + 0.5;
    vec4 w = win(s);
    float luma = dot(w.rgb, vec3(0.299, 0.587, 0.114));
    vec4 c = mix(w, premul(color2.rgb * (0.15 + 0.2 * luma), 1.0), smoothstep(0.3, 0.95, a));
    // The fill runs left to right once the bar has formed.
    float fill = smoothstep(0.4, 0.84, p);
    float x = (q.x + hb.x) / (2.0 * hb.x);
    c = mix(c, premul(mix(color.rgb, color2.rgb, x * 0.35), 1.0), step(x, fill) * smoothstep(0.85, 1.0, a));
    float rim = (1.0 - smoothstep(0.0, 1.5, abs(d))) * smoothstep(0.7, 1.0, a);
    c = glow(c * smoothstep(1.5, -0.5, d), color2.rgb, rim * 0.8 * intensity);
    return c * fade;
}
