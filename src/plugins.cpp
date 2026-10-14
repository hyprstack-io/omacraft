#include "plugins.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>

#include "proc.h"

namespace {

QJsonObject readJsonObject(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object();
}

bool hasManifest(const QString &dir) {
    return !dir.isEmpty() && QFileInfo::exists(dir + "/manifest.json");
}

} // namespace

Plugins::Plugins(const QString &home, bool runCommands, QObject *parent)
    : QObject(parent),
      m_home(home.isEmpty() ? QDir::homePath() : home),
      m_runCommands(runCommands) {
    m_pluginsDir = m_home + "/.config/omarchy/plugins";
    m_stashDir = m_home + "/.local/share/omacraft/stash";
    m_sourcesPath = m_home + "/.config/omacraft/sources.json";
    m_shellPath = m_home + "/.config/omarchy/shell.json";

    m_debounce.setSingleShot(true);
    m_debounce.setInterval(250);
    connect(&m_debounce, &QTimer::timeout, this, &Plugins::refresh);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(); });

    m_reloadDebounce.setSingleShot(true);
    m_reloadDebounce.setInterval(400);
    connect(&m_reloadDebounce, &QTimer::timeout, this, [this] {
        Proc::run(this, "omarchy-shell", {"shell", "rescanPlugins"});
    });
    connect(&m_sourceWatch, &QProcess::readyReadStandardOutput, this, [this] {
        m_sourceWatch.readAllStandardOutput();
        m_reloadDebounce.start();
    });

    loadSources();
    readShellConfig();
    rebuild();
    if (m_runCommands)
        refresh();
}

Plugins::~Plugins() {
    if (m_sourceWatch.state() != QProcess::NotRunning) {
        m_sourceWatch.kill();
        m_sourceWatch.waitForFinished(1000);
    }
}

QList<Plugins::Definition> Plugins::definitions() {
    return {
        {"omacraft.burn", "Burn My Windows",
         "Window open and close effects after the GNOME extension: fire, broken glass, the Doom melt, "
         "the Matrix, portals, an old TV switching off and more.",
         "effects", "~/Work/omacraft-burn/plugin"},
        {"omacraft.agentdock", "Agent Dock",
         "A dock on the screen edge that opens into a side panel with a tab per AI agent.",
         "dock", "~/Work/skll-agentdock/plugin"},
        {"omabar16", "omabar16",
         "The bar itself: segment shapes, themes, layouts, and the drag-and-drop customizer.",
         "bar", ""},
        {"omacraft.animations", "Animations",
         "Hyprland animation presets with a speed control, from the bar.",
         "animations", ""},
        {"omacraft.omascii", "omascii",
         "FIGlet, TheDraw, system-font and image ASCII art for the Plymouth boot screen.",
         "ascii", "~/Projects/omascii"},
        {"omacraft.studio", "Studio (OMArofi)",
         "The OMArofi launcher: rofi-style layouts, colour schemes and transitions. Studio also brings "
         "wallpapers and the bar customizer. Its own uninstall.sh puts the stock menu back best.",
         "launcher", "~/Work/skll-studio/plugin"},
        {"omacraft.hyprcraft", "HyprCraft",
         "Hyprland, Waybar, Rofi, SwayNC, GTK/Qt and terminal configurator, as a bar dropdown.",
         "hyprcraft", "~/Projects/HyprCraft/omarchy-plugin"},
    };
}

QString Plugins::installPath(const QString &id) const { return m_pluginsDir + "/" + id; }
QString Plugins::stashPath(const QString &id) const { return m_stashDir + "/" + id; }

QString Plugins::sourcePath(const QString &id) const {
    if (m_sources.contains(id))
        return Proc::expandHome(m_sources.value(id), m_home);
    for (const auto &definition : definitions())
        if (definition.id == id && !definition.defaultSource.isEmpty())
            return Proc::expandHome(definition.defaultSource, m_home);
    return {};
}

QString Plugins::pluginDir(const QString &id) const {
    for (const auto &dir : {installPath(id), stashPath(id), sourcePath(id)})
        if (hasManifest(dir))
            return QFileInfo(dir).canonicalFilePath();
    return {};
}

void Plugins::loadSources() {
    m_sources.clear();
    const auto object = readJsonObject(m_sourcesPath);
    for (auto it = object.begin(); it != object.end(); ++it)
        if (it.value().isString())
            m_sources.insert(it.key(), it.value().toString());
}

