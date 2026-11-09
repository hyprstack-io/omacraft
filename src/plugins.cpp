#include "plugins.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>

#include "proc.h"

#include <csignal>
#include <sys/prctl.h>

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
    // inotifywait runs for as long as OmaCraft does; the kernel stops it when
    // OmaCraft goes, even when OmaCraft is killed and never runs ~Plugins.
    m_sourceWatch.setChildProcessModifier([] { prctl(PR_SET_PDEATHSIG, SIGTERM); });
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
         "effects", "~/Work/omacraft-burn/plugin", "\u{f0238}"},
        {"omacraft.agentdock", "Side Dock",
         "A dock on the screen edge that opens into a side panel with a tab per AI agent.",
         "dock", "~/Work/skll-agentdock/plugin", "\u{f06a9}"},
        {"omabar16", "omabar16",
         "The bar itself: segment shapes, themes and layouts, all edited on the Main Bar page.",
         "bar", "", "\u{f0570}"},
        {"omacraft.animations", "Window Transitions",
         "Hyprland animation presets, gradient borders and a speed control.",
         "animations", "", "\u{f0d6d}"},
        {"omacraft.omascii", "omascii",
         "FIGlet, TheDraw, system-font and image ASCII art for the Plymouth boot screen.",
         "ascii", "~/Projects/omascii", "\u{f0b9e}"},
        {"omacraft.studio", "Studio (Launcher)",
         "The Launcher launcher: rofi-style layouts, colour schemes and transitions, and the wallpapers "
         "behind the Wallpapers page. Its own uninstall.sh puts the stock menu back best.",
         "launcher", "~/Work/skll-studio/plugin", "\u{f003b}"},
        {"omacraft.folders", "Folder trays",
         "Folders on the bar that open into a row of the apps you pick, like the system tray's drawer.",
         "bar", "~/Work/omacraft/plugins/folders", "\u{f024b}"},
        {"omacraft.wallpicker", "Wallpaper picker",
         "Omarchy's background switcher with OmaCraft's wallpapers: theme backgrounds, Wallhaven search, the "
         "library and favourites as tabs of slanted previews, opened from a key without OmaCraft's window.",
         "wallpaper", "~/Work/omacraft/plugins/wallpicker", "\u{f08b9}"},
        {"omacraft.hyprvyzr", "HyprVYZR",
         "Kasm Workspaces on the desktop: your remote and local Kasm servers' workspaces and Kasm's images run "
         "natively in Docker, in a carousel like the wallpaper picker's, each in a popup that minimises to the bar.",
         "hyprvyzr", "~/hyprstack.io/hyprvyze/plugin", "\u{f0379}"},
        {"omacraft.rofioma", "ROFIoma popups",
         "Draws ROFIoma's power menu, your menus and the keybind cheatsheet in the shell, with HyDE's wlogout "
         "hover: cards swell, round off and bounce under the pointer. Click a keybind to move it.",
         "rofioma", "~/Work/omacraft/plugins/rofioma", "\u{f1401}"},
        {kLockId, "Lock & Logon",
         "Omarchy's lock screen with its layout, colours, opacity, images and transitions set from OmaCraft. "
         "Authentication stays Omarchy's own. Switching it on swaps out the lock in use, which switching off puts back.",
         "lock", "~/Work/omacraft/plugins/lock", "\u{f033e}"},
        {"omacraft.hyprcraft", "Dotfile Generator",
         "Hyprland, Waybar, Rofi, SwayNC, GTK/Qt and terminal configurator. OmaCraft runs it on its own page.",
         "hyprcraft", "~/Projects/HyprCraft/omarchy-plugin", "\u{f0b0b}"},
    };
}

bool Plugins::shellInstalled() const { return !Proc::which("omarchy-shell").isEmpty(); }

QString Plugins::installPath(const QString &id) const { return m_pluginsDir + "/" + id; }
QString Plugins::stashPath(const QString &id) const { return m_stashDir + "/" + id; }

QString Plugins::packagedDir() {
    const QString dir = qEnvironmentVariable("OMACRAFT_PLUGINS_DIR");
    return dir.isEmpty() ? QString("/usr/share/omacraft/plugins") : dir;
}

