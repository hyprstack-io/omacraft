// Matrix: digital rain falls down each column and eats the window as it goes.
float glyph(vec2 cell, vec2 f, float t) {
    // A 5x7 dot glyph that changes now and then.
    vec2 g = floor(f * vec2(5.0, 7.0));
    float pick = floor(t * (2.0 + hash(cell) * 6.0));
    return step(0.5, hash(g + cell * 7.0 + pick * 13.0)) * step(0.5, f.x * 5.0 - g.x + 0.25) * step(0.5, f.y * 7.0 - g.y + 0.25);
}
vec4 effect() {
    vec2 uv = winUv();
    vec2 cellSize = vec2(12.0, 16.0);
    vec2 g = uv * winSize() / cellSize;
    vec2 cell = floor(g);
    vec2 f = fract(g);
    float rows = winSize().y / cellSize.y;
    float speed = 0.6 + hash1(cell.x) * 0.8;
    float delay = hash1(cell.x + 50.0) * 0.4;
    float head = (progress * 1.5 - delay - 0.02) * speed * 1.6 * rows;
    float behind = head - cell.y;
    vec4 w = win(uv);
    vec4 col = w * step(behind, 0.0);
    if (!inside(uv) || behind < 0.0) {
        float near = step(-1.0, behind) * step(behind, 0.0) * smoothstep(0.0, 0.05, progress);
        return glow(col, color.rgb * 0.6, near * 0.3 * float(inside(uv)));
    }
    float trail = exp(-behind / (rows * 0.25 * intensity)) * (1.0 - smoothstep(0.85, 1.0, progress));
    float ch = glyph(cell, f, time);
    vec3 green = color.rgb;
    vec3 c = behind < 1.0 ? vec3(0.85, 1.0, 0.9) : green;
    float a = ch * trail;
    return premul(c, a) + premul(green * 0.15, trail * 0.4);
}
