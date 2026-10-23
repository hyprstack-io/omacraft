#include "themesync.h"
#include "lights.h"

#include <QColor>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QRegularExpression>
#include <cmath>

#include "agentdock.h"
#include "animations.h"
#include "bar.h"
#include "burn.h"
#include "launcher.h"
#include "omascii.h"
#include "proc.h"
#include "theme.h"
#include "wallpaper.h"

namespace {

QJsonObject readJsonObject(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object();
}

// A setting's value, or what the part uses when it isn't set.
QString valueOr(const QVariantMap &map, const QString &key, const QString &fallback) {
    const QString value = map.value(key).toString();
    return value.isEmpty() ? fallback : value;
}

bool isHex(const QString &value) {
    static const QRegularExpression hex("^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$");
    return hex.match(value).hasMatch();
}

double distance(const QColor &a, const QColor &b) {
    return std::sqrt(std::pow(a.redF() - b.redF(), 2) + std::pow(a.greenF() - b.greenF(), 2)
                     + std::pow(a.blueF() - b.blueF(), 2));
}

// Runs a tool and waits for it: the hook has no event loop to come back to.
bool runNow(const QString &program, const QStringList &arguments, int timeoutMs = 30000) {
    QProcess process;
    process.setProcessChannelMode(QProcess::ForwardedChannels);
    process.start(program, arguments);
    if (!process.waitForStarted(5000))
        return false;
    process.waitForFinished(timeoutMs);
    return process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0;
}

QString colorsPath(const QString &home) { return home + "/.local/state/omarchy/current/theme/colors.toml"; }
QString hookPath(const QString &home) { return home + "/.config/omarchy/hooks/theme-set.d/70-omacraft-colors"; }

// Part ids in the order the page lists them.
const QStringList partIds{"bar", "borders", "dock", "effects", "launcher", "ascii", "keys"};

} // namespace

ThemeSync::ThemeSync(AgentDock *dock, Animations *animations, Burn *burn, Launcher *launcher, Omascii *omascii,
                     Wallpaper *wallpaper, const QString &home, bool runCommands, QObject *parent)
    : QObject(parent),
      m_dock(dock),
      m_animations(animations),
      m_burn(burn),
      m_launcher(launcher),
      m_omascii(omascii),
      m_wallpaper(wallpaper),
      m_home(home.isEmpty() ? QDir::homePath() : home),
      m_runCommands(runCommands) {
    m_config = readJsonObject(m_home + "/.config/omacraft/theme-sync.json");
    if (m_dock)
        connect(m_dock, &AgentDock::changed, this, &ThemeSync::changed);
    if (m_animations)
        connect(m_animations, &Animations::changed, this, &ThemeSync::changed);
    if (m_burn) {
        connect(m_burn, &Burn::changed, this, &ThemeSync::changed);
        connect(m_burn, &Burn::catalogChanged, this, &ThemeSync::changed);
    }
    if (m_launcher) {
        connect(m_launcher, &Launcher::changed, this, &ThemeSync::changed);
        connect(m_launcher, &Launcher::catalogChanged, this, &ThemeSync::changed);
    }
    if (m_omascii) {
        connect(m_omascii, &Omascii::configChanged, this, &ThemeSync::changed);
        connect(m_omascii, &Omascii::availableChanged, this, &ThemeSync::changed);
        connect(m_omascii, &Omascii::statusChanged, this, &ThemeSync::changed);
    }
    if (m_wallpaper) {
        connect(m_wallpaper, &Wallpaper::statusChanged, this, &ThemeSync::changed);
        connect(m_wallpaper, &Wallpaper::availableChanged, this, &ThemeSync::changed);
        connect(m_wallpaper, &Wallpaper::statusChanged, this, &ThemeSync::seedFromWallpaper);
    }
    if (m_runCommands)
        installHook();
}

