#pragma once

#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <functional>

// Burn My Windows, the omacraft.burn shell plugin: effects when windows open
// and close. The effects come from the plugin's effects.json (and its
// compiled shaders, which the page draws its previews with). The choice
// lives in ~/.config/omarchy/burn-my-windows.json, which the shell watches:
// OMAcraft rewrites it in place and keeps any keys it doesn't know.
class Burn : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY catalogChanged)
    Q_PROPERTY(QVariantList effects READ effects NOTIFY catalogChanged)
    Q_PROPERTY(QString shaderDir READ shaderDir NOTIFY catalogChanged)
    Q_PROPERTY(bool enabled READ enabled NOTIFY changed)
    Q_PROPERTY(bool openEnabled READ openEnabled NOTIFY changed)
    Q_PROPERTY(bool closeEnabled READ closeEnabled NOTIFY changed)
    Q_PROPERTY(QStringList openEffects READ openEffects NOTIFY changed)
    Q_PROPERTY(QStringList closeEffects READ closeEffects NOTIFY changed)
    Q_PROPERTY(double openSpeed READ openSpeed NOTIFY changed)
    Q_PROPERTY(double closeSpeed READ closeSpeed NOTIFY changed)
    Q_PROPERTY(double intensity READ intensity NOTIFY changed)
    Q_PROPERTY(QString color READ color NOTIFY changed)
    Q_PROPERTY(QStringList exclude READ exclude NOTIFY changed)
    Q_PROPERTY(bool skipFloating READ skipFloating NOTIFY changed)
    Q_PROPERTY(bool skipFullscreen READ skipFullscreen NOTIFY changed)
    Q_PROPERTY(bool keys READ keys NOTIFY changed)
    Q_PROPERTY(bool keysInstalled READ keysInstalled NOTIFY changed)
    Q_PROPERTY(QString settingsPath READ settingsPath CONSTANT)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    explicit Burn(std::function<QString()> pluginDir, const QString &home = {}, bool runCommands = true,
                  QObject *parent = nullptr);

    bool available() const { return !m_effects.isEmpty(); }
    QVariantList effects() const { return m_effects; }
    QString shaderDir() const { return m_shaderDir; }
    bool enabled() const { return m_settings.value("enabled").toBool(true); }
    bool openEnabled() const { return side("open").value("enabled").toBool(true); }
    bool closeEnabled() const { return side("close").value("enabled").toBool(true); }
    QStringList openEffects() const { return effectsOf("open", "glide"); }
    QStringList closeEffects() const { return effectsOf("close", "fire"); }
    double openSpeed() const { return speedOf("open"); }
    double closeSpeed() const { return speedOf("close"); }
    double intensity() const;
    QString color() const { return m_settings.value("color").toString("effect"); }
    QStringList exclude() const;
    bool skipFloating() const { return m_settings.value("skipFloating").toBool(false); }
    bool skipFullscreen() const { return m_settings.value("skipFullscreen").toBool(true); }
    bool keys() const { return m_settings.value("keys").toBool(true); }
    bool keysInstalled() const;
    QString settingsPath() const { return m_home + "/.config/omarchy/burn-my-windows.json"; }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }

    // Reads the effects from a plugin's effects.json.
    bool loadCatalog(const QString &path, QString *problem = nullptr);

    Q_INVOKABLE void reload();
    Q_INVOKABLE void setEnabled(bool on);
    // `which` is "open" or "close".
    Q_INVOKABLE void setSideEnabled(const QString &which, bool on);
    Q_INVOKABLE void setEffects(const QString &which, const QStringList &ids);
    // Adds the effect to the side's list, or takes it out; the last one stays.
    Q_INVOKABLE void toggleEffect(const QString &which, const QString &id);
    Q_INVOKABLE void setSpeed(const QString &which, double speed);
    Q_INVOKABLE void setIntensity(double value);
    Q_INVOKABLE void setColor(const QString &value);
    Q_INVOKABLE void addExclude(const QString &windowClass);
    Q_INVOKABLE void removeExclude(const QString &windowClass);
    Q_INVOKABLE void setSkipFloating(bool on);
    Q_INVOKABLE void setSkipFullscreen(bool on);
    // Routes SUPER+W / SUPER+Q through the effects, or gives them back.
    Q_INVOKABLE void setKeys(bool on);
    // Plays an effect on the active window, which is OMAcraft itself.
    Q_INVOKABLE void preview(const QString &id, const QString &direction = "both");
    Q_INVOKABLE void dismissMessages();

signals:
    void changed();
    void catalogChanged();
    void messageChanged();

private:
    QJsonObject side(const QString &which) const { return m_settings.value(which).toObject(); }
    QStringList effectsOf(const QString &which, const QString &fallback) const;
    double speedOf(const QString &which) const;
    bool known(const QString &id) const;
    void set(const QJsonObject &changes);
    void setSide(const QString &which, const QJsonObject &changes);
    void setError(const QString &message);
    void setNotice(const QString &message);
    void watch();

    std::function<QString()> m_pluginDir;
    QString m_home;
    bool m_runCommands;
    QString m_catalogStamp;
    QString m_shaderDir;
    QJsonObject m_settings;
    QVariantList m_effects;
    QString m_error;
    QString m_notice;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};