// Where a plugin's code lives: the folder set for it, else the project it is
// worked on in, else the copy the package carries, so a machine without the
// projects checked out installs every plugin straight from the package.
QString Plugins::sourcePath(const QString &id) const {
    if (m_sources.contains(id))
        return Proc::expandHome(m_sources.value(id), m_home);
    for (const auto &definition : definitions()) {
        if (definition.id != id)
            continue;
        const QString project = definition.defaultSource.isEmpty()
                                    ? QString() : Proc::expandHome(definition.defaultSource, m_home);
        if (!project.isEmpty() && hasManifest(project))
            return project;
        const QString packaged = packagedDir() + "/" + id;
        if (hasManifest(packaged))
            return packaged;
        return project;
    }
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

bool Plugins::isBarIcon(const QString &id, const QJsonObject &entry) {
    if (id == "omacraft.folders")
        return false;
    // Studio's launcher role is the menu button (Omarchy's own is switched off
    // for it); its studio role is a popout OmaCraft's pages replace.
    if (id == "omacraft.studio")
        return entry.value("role").toString() == "studio";
    return true;
}

int Plugins::barIconsIn(const QJsonObject &shell, const QString &id) {
    int count = 0;
    const auto layout = shell.value("bar").toObject().value("layout").toObject();
    for (auto it = layout.begin(); it != layout.end(); ++it)
        for (const auto &entry : it.value().toArray())
            if (entry.toObject().value("id").toString() == id && isBarIcon(id, entry.toObject()))
                ++count;
    return count;
}

bool Plugins::isOnIn(const QJsonObject &shell, const QString &id) {
    for (const auto &value : shell.value("disabledPlugins").toArray())
        if (value.toString() == id)
            return false;
    for (const auto &value : shell.value("plugins").toArray())
        if (value.toObject().value("id").toString() == id)
            return true;
    const auto layout = shell.value("bar").toObject().value("layout").toObject();
    for (auto it = layout.begin(); it != layout.end(); ++it)
        for (const auto &entry : it.value().toArray())
            if (entry.toObject().value("id").toString() == id)
                return true;
    return false;
}

void Plugins::switchIn(QJsonObject &shell, const QString &id, bool on) {
    // Its icons come off the bar either way; anything else of it stays put.
    bool kept = false;
    auto bar = shell.value("bar").toObject();
    if (bar.contains("layout")) {
        auto layout = bar.value("layout").toObject();
        for (auto it = layout.begin(); it != layout.end(); ++it) {
            QJsonArray entries;
            for (const auto &entry : it.value().toArray()) {
                const auto object = entry.toObject();
                if (object.value("id").toString() != id) {
                    entries << entry;
                } else if (!isBarIcon(id, object)) {
                    entries << entry;
                    kept = true;
                }
            }
            it.value() = entries;
        }
        bar["layout"] = layout;
        shell["bar"] = bar;
    }

    QJsonArray plugins;
    bool listed = false;
    for (const auto &value : shell.value("plugins").toArray()) {
        if (value.toObject().value("id").toString() == id) {
            if (!on || listed)
                continue;
            listed = true;
        }
        plugins << value;
    }
    if (on && !listed && !kept)
        plugins << QJsonObject{{"id", id}};
    shell["plugins"] = plugins;

    QJsonArray disabled;
    for (const auto &value : shell.value("disabledPlugins").toArray())
        if (value.toString() != id)
            disabled << value;
    // What it keeps on the bar would load it, so off has to be said.
    if (!on && kept)
        disabled << id;
    if (disabled.isEmpty())
        shell.remove("disabledPlugins");
    else
        shell["disabledPlugins"] = disabled;
}

QString Plugins::editShell(const std::function<void(QJsonObject &)> &edit) {
    QDir().mkpath(QFileInfo(m_shellPath).absolutePath());
    QFile file(m_shellPath);
    if (!file.open(QIODevice::ReadWrite))
        return "Couldn't open " + m_shellPath + ": " + file.errorString();
    const QByteArray before = file.readAll();
    QJsonObject shell;
    if (!before.trimmed().isEmpty()) {
        QJsonParseError parseError;
        const QJsonDocument doc = QJsonDocument::fromJson(before, &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isObject())
            return "shell.json isn't valid JSON (" + parseError.errorString() + "), so it was left alone.";
        shell = doc.object();
    }
    edit(shell);
    // In place, not through a rename: the shell's file watcher stays on it.
    const QByteArray bytes = QJsonDocument(shell).toJson(QJsonDocument::Indented);
    if (bytes == before)
        return {};
    if (!file.seek(0) || file.write(bytes) != bytes.size() || !file.resize(bytes.size()))
        return "Couldn't save " + m_shellPath + ": " + file.errorString();
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
        const bool barInUse = isBar && barIn(m_shellConfig) == definition.id;
        // Read from shell.json rather than the shell's list, which counts a
        // bar widget as on only while it sits on the bar.
        const bool enabled = installed && (isBar ? barInUse : isOnIn(m_shellConfig, definition.id));
        const int icons = isBar ? 0 : barIconsIn(m_shellConfig, definition.id);

        QString state;
        if (!others.isEmpty())
            state = "Also installed as " + others.join(", ");
        else if (!installed)
            state = linked ? "Broken link" : "Not installed";
        else if (m_shellRunning && shellEntry.isEmpty())
            state = "Not found by the shell";
        else if (isBar)
            state = barInUse ? "Your bar" : "Not in use";
        else if (!enabled)
            state = "Off";
        else
            state = icons > 0 ? "On, with an icon on the bar" : "On";

        QVariantMap item;
        item["id"] = definition.id;
        item["name"] = definition.name;
        item["summary"] = definition.summary;
        item["page"] = definition.page;
        item["glyph"] = definition.glyph;
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
        item["barIcons"] = icons;
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
        steps << Step{{}, [=, this] { return editShell([&](QJsonObject &shell) { switchIn(shell, id, false); }); }};

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
    if (id == kLockId) {
        switchLock(on, true);
        return;
    }
    runSteps({Step{{}, [=, this] { return editShell([&](QJsonObject &shell) { switchIn(shell, id, on); }); }},
              Step{{"omarchy-shell", "shell", "reloadConfig"}, {}, true}},
             on ? QString("%1 is on, run from OmaCraft.").arg(name) : QString("%1 is off.").arg(name));
}

// The lock is the one plugin that must never be missing: with no lock service
// `omarchy system lock` does nothing, and idling leaves the screen open. So a
// switch is always a swap, and the shell is asked afterwards who answers.
QStringList Plugins::lockServices(const QJsonObject &shell) const {
    QStringList ids;
    for (const auto &value : shell.value("plugins").toArray()) {
        const QString id = value.toObject().value("id").toString();
        const auto manifest = readJsonObject(installPath(id) + "/manifest.json");
        if (manifest.value("omarchy").toObject().value("clonedFrom").toString() == "omarchy.lock")
            ids << id;
    }
    bool stockOff = false;
    for (const auto &value : shell.value("disabledPlugins").toArray())
        stockOff = stockOff || value.toString() == "omarchy.lock";
    if (!stockOff)
        ids << "omarchy.lock";
    return ids;
}

void Plugins::swapLockIn(QJsonObject &shell, const QString &id, bool on) {
    if (id != "omarchy.lock") {
        switchIn(shell, id, on);
        return;
    }
    // First-party: on unless it's listed as off.
    QJsonArray disabled;
    for (const auto &value : shell.value("disabledPlugins").toArray())
        if (value.toString() != id)
            disabled << value;
    if (!on)
        disabled << id;
    shell["disabledPlugins"] = disabled;
}

void Plugins::switchLock(bool on, bool checkAfter) {
    const QString previousPath = m_home + "/.config/omacraft/lock-previous";
    const auto edit = [=, this]() -> QString {
        return editShell([&](QJsonObject &shell) {
            if (on) {
                QStringList others = lockServices(shell);
                others.removeAll(kLockId);
                if (!others.isEmpty())
                    Proc::writeAtomically(previousPath, others.first().toUtf8());
                for (const auto &other : others)
                    swapLockIn(shell, other, false);
                swapLockIn(shell, kLockId, true);
            } else {
                QFile file(previousPath);
                QString previous = file.open(QIODevice::ReadOnly) ? QString::fromUtf8(file.readAll()).trimmed() : QString();
                // Back to what was in use, if it's still here; else Omarchy's own.
                if (previous.isEmpty() || (previous != "omarchy.lock" && !QFileInfo::exists(installPath(previous) + "/manifest.json")))
                    previous = "omarchy.lock";
                swapLockIn(shell, kLockId, false);
                swapLockIn(shell, previous, true);
            }
        });
    };
    QList<Step> steps{Step{{}, edit}, Step{{"omarchy-shell", "shell", "reloadConfig"}, {}, true}};
    if (checkAfter) {
        steps << Step{{"sleep", "3"}, {}, true};
        steps << Step{{}, [=, this]() -> QString { checkLock(on); return {}; }};
    }
    // The check says how it went; a rollback's own error must stand.
    runSteps(steps, {});
}

void Plugins::checkLock(bool on) {
    if (!m_runCommands)
        return;
    Proc::run(this, "omarchy-shell", {"lock", "status"}, [this, on](const Proc::Result &result) {
        const auto status = QJsonDocument::fromJson(result.out).object();
        const bool answering = status.value("passwordPam").toBool();
        if (on && !(answering && status.value("provider").toString() == kLockId)) {
            switchLock(false, false);
            setError("OmaCraft's lock didn't answer, so the previous lock was put back. Restart the shell and try again.");
        } else if (!answering) {
            setError("No lock screen is answering yet. Restart the shell (Ctrl R) before you rely on locking.");
        } else {
            setNotice(on ? "OmaCraft's lock screen is in use." : "The previous lock screen is back.");
        }
    }, 5000);
}

void Plugins::takeIconsOffBar() {
    QStringList ids;
    for (const auto &value : m_plugins) {
        const auto item = value.toMap();
        if (item.value("installed").toBool() && item.value("barIcons").toInt() > 0)
            ids << item.value("id").toString();
    }
    if (ids.isEmpty())
        return;
    dismissMessages();
    runSteps({Step{{}, [=, this] {
                  return editShell([&](QJsonObject &shell) {
                      for (const auto &id : ids)
                          switchIn(shell, id, true);
                  });
              }},
              Step{{"omarchy-shell", "shell", "reloadConfig"}, {}, true}},
             ids.size() == 1 ? QString("Moved 1 plugin off the bar. It runs from OmaCraft now.")
                             : QString("Moved %1 plugins off the bar. They run from OmaCraft now.").arg(ids.size()));
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
