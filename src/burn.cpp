#include "burn.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QRegularExpression>

#include "proc.h"

Burn::Burn(std::function<QString()> pluginDir, const QString &home, bool runCommands, QObject *parent)
    : QObject(parent),
      m_pluginDir(std::move(pluginDir)),
      m_home(home.isEmpty() ? QDir::homePath() : home),
      m_runCommands(runCommands) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(120);
    connect(&m_debounce, &QTimer::timeout, this, &Burn::reload);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    reload();
}

bool Burn::loadCatalog(const QString &path, QString *problem) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        if (problem)
            *problem = "Can't read " + path;
        return false;
    }
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        if (problem)
            *problem = path + ": " + parseError.errorString();
        return false;
    }
    m_effects = doc.object().value("effects").toArray().toVariantList();
    m_shaderDir = QFileInfo(path).absolutePath() + "/shaders";
    emit catalogChanged();
    return !m_effects.isEmpty();
}

void Burn::watch() {
    const auto paths = m_watcher.files() + m_watcher.directories();
    if (!paths.isEmpty())
        m_watcher.removePaths(paths);
    for (const auto &path : {settingsPath(), QFileInfo(settingsPath()).absolutePath(), m_home + "/.config/hypr"})
        if (QFileInfo::exists(path))
            m_watcher.addPath(path);
}

void Burn::reload() {
    QFile file(settingsPath());
    QJsonObject settings;
    if (file.open(QIODevice::ReadOnly))
        settings = QJsonDocument::fromJson(file.readAll()).object();
    // Half-written files read as empty; keep what we had until the rest lands.
    if (settings.isEmpty() && file.size() > 0)
        settings = m_settings;
    if (settings != m_settings) {
        m_settings = settings;
        emit changed();
    }

    const QString dir = m_pluginDir ? m_pluginDir() : QString();
    const QString catalog = dir.isEmpty() ? QString() : dir + "/effects.json";
    const QString stamp = catalog + "|" + QFileInfo(catalog).lastModified().toString(Qt::ISODateWithMs);
    if (catalog.isEmpty() || !QFileInfo::exists(catalog)) {
        m_catalogStamp.clear();
        if (!m_effects.isEmpty()) {
            m_effects.clear();
            m_shaderDir.clear();
            emit catalogChanged();
        }
    } else if (stamp != m_catalogStamp) {
        QString problem;
        if (loadCatalog(catalog, &problem))
            m_catalogStamp = stamp;
        else
            setError("Couldn't read the window effects: " + problem);
    }
    watch();
}

QStringList Burn::effectsOf(const QString &which, const QString &fallback) const {
    QStringList ids;
    for (const auto &value : side(which).value("effects").toArray())
        ids << value.toString();
    return ids.isEmpty() ? QStringList{fallback} : ids;
}

double Burn::speedOf(const QString &which) const {
    const double value = side(which).value("speed").toDouble(1.0);
    return value > 0 ? value : 1.0;
}

double Burn::intensity() const {
    const double value = m_settings.value("intensity").toDouble(1.0);
    return value > 0 ? value : 1.0;
}

QStringList Burn::exclude() const {
    if (!m_settings.contains("exclude"))
        return {"org.omarchy.screensaver"};
    QStringList classes;
    for (const auto &value : m_settings.value("exclude").toArray())
        classes << value.toString();
    return classes;
}

bool Burn::keysInstalled() const {
    QFile file(m_home + "/.config/hypr/burn_my_windows.lua");
    if (!file.open(QIODevice::ReadOnly))
        return false;
    return file.readAll().contains("omarchy-burn close");
}

bool Burn::known(const QString &id) const {
    if (id == "random")
        return true;
    for (const auto &entry : m_effects)
        if (entry.toMap().value("id").toString() == id)
            return true;
    return false;
}

void Burn::set(const QJsonObject &changes) {
    QJsonObject settings = m_settings;
    for (auto it = changes.begin(); it != changes.end(); ++it)
        settings.insert(it.key(), it.value());
    // In place, not through a rename: the shell's FileView would lose the
    // file it watches.
    QDir().mkpath(QFileInfo(settingsPath()).absolutePath());
    QFile file(settingsPath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        setError("Can't write " + settingsPath() + ": " + file.errorString());
        return;
    }
    file.write(QJsonDocument(settings).toJson(QJsonDocument::Indented));
    file.close();
    m_settings = settings;
    emit changed();
}

