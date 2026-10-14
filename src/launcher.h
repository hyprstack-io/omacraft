#pragma once

#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <functional>

// OMArofi, the Omarchy launcher that lives in the Studio plugin. Its layouts,
// colour schemes and transitions come from the plugin's own
// LauncherStyles.js, so OMAcraft lists exactly what the launcher draws. The
// choice lives in ~/.config/omarchy/launcher-style.json, which the launcher
// watches: OMAcraft rewrites it in place (a rename would detach the shell's
// watcher) and keeps any keys it doesn't know.
class Launcher : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY catalogChanged)
    Q_PROPERTY(QVariantList layouts READ layouts NOTIFY catalogChanged)
    Q_PROPERTY(QVariantList schemes READ schemes NOTIFY catalogChanged)
    Q_PROPERTY(QVariantList transitions READ transitions NOTIFY catalogChanged)
    Q_PROPERTY(QString layout READ layout NOTIFY changed)
    Q_PROPERTY(QString scheme READ scheme NOTIFY changed)
    Q_PROPERTY(QString transition READ transition NOTIFY changed)
    Q_PROPERTY(double speed READ speed NOTIFY changed)
    Q_PROPERTY(bool animateLayouts READ animateLayouts NOTIFY changed)
    Q_PROPERTY(bool animateColors READ animateColors NOTIFY changed)
    Q_PROPERTY(QString stylePath READ stylePath CONSTANT)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    explicit Launcher(std::function<QString()> pluginDir, const QString &home = {}, bool runCommands = true,
                      QObject *parent = nullptr);

    bool available() const { return !m_layouts.isEmpty(); }
    QVariantList layouts() const { return m_layouts; }
    QVariantList schemes() const { return m_schemes; }
    QVariantList transitions() const { return m_transitions; }
    QString layout() const;
    QString scheme() const;
    QString transition() const;
    double speed() const;
    bool animateLayouts() const { return m_style.value("animateLayouts").toBool(true); }
    bool animateColors() const { return m_style.value("animateColors").toBool(true); }
    QString stylePath() const { return m_home + "/.config/omarchy/launcher-style.json"; }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }

    // Reads layouts, schemes and transitions from a LauncherStyles.js file.
    bool loadCatalog(const QString &path, QString *problem = nullptr);

    Q_INVOKABLE void reload();
    Q_INVOKABLE void setLayout(const QString &id);
    Q_INVOKABLE void setScheme(const QString &id);
    Q_INVOKABLE void setTransition(const QString &id);
    Q_INVOKABLE void setSpeed(double speed);
    Q_INVOKABLE void setAnimateLayouts(bool on);
    Q_INVOKABLE void setAnimateColors(bool on);
    Q_INVOKABLE void randomize();
    // Opens the launcher, to see the current style.
    Q_INVOKABLE void preview();
    Q_INVOKABLE void dismissMessages();

signals:
    void changed();
    void catalogChanged();
    void messageChanged();

private:
    void set(const QString &key, const QJsonValue &value);
    void set(const QJsonObject &changes);
    bool has(const QVariantList &list, const QString &id) const;
    void setError(const QString &message);
    void watch();

    std::function<QString()> m_pluginDir;
    QString m_home;
    bool m_runCommands;
    QString m_catalogStamp;
    QJsonObject m_style;
    QVariantList m_layouts;
    QVariantList m_schemes;
    QVariantList m_transitions;
    QString m_error;
    QString m_notice;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};
