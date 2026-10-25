// Mushroom: an 8-bit power-down. The window flickers between sizes in hard
// steps, goes blocky and pops out with a little starburst.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    float step8 = floor(p * 9.0);
    float big = mod(step8, 2.0) == 0.0 ? 1.0 : 0.75;
    float scale = mix(big, 0.15, smoothstep(0.55, 1.0, p));
    vec2 anchor = vec2(0.5, 1.0);
    vec2 s = (uv - anchor) / scale + anchor;
    float block = 1.0 + floor(p * 16.0 * intensity);
    vec2 bs = block / winSize();
    s = (floor(s / bs) + 0.5) * bs;
    vec4 w = win(s) * (1.0 - smoothstep(0.85, 1.0, p));
    // Starburst at the end.
    vec2 c = (uv - vec2(0.5, 0.85)) * vec2(aspect(), 1.0);
    float burst = smoothstep(0.75, 0.9, p) * (1.0 - smoothstep(0.92, 1.0, p));
    float ang = atan(c.y, c.x);
    float rays = pow(abs(cos(ang * 4.0)), 18.0) * (1.0 - smoothstep(0.0, 0.25, length(c)));
    float pixel = step(0.3, rays);
    return glow(w, mix(color.rgb, vec3(1.0, 0.9, 0.3), 0.5), pixel * burst);
}
