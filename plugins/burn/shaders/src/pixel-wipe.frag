// Pixel Wipe: a wave of pixels sweeps out from the pointer and takes the
// window with it.
vec4 effect() {
    vec2 uv = winUv();
    float block = 14.0;
    vec2 bs = block / winSize();
    vec2 cell = floor(uv / bs);
    vec2 centre = (cell + 0.5) * bs;
    vec2 a = vec2(aspect(), 1.0);
    float far = 0.0;
    far = max(far, distance(origin * a, vec2(0.0) * a));
    far = max(far, distance(origin * a, vec2(1.0, 0.0) * a));
    far = max(far, distance(origin * a, vec2(0.0, 1.0) * a));
    far = max(far, distance(origin * a, vec2(1.0) * a));
    float d = distance(centre * a, origin * a) / far;
    float front = progress * 1.3 - 0.15 + (hash(cell) - 0.5) * 0.15 * intensity;
    float e = d - front;
    vec4 w = win(uv);
    if (e > 0.12) return w;
    if (e < 0.0) return vec4(0.0);
    // In the wave: blocky and tinted.
    vec4 b = win(centre);
    float k = e / 0.12;
    b.rgb = mix(mix(b.rgb, color.rgb * b.a, 0.5), b.rgb, k);
    return b * step(hash(cell + 3.0), k * 1.2 + 0.2);
}
