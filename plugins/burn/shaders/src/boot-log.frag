// Boot Log: line by line from the top, the window turns into a scrolling
// systemd boot log, green [  OK  ] and all, with the cursor at the front.
float dotGlyph(vec2 cell, vec2 f) {
    vec2 g = floor(f * vec2(5.0, 7.0));
    float on = step(0.45, hash(g + cell * 7.0));
    vec2 inCell = f * vec2(5.0, 7.0) - g;
    // Leave a column and row of room so glyphs read as letters.
    return on * step(g.x, 3.5) * step(0.5, g.y) * step(g.y, 5.5) * step(0.2, inCell.x) * step(0.2, inCell.y);
}
vec4 effect() {
    vec2 uv = winUv();
    vec2 ws = winSize();
    vec2 cellPx = vec2(8.0, 14.0);
    vec2 g = uv * ws / cellPx;
    vec2 cell = floor(g);
    vec2 f = fract(g);
    float rows = ws.y / cellPx.y;
    float front = easeInOut(clamp(progress * 1.25, 0.0, 1.0)) * (rows + 1.0);
    vec4 w = win(uv);
    if (!inside(uv)) return w * step(front, 0.0);
    float fade = 1.0 - smoothstep(0.8, 1.0, progress);
    if (cell.y >= front) {
        // The cursor, blinking in the row the log is writing.
        float cursor = step(cell.y, front) * step(cell.x, 0.5) * step(0.5, fract(time * 3.0));
        return mix(w, premul(color2.rgb, 1.0), cursor * 0.9);
    }
    // The log scrolls up as lines come in.
    float line = cell.y + floor(time * 14.0);
    float cols = ws.x / cellPx.x;
    float len = 12.0 + hash1(line) * cols * 0.55;
    float lit = 0.0;
    vec3 ink = color2.rgb;
    if (cell.x == 0.0 || cell.x == 7.0) {
        // The brackets.
        lit = step(0.15, f.x) * step(f.x, 0.4) * step(0.2, f.y) * step(f.y, 0.85);
    } else if (cell.x >= 2.0 && cell.x <= 5.0) {
        float ok = step(0.12, hash1(line + 7.0));
        lit = dotGlyph(vec2(cell.x, 3.0 + ok), f) * step(cell.x, 3.5 + ok);
        ink = ok > 0.5 ? color.rgb : vec3(1.0, 0.45, 0.45);
    } else if (cell.x >= 9.0 && cell.x < 9.0 + len) {
        lit = dotGlyph(vec2(cell.x, line), f) * step(0.18, hash(vec2(cell.x, line) + 0.5));
    }
    vec4 bg = premul(vec3(0.04, 0.05, 0.07), 0.96);
    return over(premul(ink, lit), bg) * fade;
}
