// Snap of Disintegration: the window crumbles into dust that blows away,
// starting at one side.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    vec2 wind = normalize(vec2(1.0, -0.6));
    vec4 col = vec4(0.0);
    const int LAYERS = 8;
    for (int i = 0; i < LAYERS; i++) {
        float fi = float(i);
        // Each grain belongs to one layer; each layer drifts a bit differently.
        vec2 drift = rotate(wind, (hash1(fi) - 0.5) * 1.2) * (0.6 + hash1(fi + 9.0) * 0.8);
        float curl = sin(fi * 2.3 + time * 2.0) * 0.08;
        // Grains on the left go first.
        vec2 guess = uv;
        for (int k = 0; k < 2; k++) {
            float local = clamp((p * 1.6 - guess.x * 0.6 - hash(floor(guess * winSize() / 3.0)) * 0.15) / 0.7, 0.0, 1.0);
            guess = uv - (drift + vec2(0.0, curl)) * easeIn(local) * 0.6 * intensity;
        }
        vec2 grain = floor(guess * winSize() / 3.0);
        if (floor(hash(grain + 31.0) * float(LAYERS)) != fi) continue;
        float local = clamp((p * 1.6 - guess.x * 0.6 - hash(grain) * 0.15) / 0.7, 0.0, 1.0);
        vec4 w = win(guess);
        if (w.a <= 0.0) continue;
        if (local > 0.0) w.rgb = mix(w.rgb, color.rgb * w.a * 0.7, local * 0.6);
        col = over(w * (1.0 - local), col);
    }
    return col;
}
