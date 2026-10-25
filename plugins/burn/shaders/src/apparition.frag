// Apparition: the window twists into a ghostly swirl and fades away.
vec4 effect() {
    vec2 uv = winUv();
    float p = easeIn(progress);
    vec2 c = (uv - 0.5) * vec2(aspect(), 1.0);
    float r = length(c);
    float scale = 1.0 - p * 0.7;
    float twist = p * 8.0 * intensity * (1.0 - smoothstep(0.0, 0.9, r));
    vec2 s = rotate(c, twist) / scale;
    vec2 suv = s / vec2(aspect(), 1.0) + 0.5;
    vec4 w = win(suv);
    float smoke = fbm(suv * 4.0 + vec2(time * 0.6, -time * 0.9));
    float a = smoothstep(progress * 1.2 - 0.1, progress * 1.2 + 0.15, smoke * 0.9 + (1.0 - r) * 0.2);
    vec3 ghost = mix(w.rgb, vec3(dot(w.rgb, vec3(0.33))) + color.rgb * 0.3, p);
    return vec4(ghost, w.a) * a * (1.0 - p * 0.6);
}
