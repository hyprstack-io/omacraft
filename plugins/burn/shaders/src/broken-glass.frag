// Broken Glass: the window cracks into shards that fly out and fall.
const int GX = 7;
const int GY = 5;

vec2 site(ivec2 c) {
    return (vec2(c) + 0.2 + 0.6 * hash2(vec2(c) + 3.1)) / vec2(GX, GY);
}

bool owns(ivec2 cell, vec2 uv) {
    vec2 me = site(cell);
    float dm = distance(uv * vec2(aspect(), 1.0), me * vec2(aspect(), 1.0));
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++) {
            if (x == 0 && y == 0) continue;
            ivec2 n = cell + ivec2(x, y);
            if (n.x < 0 || n.y < 0 || n.x >= GX || n.y >= GY) continue;
            if (distance(uv * vec2(aspect(), 1.0), site(n) * vec2(aspect(), 1.0)) < dm) return false;
        }
    return true;
}

vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    float crack = smoothstep(0.0, 0.15, p);
    float t = max(p - 0.12, 0.0) / 0.88;
    vec2 impact = origin;
    vec4 col = vec4(0.0);
    for (int y = 0; y < GY; y++)
        for (int x = 0; x < GX; x++) {
            ivec2 cell = ivec2(x, y);
            vec2 s = site(cell);
            float r = hash(vec2(cell) + 7.7);
            vec2 dir = normalize(s - impact + (hash2(vec2(cell)) - 0.5) * 0.3);
            float lag = (distance(s, impact) * 0.4 + r * 0.2);
            float tt = clamp((t - lag * 0.5) / (1.0 - lag * 0.5), 0.0, 1.0);
            vec2 move = dir * tt * (0.35 + r * 0.4) * intensity + vec2(0.0, 1.6 * tt * tt);
            float ang = (r - 0.5) * 4.0 * tt;
            // Back from the screen to the shard's place in the window.
            vec2 q = (uv - s - move) * vec2(aspect(), 1.0);
            q = rotate(q, -ang) / vec2(aspect(), 1.0) + s;
            q = (q - s) / (1.0 - 0.3 * tt) + s;
            if (!inside(q) || !owns(cell, q)) continue;
            vec4 w = win(q);
            // A bright rim along each shard's edges once the glass cracks.
            vec2 a = q * vec2(aspect(), 1.0);
            float d1 = 9.0, d2 = 9.0;
            for (int yy = -1; yy <= 1; yy++)
                for (int xx = -1; xx <= 1; xx++) {
                    ivec2 n = cell + ivec2(xx, yy);
                    if (n.x < 0 || n.y < 0 || n.x >= GX || n.y >= GY) continue;
                    float d = distance(a, site(n) * vec2(aspect(), 1.0));
                    if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) d2 = d;
                }
            float rim = (1.0 - smoothstep(0.0, 0.006, d2 - d1)) * crack;
            w = glow(w, vec3(0.9, 0.95, 1.0), rim * 0.8);
            w.rgb += vec3(0.08) * (1.0 - abs(ang)) * tt;
            col = w * (1.0 - smoothstep(0.75, 1.0, tt));
        }
    return col;
}
