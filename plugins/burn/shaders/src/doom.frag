// Doom: the screen melt from the game, column by column.
vec4 effect() {
    vec2 uv = winUv();
    float cols = 40.0 * clamp(aspect(), 0.6, 2.5);
    float c = floor(uv.x * cols);
    // Neighbouring columns start close together, like the original.
    float delay = hash1(c) * 0.25 + noise(vec2(c * 0.3, seed * 9.0)) * 0.25;
    float t = clamp((progress * 1.4 - delay) / 0.9, 0.0, 1.0);
    float shift = easeIn(t) * (1.0 + pad.y * 2.0 / winSize().y) * intensity;
    vec2 s = vec2(uv.x, uv.y - shift);
    if (s.y < 0.0) return vec4(0.0);
    return win(s);
}