QStringList ThemeSync::borderColors(const QHash<QString, QString> &themeColors) {
    const QColor background(themeColors.value("background"));
    QList<QColor> picked;
    for (const auto &key : {"accent", "magenta", "blue", "cyan", "green", "yellow", "orange", "red"}) {
        const QColor color(themeColors.value(key));
        if (!isHex(themeColors.value(key)) || picked.size() == 4)
            continue;
        // A border the colour of the desktop around it is no border.
        if (background.isValid() && Theme::contrastRatio(color, background) < 1.6)
            continue;
        bool repeat = false;
        for (const auto &other : picked)
            repeat = repeat || distance(color, other) < 0.12;
        if (!repeat)
            picked << color;
    }
    if (picked.isEmpty())
        picked << QColor(Theme::readAccent(QString()));
    // One colour still needs a second for the gradient to run.
    if (picked.size() == 1)
        picked << Theme::mix(picked.first(), background.isValid() ? background : QColor(Qt::black), 0.45);
    QStringList out;
    for (const auto &color : picked)
        out << color.name().mid(1);
    return out;
}

bool ThemeSync::writeBorderRun(const QString &home, const QHash<QString, QString> &themeColors) {
    const QString path = home + "/.config/omarchy/animation-presets.json";
    QJsonObject presets = readJsonObject(path);
    QJsonObject borders = presets.value("borders").toObject();
    const QJsonObject run{{"name", "Wallpaper"},
                          {"colors", QJsonArray::fromStringList(borderColors(themeColors))},
                          {"angle", 45}};
    if (borders.value(borderRun).toObject() == run)
        return false;
    borders.insert(borderRun, run);
    presets.insert("borders", borders);
    // omarchy-animations reads its curves and presets from here as well.
    if (!presets.contains("presets"))
        presets.insert("presets", QJsonArray());
    if (!presets.contains("curves"))
        presets.insert("curves", QJsonObject());
    return Proc::writeAtomically(path, QJsonDocument(presets).toJson());
}

int ThemeSync::syncNow(const QString &homeIn) {
    const QString home = homeIn.isEmpty() ? QDir::homePath() : homeIn;
    const auto colors = Theme::readColors(colorsPath(home));
    if (colors.isEmpty())
        return 0;

    // The border gradient, when it is the one in use.
    const QJsonObject look = readJsonObject(home + "/.config/omarchy/animation-preset.json");
    if (look.value("border").toString() == borderRun && writeBorderRun(home, colors)) {
        const QString script = home + "/.config/omarchy/plugins/omacraft.animations/bin/omarchy-animations";
        if (QFileInfo::exists(script))
            runNow("python3", {script, "border", borderRun});
    }

    // An underlined omabar16's text, after hyprskin has recoloured the bar.
    const QJsonObject bar = readJsonObject(home + "/.config/omarchy/shell.json").value("bar").toObject();
    if (bar.value("id").toString() == "omabar16") {
        const QString ink = Bar::underlineInk(bar, colors);
        const QString before = bar.value("style").toObject().value("fg").toString();
        if (!ink.isEmpty() && runNow("omarchy-shell", {"omabar16", "color", "fg", ink}, 15000)) {
            // hyprskin takes a bar unlike the one it last wrote for a change of
            // yours, and stops putting your own colours back. This is still
            // its bar, so it learns the new text colour.
            const QString state = qEnvironmentVariable("XDG_STATE_HOME", home + "/.local/state")
                                + "/hyprskin/omabar16-base.json";
            QJsonObject saved = readJsonObject(state);
            QJsonObject written = saved.value("written").toObject();
            if (!written.isEmpty() && written.value("fg").toString() == before) {
                written.insert("fg", ink);
                saved.insert("written", written);
                Proc::writeAtomically(state, QJsonDocument(saved).toJson());
            }
        }
    }
    return 0;
}

QString ThemeSync::hookScript(const QString &program) {
    return QString(R"sh(#!/bin/bash
# Installed by OmaCraft. After every theme switch, the wallpaper's colours
# included, it rebuilds the window-border gradient OmaCraft makes from the
# theme and keeps an underlined omabar16's text readable on the bar.
omacraft="$(command -v omacraft 2>/dev/null)"
[[ -n $omacraft ]] || omacraft=%1
[[ -x $omacraft ]] || exit 0
setsid "$omacraft" --sync-colors >/dev/null 2>&1 &
exit 0
)sh")
        .arg(Proc::shellQuote(program));
}

