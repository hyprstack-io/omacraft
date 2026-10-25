// Focus: the window blurs out of focus, grows a little and fades.
vec4 effect() {
    vec2 uv = winUv();
    float p = progress;
    vec2 c = (uv - 0.5) / (1.0 + p * 0.12) + 0.5;
    float radius = p * 28.0 * intensity;
    vec4 sum = vec4(0.0);
    float total = 0.0;
    for (int i = 0; i < 24; i++) {
        float fi = float(i);
        float r = sqrt((fi + 0.5) / 24.0) * radius;
        float a = fi * 2.39996;
        vec2 o = vec2(cos(a), sin(a)) * r / winSize();
        sum += win(c + o);
        total += 1.0;
    }
    return sum / total * (1.0 - progress);
}
