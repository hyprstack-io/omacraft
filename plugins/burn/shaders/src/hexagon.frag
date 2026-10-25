// Hexagon: the window breaks into a honeycomb that winks out cell by cell,
// leaving glowing seams.
vec4 hexCoords(vec2 p) {
    const vec2 s = vec2(1.0, 1.7320508);
    vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
    vec4 h = vec4(p - hc.xy * s, p - (hc.zw + 0.5) * s);
    return dot(h.xy, h.xy) < dot(h.zw, h.zw) ? vec4(h.xy, hc.xy) : vec4(h.zw, hc.zw + 0.5);
}
float hexEdge(vec2 p) {
    p = abs(p);
    return max(dot(p, normalize(vec2(1.0, 1.7320508))), p.x);
}
vec4 effect() {
    vec2 uv = winUv();
    vec2 g = uv * vec2(aspect(), 1.0) * 9.0;
    vec4 h = hexCoords(g);
    vec2 centre = h.zw * vec2(1.0, 1.7320508) / 9.0 / vec2(aspect(), 1.0);
    float delay = distance(centre, origin) * 0.6 + hash(h.zw) * 0.3;
    float t = clamp((progress * 1.6 - delay) / 0.6, 0.0, 1.0);
    float e = hexEdge(h.xy);
    float shrink = 0.5 * (1.0 - t);
    vec4 w = win(uv);
    vec4 col = w * step(e, shrink);
    float seam = (1.0 - smoothstep(0.0, 0.05, abs(e - shrink))) * sin(min(t * 1.5, 1.0) * PI);
    float line = smoothstep(0.44, 0.5, e) * sin(clamp(progress * 2.0, 0.0, 1.0) * PI) * 0.6;
    float lit = (seam + line) * intensity * float(inside(uv));
    return glow(col, color.rgb, lit);
}
