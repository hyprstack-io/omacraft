#pragma once

#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QTimer>

#include "scene.h"

// The scene on disk, ~/.config/alienflare/state.json, shared by the window,
// OmaCraft's Alienflare page and the lighting service. Writes are atomic
// (beside the file, then renamed), so a reader never sees half a file, and
// the file is watched so a change from any of them reaches the others.
class Store : public QObject {
    Q_OBJECT

public:
    explicit Store(const QString &configDirectory = {}, QObject *parent = nullptr);

    QString path() const { return m_directory + "/state.json"; }
    const Scene &scene() const { return m_scene; }
    // Writes the scene; false (with `error`) when it couldn't be saved.
    bool save(const Scene &scene, QString *error = nullptr);

    static QString defaultDirectory();

signals:
    // The file changed underneath us.
    void changed();

private:
    void reload();
    void rearm();

    QString m_directory;
    Scene m_scene;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};

// What the lighting service reports about itself, in
// ~/.local/state/alienflare/status.json: whether it runs, what it writes the
// keyboard through, and what is wrong.
struct DriverStatus {
    qint64 pid = 0;
    QString keyboard;
    QString keyboardError;
    QString chassisError;

    static QString defaultPath();
    static DriverStatus read(const QString &path = defaultPath());
    bool write(const QString &path = defaultPath()) const;
    // Whether the pid is a live alienflare process.
    bool running() const;
};
