// T-Rex Attack: three claw marks rip across the window, and the torn strips
// fall away.
float lineAt(vec2 q, float k) {
    // The slashes run from top right to bottom left.
    return q.x + q.y * 0.55 - k;
}
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    float slash = smoothstep(0.0, 0.25, p);
    float fall = clamp((p - 0.25) / 0.75, 0.0, 1.0);
    const float k0 = 0.42, gap = 0.17;
    vec4 col = vec4(0.0);
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float lo = i == 0 ? -9.0 : k0 + gap * (fi - 1.0);
        float hi = i == 3 ? 9.0 : k0 + gap * fi;
        vec2 dir = normalize(vec2(1.0, 0.55)) * (fi - 1.5) * 0.12;
        vec2 move = dir * fall + vec2(0.0, 1.4 * fall * fall) * (0.7 + hash1(fi) * 0.6);
        float ang = (hash1(fi + 4.0) - 0.5) * 1.2 * fall;
        vec2 piv = vec2(0.5);
        vec2 q = rotate((uv - move - piv) * vec2(aspect(), 1.0), -ang) / vec2(aspect(), 1.0) + piv;
        float l = lineAt(q, 0.0);
        if (l < lo || l >= hi) continue;
        vec4 w = win(q);
        // Raw edges along the tears.
        float tear = min(abs(l - lo), abs(l - hi));
        float rip = (1.0 - smoothstep(0.0, 0.012 * intensity, tear + noise(q * 90.0) * 0.006)) * slash;
        w = mix(w, premul(color.rgb, w.a), rip * 0.85);
        col = over(w * (1.0 - smoothstep(0.7, 1.0, fall)), col);
    }
    // The claw marks themselves while they cut.
    float cut = 0.0;
    for (int j = 0; j < 3; j++) {
        float d = abs(lineAt(uv, k0 + gap * float(j)));
        float reach = slash * 1.6 - (1.0 - uv.y);
        cut += (1.0 - smoothstep(0.0, 0.01, d)) * step(0.0, reach) * (1.0 - smoothstep(0.0, 0.15, fall));
    }
    return glow(col, color.rgb, cut * float(inside(uv)));
}
