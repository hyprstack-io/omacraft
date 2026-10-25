// Border Trace: two comets in the active border's gradient chase round the
// window as it draws in and fades.
float sdRoundRect(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
vec4 effect() {
    vec2 uv = winUv();
    vec2 ws = winSize();
    float p = progress;
    float scale = 1.0 - easeIn(p) * 0.3 * intensity;
    vec2 q = (uv - 0.5) * ws;
    float d = sdRoundRect(q, ws * 0.5 * scale, 10.0);
    vec4 w = win((uv - 0.5) / scale + 0.5) * step(d, 0.0);
    w *= 1.0 - smoothstep(0.35, 0.9, p);
    // Where round the edge this pixel is, 0 to 1.
    float u = atan(q.y / ws.y, q.x / ws.x) / TAU + 0.5;
    float head = fract(p * 1.6 + seed);
    float behind = min(fract(head - u), fract(head + 0.5 - u));
    float tail = exp(-behind / 0.09);
    float ring = 1.0 - smoothstep(1.0, 2.5 + intensity, abs(d + 1.5));
    // A soft glow just outside the line, gone within a few pixels.
    float halo = exp(-max(d, 0.0) / 3.0) * step(0.0, d) * 0.3;
    vec3 rim = mix(color.rgb, color2.rgb, 0.5 + 0.5 * sin(u * TAU * 2.0 + time * 2.0));
    float life = sin(clamp(p * 1.15, 0.0, 1.0) * PI);
    return glow(w, rim, (ring + halo) * tail * life);
}
