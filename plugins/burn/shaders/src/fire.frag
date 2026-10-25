// Fire: the window burns from the bottom up behind a front of flames.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    float n = fbm(uv * vec2(5.0, 3.0) + vec2(0.0, time * 1.3) + seed * 10.0);
    float v = (1.0 - uv.y) * 0.65 + n * 0.35;
    float front = p * 1.3 - 0.15;
    float d = v - front;

    vec4 w = win(uv);
    w.rgb *= mix(0.15, 1.0, smoothstep(0.0, 0.1, d));
    vec4 col = w * smoothstep(0.0, 0.015, d);

    // Tongues of flame lick upwards from just behind the front.
    float tongue = fbm(vec2(uv.x * 7.0, uv.y * 3.0 + time * 3.2) + seed * 4.0);
    float above = d - 0.02;
    float heat = 1.0 - smoothstep(0.0, 0.22 * intensity, abs(above) + (1.0 - tongue) * 0.25 - 0.08);
    heat *= smoothstep(1.0, 0.85, p) * smoothstep(0.0, 0.05, p);
    // Flames stay over the window's own width, and rise a little above it.
    heat *= smoothstep(-0.02, 0.03, uv.x) * smoothstep(1.02, 0.97, uv.x);
    heat *= smoothstep(-0.4, -0.1, uv.y) * step(uv.y, 1.0);
    return over(premul(fireColor(heat * 0.95), clamp(heat * 1.3, 0.0, 1.0)), col);
}