void Plugins::readShellConfig() {
    m_shellConfig = readJsonObject(m_shellPath);
}

QString Plugins::sectionIn(const QJsonObject &shell, const QString &id) {
    const auto layout = shell.value("bar").toObject().value("layout").toObject();
    for (const auto &section : {"left", "center", "right"}) {
        for (const auto &entry : layout.value(section).toArray())
            if (entry.toObject().value("id").toString() == id)
                return section;
    }
    return {};
}

QString Plugins::barIn(const QJsonObject &shell) {
    const auto id = shell.value("bar").toObject().value("id").toString();
    return id.isEmpty() ? "omarchy.bar" : id;
}

QHash<QString, QStringList> Plugins::duplicatesIn(const QString &pluginsDir) {
    QHash<QString, QStringList> duplicates;
    const auto names = QDir(pluginsDir).entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const auto &name : names) {
        // Hidden folders are backups and clone staging; the shell skips them.
        if (name.startsWith('.'))
            continue;
        const auto id = readJsonObject(pluginsDir + "/" + name + "/manifest.json").value("id").toString();
        if (!id.isEmpty() && id != name)
            duplicates[id] << name;
    }
    return duplicates;
}

void Plugins::rebuild() {
    QVariantList list;
    QStringList linkedSources;
    const auto duplicates = duplicatesIn(m_pluginsDir);
    for (const auto &definition : definitions()) {
        const QString path = installPath(definition.id);
        const QFileInfo info(path);
        const bool installed = hasManifest(path);
        const bool linked = info.isSymLink();
        const bool stashed = hasManifest(stashPath(definition.id));
        const QString source = sourcePath(definition.id);
        const QString dir = pluginDir(definition.id);
        const auto manifest = readJsonObject(dir + "/manifest.json");
        const QStringList others = duplicates.value(definition.id);
        if (installed && linked)
            linkedSources << QFileInfo(path).canonicalFilePath();

        QJsonObject shellEntry;
        for (const auto &value : m_shellList)
            if (value.toObject().value("id").toString() == definition.id)
                shellEntry = value.toObject();

        QStringList kinds;
        const auto kindsJson = shellEntry.isEmpty() ? manifest.value("kinds").toArray()
                                                    : shellEntry.value("kinds").toArray();
        for (const auto &kind : kindsJson)
            kinds << kind.toString();
        const bool isBar = kinds.contains("bar");
        const bool barWidget = kinds.contains("bar-widget");
        const bool barInUse = isBar && barIn(m_shellConfig) == definition.id;
        const bool enabled = isBar ? barInUse : shellEntry.value("enabled").toBool();

        QString state;
        if (!others.isEmpty())
            state = "Also installed as " + others.join(", ");
        else if (!installed)
            state = linked ? "Broken link" : "Not installed";
        else if (!m_shellRunning)
            state = "Installed";
        else if (shellEntry.isEmpty())
            state = "Not found by the shell";
        else if (isBar)
            state = barInUse ? "Your bar" : "Installed, not in use";
        else
            state = enabled ? "Enabled" : "Disabled";

        QVariantMap item;
        item["id"] = definition.id;
        item["name"] = definition.name;
        item["summary"] = definition.summary;
        item["page"] = definition.page;
        item["version"] = manifest.value("version").toString();
        item["kinds"] = kinds;
        item["installed"] = installed;
        item["linked"] = linked;
        item["linkTarget"] = linked ? info.symLinkTarget() : QString();
        item["stashed"] = stashed;
        item["source"] = source;
        item["sourceExists"] = hasManifest(source);
        item["canInstall"] = !installed && (stashed || hasManifest(source));
        item["known"] = !shellEntry.isEmpty();
        item["enabled"] = enabled;
        item["isBar"] = isBar;
        item["barWidget"] = barWidget;
        item["section"] = barWidget ? sectionIn(m_shellConfig, definition.id) : QString();
        item["defaultSection"] = manifest.value("barWidget").toObject().value("defaultSection").toString();
        item["dir"] = dir;
        item["duplicates"] = others;
        item["state"] = state;
        list << item;
    }
    m_plugins = list;
    if (m_runCommands)
        watchSources(linkedSources);
    emit changed();
}

