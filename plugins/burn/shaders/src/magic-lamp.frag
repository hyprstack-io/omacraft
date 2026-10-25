// Magic Lamp: the window is pulled down into the bottom edge like a genie.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    float bottom = 1.0 + pad.y / winSize().y;
    float slide = easeIn(clamp((p - 0.25) / 0.75, 0.0, 1.0)) * bottom;
    float pinch = smoothstep(0.0, 0.55, p);
    // How far down the curve this row is: lower rows pinch first.
    float row = clamp(uv.y / bottom, 0.0, 1.0);
    float k = smoothstep(0.0, 1.0, row) * pinch;
    float width = mix(1.0, 0.06, k * intensity / max(intensity, 1.0));
    float cx = mix(0.5, origin.x, k);
    vec2 s = vec2((uv.x - cx) / width + 0.5, uv.y - slide);
    if (s.y > 1.0 || s.y < -0.01) return vec4(0.0);
    return win(s);
}