void Burn::setSide(const QString &which, const QJsonObject &changes) {
    if (which != "open" && which != "close")
        return setError("Effects are for windows that open or close, not " + which + ".");
    QJsonObject part = side(which);
    for (auto it = changes.begin(); it != changes.end(); ++it)
        part.insert(it.key(), it.value());
    set(QJsonObject{{which, part}});
}

void Burn::setEnabled(bool on) { set(QJsonObject{{"enabled", on}}); }
void Burn::setSideEnabled(const QString &which, bool on) { setSide(which, QJsonObject{{"enabled", on}}); }

void Burn::setEffects(const QString &which, const QStringList &ids) {
    if (ids.isEmpty())
        return setError("Pick at least one effect.");
    for (const auto &id : ids)
        if (!known(id))
            return setError("There's no effect called " + id + ". Update the omacraft.burn plugin.");
    setSide(which, QJsonObject{{"effects", QJsonArray::fromStringList(ids)}});
}

void Burn::toggleEffect(const QString &which, const QString &id) {
    QStringList ids = which == "open" ? openEffects() : closeEffects();
    if (id == "random") {
        ids = ids.contains("random") ? QStringList{} : QStringList{"random"};
    } else {
        ids.removeAll("random");
        if (ids.contains(id)) {
            // Taking out the last one would leave nothing to play.
            if (ids.size() == 1)
                return;
            ids.removeAll(id);
        } else {
            ids << id;
        }
    }
    if (ids.isEmpty())
        ids << (which == "open" ? "glide" : "fire");
    setEffects(which, ids);
}

void Burn::setSpeed(const QString &which, double speed) {
    setSide(which, QJsonObject{{"speed", qRound(qBound(0.25, speed, 3.0) * 100) / 100.0}});
}

void Burn::setIntensity(double value) { set(QJsonObject{{"intensity", qRound(qBound(0.25, value, 2.5) * 100) / 100.0}}); }

void Burn::setColor(const QString &value) {
    static const QRegularExpression hex("^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$");
    if (value != "effect" && value != "theme" && !hex.match(value).hasMatch())
        return setError("The colour is the effect's own, the theme's, or a #rrggbb.");
    set(QJsonObject{{"color", value}});
}

void Burn::addExclude(const QString &windowClass) {
    const QString name = windowClass.trimmed();
    if (name.isEmpty())
        return;
    QStringList classes = exclude();
    if (classes.contains(name))
        return;
    classes << name;
    set(QJsonObject{{"exclude", QJsonArray::fromStringList(classes)}});
}

void Burn::removeExclude(const QString &windowClass) {
    QStringList classes = exclude();
    classes.removeAll(windowClass);
    set(QJsonObject{{"exclude", QJsonArray::fromStringList(classes)}});
}

void Burn::setSkipFloating(bool on) { set(QJsonObject{{"skipFloating", on}}); }
void Burn::setSkipFullscreen(bool on) { set(QJsonObject{{"skipFullscreen", on}}); }

void Burn::setKeys(bool on) {
    const QString dir = m_pluginDir ? m_pluginDir() : QString();
    if (dir.isEmpty())
        return setError("Install the omacraft.burn plugin first.");
    if (!m_runCommands) {
        set(QJsonObject{{"keys", on}});
        return;
    }
    Proc::run(this, dir + "/bin/omarchy-burn", {"keys", on ? "on" : "off"}, [this, on](const Proc::Result &result) {
        reload();
        if (!result.ok())
            return setError("Couldn't change the close keys: " + result.message());
        setNotice(on ? "SUPER+W and SUPER+Q now close windows through the effects."
                     : "SUPER+W and SUPER+Q close windows the usual way again.");
    });
}

void Burn::preview(const QString &id, const QString &direction) {
    if (!m_runCommands)
        return;
    if (!known(id) || id == "random")
        return setError("There's no effect called " + id + ".");
    const QString method = direction == "open" ? "previewOpen" : direction == "close" ? "previewClose" : "preview";
    Proc::run(this, "omarchy-shell", {"burn", method, id}, [this](const Proc::Result &result) {
        if (!result.ok())
            setError("The shell isn't running the effects yet. Enable Burn My Windows on the Plugin Suite page, "
                     "or restart the shell if you just did.");
    });
}

void Burn::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}

void Burn::setNotice(const QString &message) {
    m_notice = message;
    m_error.clear();
    emit messageChanged();
}

void Burn::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}
