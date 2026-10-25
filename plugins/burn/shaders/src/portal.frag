// Portal: a swirling portal opens behind the window, sucks it in and closes.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    vec2 a = vec2(aspect(), 1.0);
    vec2 c = (uv - 0.5) * a;
    float r = length(c);
    float ang = atan(c.y, c.x);

    float open = sin(clamp(p * 1.15, 0.0, 1.0) * PI);
    float radius = open * 0.42 * min(a.x, 1.0) * intensity;
    float swirl = fbm(vec2(ang * 1.5 + r * 10.0 - time * 3.0, r * 6.0 - time));
    float edge = radius * (0.85 + swirl * 0.3);
    float disc = 1.0 - smoothstep(edge - 0.02, edge, r);
    vec3 green = color.rgb;
    vec3 portal = mix(green * 0.35, mix(green, vec3(0.85, 1.0, 0.6), 0.5), swirl);
    portal += vec3(1.0) * pow(1.0 - smoothstep(0.0, 0.03, abs(r - edge)), 2.0) * 0.6;
    vec4 col = premul(portal, disc);

    // The window spirals inwards, shrinking towards the middle.
    float t = smoothstep(0.1, 0.85, p);
    float scale = 1.0 - t * 0.98;
    vec2 s = rotate(c, t * (6.0 + 4.0 * (1.0 - r))) / scale;
    vec4 w = win(s / a + 0.5);
    w *= 1.0 - smoothstep(0.7, 0.9, p);
    return over(w, col);
}
