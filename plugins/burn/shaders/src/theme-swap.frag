// Theme Swap: a band sweeps across like a new Omarchy theme going on,
// recolouring the window in its two colours, and the window comes apart in
// stripes behind it.
vec4 effect() {
    vec2 uv = winUv();
    vec2 dir = normalize(vec2(1.0, 0.55));
    vec2 a = vec2(aspect(), 1.0);
    float smax = dot(a, dir);
    float d = dot(uv * a, dir) / smax;
    float front = progress * 1.45 - 0.2;
    float e = d - front;
    vec4 w = win(uv);
    float band = 0.22;
    if (e > band || !inside(uv)) return w * step(-0.001, e);
    // Duotone: the window's light and dark mapped onto the two colours.
    float luma = dot(w.rgb / max(w.a, 0.001), vec3(0.299, 0.587, 0.114));
    vec3 duo = mix(color2.rgb, color.rgb, smoothstep(0.1, 0.9, luma));
    float stripes = step(0.5, fract(d * 46.0 - time * 1.5));
    duo *= 0.85 + 0.15 * stripes;
    if (e >= 0.0) {
        float k = e / band;
        vec3 c = mix(duo, w.rgb / max(w.a, 0.001), smoothstep(0.55, 1.0, k));
        float lead = (1.0 - smoothstep(0.0, 0.025, abs(e - band * 0.96))) * intensity;
        return glow(premul(c, w.a), color.rgb, lead * w.a);
    }
    // Behind the band: thinning stripes of the new colours.
    float left = 1.0 + e / 0.18;
    float keep = step(fract(d * 23.0 + hash1(floor(d * 23.0)) * 0.3), 0.5 * left);
    return premul(duo, w.a * keep * clamp(left, 0.0, 1.0));
}
