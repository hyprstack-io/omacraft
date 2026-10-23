#pragma once

#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <functional>

// Folder trays: bar folders that open into a row of chosen apps, drawn by
// the omacraft.folders shell plugin. Each folder is one entry in shell.json's
// bar layout, with everything about it inline ({"id": "omacraft.folders",
// "name": …, "icon": …, "apps": […]}), so a bar can carry any number.
//
// `omarchy bar put` keeps a single copy of a widget, so it can't add a second
// folder; OmaCraft edits those entries in shell.json itself, rewriting the
// file in place so the shell's watcher stays on it and reloads the bar. Only
// omacraft.folders entries are touched, and each change checks the entry it
// was asked about is still the one at that place.
class Folders : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList folders READ folders NOTIFY changed)
    Q_PROPERTY(QVariantList apps READ apps NOTIFY appsChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    static constexpr const char *kWidgetId = "omacraft.folders";

    // applicationDirs: where .desktop files live, most important first
    // (empty: XDG_DATA_HOME, then XDG_DATA_DIRS).
    explicit Folders(const QString &home = {}, QStringList applicationDirs = {}, QObject *parent = nullptr);

    QVariantList folders() const { return m_folders; }
    QVariantList apps();
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }
    QString shellPath() const { return m_home + "/.config/omarchy/shell.json"; }

    // The folders in a shell.json document, each with its section and index.
    static QVariantList foldersIn(const QJsonObject &shell);
    // The installed applications under these folders: id, name, icon, comment.
    static QVariantList scanApplications(const QStringList &dirs);

    Q_INVOKABLE void reload();
    Q_INVOKABLE void reloadApps();
    // A new, empty folder at the end of a bar section. Returns its index.
    Q_INVOKABLE int add(const QString &name, const QString &section);
    Q_INVOKABLE void update(const QString &section, int index, const QVariantMap &changes);
    Q_INVOKABLE void remove(const QString &section, int index);
    // To another section's end, or one step along its own (step -1 / +1).
    Q_INVOKABLE void moveTo(const QString &section, int index, const QString &toSection);
    Q_INVOKABLE void shift(const QString &section, int index, int step);
    Q_INVOKABLE void addApp(const QString &section, int index, const QString &desktopId);
    Q_INVOKABLE void addCommand(const QString &section, int index, const QString &name, const QString &icon,
                                const QString &command);
    Q_INVOKABLE void removeApp(const QString &section, int index, int appIndex);
    Q_INVOKABLE void moveApp(const QString &section, int index, int appIndex, int step);
    Q_INVOKABLE void dismissMessages();

signals:
    void changed();
    void appsChanged();
    void messageChanged();

private:
    // Reads shell.json, runs edit on it and writes it back in place. edit
    // returns an error, or empty when the change was made.
    bool mutate(const std::function<QString(QJsonObject &)> &edit);
    // The folder entry at section/index, or an error.
    static QString folderAt(QJsonObject &shell, const QString &section, int index, QJsonObject *entry);
    static void putFolder(QJsonObject &shell, const QString &section, int index, const QJsonObject &entry);
    void setError(const QString &message);
    void watch();

    QString m_home;
    QStringList m_applicationDirs;
    QVariantList m_folders;
    QVariantList m_apps;
    bool m_appsLoaded = false;
    QString m_error;
    QString m_notice;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};
