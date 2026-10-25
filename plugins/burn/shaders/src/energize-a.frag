// Energize A: the original transporter. The window dissolves into a
// shimmering cloud of sparkles.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    vec4 w = win(uv);
    float shimmer = sin(p * PI);
    vec2 g = uv * vec2(aspect(), 1.0) * 28.0;
    vec2 cell = floor(g);
    vec2 f = fract(g) - 0.5;
    vec2 jitter = (hash2(cell) - 0.5) * 0.6;
    float tw = sin(time * (8.0 + hash(cell) * 14.0) + hash(cell + 2.0) * TAU) * 0.5 + 0.5;
    float star = max(0.0, 1.0 - length(f - jitter) * 3.0);
    star = pow(star, 3.0) * tw;
    float cross = max(0.0, 1.0 - abs(f.x - jitter.x) * 18.0) * max(0.0, 1.0 - abs(f.y - jitter.y) * 3.0)
                + max(0.0, 1.0 - abs(f.y - jitter.y) * 18.0) * max(0.0, 1.0 - abs(f.x - jitter.x) * 3.0);
    float spark = (star + cross * 0.3 * tw) * shimmer * 1.6 * intensity * step(hash(cell + 5.0), 0.65);
    spark *= inside(uv) ? 1.0 : 0.0;
    vec3 beam = color.rgb;
    vec4 col = w * (1.0 - smoothstep(0.15, 0.85, p));
    col.rgb = mix(col.rgb, beam * col.a, shimmer * 0.35);
    col = glow(col, beam * 0.25, shimmer * 0.25 * float(inside(uv)) * (1.0 - p));
    return glow(col, mix(beam, vec3(1.0), 0.5), spark);
}
