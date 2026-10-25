#pragma once

#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QStringList>
#include <QVariantList>

class AgentDock;
class Animations;
class Burn;
class Launcher;
class Omascii;
class Wallpaper;
class Lights;

// The wallpaper's colours reaching every part OmaCraft sets. hyprskin builds
// the Omarchy theme from the wallpaper, which recolours whatever reads the
// theme; the parts below keep colours of their own unless told to follow it:
// omabar16's style (hyprskin's colorizeBar), the window border (a gradient
// OmaCraft builds from the theme), Side Dock and Burn My Windows ("theme"),
// Launcher (its "omarchy" scheme) and omascii (the theme's colour names).
// Turning a part on keeps what it had in ~/.config/omacraft/theme-sync.json,
// so turning it off puts that back.
//
// A theme-set hook runs `omacraft --sync-colors` after every theme switch, so
// the border gradient follows each new wallpaper, and an underlined bar's text
// stays readable, while OmaCraft is closed.
class ThemeSync : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList parts READ parts NOTIFY changed)
    Q_PROPERTY(bool allFollow READ allFollow NOTIFY changed)

public:
    ThemeSync(AgentDock *dock, Animations *animations, Burn *burn, Launcher *launcher, Omascii *omascii,
              Wallpaper *wallpaper, const QString &home = {}, bool runCommands = true, QObject *parent = nullptr);

    // The border colour run OmaCraft writes and keeps up to date.
    static constexpr const char *borderRun = "wallpaper";

    QVariantList parts() const;
    bool allFollow() const;

    Q_INVOKABLE void setFollow(const QString &id, bool on);
    // Every installed part that doesn't follow yet.
    Q_INVOKABLE void followAll();

    // AlienFlare's keyboard lights, a part that follows the theme too.
    void setLights(Lights *lights);

    // The theme's accent and hues as a border gradient: up to four colours
    // ("rrggbb"), none lost in the background, none repeating another.
    static QStringList borderColors(const QHash<QString, QString> &themeColors);
    // Puts the "wallpaper" run in animation-presets.json, keeping everything
    // else there; true when its colours changed.
    static bool writeBorderRun(const QString &home, const QHash<QString, QString> &themeColors);
    // The hook's work, run without a window: the border run, then an
    // underlined bar's text. Returns the process exit code.
    static int syncNow(const QString &home = {});
    static QString hookScript(const QString &program);

signals:
    void changed();

private:
    bool follows(const QString &id) const;
    bool available(const QString &id) const;
    void save(const QString &id, const QJsonObject &values);
    QJsonObject saved(const QString &id) const;
    void writeConfig();
    void installHook();
    void seedFromWallpaper();

    AgentDock *m_dock;
    Animations *m_animations;
    Burn *m_burn;
    Launcher *m_launcher;
    Omascii *m_omascii;
    Wallpaper *m_wallpaper;
    Lights *m_lights = nullptr;
    QString m_home;
    bool m_runCommands;
    QJsonObject m_config;
};
