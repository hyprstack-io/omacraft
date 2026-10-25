// RGB Warp: the colour channels drift apart in waves and fade.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    float amt = easeIn(p) * 0.12 * intensity;
    vec2 wave = vec2(sin(uv.y * 14.0 + time * 6.0), cos(uv.x * 11.0 - time * 5.0)) * amt * 0.5;
    vec4 r = win(uv + vec2(amt, 0.0) + wave);
    vec4 g = win(uv - wave * 1.3);
    vec4 b = win(uv - vec2(amt, -amt * 0.4) + wave.yx);
    float a = max(max(r.a, g.a), b.a);
    return vec4(r.r, g.g, b.b, a) * (1.0 - smoothstep(0.4, 1.0, p));
}
