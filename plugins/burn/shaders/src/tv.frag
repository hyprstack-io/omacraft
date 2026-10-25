// TV Effect: an old CRT switching off. The picture collapses to a bright
// line, then to a dot, then fades.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    float sy = 1.0 - smoothstep(0.0, 0.55, p) * 0.995;
    float sx = 1.0 - smoothstep(0.5, 0.85, p) * 0.995;
    vec2 c = uv - 0.5;
    vec2 s = c / vec2(sx, sy) + 0.5;
    vec4 w = win(s);
    float bright = smoothstep(0.1, 0.55, p);
    w.rgb = mix(w.rgb, vec3(w.a), bright * 0.85);
    w *= 1.0 - smoothstep(0.85, 1.0, p);
    vec2 a = vec2(aspect(), 1.0);
    float dot = (1.0 - smoothstep(0.0, 0.04 * intensity, length(c * a))) * smoothstep(0.75, 0.88, p) * (1.0 - smoothstep(0.9, 1.0, p));
    return glow(w, mix(vec3(1.0), color.rgb, 0.25), dot);
}
