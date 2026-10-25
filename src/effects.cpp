#include "effects.h"

#include <QHash>
#include <QSet>
#include <algorithm>
#include <array>
#include <cmath>
#include <optional>

namespace {

constexpr double tau = 6.283185307179586;

// --- colour helpers ---

QColor mix(const QColor &a, const QColor &b, double t) {
    t = std::clamp(t, 0.0, 1.0);
    return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * t, a.greenF() + (b.greenF() - a.greenF()) * t,
                            a.blueF() + (b.blueF() - a.blueF()) * t);
}

QColor scaled(const QColor &c, double k) {
    k = std::clamp(k, 0.0, 1.0);
    return QColor::fromRgbF(c.redF() * k, c.greenF() * k, c.blueF() * k);
}

// A point along evenly spaced stops, clamped at the ends.
QColor ramp(const QList<QColor> &stops, double t) {
    if (stops.isEmpty())
        return Qt::black;
    if (stops.size() == 1)
        return stops.first();
    t = std::clamp(t, 0.0, 1.0) * (stops.size() - 1);
    const int i = std::min<int>(int(t), stops.size() - 2);
    return mix(stops[i], stops[i + 1], t - i);
}

// A point round a loop of stops, so the last blends back into the first.
QColor loop(const QList<QColor> &stops, double t) {
    if (stops.isEmpty())
        return Qt::black;
    t = t - std::floor(t);
    const double at = t * stops.size();
    const int i = int(at) % stops.size();
    return mix(stops[i], stops[(i + 1) % stops.size()], at - std::floor(at));
}

QList<QColor> rainbow() {
    QList<QColor> hues;
    for (int i = 0; i < 6; ++i)
        hues << QColor::fromHsvF(i / 6.0, 1.0, 1.0);
    return hues;
}

// --- deterministic noise, so every frame is reproducible ---

double hash(double n) {
    const double s = std::sin(n * 127.1 + 311.7) * 43758.5453123;
    return s - std::floor(s);
}

double smooth(double t) { return t * t * (3 - 2 * t); }

double noise2(double x, double y) {
    const double ix = std::floor(x), iy = std::floor(y);
    const double fx = smooth(x - ix), fy = smooth(y - iy);
    auto at = [](double a, double b) { return hash(a * 57.0 + b * 131.0); };
    const double top = at(ix, iy) + (at(ix + 1, iy) - at(ix, iy)) * fx;
    const double bottom = at(ix, iy + 1) + (at(ix + 1, iy + 1) - at(ix, iy + 1)) * fx;
    return top + (bottom - top) * fy;
}

// --- designs drawn with the keys ---

// Fifteen columns by six rows, one character per key-sized cell: '1' to '3'
// are the first three slots, '.' the background slot and '0' off. A key
// takes the cell under its centre.
using Bitmap = std::array<const char *, 6>;

const QHash<QString, Bitmap> &bitmaps() {
    static const QHash<QString, Bitmap> maps{
        {"alien", {"....1111111....",
                   "...111111111...",
                   "..12221112221..",
                   "...112212211...",
                   "....1111111....",
                   "......111......"}},
        {"heart", {"..111.....111..",
                   ".12111...11111.",
                   ".1111111111111.",
                   "..11111111111..",
                   "....1111111....",
                   "......111......"}},
        {"smiley", {"....1111111....",
                    "...112111211...",
                    "..11121112111..",
                    "..13111111131..",
                    "...113333311...",
                    "....1111111...."}},
        {"invader", {"....1.....1....",
                     "....1111111....",
                     "...112111211...",
                     "..11111111111..",
                     "..1.1111111.1..",
                     "..1.1.....1.1.."}},
        {"creeper", {"111111111111111",
                     "111000111000111",
                     "111000111000111",
                     "111111000111111",
                     "111100000001111",
                     "111100111001111"}},
        {"pacman", {"..11111...222..",
                    ".1110111.20202.",
                    "11111..3.22222.",
                    "11111..3.22222.",
                    ".1111111.2.2.2.",
                    "..11111........"}},
        {"bolt", {".......1111....",
                  "......1111.....",
                  ".....12222111..",
                  "........1111...",
                  ".......111.....",
                  "......11......."}},
        {"arrow", {".........1.....",
                   ".........111...",
                   ".2222222211111.",
                   ".2222222211111.",
                   ".........111...",
                   ".........1....."}},
        {"sunset", {"222222222222222",
                    "222211111112222",
                    "211111111111112",
                    "333333333333333",
                    "3.3.3.3.3.3.3.3",
                    "333333333333333"}},
        {"diamond", {"......111......",
                     "....1122211....",
                     "..11223332211..",
                     "..11223332211..",
                     "....1122211....",
                     "......111......"}},
    };
    return maps;
}