void Plugins::watchSources(const QStringList &dirs) {
    if (dirs == m_watchedSources && (dirs.isEmpty() || m_sourceWatch.state() != QProcess::NotRunning))
        return;
    if (m_sourceWatch.state() != QProcess::NotRunning) {
        m_sourceWatch.kill();
        m_sourceWatch.waitForFinished(1000);
    }
    m_watchedSources = dirs;
    if (dirs.isEmpty() || Proc::which("inotifywait").isEmpty())
        return;
    // The same events the shell watches its own plugins folder for.
    m_sourceWatch.start("inotifywait",
                        QStringList{"-m", "-r", "-q", "-e", "close_write,create,delete,move",
                                    "--exclude", "/\\.git(/|$)", "--format", "%w%f"} + dirs);
}

QVariantMap Plugins::plugin(const QString &id) const {
    for (const auto &value : m_plugins)
        if (value.toMap().value("id").toString() == id)
            return value.toMap();
    return {};
}

bool Plugins::isInstalled(const QString &id) const { return plugin(id).value("installed").toBool(); }
bool Plugins::isEnabled(const QString &id) const { return plugin(id).value("enabled").toBool(); }

void Plugins::watch() {
    const auto paths = m_watcher.files() + m_watcher.directories();
    if (!paths.isEmpty())
        m_watcher.removePaths(paths);
    // shell.json is replaced on every save, so watch its folder as well as the
    // file, and re-arm after each change.
    for (const auto &path : {m_pluginsDir, m_shellPath, QFileInfo(m_shellPath).absolutePath()})
        if (QFileInfo::exists(path))
            m_watcher.addPath(path);
}

void Plugins::refresh() {
    loadSources();
    readShellConfig();
    watch();
    if (!m_runCommands) {
        rebuild();
        return;
    }
    Proc::run(this, "omarchy-plugin-list", {"--json"}, [this](const Proc::Result &result) {
        const auto document = QJsonDocument::fromJson(result.out);
        m_shellRunning = result.ok() && document.isArray();
        m_shellList = m_shellRunning ? document.array() : QJsonArray();
        rebuild();
    }, 15000);
}

void Plugins::runSteps(QList<Step> steps, const QString &doneNotice) {
    if (steps.isEmpty()) {
        setBusy(false);
        setNotice(doneNotice);
        refresh();
        return;
    }
    setBusy(true);
    const Step step = steps.takeFirst();
    if (step.action) {
        const QString problem = step.action();
        if (!problem.isEmpty() && !step.mayFail) {
            setBusy(false);
            setError(problem);
            refresh();
            return;
        }
        runSteps(steps, doneNotice);
        return;
    }
    if (!m_runCommands) {
        runSteps(steps, doneNotice);
        return;
    }
    Proc::run(this, step.command.first(), step.command.mid(1),
              [this, steps, doneNotice, step](const Proc::Result &result) {
        if (!result.ok() && !step.mayFail) {
            setBusy(false);
            setError(QString("%1 failed: %2").arg(step.command.join(' '), result.message()));
            refresh();
            return;
        }
        runSteps(steps, doneNotice);
    });
}

void Plugins::install(const QString &id) {
    const auto item = plugin(id);
    if (item.isEmpty() || item.value("installed").toBool())
        return;
    dismissMessages();

    const QString target = installPath(id);
    const QString stash = stashPath(id);
    const QString source = sourcePath(id);

    QList<Step> steps;
    steps << Step{{}, [=, this]() -> QString {
        QDir().mkpath(m_pluginsDir);
        const QFileInfo existing(target);
        // A link whose folder is gone can be replaced; anything else in the
        // way is the user's, and stays.
        if (existing.isSymLink() && !existing.exists())
            QFile::remove(target);
        else if (existing.exists() || existing.isSymLink())
            return QString("%1 is in the way. Move it, then install again.").arg(target);

        if (hasManifest(stash)) {
            if (!QDir().rename(stash, target))
                return QString("Couldn't move %1 back into %2.").arg(stash, m_pluginsDir);
            return {};
        }
        if (!hasManifest(source))
            return QString("There's no plugin at %1. Set where its code lives, then install again.").arg(source);
        if (!QFile::link(source, target))
            return QString("Couldn't link %1 to %2.").arg(target, source);
        return {};
    }};
    steps << Step{{"omarchy-shell", "shell", "rescanPlugins"}, {}, true};
    runSteps(steps, QString("Installed %1. Enable it to start using it.").arg(item.value("name").toString()));
}

