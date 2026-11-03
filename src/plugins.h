#pragma once

#include <QFileSystemWatcher>
#include <QJsonArray>
#include <QJsonObject>
#include <QHash>
#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <functional>

// The Omarchy shell plugins OmaCraft houses: whether each is installed in
// ~/.config/omarchy/plugins and whether it's switched on. They're run from
// OmaCraft, not from icons on the bar: the shell loads a plugin whenever
// shell.json names it, so switching one on lists it in shell.json's
// plugins[] and takes any icon of its own off the bar, and switching it off
// lists it in disabledPlugins[], which keeps whatever it still has on the
// bar (folder trays, the launcher button) for when it comes back. shell.json
// is rewritten in place, touching only that plugin's entries, so the shell's
// watcher stays on it. Installing and removing still link and set aside code
// as before, and the bar itself is switched with `omarchy bar use|reset`.
class Plugins : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList plugins READ plugins NOTIFY changed)
    Q_PROPERTY(bool shellRunning READ shellRunning NOTIFY changed)
    Q_PROPERTY(bool shellInstalled READ shellInstalled CONSTANT)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    static inline const QString kLockId = "omacraft.lock";

    struct Definition {
        QString id;
        QString name;
        QString summary;
        QString page;          // the OmaCraft page that holds its settings
        QString defaultSource; // where its code lives when it isn't installed
        QString glyph;         // its Nerd Font icon in OmaCraft
    };

    // home is the user's home folder; tests pass a temp directory and set
    // runCommands to false so nothing reaches the real shell.
    explicit Plugins(const QString &home = {}, bool runCommands = true, QObject *parent = nullptr);
    ~Plugins() override;

    static QList<Definition> definitions();

    QVariantList plugins() const { return m_plugins; }
    bool shellRunning() const { return m_shellRunning; }
    bool shellInstalled() const;
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }

    // The folder a plugin's files are in right now: installed, set aside by
    // OmaCraft, or its source. Empty when there is none.
    QString pluginDir(const QString &id) const;
    QString installPath(const QString &id) const;
    QString stashPath(const QString &id) const;
    QString sourcePath(const QString &id) const;
    // The copies of every plugin the package installs (OMACRAFT_PLUGINS_DIR overrides it).
    static QString packagedDir();

    Q_INVOKABLE QVariantMap plugin(const QString &id) const;
    Q_INVOKABLE bool isInstalled(const QString &id) const;
    Q_INVOKABLE bool isEnabled(const QString &id) const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void install(const QString &id);
    // Disables it, then unlinks it, or sets a real folder aside in
    // ~/.local/share/omacraft/stash so installing again brings it back.
    // Nothing is ever deleted.
    Q_INVOKABLE void remove(const QString &id);
    // On: listed in plugins[], with no icon of its own on the bar. Off:
    // listed in disabledPlugins[]. The bar is used or reset instead.
    Q_INVOKABLE void setEnabled(const QString &id, bool on);
    // Moves every installed plugin's bar icon into OmaCraft, leaving each
    // one switched on.
    Q_INVOKABLE void takeIconsOffBar();
    Q_INVOKABLE void setSource(const QString &id, const QString &path);
    Q_INVOKABLE void restartShell();
    Q_INVOKABLE void dismissMessages();

    // Whether a bar entry is the plugin's own icon, which OmaCraft replaces,
    // rather than something made with it that belongs on the bar: a folder
    // tray, or Studio's launcher button standing in for Omarchy's menu.
    static bool isBarIcon(const QString &id, const QJsonObject &entry);
    // How many of a plugin's icons a shell.json document has on the bar.
    static int barIconsIn(const QJsonObject &shell, const QString &id);
    // Whether a shell.json document has the shell load a plugin: named in
    // plugins[] or on the bar, and not in disabledPlugins[].
    static bool isOnIn(const QJsonObject &shell, const QString &id);
    // Switches a plugin on or off in a shell.json document, as described
    // above. Touches nothing but that plugin's entries.
    static void switchIn(QJsonObject &shell, const QString &id, bool on);
    // The id of the bar in use, "omarchy.bar" when shell.json names none.
    static QString barIn(const QJsonObject &shell);
    // Folders in pluginsDir whose manifest names another folder's id, by that
    // id. The shell keys plugins by manifest id, so one of these silently
    // replaces the folder that carries the id as its name.
    static QHash<QString, QStringList> duplicatesIn(const QString &pluginsDir);

signals:
    void changed();
    void busyChanged();
    void messageChanged();

private:
    void rebuild();
    void readShellConfig();
    // Reads shell.json, runs edit on it and writes it back in place. Returns
    // what went wrong, or nothing.
    QString editShell(const std::function<void(QJsonObject &)> &edit);
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
    // Swaps OmaCraft's lock in or back out, never leaving the shell without one.
    QStringList lockServices(const QJsonObject &shell) const;
    void swapLockIn(QJsonObject &shell, const QString &id, bool on);
    void switchLock(bool on, bool checkAfter);
    void checkLock(bool on);
    void setBusy(bool busy);
    void setError(const QString &message);
    void setNotice(const QString &message);
    void watch();
    // The shell's own watcher doesn't follow links, so edits to a linked
    // plugin's code never reach it. Watch those folders here and ask the
    // shell to rescan when they change.
    void watchSources(const QStringList &dirs);

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
    QProcess m_sourceWatch;
    QStringList m_watchedSources;
    QTimer m_reloadDebounce;
};