// Designs made of key groups rather than shapes.
const QHash<QString, QList<QStringList>> &groups() {
    static const QHash<QString, QList<QStringList>> sets{
        {"gamer", {{"w", "a", "s", "d", "up", "down", "left", "right"},
                   {"q", "e", "r", "f", "lshift", "lctrl", "tab", "space", "c"},
                   {"1", "2", "3", "4", "5", "esc", "g", "m"}}},
        {"vim", {{"h", "j", "k", "l"},
                 {"w", "b", "e", "0", "4", "g", "n"},
                 {"esc", "i", "a", "o", "v", "semicolon", "slash", "u", "y", "p", "d", "x"}}},
        {"zones", {{"q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "a", "s", "d", "f", "g", "h", "j", "k", "l",
                    "z", "x", "c", "v", "b", "n", "m"},
                   {"grave", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "minus", "equals"},
                   {"esc", "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "f10", "f11", "f12", "home", "end",
                    "del", "up", "down", "left", "right"}}},
    };
    return sets;
}

int column(const Key &key) { return std::clamp(int(std::floor(key.cx())), 0, Layout::columns - 1); }

int cellSlot(const Bitmap &map, const Key &key) {
    const char c = map[std::clamp(key.row, 0, 5)][column(key)];
    switch (c) {
    case '1': return 0;
    case '2': return 1;
    case '3': return 2;
    case '0': return -1;
    default: return 3;
    }
}

// The key a typed character lights.
QString keyFor(QChar c) {
    if (c.isLetterOrNumber())
        return QString(c.toLower());
    static const QHash<QChar, QString> punctuation{
        {'`', "grave"}, {'-', "minus"}, {'=', "equals"}, {'[', "lbracket"}, {']', "rbracket"},
        {'\\', "backslash"}, {';', "semicolon"}, {'\'', "quote"}, {',', "comma"}, {'.', "period"},
        {'/', "slash"}, {' ', "space"}};
    return punctuation.value(c);
}

// A design's slot for one key (0..3), or -1 for off. Empty when the design
// is not slot based, so the caller computes a colour instead.
std::optional<int> patternSlot(const Scene &scene, const Key &key) {
    const QString &id = scene.pattern;
    if (bitmaps().contains(id))
        return cellSlot(bitmaps().value(id), key);
    if (groups().contains(id)) {
        const auto &sets = groups().value(id);
        for (int i = 0; i < sets.size(); ++i)
            if (sets[i].contains(key.id))
                return i;
        return 3;
    }
    if (id == "word") {
        for (int i = 0; i < scene.word.size(); ++i)
            if (keyFor(scene.word[i]) == key.id)
                return i == 0 ? 1 : 0;
        return 3;
    }
    if (id == "checker")
        return (column(key) + key.row) % 2 == 0 ? 0 : 1;
    if (id == "target") {
        const double dx = (key.cx() - 7.5) / 1.6, dy = key.cy() - 3.0;
        const double d = std::sqrt(dx * dx + dy * dy);
        if (d < 0.9)
            return 0;
        return d < 1.9 ? 1 : d < 2.9 ? 2 : d < 3.9 ? 0 : 3;
    }
    return std::nullopt;
}

QColor patternColor(const Scene &scene, const Key &key, const QList<QColor> &slot, const QList<QColor> &cycle) {
    if (auto s = patternSlot(scene, key))
        return *s < 0 ? QColor(Qt::black) : slot[*s];
    const double u = key.cx() / Layout::width, v = key.cy() / Layout::height;
    if (scene.pattern == "rows")
        return cycle[key.row % cycle.size()];
    // "gradient", and anything unknown.
    return ramp({slot[0], slot[1], slot[2]}, u * 0.75 + v * 0.25);
}

// --- animations ---

// The keys in a snake's path: along the first row, back along the next.
QList<int> serpentine(const Layout &layout) {
    QList<int> order;
    for (int row = 0; row < Layout::rows; ++row) {
        QList<int> inRow;
        for (int i = 0; i < layout.keys().size(); ++i)
            if (layout.keys()[i].row == row && layout.keys()[i].lit())
                inRow << i;
        std::sort(inRow.begin(), inRow.end(), [&layout, row](int a, int b) {
            const double ax = layout.keys()[a].cx() + layout.keys()[a].y * 0.01;
            const double bx = layout.keys()[b].cx() + layout.keys()[b].y * 0.01;
            return row % 2 == 0 ? ax < bx : ax > bx;
        });
        order += inRow;
    }
    return order;
}

