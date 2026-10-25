#version 440

// Shared by every effect. bin/build-shaders puts this in front of each
// effect's source before compiling it with qsb.
//
// The effect item covers the window plus `pad` pixels on every side, so an
// effect can draw outside the window (flames, shards, dust). `progress` is how
// far the window has gone: 0 is the whole window, 1 is nothing left. Opening
// windows run the same effect from 1 back to 0, with `opening` set to 1.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float time;
    float seed;
    float opening;
    float intensity;
    float border;
    vec2 size;
    vec2 pad;
    vec2 origin;
    vec4 color;
    vec4 color2;
    vec4 borderColor;
};

layout(binding = 1) uniform sampler2D source;

const float PI = 3.14159265359;
const float TAU = 6.28318530718;

// ------------------------------------------------------------ coordinates

vec2 itemPx() { return qt_TexCoord0 * size; }
vec2 winSize() { return max(size - 2.0 * pad, vec2(1.0)); }
// Item pixels to window uv: the window is [0, 1] on both axes.
vec2 toWin(vec2 p) { return (p - pad) / winSize(); }
vec2 winUv() { return toWin(itemPx()); }
float aspect() { return winSize().x / winSize().y; }

// The window as Hyprland drew it, with its border outside the client area.
// Premultiplied, transparent outside.
vec4 win(vec2 uv) {
    vec2 ws = winSize();
    if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0)
        return texture(source, uv);
    vec2 p = uv * ws;
    vec2 o = max(max(-p, p - ws), vec2(0.0));
    if (border > 0.0 && max(o.x, o.y) <= border)
        return vec4(borderColor.rgb * borderColor.a, borderColor.a);
    return vec4(0.0);
}

bool inside(vec2 uv) { return uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0; }

vec2 rotate(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// ------------------------------------------------------------ noise

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21) + seed * 17.0);
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float hash1(float n) { return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453); }
vec2 hash2(vec2 p) { return vec2(hash(p), hash(p + 19.19)); }

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + 11.7;
        a *= 0.5;
    }
    return v;
}

// ------------------------------------------------------------ helpers

vec4 premul(vec3 rgb, float a) { return vec4(rgb * a, a); }
// Paints `top` (premultiplied) over `bottom`.
vec4 over(vec4 top, vec4 bottom) { return top + bottom * (1.0 - top.a); }
// Adds light without needing a background.
vec4 glow(vec4 base, vec3 rgb, float a) { return vec4(base.rgb + rgb * a, clamp(base.a + a, 0.0, 1.0)); }

vec3 fireColor(float t) {
    t = clamp(t, 0.0, 1.0);
    vec3 c = mix(vec3(0.25, 0.02, 0.0), vec3(0.95, 0.25, 0.02), smoothstep(0.0, 0.35, t));
    c = mix(c, vec3(1.0, 0.65, 0.1), smoothstep(0.35, 0.7, t));
    return mix(c, vec3(1.0, 0.95, 0.75), smoothstep(0.7, 1.0, t));
}

float easeIn(float t) { return t * t; }
float easeOut(float t) { return 1.0 - (1.0 - t) * (1.0 - t); }
float easeInOut(float t) { return t < 0.5 ? 2.0 * t * t : 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0; }

vec4 effect();

void main() {
    fragColor = effect() * qt_Opacity;
}
