// Team Rocket: the window is blasted off over the horizon, spinning, and
// disappears with a twinkle.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    float t = easeIn(clamp(p / 0.85, 0.0, 1.0));
    vec2 a = vec2(aspect(), 1.0);
    vec2 target = vec2(1.0 + pad.x / winSize().x * 0.6, -pad.y / winSize().y * 0.6);
    vec2 centre = mix(vec2(0.5), target, t) + vec2(0.0, -sin(t * PI) * 0.15);
    float scale = mix(1.0, 0.03, t);
    vec2 c = (uv - centre) * a;
    c = rotate(c, -t * 9.0 * intensity) / scale;
    vec4 w = win(c / a + 0.5);
    w *= 1.0 - smoothstep(0.8, 0.9, p);
    // Ding.
    float star = smoothstep(0.82, 0.9, p) * (1.0 - smoothstep(0.92, 1.0, p));
    vec2 sc = (uv - target) * a;
    float ang = atan(sc.y, sc.x);
    float rays = pow(abs(cos(ang * 2.0)), 40.0) * (1.0 - smoothstep(0.0, 0.12, length(sc)));
    float core = 1.0 - smoothstep(0.0, 0.015, length(sc));
    return glow(w, mix(color.rgb, vec3(1.0), 0.6), (rays + core) * star * 1.5);
}
