#include "layout.h"

namespace {

struct Spec {
    const char *id;
    const char *label;
    double w;
    int led;
    int second = -1;
};

// Lays a row of keys left to right from x = 0.
void addRow(QList<Key> &keys, int row, std::initializer_list<Spec> specs) {
    double x = 0;
    for (const auto &spec : specs) {
        Key key;
        key.id = spec.id;
        key.label = QString::fromUtf8(spec.label);
        key.x = x;
        key.y = row;
        key.w = spec.w;
        key.row = row;
        if (spec.led >= 0)
            key.leds << spec.led;
        if (spec.second >= 0)
            key.leds << spec.second;
        keys << key;
        x += spec.w;
    }
}

QList<Key> makeX15() {
    QList<Key> keys;
    // The top row fits sixteen keys in the width of fifteen.
    const double f = 15.0 / 16.0;
    addRow(keys, 0, {{"esc", "Esc", f, 0}, {"f1", "F1", f, 1}, {"f2", "F2", f, 2}, {"f3", "F3", f, 3},
                     {"f4", "F4", f, 4}, {"f5", "F5", f, 5}, {"f6", "F6", f, 6}, {"f7", "F7", f, 7},
                     {"f8", "F8", f, 8}, {"f9", "F9", f, 9}, {"f10", "F10", f, 10}, {"f11", "F11", f, 11},
                     {"f12", "F12", f, 12}, {"home", "Home", f, 13}, {"end", "End", f, 14}, {"del", "Del", f, 15}});
    addRow(keys, 1, {{"grave", "`", 1, 20}, {"1", "1", 1, 21}, {"2", "2", 1, 22}, {"3", "3", 1, 23},
                     {"4", "4", 1, 24}, {"5", "5", 1, 25}, {"6", "6", 1, 26}, {"7", "7", 1, 27},
                     {"8", "8", 1, 28}, {"9", "9", 1, 29}, {"0", "0", 1, 30}, {"minus", "-", 1, 31},
                     {"equals", "=", 1, 32}, {"backspace", "⌫", 2, 34, 35}});
    addRow(keys, 2, {{"tab", "Tab", 1.5, 40}, {"q", "Q", 1, 42}, {"w", "W", 1, 43}, {"e", "E", 1, 44},
                     {"r", "R", 1, 45}, {"t", "T", 1, 46}, {"y", "Y", 1, 47}, {"u", "U", 1, 48},
                     {"i", "I", 1, 49}, {"o", "O", 1, 50}, {"p", "P", 1, 51}, {"lbracket", "[", 1, 52},
                     {"rbracket", "]", 1, 53}, {"backslash", "\\", 1.5, 55}});
    addRow(keys, 3, {{"caps", "Caps", 1.75, 60, 61}, {"a", "A", 1, 62}, {"s", "S", 1, 63}, {"d", "D", 1, 64},
                     {"f", "F", 1, 65}, {"g", "G", 1, 66}, {"h", "H", 1, 67}, {"j", "J", 1, 68},
                     {"k", "K", 1, 69}, {"l", "L", 1, 70}, {"semicolon", ";", 1, 71}, {"quote", "'", 1, 72},
                     {"enter", "Enter", 2.25, 74}});
    addRow(keys, 4, {{"lshift", "Shift", 2.25, 80, 81}, {"z", "Z", 1, 83}, {"x", "X", 1, 84}, {"c", "C", 1, 85},
                     {"v", "V", 1, 86}, {"b", "B", 1, 87}, {"n", "N", 1, 88}, {"m", "M", 1, 89},
                     {"comma", ",", 1, 90}, {"period", ".", 1, 91}, {"slash", "/", 1, 92},
                     {"rshift", "Shift", 2.75, 94}});
    addRow(keys, 5, {{"lctrl", "Ctrl", 1.25, 100}, {"fn", "Fn", 1, 101}, {"lsuper", "Super", 1, 102, 103},
                     {"lalt", "Alt", 1.25, 104}, {"space", "", 4.5, -1}, {"ralt", "Alt", 1, 111},
                     {"rsuper", "Menu", 1, 109}, {"rctrl", "Ctrl", 1, 112}, {"left", "←", 1, 133},
                     {"up", "↑", 1, 114}, {"right", "→", 1, 135}});

    // Up and down share one column at half height, as on the laptop: down
    // sits under up.
    for (int i = 0; i < keys.size(); ++i) {
        if (keys[i].id != "up")
            continue;
        keys[i].h = 0.5;
        Key down = keys[i];
        down.id = "down";
        down.label = "↓";
        down.y += 0.5;
        down.leds = {134};
        keys.insert(i + 1, down);
        break;
    }
    return keys;
}

} // namespace

const Layout &Layout::x15() {
    static const Layout layout = [] {
        Layout l;
        l.m_keys = makeX15();
        return l;
    }();
    return layout;
}

int Layout::indexOf(const QString &id) const {
    for (int i = 0; i < m_keys.size(); ++i)
        if (m_keys[i].id == id)
            return i;
    return -1;
}

int Layout::ledCount() const {
    int count = 0;
    for (const auto &key : m_keys)
        count += key.leds.size();
    return count;
}
