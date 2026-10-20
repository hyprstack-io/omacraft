#pragma once

#include <QColor>
#include <QList>
#include <QString>
#include <QStringList>
#include <QVector>

#include "layout.h"
#include "palette.h"
#include "scene.h"

// A design or an animation the window offers, with the colours it starts
// in when the theme isn't chosen.
struct Preset {
    QString id;
    QString name;
    QString description;
    QList<QColor> colors;
    // What each of the four slots is for in this preset.
    QStringList slotNames;
};

// Turns a scene into a colour for every key, at a moment in time. It is a
// pure function of its inputs, so the preview in the window and the lighting
// service always agree, and tests can check any frame.
namespace Effects {

const QList<Preset> &patterns();
const QList<Preset> &animations();
const Preset *findPattern(const QString &id);
const Preset *findAnimation(const QString &id);

// The four slots the scene paints with: its own, or the theme's.
QList<QColor> slotColors(const Scene &scene, const ThemePalette &palette);

// Whether the scene changes over time (and so needs a running clock).
bool animated(const Scene &scene);

// The colour of each key in layout order, as the scene designs it, before
// brightness. Keys without leds come back black.
QVector<QColor> render(const Layout &layout, const Scene &scene, const ThemePalette &palette, double seconds);

// The colour as the leds should show it: boosted by `vivid`, then scaled by
// brightness. The preview uses this too.
QColor finish(const QColor &color, const Scene &scene);

// A shape design's rows, or empty for designs that aren't drawn as shapes.
QStringList bitmap(const QString &id);

// The scene as paint for every lit key, so a design (or an animation's
// first frame) can be copied onto the canvas and edited. Slot-based keys
// stay slots ("@0".."@3"), so they keep following the theme.
QHash<QString, QString> bake(const Layout &layout, const Scene &scene, const ThemePalette &palette);

} // namespace Effects
