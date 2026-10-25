// Pixelate: the window coarsens into big pixels that drop out at random.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    float size = 1.0 + floor(easeIn(p) * 48.0 * intensity);
    vec2 bs = size / winSize();
    vec2 cell = floor(uv / bs);
    vec2 s = (cell + 0.5) * bs;
    vec4 w = win(s);
    float gone = step(hash(cell + size * 0.13), smoothstep(0.3, 1.0, p));
    return w * (1.0 - gone);
}
