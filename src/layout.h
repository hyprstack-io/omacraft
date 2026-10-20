#pragma once

#include <QList>
#include <QString>

// One key on the keyboard as it is drawn and lit. Positions are in key units
// (a letter key is 1 x 1), measured from the top left of the Esc key.
struct Key {
    QString id;
    QString label;
    double x = 0;
    double y = 0;
    double w = 1;
    double h = 1;
    int row = 0;
    // The controller's wire indices for this key. Four wide keys carry two
    // leds; the space bar carries none and can't be lit.
    QList<int> leds;

    double cx() const { return x + w / 2; }
    double cy() const { return y + h / 2; }
    bool lit() const { return !leds.isEmpty(); }
};

// The keyboard as a grid of keys, 15 units wide and 6 rows tall.
class Layout {
public:
    static constexpr double width = 15;
    static constexpr double height = 6;
    static constexpr int columns = 15;
    static constexpr int rows = 6;

    // The Alienware x15 R1 / R2 keyboard. The wire indices are the ones
    // alienwarectl's KEYMAP.txt confirmed by lighting each one on the machine;
    // they follow the keyboard matrix, not the layout, so they are listed
    // rather than worked out.
    static const Layout &x15();

    const QList<Key> &keys() const { return m_keys; }
    int indexOf(const QString &id) const;
    // How many leds the keyboard lights in all.
    int ledCount() const;

private:
    QList<Key> m_keys;
};