void ThemeSync::installHook() {
    const QString script = hookScript(QCoreApplication::applicationFilePath());
    const QString path = hookPath(m_home);
    QFile current(path);
    if (current.open(QIODevice::ReadOnly) && current.readAll() == script.toUtf8())
        return;
    current.close();
    if (Proc::writeAtomically(path, script.toUtf8()))
        QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner
                                        | QFileDevice::ReadGroup | QFileDevice::ExeGroup | QFileDevice::ReadOther
                                        | QFileDevice::ExeOther);
}

void ThemeSync::setLights(Lights *lights) {
    m_lights = lights;
    if (m_lights)
        connect(m_lights, &Lights::changed, this, &ThemeSync::changed);
}

bool ThemeSync::available(const QString &id) const {
    if (id == "keys")
        return m_lights != nullptr;
    if (id == "bar")
        return m_wallpaper && m_wallpaper->available();
    if (id == "borders")
        return m_animations && m_animations->available();
    if (id == "dock")
        return m_dock && m_dock->available();
    if (id == "effects")
        return m_burn && m_burn->available();
    if (id == "launcher")
        return m_launcher && m_launcher->available();
    if (id == "ascii")
        return m_omascii && m_omascii->available() && m_omascii->loaded();
    return false;
}

bool ThemeSync::follows(const QString &id) const {
    if (id == "keys")
        return m_lights && m_lights->followTheme();
    if (id == "bar")
        return m_wallpaper && m_wallpaper->status().value("settings").toMap().value("colorizeBar", true).toBool();
    if (id == "borders") {
        // The theme's own border is the hyprskin theme's, so it follows too.
        const QString border = m_animations ? m_animations->border() : QString();
        return border == borderRun || border == "theme";
    }
    if (id == "dock") {
        const auto settings = m_dock ? m_dock->settings() : QVariantMap();
        return valueOr(settings, "dockColor", "theme") == "theme"
            && valueOr(settings, "accentColor", "theme") == "theme";
    }
    if (id == "effects")
        return m_burn && m_burn->color() == "theme";
    if (id == "launcher")
        return m_launcher && m_launcher->scheme() == "omarchy";
    if (id == "ascii") {
        const auto config = m_omascii ? m_omascii->config() : QVariantMap();
        return !isHex(config.value("color").toString()) && !isHex(config.value("color2").toString())
            && config.value("colorMode").toString() != "palette";
    }
    return false;
}

QVariantList ThemeSync::parts() const {
    static const QHash<QString, QPair<QString, QString>> text{
        {"bar", {"Bar colours", "omabar16's segment, text and background colours, mapped onto the wallpaper's palette. "
                                "An underlined bar's text is kept readable on the bar."}},
        {"borders", {"Window borders", "A gradient of the wallpaper's accent and hues, rebuilt with every wallpaper "
                                       "(it spins if the Window Transitions page says so). The theme's own border follows too."}},
        {"dock", {"Side Dock", "The dock and its accent take the theme's colours instead of a named colour."}},
        {"effects", {"Burn My Windows", "Opening and closing effects take the theme's accent instead of their own colours."}},
        {"launcher", {"Launcher", "The launcher uses the Omarchy theme's colours instead of a fixed scheme."}},
        {"ascii", {"Boot Splash", "Its colours become the theme's accent and blue. The boot screen takes them the next "
                                 "time you apply it to boot."}},
        {"keys", {"Keyboard lights", "AlienFlare's designs and animations take the theme's colours on the "
                                     "Alienware keyboard, and change with every wallpaper."}}};
    QVariantList out;
    for (const auto &id : partIds) {
        const bool follow = follows(id);
        // Following with nothing to go back to: the part's own default is the
        // theme (the dock), or the theme's border, so there's nothing to undo.
        const bool fixed = follow && id != "bar" && id != "keys" && saved(id).isEmpty();
        out << QVariantMap{{"id", id},
                           {"label", text.value(id).first},
                           {"description", text.value(id).second},
                           {"available", available(id)},
                           {"follow", follow},
                           {"fixed", fixed}};
    }
    return out;
}

