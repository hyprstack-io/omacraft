// Glide: the window tilts away from you, shrinks and fades.
vec4 effect() {
    vec2 uv = winUv();
    float p = easeIn(progress);
    float scale = 1.0 - p * 0.35 * intensity;
    vec2 c = uv - 0.5;
    c.y += p * 0.1;
    // A cheap perspective: rows further away get narrower.
    float tilt = p * 0.9;
    float depth = 1.0 + tilt * (0.5 - uv.y) * 0.8;
    c.x *= depth;
    vec2 s = c / scale + 0.5;
    return win(s) * (1.0 - progress);
}