void Plugins::remove(const QString &id) {
    const auto item = plugin(id);
    if (item.isEmpty() || (!QFileInfo(installPath(id)).isSymLink() && !QFileInfo::exists(installPath(id))))
        return;
    dismissMessages();

    QList<Step> steps;
    if (item.value("isBar").toBool() && item.value("enabled").toBool())
        steps << Step{{"omarchy-bar", "reset"}};
    else if (item.value("enabled").toBool())
        steps << Step{{"omarchy-plugin-disable", id}};

    const QString target = installPath(id);
    const QString stash = stashPath(id);
    steps << Step{{}, [=, this]() -> QString {
        const QFileInfo info(target);
        if (info.isSymLink()) {
            if (!QFile::remove(target))
                return QString("Couldn't remove the link %1.").arg(target);
            return {};
        }
        // A real folder is the only copy of the plugin, so set it aside
        // rather than delete it. An older copy already set aside keeps a
        // dated name.
        QDir().mkpath(m_stashDir);
        if (QFileInfo::exists(stash))
            QDir().rename(stash, stash + ".before-" + QString::number(QDateTime::currentSecsSinceEpoch()));
        if (!QDir().rename(target, stash))
            return QString("Couldn't move %1 to %2.").arg(target, stash);
        return {};
    }};
    steps << Step{{"omarchy-shell", "shell", "rescanPlugins"}, {}, true};
    runSteps(steps, QString("Removed %1 from the shell. Its files are kept, so Install brings it back.")
                        .arg(item.value("name").toString()));
}

void Plugins::setEnabled(const QString &id, bool on) {
    const auto item = plugin(id);
    if (item.isEmpty() || !item.value("installed").toBool())
        return;
    dismissMessages();
    const QString name = item.value("name").toString();

    if (item.value("isBar").toBool()) {
        if (on)
            runSteps({Step{{"omarchy-bar", "use", id}}}, QString("%1 is now your bar.").arg(name));
        else
            runSteps({Step{{"omarchy-bar", "reset"}}}, "Back to the built-in Omarchy bar.");
        return;
    }
    if (on)
        runSteps({Step{{"omarchy-plugin-enable", id}}}, QString("Enabled %1.").arg(name));
    else
        runSteps({Step{{"omarchy-plugin-disable", id}}}, QString("Disabled %1.").arg(name));
}

void Plugins::place(const QString &id, const QString &section) {
    const auto item = plugin(id);
    if (item.isEmpty() || !item.value("barWidget").toBool())
        return;
    dismissMessages();
    const QString name = item.value("name").toString();
    QList<Step> steps;
    if (!item.value("enabled").toBool())
        steps << Step{{"omarchy-plugin-enable", id, "--section", section}};
    else if (item.value("section").toString().isEmpty())
        steps << Step{{"omarchy-bar", "put", id, "--section", section}};
    else
        steps << Step{{"omarchy-bar", "move", id, "--section", section}};
    runSteps(steps, QString("Moved %1 to the %2 of the bar.").arg(name, section == "center" ? "centre" : section));
}

void Plugins::setSource(const QString &id, const QString &path) {
    auto object = readJsonObject(m_sourcesPath);
    const QString trimmed = path.trimmed();
    if (trimmed.isEmpty())
        object.remove(id);
    else
        object.insert(id, trimmed);
    QString problem;
    if (!Proc::writeAtomically(m_sourcesPath, QJsonDocument(object).toJson(), &problem))
        setError(problem);
    refresh();
}

void Plugins::restartShell() {
    dismissMessages();
    runSteps({Step{{"omarchy-restart-shell"}}},
             "Restarted the shell, so plugins load their latest code.");
}

void Plugins::dismissMessages() {
    setError({});
    setNotice({});
}

void Plugins::setBusy(bool busy) {
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void Plugins::setError(const QString &message) {
    m_error = message;
    if (!message.isEmpty())
        m_notice.clear();
    emit messageChanged();
}

void Plugins::setNotice(const QString &message) {
    m_notice = message;
    if (!message.isEmpty())
        m_error.clear();
    emit messageChanged();
}
