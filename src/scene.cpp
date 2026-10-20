#include "scene.h"

#include <QJsonArray>
#include <QRegularExpression>
#include <algorithm>

QJsonObject Scene::toJson() const {
    QJsonArray slotList;
    for (const auto &c : colors)
        slotList << c.name();
    QJsonObject painted;
    for (auto it = paint.constBegin(); it != paint.constEnd(); ++it)
        painted.insert(it.key(), it.value());
    return {
        {"version", 1},
        {"on", on},
        {"mode", mode},
        {"pattern", pattern},
        {"animation", animation},
        {"followTheme", followTheme},
        {"colors", slotList},
        {"speed", speed},
        {"brightness", brightness},
        {"vivid", vivid},
        {"word", word},
        {"paint", painted},
        {"chassis", chassis},
    };
}

Scene Scene::fromJson(const QJsonObject &json) {
    Scene scene;
    scene.on = json.value("on").toBool(scene.on);
    const QString mode = json.value("mode").toString();
    if (mode == "paint" || mode == "pattern" || mode == "animation")
        scene.mode = mode;
    scene.pattern = json.value("pattern").toString(scene.pattern);
    scene.animation = json.value("animation").toString(scene.animation);
    scene.followTheme = json.value("followTheme").toBool(scene.followTheme);
    const QJsonArray slotList = json.value("colors").toArray();
    for (int i = 0; i < std::min<qsizetype>(slotList.size(), scene.colors.size()); ++i) {
        const QColor c(slotList.at(i).toString());
        if (c.isValid())
            scene.colors[i] = c;
    }
    scene.speed = std::clamp(json.value("speed").toDouble(scene.speed), 0.25, 3.0);
    scene.brightness = std::clamp(json.value("brightness").toInt(scene.brightness), 0, 100);
    scene.vivid = std::clamp(json.value("vivid").toInt(scene.vivid), 0, 100);
    scene.word = json.value("word").toString(scene.word).left(32);
    const QRegularExpression valid("^(#[0-9a-fA-F]{6}|@[0-3])$");
    const QJsonObject painted = json.value("paint").toObject();
    for (auto it = painted.constBegin(); it != painted.constEnd(); ++it)
        if (valid.match(it.value().toString()).hasMatch())
            scene.paint.insert(it.key(), it.value().toString().toLower());
    const QString chassis = json.value("chassis").toString();
    if (chassis == "leave" || chassis == "off" || chassis == "primary" || chassis == "secondary" || chassis == "keyboard")
        scene.chassis = chassis;
    return scene;
}

bool Scene::operator==(const Scene &o) const {
    return on == o.on && mode == o.mode && pattern == o.pattern && animation == o.animation
           && followTheme == o.followTheme && colors == o.colors && qFuzzyCompare(speed, o.speed)
           && brightness == o.brightness && vivid == o.vivid && word == o.word && paint == o.paint
           && chassis == o.chassis;
}
