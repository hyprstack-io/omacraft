#pragma once

#include <QFileSystemWatcher>
#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <functional>

// The Omarchy shell plugins OMAcraft houses: whether each is installed in
// ~/.config/omarchy/plugins, enabled in the shell, and where it sits on the
// bar. Every change goes through Omarchy's own `omarchy plugin` and
// `omarchy bar` commands, so the shell stays the one that owns shell.json.
class Plugins : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList plugins READ plugins NOTIFY changed)
    Q_PROPERTY(bool shellRunning READ shellRunning NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    struct Definition {
        QString id;
        QString name;
        QString summary;
        QString page;          // the OMAcraft page that holds its settings
        QString defaultSource; // where its code lives when it isn't installed
    };

    // home is the user's home folder; tests pass a temp directory and set
    // runCommands to false so nothing reaches the real shell.
    explicit Plugins(const QString &home = {}, bool runCommands = true, QObject *parent = nullptr);

    static QList<Definition> definitions();

    QVariantList plugins() const { return m_plugins; }
    bool shellRunning() const { return m_shellRunning; }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }

    // The folder a plugin's files are in right now: installed, set aside by
    // OMAcraft, or its source. Empty when there is none.
    QString pluginDir(const QString &id) const;
    QString installPath(const QString &id) const;
    QString stashPath(const QString &id) const;
    QString sourcePath(const QString &id) const;

    Q_INVOKABLE QVariantMap plugin(const QString &id) const;
    Q_INVOKABLE bool isInstalled(const QString &id) const;
    Q_INVOKABLE bool isEnabled(const QString &id) const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void install(const QString &id);
    // Disables it, then unlinks it, or sets a real folder aside in
    // ~/.local/share/omacraft/stash so installing again brings it back.
    // Nothing is ever deleted.
    Q_INVOKABLE void remove(const QString &id);
    Q_INVOKABLE void setEnabled(const QString &id, bool on);
    Q_INVOKABLE void place(const QString &id, const QString &section);
    Q_INVOKABLE void setSource(const QString &id, const QString &path);
    Q_INVOKABLE void restartShell();
    Q_INVOKABLE void dismissMessages();

    // The bar section ("left", "center", "right") holding a widget in a
    // shell.json document, or empty when it isn't on the bar.
    static QString sectionIn(const QJsonObject &shell, const QString &id);
    // The id of the bar in use, "omarchy.bar" when shell.json names none.
    static QString barIn(const QJsonObject &shell);

signals:
    void changed();
    void busyChanged();
    void messageChanged();

private:
    void rebuild();
    void readShellConfig();
    void loadSources();
    // One step of a change: a command to run, or work done here (returning
    // what went wrong, or nothing).
    struct Step {
        QStringList command = {};
        std::function<QString()> action = {};
        bool mayFail = false;
    };
    // Runs steps one after another, stopping at the first that fails.
    void runSteps(QList<Step> steps, const QString &doneNotice);
    void setBusy(bool busy);
    void setError(const QString &message);
    void setNotice(const QString &message);
    void watch();

    QString m_home;
    bool m_runCommands;
    QString m_pluginsDir;
    QString m_stashDir;
    QString m_sourcesPath;
    QString m_shellPath;

    QVariantList m_plugins;
    QJsonArray m_shellList; // `omarchy plugin list --json`
    QJsonObject m_shellConfig;
    QHash<QString, QString> m_sources;
    bool m_shellRunning = false;
    bool m_busy = false;
    QString m_error;
    QString m_notice;

    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};