QColor animationColor(const Scene &scene, const Layout &layout, int index, const QList<QColor> &slot,
                      const QList<QColor> &cycle, double t) {
    const Key &key = layout.keys()[index];
    const QString &id = scene.animation;
    const double x = key.cx(), y = key.cy();
    const double u = x / Layout::width;
    const QColor &bg = slot[3];

    if (id == "rainbow")
        return loop(cycle, u * 0.9 - t * 0.22);

    if (id == "breathe") {
        const double b = 0.5 - 0.5 * std::cos(tau * t / 4.0);
        // Every other breath takes the second colour.
        const bool second = int(std::floor(t / 4.0)) % 2 != 0;
        return mix(bg, second ? slot[1] : slot[0], b);
    }

    if (id == "spectrum")
        return loop(cycle, t * 0.1);

    if (id == "ripple") {
        const double dx = (x - 7.5) / 1.3, dy = y - 3.0;
        const double d = std::sqrt(dx * dx + dy * dy);
        const double phase = t * 0.6 - d / 4.0;
        const double wave = std::pow(0.5 + 0.5 * std::cos(tau * phase), 4);
        const int ring = int(std::floor(phase));
        return mix(bg, slot[((ring % 3) + 3) % 3], wave);
    }

    if (id == "scanner") {
        const double sweep = t * 0.45;
        const double tri = std::abs(2 * (sweep - std::floor(sweep + 0.5)));
        const double head = tri * Layout::width;
        const bool rightward = (sweep - std::floor(sweep)) < 0.5;
        const double d = x - head;
        const bool behind = rightward ? d < 0 : d > 0;
        const double glow = std::exp(-std::abs(d) * (behind ? 0.55 : 2.4));
        const QColor body = mix(bg, slot[0], glow);
        return std::abs(d) < 0.55 ? mix(body, slot[1], 0.6) : body;
    }

    if (id == "matrix") {
        const int c = column(key);
        const double rate = 1.6 + hash(c) * 1.8;
        const double period = 10.0;
        const double head = std::fmod(t * rate + hash(c + 99.0) * period, period) - 2.0;
        const double dy = head - y;
        if (dy >= -0.5 && dy < 0.5)
            return slot[1];
        if (dy >= 0.5 && dy < 4.5)
            return mix(bg, slot[0], 1.0 - (dy - 0.5) / 4.0);
        return bg;
    }

    if (id == "twinkle") {
        const double clock = t * 0.9 + hash(index * 3.1) * 10.0;
        const double n = std::floor(clock), f = clock - n;
        if (hash(index * 31.0 + n * 7.0) > 0.62) {
            const double env = std::pow(std::sin(M_PI * f), 2);
            const QColor star = slot[int(hash(index + n * 13.0) * 3) % 3];
            return mix(bg, star, env);
        }
        return bg;
    }

    if (id == "fire") {
        const double base = std::pow(y / Layout::height, 1.3) * 1.15;
        const double flicker = noise2(x * 0.7, y * 0.9 + t * 2.2) - 0.5;
        const double heat = std::clamp(base + flicker * 0.75 - 0.1, 0.0, 1.0);
        return ramp({bg, slot[2], slot[0], slot[1]}, heat);
    }

    if (id == "aurora") {
        const double p = std::sin(x * 0.45 + t * 0.9) + std::sin(y * 0.9 - t * 0.6) + std::sin((x + y) * 0.3 + t * 0.5);
        const double n = (p + 3.0) / 6.0;
        const double glow = 0.55 + 0.45 * std::sin(x * 0.3 - t * 0.7 + y * 0.2);
        return mix(bg, ramp({slot[0], slot[1], slot[2]}, n), glow);
    }

    if (id == "radar") {
        const double angle = std::atan2(y - 3.0, (x - 7.5) / 1.4);
        const double sweep = std::fmod(t * 1.6, tau);
        const double behind = std::fmod(sweep - angle + 2 * tau, tau);
        const QColor beam = mix(bg, slot[0], std::exp(-behind * 1.3));
        // A few keys are contacts that light as the beam crosses them.
        if (hash(index * 17.0) > 0.88)
            return mix(beam, slot[1], std::exp(-behind * 0.5));
        return beam;
    }

    if (id == "heartbeat") {
        Scene heart = scene;
        heart.pattern = "heart";
        const auto s = patternSlot(heart, key);
        const double ph = std::fmod(t, 1.3);
        double beat = std::exp(-ph * 9.0);
        if (ph > 0.26)
            beat += 0.7 * std::exp(-(ph - 0.26) * 9.0);
        const double level = 0.18 + 0.82 * std::min(1.0, beat);
        if (!s || *s == 3 || *s < 0)
            return bg;
        return mix(bg, slot[*s], level);
    }

    if (id == "alien") {
        Scene alien = scene;
        alien.pattern = "alien";
        const auto s = patternSlot(alien, key);
        if (!s || *s < 0)
            return Qt::black;
        if (*s == 3) {
            // A scan line drifts down the background.
            const double line = std::fmod(t * 1.2, 8.0) - 1.0;
            return mix(bg, slot[2], std::exp(-std::pow(y - line, 2) * 3.0) * 0.6);
        }
        if (*s == 1)
            return mix(scaled(slot[1], 0.25), slot[1], 0.5 + 0.5 * std::sin(t * 3.0));
        return mix(scaled(slot[0], 0.35), slot[0], 0.65 + 0.35 * std::sin(t * 1.1));
    }

    if (id == "snake") {
        static const QList<int> path = serpentine(Layout::x15());
        const QList<int> order = &layout == &Layout::x15() ? path : serpentine(layout);
        const int at = order.indexOf(index);
        if (at < 0 || order.isEmpty())
            return bg;
        const int length = 12;
        const int head = int(std::floor(t * 9.0)) % order.size();
        const int d = (head - at + order.size()) % order.size();
        if (d < length)
            return mix(slot[0], slot[1], double(d) / length);
        // The food: one key that moves on each lap.
        const int lap = int(std::floor(t * 9.0)) / order.size();
        if (at == int(hash(lap + 5.0) * order.size()))
            return slot[2];
        return bg;
    }

    if (id == "storm") {
        const QColor base = mix(bg, slot[2], 0.15 + 0.1 * noise2(x * 0.3 + t * 0.4, y * 0.5));
        const double clock = t * 0.6;
        const double epoch = std::floor(clock), ft = clock - epoch;
        if (hash(epoch) > 0.3) {
            double flash = std::exp(-ft * 10.0);
            if (ft > 0.12)
                flash += 0.8 * std::exp(-(ft - 0.12) * 12.0);
            const double where = hash(epoch * 3.0 + 1.0) * Layout::width;
            const double spread = std::exp(-std::abs(x - where) / 2.6);
            return mix(base, slot[0], std::min(1.0, flash) * spread);
        }
        return base;
    }

    if (id == "vortex") {
        const double dx = (x - 7.5) / 1.3, dy = y - 3.0;
        const double a = std::atan2(dy, dx) / tau;
        const double r = std::sqrt(dx * dx + dy * dy) / 6.0;
        return loop(cycle, a + r * 0.9 - t * 0.3);
    }

    if (id == "equalizer") {
        const int c = column(key);
        const double level = std::clamp(0.15 + noise2(c * 0.8, t * 1.8) * 0.95, 0.0, 1.0);
        const int fromBottom = 5 - key.row;
        if (fromBottom >= int(std::round(level * 6)))
            return bg;
        return fromBottom < 3 ? slot[0] : fromBottom < 5 ? slot[2] : slot[1];
    }

    if (id == "comet") {
        // Three comets on slanted paths, each a new path every pass.
        QColor out = bg;
        for (int k = 0; k < 3; ++k) {
            const double clock = t / (2.4 + k * 0.7) + hash(k * 7.0);
            const double lap = std::floor(clock), f = clock - lap;
            const double row = 0.5 + hash(lap * 3.0 + k) * 5.0;
            const double slope = (hash(lap * 5.0 + k * 2.0) - 0.5) * 0.5;
            const double head = -3.0 + f * (Layout::width + 12.0);
            const double off = y - (row + slope * (x - 7.5));
            const double along = head - x;
            const double tail = along >= 0 ? std::exp(-along * 0.42) : std::exp(along * 4.0);
            const double level = std::exp(-off * off * 2.2) * tail;
            out = mix(out, along < 0.7 ? slot[1] : slot[k == 1 ? 2 : 0], level);
        }
        return out;
    }

    if (id == "fireflies") {
        QColor out = bg;
        for (int k = 0; k < 7; ++k) {
            const double fx = 7.5 + 6.8 * std::sin(t * (0.21 + hash(k) * 0.2) + k * 2.1);
            const double fy = 3.0 + 2.6 * std::sin(t * (0.33 + hash(k + 9.0) * 0.25) + k * 1.3);
            const double dx = x - fx, dy = y - fy;
            const double blink = std::pow(0.5 + 0.5 * std::sin(t * (1.1 + hash(k + 3.0)) + k), 3);
            out = mix(out, slot[k % 3], std::exp(-(dx * dx + dy * dy) * 0.9) * blink);
        }
        return out;
    }

    if (id == "lava") {
        // Metaballs: wax glows where the blobs' fields add up past one.
        double field = 0;
        for (int k = 0; k < 4; ++k) {
            const double bx = 2.0 + k * 3.6 + 1.4 * std::sin(t * 0.31 + k * 2.0);
            const double by = 3.0 + 3.4 * std::sin(t * (0.22 + 0.06 * k) + k * 1.7);
            const double dx = x - bx, dy = (y - by) * 1.2;
            field += 2.4 / (dx * dx + dy * dy + 0.3);
        }
        if (field >= 1.0)
            return mix(slot[0], slot[1], std::min(1.0, (field - 1.0) / 2.0));
        return mix(bg, slot[2], smooth((field - 0.45) / 0.55) * 0.7);
    }

    if (id == "plasma") {
        const double v = std::sin(x * 0.55 + t) + std::sin(y * 0.9 + t * 0.7) + std::sin((x + y) * 0.4 + t * 0.5)
                       + std::sin(std::hypot(x - 7.5, y - 3.0) * 0.9 - t * 1.3);
        return loop(cycle, v / 8.0 + t * 0.05);
    }

    if (id == "raindrops") {
        QColor out = bg;
        for (int k = 0; k < 5; ++k) {
            const double clock = t * 0.55 + k / 5.0;
            const double n = std::floor(clock), f = clock - n;
            const double cx = 1.0 + hash(n * 11.0 + k) * 13.0, cy = 0.5 + hash(n * 13.0 + k * 3.0) * 5.0;
            const double d = std::hypot((x - cx) / 1.2, y - cy);
            const double ring = std::exp(-std::pow(d - f * 5.5, 2) * 2.5) * (1.0 - f);
            const double splash = f < 0.15 ? std::exp(-d * d * 2.0) * (1.0 - f / 0.15) : 0.0;
            out = mix(out, slot[k % 3], std::min(1.0, ring + splash));
        }
        return out;
    }

    if (id == "pong") {
        auto tri = [](double s) { return std::abs(2 * (s - std::floor(s + 0.5))); };
        const double bx = 1.4 + tri(t * 0.3) * (Layout::width - 2.8);
        const double by = 0.5 + tri(t * 0.47 + 0.2) * (Layout::height - 1.0);
        if (std::hypot(x - bx, (y - by) * 1.2) < 0.75)
            return slot[1];
        // Each paddle follows the ball, the far one a little late.
        const double left = 0.5 + tri(t * 0.47 + 0.2 - (bx / Layout::width) * 0.12) * (Layout::height - 1.0);
        const double right = 0.5 + tri(t * 0.47 + 0.2 - (1.0 - bx / Layout::width) * 0.12) * (Layout::height - 1.0);
        if ((x < 1.3 && std::abs(y - left) < 1.2) || (x > Layout::width - 1.3 && std::abs(y - right) < 1.2))
            return slot[0];
        if (std::abs(x - 7.5) < 0.6 && key.row % 2 == 0)
            return slot[2];
        return bg;
    }

    if (id == "helix") {
        const double phase = x * 0.7 - t * 2.0;
        const double a = 3.0 + 2.3 * std::sin(phase), b = 3.0 - 2.3 * std::sin(phase);
        const double front = std::cos(phase);
        const double la = std::exp(-std::pow(y - a, 2) * 2.5) * (front > 0 ? 1.0 : 0.45);
        const double lb = std::exp(-std::pow(y - b, 2) * 2.5) * (front > 0 ? 0.45 : 1.0);
        QColor out = bg;
        // Rungs join the strands on every other column.
        if (column(key) % 2 == 0 && y > std::min(a, b) && y < std::max(a, b))
            out = mix(bg, slot[2], 0.6);
        out = mix(out, slot[1], lb);
        return mix(out, slot[0], la);
    }

    if (id == "ocean") {
        const double surface = 2.6 + 0.9 * std::sin(x * 0.55 - t * 1.4) + 0.45 * std::sin(x * 1.3 + t * 0.9);
        const double depth = y - surface;
        if (depth < -0.45)
            return bg;
        if (depth < 0.45)
            return mix(slot[1], slot[2], 1.0 - std::abs(depth) / 0.45);
        return mix(slot[1], slot[0], std::min(1.0, depth / 3.0));
    }

    if (id == "typist") {
        // The word typed four letters a second, a beat on Enter, then again.
        const QString word = scene.word.isEmpty() ? QString("OMARCHY") : scene.word;
        const int n = word.size();
        const double clock = t * 4.0;
        const double typed = std::fmod(clock, n + 6.0);
        double level = 0;
        bool first = false;
        for (int i = 0; i < n && i <= typed; ++i) {
            if (keyFor(word[i]) != key.id)
                continue;
            const double age = (typed - i) / 4.0;
            const double glow = typed > n + 3.0 ? 0.35 * (n + 6.0 - typed) / 3.0 : 0.35;
            const double l = glow + (1.0 - glow) * std::exp(-age * 4.0);
            if (l > level) {
                level = l;
                first = i == 0;
            }
        }
        if (key.id == "enter" && typed >= n + 0.5)
            return mix(bg, slot[2], std::exp(-(typed - n - 0.5) * 1.5));
        return mix(bg, first ? slot[1] : slot[0], level);
    }

    if (id == "bounce") {
        // A block drifting like an old DVD logo, a new colour off every wall.
        const double sx = t * 0.38, sy = t * 0.53;
        auto tri = [](double s) { return std::abs(2 * (s - std::floor(s + 0.5))); };
        const double bx = 1.5 + tri(sx) * (Layout::width - 3.0);
        const double by = 1.0 + tri(sy) * (Layout::height - 2.0);
        const int hits = int(std::floor(sx * 2 + 0.5)) + int(std::floor(sy * 2 + 0.5));
        const double dx = std::max(0.0, std::abs(x - bx) - 1.5), dy = std::max(0.0, std::abs(y - by) - 1.0);
        return mix(bg, slot[((hits % 3) + 3) % 3], std::exp(-(dx * dx + dy * dy) * 6.0));
    }

    if (id == "kaleidoscope") {
        const double dx = std::abs(x - 7.5) / 1.3, dy = std::abs(y - 3.0);
        double a = std::atan2(dy, dx) + t * 0.25;
        const double wedge = tau / 8.0;
        a = std::fmod(a, wedge);
        if (a > wedge / 2)
            a = wedge - a;
        const double r = std::hypot(dx, dy);
        const double v = noise2(r * std::cos(a) * 0.9 + t * 0.4, r * std::sin(a) * 2.2 - t * 0.3)
                       + 0.35 * std::sin(r * 1.3 - t * 1.6);
        return loop(cycle, v + t * 0.03);
    }

    if (id == "hyperspace") {
        // Stars stream out of the middle, stretching into streaks as they speed up.
        QColor out = bg;
        const double px = (x - 7.5) / 1.3, py = y - 3.0;
        for (int k = 0; k < 10; ++k) {
            const double clock = t * (0.45 + hash(k * 5.0) * 0.35) + hash(k);
            const double lap = std::floor(clock), f = clock - lap;
            const double angle = hash(lap * 7.0 + k * 13.0) * tau;
            const double r = f * f * 7.5;
            const double length = 0.3 + f * 2.2;
            const double along = px * std::cos(angle) + py * std::sin(angle);
            const double across = -px * std::sin(angle) + py * std::cos(angle);
            if (along > r || along < r - length)
                continue;
            const double level = std::exp(-across * across * 5.0) * (0.3 + 0.7 * (along - r + length) / length);
            out = mix(out, along > r - 0.5 ? slot[1] : slot[0], level * std::min(1.0, f * 3.0));
        }
        return out;
    }

    if (id == "siren") {
        // Left flashes twice, then right, with a white strobe between.
        const double phase = std::fmod(t * 1.2, 2.0);
        const bool leftTurn = phase < 1.0;
        const double f = phase - std::floor(phase);
        const bool flash = std::fmod(f * 4.0, 2.0) < 1.0 && f < 0.5;
        const bool left = x < 7.5;
        if (flash && left == leftTurn)
            return mix(left ? slot[0] : slot[1], slot[2], std::exp(-std::abs(x - 7.5) * 0.6) * 0.3);
        if (f > 0.55 && f < 0.62 && std::abs(x - 7.5) < 2.0)
            return slot[2];
        return mix(bg, left ? slot[0] : slot[1], 0.08);
    }

    return bg;
}

} // namespace