bool ThemeSync::allFollow() const {
    for (const auto &id : partIds)
        if (available(id) && !follows(id))
            return false;
    return true;
}

QJsonObject ThemeSync::saved(const QString &id) const {
    return m_config.value("saved").toObject().value(id).toObject();
}

void ThemeSync::save(const QString &id, const QJsonObject &values) {
    QJsonObject all = m_config.value("saved").toObject();
    if (values.isEmpty())
        all.remove(id);
    else
        all.insert(id, values);
    m_config.insert("saved", all);
    writeConfig();
}

void ThemeSync::writeConfig() {
    Proc::writeAtomically(m_home + "/.config/omacraft/theme-sync.json", QJsonDocument(m_config).toJson());
}

void ThemeSync::setFollow(const QString &id, bool on) {
    if (!available(id) || on == follows(id))
        return;

    // The scene keeps its own colours while it follows, so there is
    // nothing to save or put back.
    if (id == "keys") {
        m_lights->setFollowTheme(on);
        return;
    }

    if (id == "bar") {
        m_wallpaper->setOption("colorizeBar", on);
        return;
    }

    if (on) {
        if (id == "borders") {
            save(id, {{"border", m_animations->border()}});
            // The run has to exist before omarchy-animations will take it.
            writeBorderRun(m_home, Theme::readColors(colorsPath(m_home)));
            m_animations->setBorder(borderRun);
        } else if (id == "dock") {
            const auto settings = m_dock->settings();
            save(id, QJsonObject{{"dockColor", valueOr(settings, "dockColor", "theme")},
                                 {"accentColor", valueOr(settings, "accentColor", "theme")}});
            m_dock->set("dockColor", "theme");
            m_dock->set("accentColor", "theme");
        } else if (id == "effects") {
            save(id, {{"color", m_burn->color()}});
            m_burn->setColor("theme");
        } else if (id == "launcher") {
            save(id, {{"scheme", m_launcher->scheme()}});
            m_launcher->setScheme("omarchy");
        } else if (id == "ascii") {
            const auto config = m_omascii->config();
            save(id, QJsonObject::fromVariantMap({{"color", config.value("color")},
                                                  {"color2", config.value("color2")},
                                                  {"colorMode", config.value("colorMode")}}));
            if (isHex(config.value("color").toString()))
                m_omascii->setOption("color", "accent");
            if (isHex(config.value("color2").toString()))
                m_omascii->setOption("color2", "blue");
            if (config.value("colorMode").toString() == "palette")
                m_omascii->setOption("colorMode", "gradient");
        }
        emit changed();
        return;
    }

    // Off: back to what the part had before it followed.
    const QJsonObject before = saved(id);
    if (before.isEmpty())
        return;
    if (id == "borders") {
        m_animations->setBorder(before.value("border").toString("theme"));
    } else if (id == "dock") {
        m_dock->set("dockColor", before.value("dockColor").toString("theme"));
        m_dock->set("accentColor", before.value("accentColor").toString("theme"));
    } else if (id == "effects") {
        m_burn->setColor(before.value("color").toString("effect"));
    } else if (id == "launcher") {
        m_launcher->setScheme(before.value("scheme").toString());
    } else if (id == "ascii") {
        for (const auto &key : {"color", "color2", "colorMode"})
            if (before.contains(key))
                m_omascii->setOption(key, before.value(key).toVariant());
    }
    save(id, {});
    emit changed();
}

void ThemeSync::followAll() {
    for (const auto &id : partIds)
        setFollow(id, true);
}

// The first time OmaCraft sees wallpaper colours in use, every part follows
// them; after that each part is yours to switch.
void ThemeSync::seedFromWallpaper() {
    if (m_config.value("seeded").toBool() || !m_wallpaper)
        return;
    const auto settings = m_wallpaper->status().value("settings").toMap();
    if (settings.isEmpty())
        return;
    m_config.insert("seeded", true);
    writeConfig();
    if (settings.value("dynamicColors").toBool())
        followAll();
}
