// Aura Glow: a glowing aura rises around the window and eats it from the
// edges in.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    vec2 ws = winSize();
    vec2 px = uv * ws;
    float edge = min(min(px.x, px.y), min(ws.x - px.x, ws.y - px.y)) / (0.5 * min(ws.x, ws.y));
    float n = fbm(uv * 5.0 + vec2(0.0, -time * 0.8)) * 0.25;
    float front = p * 1.3 - 0.1;
    float e = edge + n - front;
    vec4 w = win(uv) * smoothstep(0.0, 0.03, e);
    float aura = (1.0 - smoothstep(0.0, 0.07 * intensity, abs(e))) * sin(min(p * 1.2, 1.0) * PI);
    // Outside the window a halo fades with distance, gone before the
    // padding ends.
    float halo = 0.0;
    if (!inside(uv)) {
        vec2 o = max(max(-px, px - ws), vec2(0.0));
        float far = length(o);
        halo = exp(-far / (18.0 * intensity)) * (1.0 - smoothstep(pad.x * 0.4, pad.x * 0.9, far)) * sin(p * PI) * 0.7;
        aura = 0.0;
    }
    return glow(w, mix(color.rgb, color2.rgb, n * 2.0), aura + halo);
}
