// Warp Speed (OMAcraft's own): the window stretches into streaks of light
// and jumps away towards the pointer.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    vec2 a = vec2(aspect(), 1.0);
    vec2 dir = (uv - origin) * a;
    float r = length(dir);
    float stretch = easeIn(p) * 0.6 * intensity;
    vec4 sum = vec4(0.0);
    for (int i = 0; i < 16; i++) {
        float k = float(i) / 15.0;
        vec2 s = origin + dir / a * (1.0 - stretch * k) / (1.0 - easeIn(p) * 0.4);
        sum += win(s) * (1.0 - k * 0.5);
    }
    sum /= 12.0;
    sum.rgb += color.rgb * sum.a * stretch * 0.6;
    float fade = 1.0 - smoothstep(0.55, 1.0, p);
    float flash = (1.0 - smoothstep(0.0, 0.04, r)) * smoothstep(0.75, 0.9, p) * (1.0 - smoothstep(0.9, 1.0, p));
    return glow(min(sum, vec4(1.0)) * fade, vec3(1.0), flash);
}
