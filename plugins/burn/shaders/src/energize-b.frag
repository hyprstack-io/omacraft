// Energize B: the later transporter, with rising streaks of gold light.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    vec4 w = win(uv);
    float shimmer = sin(p * PI);
    float streak = noise(vec2(uv.x * 90.0, uv.y * 2.0 - time * 3.0));
    streak = pow(streak, 6.0) * 3.0;
    float rise = noise(vec2(uv.x * 30.0, uv.y * 6.0 + time * 4.0));
    float sparkle = pow(hash(floor(uv * winSize() / 1.5) + floor(time * 20.0)), 60.0) * 2.5;
    float band = smoothstep(0.0, 0.3, 1.0 - abs(uv.y - (1.0 - p * 1.4 + 0.2)) * 3.0);
    vec3 gold = mix(color.rgb, vec3(1.0, 0.85, 0.5), 0.4);
    float a = (1.0 - smoothstep(0.2, 0.9, p)) * mix(1.0, rise, shimmer * 0.8);
    vec4 col = w * a;
    float light = (streak * 0.6 + sparkle) * shimmer * (1.0 - smoothstep(0.6, 1.0, p)) + band * shimmer * 0.5;
    light *= float(inside(uv)) * intensity;
    col = glow(col, mix(gold, vec3(1.0, 0.3, 0.2), rise * 0.4), light * 0.7);
    return col;
}
