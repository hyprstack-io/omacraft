// Glitch: the window jumps, splits its colours and drops out in blocks.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    float frame = floor(time * 18.0);
    float row = floor(uv.y * 24.0 + hash1(frame) * 3.0);
    float jump = (hash(vec2(row, frame)) - 0.5) * 0.25 * p * intensity * step(0.5 - p * 0.4, hash(vec2(frame, row)));
    vec2 s = vec2(uv.x + jump, uv.y);
    float split = 0.02 * p * intensity * (hash1(frame + 3.0) - 0.3);
    vec4 r = win(s + vec2(split, 0.0));
    vec4 g = win(s);
    vec4 b = win(s - vec2(split, 0.0));
    vec4 col = vec4(r.r, g.g, b.b, max(max(r.a, g.a), b.a));
    vec2 block = floor(uv * vec2(16.0, 12.0) + vec2(hash1(frame), hash1(frame + 1.0)) * 4.0);
    float gone = step(hash(block + frame * 0.01), p * 1.15);
    float flash = step(0.96, hash(block + frame)) * sin(p * PI);
    col = glow(col, color.rgb, flash * 0.5 * float(inside(uv)));
    return col * (1.0 - gone);
}
