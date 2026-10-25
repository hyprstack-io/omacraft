// Incinerate: a spark catches somewhere on the window and burns a hole that
// spreads outwards, with glowing embers along the edge and ash above it.
vec4 effect() {
    vec2 uv = winUv();
    vec2 a = vec2(aspect(), 1.0);
    float far = 0.0;
    for (int i = 0; i < 4; i++) far = max(far, distance(origin * a, vec2(float(i & 1), float(i >> 1)) * a));
    float d = distance(uv * a, origin * a) / far;
    float n = fbm(uv * 6.0 + seed * 5.0) * 0.35 + fbm(uv * 18.0 - time * 0.2) * 0.1;
    float front = progress * 1.3 - 0.08;
    float e = d + n * 0.6 - 0.15 - front;
    vec4 w = win(uv);
    w.rgb *= mix(0.1, 1.0, smoothstep(0.0, 0.08, e));
    vec4 col = w * smoothstep(0.0, 0.01, e);
    float ember = (1.0 - smoothstep(0.0, 0.035 * intensity, abs(e))) * float(inside(uv));
    ember *= 0.6 + 0.4 * noise(uv * 80.0 + time * 6.0);
    col = glow(col, fireColor(0.6 + ember * 0.4), ember * 1.3);
    // Ash drifts up out of the hole.
    vec2 ash = floor((uv + vec2(sin(time + uv.y * 7.0) * 0.01, time * 0.08)) * winSize() / 3.0);
    float speck = step(0.985, hash(ash)) * smoothstep(0.0, -0.15, e) * (1.0 - progress) * float(inside(uv));
    return over(premul(vec3(0.35, 0.3, 0.28), speck * 0.8), col);
}
