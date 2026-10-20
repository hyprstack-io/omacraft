#include "store.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QSaveFile>
#include <QStandardPaths>

Store::Store(const QString &directory, QObject *parent)
    : QObject(parent), m_directory(directory.isEmpty() ? defaultDirectory() : directory) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(60);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(); });
    connect(&m_debounce, &QTimer::timeout, this, [this] {
        const Scene before = m_scene;
        reload();
        rearm();
        if (m_scene != before)
            emit changed();
    });
    reload();
    rearm();
}

QString Store::defaultDirectory() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + "/alienflare";
}

void Store::reload() {
    QFile file(path());
    if (!file.open(QIODevice::ReadOnly))
        return;
    const auto doc = QJsonDocument::fromJson(file.readAll());
    // A half-written or broken file keeps what we had, rather than resetting
    // the lights to the defaults.
    if (doc.isObject())
        m_scene = Scene::fromJson(doc.object());
}

void Store::rearm() {
    const auto paths = m_watcher.files() + m_watcher.directories();
    if (!paths.isEmpty())
        m_watcher.removePaths(paths);
    // An atomic save replaces the file, which ends a watch on it, so the
    // directory is watched too.
    QDir().mkpath(m_directory);
    m_watcher.addPath(m_directory);
    if (QFileInfo::exists(path()))
        m_watcher.addPath(path());
}

bool Store::save(const Scene &scene, QString *error) {
    QDir().mkpath(m_directory);
    QSaveFile file(path());
    if (!file.open(QIODevice::WriteOnly)) {
        if (error)
            *error = "Can't write " + path() + ": " + file.errorString();
        return false;
    }
    file.write(QJsonDocument(scene.toJson()).toJson(QJsonDocument::Indented));
    if (!file.commit()) {
        if (error)
            *error = "Can't save " + path() + ": " + file.errorString();
        return false;
    }
    m_scene = scene;
    return true;
}

// --- the service's status ---

QString DriverStatus::defaultPath() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation) + "/alienflare/status.json";
}

DriverStatus DriverStatus::read(const QString &path) {
    DriverStatus status;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return status;
    const auto json = QJsonDocument::fromJson(file.readAll()).object();
    status.pid = json.value("pid").toInteger();
    status.keyboard = json.value("keyboard").toString();
    status.keyboardError = json.value("keyboardError").toString();
    status.chassisError = json.value("chassisError").toString();
    return status;
}

bool DriverStatus::write(const QString &path) const {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    const QJsonObject json{{"pid", pid}, {"keyboard", keyboard}, {"keyboardError", keyboardError},
                           {"chassisError", chassisError}};
    file.write(QJsonDocument(json).toJson(QJsonDocument::Indented));
    return file.commit();
}

bool DriverStatus::running() const {
    if (pid <= 0)
        return false;
    QFile comm(QString("/proc/%1/comm").arg(pid));
    return comm.open(QIODevice::ReadOnly) && comm.readAll().trimmed() == "alienflare";
}
