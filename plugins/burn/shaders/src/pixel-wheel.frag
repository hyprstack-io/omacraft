// Pixel Wheel: the window turns into a wheel of blocks that spins away.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    vec2 c = (uv - 0.5) * vec2(aspect(), 1.0);
    float r = length(c);
    float ang = atan(c.y, c.x);
    float rings = 22.0;
    float spokes = 48.0;
    float ri = floor(r * rings);
    float spin = easeIn(p) * (3.0 + ri * 0.15) * intensity;
    float ai = floor((ang - spin) / TAU * spokes);
    float qr = (ri + 0.5) / rings;
    float qa = (ai + 0.5) / spokes * TAU + spin;
    float mixQ = smoothstep(0.0, 0.3, p);
    vec2 q = mix(c, vec2(cos(qa), sin(qa)) * qr, mixQ);
    vec2 s = q / vec2(aspect(), 1.0) + 0.5;
    vec2 s0 = rotate(c, spin * (1.0 - mixQ)) / vec2(aspect(), 1.0) + 0.5;
    vec4 w = win(mixQ > 0.0 ? s : s0);
    float gone = step(hash(vec2(ri, ai)), smoothstep(0.35, 1.0, p) * (0.6 + r));
    return w * (1.0 - gone);
}
