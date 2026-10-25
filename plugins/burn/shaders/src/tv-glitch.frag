// TV Glitch: the CRT switch-off with a bad signal: rolling noise, tearing
// and colour fringes.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    float sy = 1.0 - smoothstep(0.15, 0.65, p) * 0.995;
    float sx = 1.0 - smoothstep(0.6, 0.9, p) * 0.995;
    vec2 c = uv - 0.5;
    float frame = floor(time * 24.0);
    float tear = (noise(vec2(uv.y * 30.0, frame)) - 0.5) * 0.08 * smoothstep(0.0, 0.3, p) * intensity;
    vec2 s = (c + vec2(tear, 0.0)) / vec2(sx, sy) + 0.5;
    float fringe = 0.01 * p * intensity;
    vec4 r = win(s + vec2(fringe, 0.0));
    vec4 g = win(s);
    vec4 b = win(s - vec2(fringe, 0.0));
    vec4 w = vec4(r.r, g.g, b.b, max(max(r.a, g.a), b.a));
    float snow = hash(floor(uv * winSize() / 2.0) + frame);
    float roll = smoothstep(0.0, 0.05, fract(uv.y * 2.0 - time * 1.5)) * 0.2 + 0.8;
    w.rgb = mix(w.rgb, vec3(snow) * w.a, smoothstep(0.0, 0.6, p) * 0.5) * roll;
    w.rgb = mix(w.rgb, vec3(w.a), smoothstep(0.4, 0.7, p) * 0.7);
    w *= 1.0 - smoothstep(0.88, 1.0, p);
    return w;
}
