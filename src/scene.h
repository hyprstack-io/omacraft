#pragma once

#include <QColor>
#include <QHash>
#include <QJsonObject>
#include <QList>
#include <QString>

// Everything that decides what the keyboard shows. The window edits it, it
// is saved to ~/.config/alienflare/state.json, and the lighting service
// renders it. Nothing else is needed to reproduce the lights exactly.
struct Scene {
    bool on = true;
    // "paint" (keys set one by one), "pattern" (a design drawn with the
    // keys) or "animation".
    QString mode = "pattern";
    QString pattern = "alien";
    QString animation = "rainbow";
    // Take the colour slots from the Omarchy theme, so the lights change
    // with every theme and wallpaper switch.
    bool followTheme = true;
    // The four slots used when not following the theme: primary,
    // secondary, third, and the background between lit keys.
    QList<QColor> colors{QColor("#00e5ff"), QColor("#7a00ff"), QColor("#ff2bd6"), QColor("#050014")};
    // Animation tempo, 0.25 to 3.
    double speed = 1.0;
    // Led brightness and colour boost, 0 to 100.
    int brightness = 100;
    int vivid = 40;
    // The word the "Spell" design lights.
    QString word = "OMARCHY";
    // Painted keys: key id to "#rrggbb", or "@0".."@3" for a slot, which
    // then follows the theme like a design does.
    QHash<QString, QString> paint;
    // What the lid logo, power button and ring show: "leave" (untouched,
    // for another tool to set), "off", "primary", "secondary" or "keyboard"
    // (an average of the keys).
    QString chassis = "primary";

    QJsonObject toJson() const;
    static Scene fromJson(const QJsonObject &json);

    bool operator==(const Scene &other) const;
    bool operator!=(const Scene &other) const { return !(*this == other); }
};