namespace Effects {

const QList<Preset> &patterns() {
    auto c = [](const char *a, const char *b, const char *d, const char *e) {
        return QList<QColor>{QColor(a), QColor(b), QColor(d), QColor(e)};
    };
    static const QList<Preset> list{
        {"alien", "Alien", "The Alienware head with glowing eyes", c("#00ff6a", "#00e5ff", "#7a00ff", "#001405"),
         {"Head", "Eyes", "—", "Background"}},
        {"heart", "Heart", "A heart across the middle of the keys", c("#ff1e56", "#ff9ec0", "#ff6a00", "#14000a"),
         {"Heart", "Shine", "—", "Background"}},
        {"smiley", "Smiley", "A face with eyes, cheeks and a grin", c("#ffd60a", "#101010", "#ff3b30", "#0a0600"),
         {"Face", "Eyes", "Mouth", "Background"}},
        {"invader", "Invader", "An arcade space invader", c("#38ff6a", "#ff2bd6", "#ffffff", "#000a02"),
         {"Body", "Eyes", "—", "Background"}},
        {"creeper", "Creeper", "Green blocks with a dark face", c("#2bd62b", "#0f6b0f", "#000000", "#000000"),
         {"Skin", "—", "—", "—"}},
        {"pacman", "Pac-Man", "Pac-Man chasing a ghost past a pellet", c("#ffd60a", "#ff1e56", "#ffffff", "#000014"),
         {"Pac-Man", "Ghost", "Pellet", "Maze"}},
        {"bolt", "Lightning", "A lightning bolt striking down the keys", c("#ffe600", "#ffffff", "#ff7a00", "#00061a"),
         {"Bolt", "Core", "—", "Sky"}},
        {"arrow", "Arrow", "An arrow pointing right", c("#00e5ff", "#0050ff", "#ffffff", "#000814"),
         {"Head", "Shaft", "—", "Background"}},
        {"sunset", "Synthwave", "A sun setting over a neon grid", c("#ff7a1a", "#ff2bd6", "#19e3ff", "#0a0014"),
         {"Sun", "Sky", "Grid", "Grid gaps"}},
        {"diamond", "Diamond", "A cut gem, bright at its heart", c("#00b4ff", "#7a00ff", "#ffffff", "#000510"),
         {"Edge", "Facets", "Heart", "Background"}},
        {"target", "Target", "Rings round a bullseye", c("#ff1e1e", "#ffffff", "#ff7a00", "#140000"),
         {"Bullseye", "Ring", "Ring", "Background"}},
        {"checker", "Checkers", "Alternating squares", c("#ff2bd6", "#00e5ff", "#000000", "#000000"),
         {"Squares", "Squares", "—", "—"}},
        {"gamer", "Gamer", "WASD and arrows, actions, and number keys", c("#ff1e1e", "#ff7a00", "#ffd60a", "#140202"),
         {"Movement", "Actions", "Hotbar", "Everything else"}},
        {"vim", "Vim", "Motions, jumps and modes in their own colours", c("#38ff6a", "#00b4ff", "#ffd60a", "#020a04"),
         {"h j k l", "Jumps", "Modes and edits", "Everything else"}},
        {"zones", "Zones", "Letters, numbers and function keys apart", c("#00e5ff", "#7a00ff", "#ff2bd6", "#05000f"),
         {"Letters", "Numbers", "Function and arrows", "Everything else"}},
        {"word", "Spell a word", "Lights the keys of a word you choose", c("#ffffff", "#00e5ff", "#000000", "#04040a"),
         {"Letters", "First letter", "—", "Everything else"}},
        {"gradient", "Gradient", "Three colours blended across the board", c("#00e5ff", "#7a00ff", "#ff2bd6", "#000000"),
         {"Left", "Middle", "Right", "—"}},
        {"rows", "Rows", "Each row its own colour round the wheel", c("#ff0000", "#00ff00", "#0000ff", "#000000"),
         {"—", "—", "—", "—"}},
    };
    return list;
}

const QList<Preset> &animations() {
    auto c = [](const char *a, const char *b, const char *d, const char *e) {
        return QList<QColor>{QColor(a), QColor(b), QColor(d), QColor(e)};
    };
    static const QList<Preset> list{
        {"rainbow", "Rainbow wave", "Colour rolls across the keys, or the theme's colours do",
         c("#ff0000", "#00ff00", "#0000ff", "#000000"), {"—", "—", "—", "—"}},
        {"breathe", "Breathe", "A slow fade in and out, alternating two colours",
         c("#00e5ff", "#ff2bd6", "#ffffff", "#000000"), {"First breath", "Second breath", "—", "Rest"}},
        {"spectrum", "Colour cycle", "The whole board drifts through the colours",
         c("#ff0000", "#00ff00", "#0000ff", "#000000"), {"—", "—", "—", "—"}},
        {"ripple", "Ripple", "Rings spread out from the middle",
         c("#00e5ff", "#7a00ff", "#ff2bd6", "#00040a"), {"Ring", "Ring", "Ring", "Water"}},
        {"scanner", "Scanner", "A light sweeps side to side with a trail",
         c("#ff1e1e", "#ffffff", "#000000", "#0a0000"), {"Beam", "Head", "—", "Background"}},
        {"matrix", "Digital rain", "Code falls down each column",
         c("#00ff41", "#d6ffd6", "#000000", "#000a02"), {"Trail", "Drop", "—", "Background"}},
        {"twinkle", "Starfield", "Keys twinkle on and off like stars",
         c("#ffffff", "#9ecbff", "#ffd6a0", "#00020a"), {"Star", "Star", "Star", "Night"}},
        {"fire", "Fire", "Flames lick up from the bottom row",
         c("#ff5a00", "#ffd000", "#c00000", "#0a0000"), {"Flame", "Tips", "Embers", "Smoke"}},
        {"aurora", "Aurora", "Soft curtains of colour drifting",
         c("#00ff9c", "#00b4ff", "#a000ff", "#00030a"), {"Green", "Blue", "Violet", "Sky"}},
        {"radar", "Radar", "A sweeping beam that lights up contacts",
         c("#38ff6a", "#ff3b30", "#000000", "#000a02"), {"Beam", "Contacts", "—", "Screen"}},
        {"heartbeat", "Heartbeat", "The heart beating lub-dub",
         c("#ff1e56", "#ff9ec0", "#000000", "#0a0004"), {"Heart", "Shine", "—", "Background"}},
        {"alien", "Alien pulse", "The alien head breathing, eyes glowing",
         c("#00ff6a", "#00e5ff", "#7a00ff", "#000802"), {"Head", "Eyes", "Scan line", "Background"}},
        {"snake", "Snake", "A snake winds through every key after its food",
         c("#38ff6a", "#00b4ff", "#ff3b30", "#000000"), {"Head", "Tail", "Food", "Background"}},
        {"storm", "Storm", "Lightning flashes through a dark sky",
         c("#e6f0ff", "#000000", "#2850ff", "#00010a"), {"Lightning", "—", "Clouds", "Night"}},
        {"vortex", "Vortex", "Colours spiral round the middle",
         c("#ff0000", "#00ff00", "#0000ff", "#000000"), {"—", "—", "—", "—"}},
        {"equalizer", "Equalizer", "Columns bounce like a music visualiser",
         c("#38ff6a", "#ff1e1e", "#ffd60a", "#000000"), {"Low", "Peak", "Mid", "Background"}},
        {"comet", "Comets", "Comets streak across with glowing tails",
         c("#00b4ff", "#ffffff", "#ff2bd6", "#00010a"), {"Tail", "Head", "Tail", "Space"}},
        {"fireflies", "Fireflies", "Glowing bugs wander over the keys and blink",
         c("#c8ff3a", "#ffe14d", "#7affc1", "#010600"), {"Firefly", "Firefly", "Firefly", "Night"}},
        {"lava", "Lava lamp", "Blobs of wax rise, merge and sink",
         c("#ff3d00", "#ffb300", "#ff0080", "#0a0005"), {"Wax", "Hot core", "Glow", "Lamp"}},
        {"plasma", "Plasma", "A demoscene plasma swirling through the colours",
         c("#ff0000", "#00ff00", "#0000ff", "#000000"), {"—", "—", "—", "—"}},
        {"raindrops", "Raindrops", "Drops land on the keys and ripple out",
         c("#4fc3ff", "#a0e8ff", "#6a7bff", "#00030a"), {"Ripple", "Ripple", "Ripple", "Pond"}},
        {"pong", "Pong", "A ball rallies between two paddles",
         c("#ffffff", "#38ff6a", "#3a3a3a", "#000000"), {"Paddles", "Ball", "Net", "Court"}},
        {"helix", "Double helix", "Two strands of DNA twist across the board",
         c("#00e5ff", "#ff2bd6", "#7a00ff", "#00020a"), {"Strand", "Strand", "Rungs", "Background"}},
        {"ocean", "Ocean", "Waves roll in with foam on the crests",
         c("#002a7a", "#00a0ff", "#e6f7ff", "#000614"), {"Deep", "Shallows", "Foam", "Sky"}},
        {"typist", "Ghost typist", "An invisible hand types your word, then hits Enter",
         c("#ffffff", "#00e5ff", "#ff2bd6", "#04040a"), {"Letters", "First letter", "Enter", "Everything else"}},
        {"bounce", "Bouncing logo", "A block drifts round, changing colour at every wall",
         c("#ff2bd6", "#00e5ff", "#ffd60a", "#000000"), {"Colour", "Colour", "Colour", "Background"}},
        {"kaleidoscope", "Kaleidoscope", "Mirrored colour turning about the middle",
         c("#ff0000", "#00ff00", "#0000ff", "#000000"), {"—", "—", "—", "—"}},
        {"hyperspace", "Hyperspace", "Stars stream out of the middle at warp speed",
         c("#5aa0ff", "#ffffff", "#000000", "#000006"), {"Streak", "Star", "—", "Space"}},
        {"siren", "Siren", "Red and blue lights flash side to side",
         c("#ff1010", "#1030ff", "#ffffff", "#000000"), {"Left", "Right", "Strobe", "Background"}},
    };
    return list;
}

const Preset *findPattern(const QString &id) {
    for (const auto &p : patterns())
        if (p.id == id)
            return &p;
    return nullptr;
}

const Preset *findAnimation(const QString &id) {
    for (const auto &p : animations())
        if (p.id == id)
            return &p;
    return nullptr;
}

QList<QColor> slotColors(const Scene &scene, const ThemePalette &palette) {
    QList<QColor> slot = scene.followTheme ? palette.slotColors() : scene.colors;
    while (slot.size() < 4)
        slot << QColor(Qt::black);
    return slot;
}

bool animated(const Scene &scene) {
    return scene.on && scene.mode == "animation";
}

QVector<QColor> render(const Layout &layout, const Scene &scene, const ThemePalette &palette, double seconds) {
    QVector<QColor> out(layout.keys().size(), QColor(Qt::black));
    if (!scene.on)
        return out;
    const QList<QColor> slot = slotColors(scene, palette);
    // The colour wheel the sweeping animations travel: the theme's hues, or
    // a full rainbow. The designs that use slots ignore it.
    const QList<QColor> cycle = scene.followTheme ? palette.cycle() : rainbow();
    const double t = seconds * scene.speed;

    for (int i = 0; i < layout.keys().size(); ++i) {
        const Key &key = layout.keys()[i];
        if (!key.lit())
            continue;
        if (scene.mode == "paint") {
            const QString value = scene.paint.value(key.id);
            if (value.startsWith('@'))
                out[i] = slot[std::clamp(value.mid(1).toInt(), 0, 3)];
            else if (!value.isEmpty())
                out[i] = QColor(value);
            else
                out[i] = slot[3];
        } else if (scene.mode == "animation") {
            out[i] = animationColor(scene, layout, i, slot, cycle, t);
        } else {
            out[i] = patternColor(scene, key, slot, cycle);
        }
    }
    return out;
}

QColor finish(const QColor &color, const Scene &scene) {
    QColor c = color.toHsv();
    const double s = c.hsvSaturationF();
    if (c.hsvHueF() >= 0 && s > 0.02) {
        // Lift saturation in proportion to itself, so colours get richer
        // and greys stay grey: theme colours are often pastel, and pastels
        // read as white on the leds.
        const double k = scene.vivid / 100.0;
        c.setHsvF(c.hsvHueF(), std::min(1.0, s + (1 - s) * k * s * 1.5), c.valueF());
    }
    return scaled(c.toRgb(), scene.brightness / 100.0);
}

QStringList bitmap(const QString &id) {
    QStringList rows;
    if (bitmaps().contains(id))
        for (const char *row : bitmaps().value(id))
            rows << QString::fromLatin1(row);
    return rows;
}

QHash<QString, QString> bake(const Layout &layout, const Scene &scene, const ThemePalette &palette) {
    QHash<QString, QString> painted;
    if (scene.mode == "paint")
        return scene.paint;
    const auto frame = render(layout, scene, palette, 0);
    for (int i = 0; i < layout.keys().size(); ++i) {
        const Key &key = layout.keys()[i];
        if (!key.lit())
            continue;
        std::optional<int> s;
        if (scene.mode == "pattern")
            s = patternSlot(scene, key);
        if (s && *s >= 0)
            painted.insert(key.id, "@" + QString::number(*s));
        else if (s)
            painted.insert(key.id, "#000000");
        else
            painted.insert(key.id, frame[i].name());
    }
    return painted;
}

} // namespace Effects
