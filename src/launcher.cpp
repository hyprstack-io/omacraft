#include "launcher.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJSEngine>
#include <QJsonDocument>
#include <QRandomGenerator>
#include <QRegularExpression>

#include "proc.h"

Launcher::Launcher(std::function<QString()> pluginDir, const QString &home, bool runCommands, QObject *parent)
    : QObject(parent),
      m_pluginDir(std::move(pluginDir)),
      m_home(home.isEmpty() ? QDir::homePath() : home),
      m_runCommands(runCommands) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(120);
    connect(&m_debounce, &QTimer::timeout, this, &Launcher::reload);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    reload();
}

bool Launcher::loadCatalog(const QString &path, QString *problem) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        if (problem)
            *problem = "Can't read " + path;
        return false;
    }
    // ".pragma library" is a QML directive, not JavaScript.
    QString source = QString::fromUtf8(file.readAll());
    source.replace(QRegularExpression(R"(^\s*\.pragma\s+library\s*$)", QRegularExpression::MultilineOption), "");

    QJSEngine engine;
    const QJSValue result = engine.evaluate(source, path);
    if (result.isError()) {
        if (problem)
            *problem = QString("%1 line %2: %3").arg(path).arg(result.property("lineNumber").toInt()).arg(result.toString());
        return false;
    }
    const QJSValue global = engine.globalObject();
    m_layouts = global.property("layouts").toVariant().toList();
    m_schemes = global.property("schemes").toVariant().toList();
    // An older launcher without transitions still gets its layouts and colours.
    m_transitions = global.property("transitions").isArray() ? global.property("transitions").toVariant().toList()
                                                             : QVariantList{};
    emit catalogChanged();
    return !m_layouts.isEmpty();
}

void Launcher::watch() {
    const auto paths = m_watcher.files() + m_watcher.directories();
    if (!paths.isEmpty())
        m_watcher.removePaths(paths);
    for (const auto &path : {stylePath(), QFileInfo(stylePath()).absolutePath()})
        if (QFileInfo::exists(path))
            m_watcher.addPath(path);
}

void Launcher::reload() {
    QFile file(stylePath());
    QJsonObject style;
    if (file.open(QIODevice::ReadOnly))
        style = QJsonDocument::fromJson(file.readAll()).object();
    if (style != m_style) {
        m_style = style;
        emit changed();
    }

    const QString dir = m_pluginDir ? m_pluginDir() : QString();
    const QString catalog = dir.isEmpty() ? QString() : dir + "/LauncherStyles.js";
    const QString stamp = catalog + "|" + QFileInfo(catalog).lastModified().toString(Qt::ISODateWithMs);
    if (catalog.isEmpty() || !QFileInfo::exists(catalog)) {
        m_catalogStamp.clear();
        if (!m_layouts.isEmpty()) {
            m_layouts.clear();
            m_schemes.clear();
            m_transitions.clear();
            emit catalogChanged();
        }
    } else if (stamp != m_catalogStamp) {
        QString problem;
        if (loadCatalog(catalog, &problem))
            m_catalogStamp = stamp;
        else
            setError("Couldn't read the launcher's styles: " + problem);
    }
    watch();
}

QString Launcher::layout() const { return m_style.value("layout").toString("classic"); }
QString Launcher::scheme() const { return m_style.value("scheme").toString("omarchy"); }
QString Launcher::transition() const { return m_style.value("transition").toString("auto"); }

double Launcher::speed() const {
    const double value = m_style.value("speed").toDouble(1.0);
    return value > 0 ? value : 1.0;
}

bool Launcher::has(const QVariantList &list, const QString &id) const {
    for (const auto &entry : list)
        if (entry.toMap().value("id").toString() == id)
            return true;
    return false;
}

void Launcher::set(const QString &key, const QJsonValue &value) { set(QJsonObject{{key, value}}); }

void Launcher::set(const QJsonObject &changes) {
    QJsonObject style = m_style;
    for (auto it = changes.begin(); it != changes.end(); ++it)
        style.insert(it.key(), it.value());
    // In place, not through a rename: the launcher's FileView would lose the
    // file it watches.
    QDir().mkpath(QFileInfo(stylePath()).absolutePath());
    QFile file(stylePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        setError("Can't write " + stylePath() + ": " + file.errorString());
        return;
    }
    file.write(QJsonDocument(style).toJson(QJsonDocument::Indented));
    file.close();
    m_style = style;
    emit changed();
}

void Launcher::setLayout(const QString &id) {
    if (!has(m_layouts, id))
        return setError("The launcher has no layout called " + id);
    set("layout", id);
}

void Launcher::setScheme(const QString &id) {
    if (!has(m_schemes, id))
        return setError("The launcher has no colour scheme called " + id);
    set("scheme", id);
}

void Launcher::setTransition(const QString &id) {
    if (!has(m_transitions, id))
        return setError("This launcher has no transition called " + id + ". Update the Studio plugin.");
    set("transition", id);
}

void Launcher::setSpeed(double speed) { set("speed", qRound(qBound(0.25, speed, 3.0) * 100) / 100.0); }
void Launcher::setAnimateLayouts(bool on) { set("animateLayouts", on); }
void Launcher::setAnimateColors(bool on) { set("animateColors", on); }

void Launcher::randomize() {
    if (m_layouts.isEmpty() || m_schemes.isEmpty())
        return;
    auto *random = QRandomGenerator::global();
    set(QJsonObject{{"layout", m_layouts.at(random->bounded(m_layouts.size())).toMap().value("id").toString()},
                    {"scheme", m_schemes.at(random->bounded(m_schemes.size())).toMap().value("id").toString()}});
}

void Launcher::preview() {
    if (!m_runCommands)
        return;
    if (!Proc::detach("omarchy-menu", {"summon", "root"}))
        setError("Couldn't run omarchy-menu to open the launcher.");
}

void Launcher::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}

void Launcher::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}
