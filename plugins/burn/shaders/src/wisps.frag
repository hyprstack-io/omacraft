// Wisps: the window fades while glowing wisps of light float off it.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    vec4 w = win(uv) * (1.0 - smoothstep(0.1, 0.8, p));
    vec2 a = vec2(aspect(), 1.0);
    float light = 0.0;
    vec3 tint = vec3(0.0);
    for (int i = 0; i < 36; i++) {
        float fi = float(i);
        vec2 start = vec2(hash1(fi), hash1(fi + 40.0));
        float life = clamp(p * 1.5 - hash1(fi + 80.0) * 0.5, 0.0, 1.0);
        vec2 pos = start + vec2(sin(life * 6.0 + fi) * 0.08, -life * (0.4 + hash1(fi + 120.0) * 0.5)) * intensity;
        pos.x += cos(life * 9.0 + fi * 1.7) * 0.03;
        float d = length((uv - pos) * a);
        float k = sin(life * PI) * max(0.0, 0.0025 / (d * d + 0.0004) - 0.08);
        light += k;
        tint += mix(color.rgb, color2.rgb, hash1(fi + 7.0)) * k;
    }
    light = min(light, 2.0);
    return glow(w, tint / max(light, 0.001) , light * 0.5);
}
