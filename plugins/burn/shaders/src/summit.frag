// Summit: the window breaks into a field of triangles that wink out from
// the top corners in, leaving a mountain peak a moment before it goes.
vec4 effect() {
    vec2 uv = winUv();
    const float H = 0.8660254;
    float n = 7.0;
    vec2 g = uv * vec2(aspect(), 1.0) * n;
    float y = g.y / H;
    float r = floor(y);
    float fy = fract(y);
    float shift = 0.5 * mod(r, 2.0);
    float x = g.x + shift;
    float c = floor(x);
    float fx = fract(x);
    // Each triangle in a frame where it points up: |tx - 0.5| <= (1 - ty) / 2.
    bool up = abs(fx - 0.5) <= 0.5 * (1.0 - fy);
    float side = fx < 0.5 ? 0.0 : 1.0;
    vec2 t = up ? vec2(fx, fy) : vec2(fx - side + 0.5, 1.0 - fy);
    vec2 id = up ? vec2(c * 2.0, r) : vec2(c * 2.0 + side * 2.0 - 1.0, r);
    vec2 cen = vec2(0.5, 1.0 / 3.0);
    // Back from a point in the triangle's frame to window uv.
    vec2 base = vec2(c - shift + (up ? 0.0 : side - 0.5), r);
    vec2 cenG = vec2(base.x + cen.x, (r + (up ? cen.y : 1.0 - cen.y)) * H);
    vec2 cenUv = cenG / (vec2(aspect(), 1.0) * n);
    float reach = clamp((1.0 - cenUv.y) * 0.5 + abs(cenUv.x - 0.5) * 0.65, 0.0, 1.0);
    float delay = 0.7 * (1.0 - reach) + hash(id) * 0.08;
    float tt = clamp((progress * 1.6 - delay) / 0.5, 0.0, 1.0);
    float k = 1.0 - easeIn(tt);
    if (k < 0.001) return vec4(0.0);
    vec2 s = cen + (t - cen) / k;
    float m = min(s.y, 0.5 * (1.0 - s.y) - abs(s.x - 0.5));
    if (m < 0.0) return vec4(0.0);
    vec2 sg = vec2(base.x + s.x, (r + (up ? s.y : 1.0 - s.y)) * H);
    vec4 w = win(sg / (vec2(aspect(), 1.0) * n));
    float edge = (1.0 - smoothstep(0.0, 0.05, m)) * sin(tt * PI) * intensity;
    return glow(w * (1.0 - smoothstep(0.7, 1.0, tt)), mix(color.rgb, color2.rgb, tt), edge * float(inside(uv)));
}
