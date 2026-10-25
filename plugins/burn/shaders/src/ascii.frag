// ASCII (OMAcraft's own): the window turns into coloured text characters,
// which then flicker out, Omarchy screensaver style.
float charShape(float level, vec2 f, vec2 cell) {
    // Brighter cells get denser characters: . : + * # @
    vec2 g = floor(f * vec2(5.0, 7.0));
    vec2 d = abs(g - vec2(2.0, 3.0));
    if (level < 0.15) return 0.0;
    if (level < 0.3) return float(g.x == 2.0 && g.y == 5.0);
    if (level < 0.45) return float(g.x == 2.0 && (g.y == 2.0 || g.y == 5.0));
    if (level < 0.6) return float((g.x == 2.0 && d.y <= 2.0) || (g.y == 3.0 && d.x <= 2.0));
    if (level < 0.75) return float(d.x == d.y || (g.x == 2.0 && d.y <= 2.0));
    if (level < 0.9) return float(g.x == 1.0 || g.x == 3.0 || g.y == 2.0 || g.y == 4.0);
    return float(d.x <= 2.0 && d.y <= 3.0 && !(d.x <= 1.0 && d.y <= 1.0 && g != vec2(2.0, 3.0)));
}
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    vec2 cellPx = vec2(8.0, 12.0) * intensity;
    vec2 g = uv * winSize() / cellPx;
    vec2 cell = floor(g);
    vec2 centre = (cell + 0.5) * cellPx / winSize();
    vec4 avg = win(centre);
    float level = clamp(dot(avg.rgb, vec3(0.3, 0.59, 0.11)) / max(avg.a, 0.001) * 3.0 + 0.2, 0.0, 1.0);
    float into = smoothstep(0.0, 0.3, p);
    float gone = step(hash(cell), smoothstep(0.45, 1.0, p) + (hash(cell + floor(time * 15.0)) - 0.5) * 0.1);
    float ch = charShape(level, fract(g), cell);
    vec3 tint = mix(mix(avg.rgb / max(avg.a, 0.001), color.rgb, 0.5), vec3(1.0), 0.25);
    vec4 text = premul(tint, ch * avg.a) * (1.0 - gone);
    vec4 back = win(uv) * 0.25 * (1.0 - smoothstep(0.3, 0.8, p));
    return mix(win(uv), over(text, back), into);
}
