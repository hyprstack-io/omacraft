#include "agentdock.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QStandardPaths>

#include "proc.h"

AgentDock::AgentDock(std::function<QString()> pluginDir, std::function<bool()> running, const QString &home,
                     QObject *parent)
    : QObject(parent),
      m_pluginDir(std::move(pluginDir)),
      m_running(std::move(running)),
      m_home(home.isEmpty() ? QDir::homePath() : home) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(150);
    connect(&m_debounce, &QTimer::timeout, this, &AgentDock::reload);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    reload();
}

QStringList AgentDock::settingKeys() {
    return {"position", "gap", "iconSize", "opacity", "reserveCollapsed", "reserveExpanded", "autoHide",
            "hiddenAgents", "cwd", "dock", "width", "magnify", "magnifyScale", "magnifyRange",
            "dockShape", "iconShape", "iconPlate", "dockColor", "accentColor", "dockBorder"};
}

QJsonObject AgentDock::defaultState() {
    // Matches the JsonAdapter defaults in the plugin's Dock.qml.
    return QJsonObject{
        {"width", 520}, {"activeTab", ""}, {"dock", QJsonArray()}, {"dockSeeded", false},
        {"position", "right"}, {"gap", 10}, {"iconSize", 28}, {"opacity", 0.94},
        {"reserveCollapsed", false}, {"reserveExpanded", true}, {"autoHide", false}, {"hiddenAgents", QJsonArray()}, {"cwd", ""},
        {"magnify", false}, {"magnifyScale", 1.7}, {"magnifyRange", 2}, {"dockShape", "rounded"},
        {"iconShape", "rounded"}, {"iconPlate", "hover"}, {"dockColor", "theme"}, {"accentColor", "theme"},
        {"dockBorder", "subtle"},
    };
}

QVariantList AgentDock::defaultAgents() {
    return {
        QVariantMap{{"id", "claude"}, {"name", "Claude Code"}, {"icon", "icons/claude.svg"},
                    {"command", "claude"}, {"install", ""}, {"cwd", ""}},
        QVariantMap{{"id", "gemini"}, {"name", "Gemini"}, {"icon", "icons/gemini.svg"},
                    {"command", "gemini"}, {"install", "omarchy pkg add gemini-cli"}, {"cwd", ""}},
    };
}

QJsonObject AgentDock::readState() const {
    QJsonObject state = defaultState();
    QFile file(statePath());
    if (file.open(QIODevice::ReadOnly)) {
        const auto saved = QJsonDocument::fromJson(file.readAll()).object();
        for (auto it = saved.begin(); it != saved.end(); ++it)
            state.insert(it.key(), it.value());
    }
    return state;
}

void AgentDock::watch() {
    const auto paths = m_watcher.files() + m_watcher.directories();
    if (!paths.isEmpty())
        m_watcher.removePaths(paths);
    // Both files are replaced rather than rewritten, so watch their folders.
    for (const auto &path : {statePath(), configPath(), QFileInfo(statePath()).absolutePath(),
                             QFileInfo(configPath()).absolutePath()})
        if (QFileInfo::exists(path))
            m_watcher.addPath(path);
}

void AgentDock::reload() {
    m_state = readState();
    QFile file(configPath());
    m_config = file.open(QIODevice::ReadOnly) ? QJsonDocument::fromJson(file.readAll()).object() : QJsonObject();
    watch();
    emit changed();
}

QVariantMap AgentDock::settings() const {
    QVariantMap map;
    for (const auto &key : settingKeys())
        if (key != "dock")
            map.insert(key, m_state.value(key).toVariant());
    return map;
}

QVariantMap AgentDock::desktopEntry(const QString &id) const {
    const QString file = QStandardPaths::locate(QStandardPaths::ApplicationsLocation, id + ".desktop");
    if (file.isEmpty())
        return {};
    // Read by hand: QSettings would split a name at its commas.
    QFile entry(file);
    if (!entry.open(QIODevice::ReadOnly))
        return {};
    QVariantMap map{{"id", id}, {"name", ""}, {"icon", ""}, {"hidden", false}};
    bool inMain = false;
    for (const auto &raw : QString::fromUtf8(entry.readAll()).split('\n')) {
        const QString line = raw.trimmed();
        if (line.startsWith('[')) {
            inMain = line == "[Desktop Entry]";
            continue;
        }
        if (!inMain)
            continue;
        const QString key = line.section('=', 0, 0).trimmed();
        const QString value = line.section('=', 1).trimmed();
        if (key == "Name")
            map["name"] = value;
        else if (key == "Icon")
            map["icon"] = value;
        else if (key == "NoDisplay" || key == "Hidden")
            map["hidden"] = map.value("hidden").toBool() || value == "true";
    }
    return map;
}

QVariantMap AgentDock::describe(const QVariantMap &item) const {
    QVariantMap described = item;
    const QString type = item.value("type").toString();
    if (type == "app") {
        const auto entry = desktopEntry(item.value("id").toString());
        described["label"] = entry.value("name").toString().isEmpty() ? item.value("id") : entry.value("name");
        described["icon"] = entry.value("icon");
        described["missing"] = entry.isEmpty();
    } else if (type == "cmd") {
        described["label"] = item.value("name");
    } else {
        described["label"] = type == "spacer" ? "Spacer" : "Divider";
    }
    return described;
}

QVariantList AgentDock::dock() const {
    QVariantList list;
    for (const auto &value : m_state.value("dock").toArray())
        list << describe(value.toObject().toVariantMap());
    return list;
}

bool AgentDock::customAgents() const {
    return m_config.value("agents").isArray() && !m_config.value("agents").toArray().isEmpty();
}

QVariantList AgentDock::agents() const {
    QVariantList list = customAgents() ? m_config.value("agents").toArray().toVariantList() : defaultAgents();
    const auto hidden = m_state.value("hiddenAgents").toArray().toVariantList();
    const QString dir = pluginDir();
    for (auto &value : list) {
        auto agent = value.toMap();
        agent["shown"] = !hidden.contains(agent.value("id"));
        const QString icon = agent.value("icon").toString();
        // Relative icons are inside the plugin, as the dock resolves them.
        agent["iconUrl"] = icon.isEmpty() ? QString()
                         : icon.startsWith('/') ? "file://" + icon
                         : dir.isEmpty() ? QString() : "file://" + dir + "/" + icon;
        agent["installed"] = !Proc::which(agent.value("command").toString().section(' ', 0, 0)).isEmpty();
        value = agent;
    }
    return list;
}

void AgentDock::set(const QString &key, const QVariant &value) {
    if (!settingKeys().contains(key))
        return;
    const QJsonValue json = QJsonValue::fromVariant(value);
    m_state.insert(key, json);
    emit changed();

    if (running()) {
        const QByteArray encoded = QJsonDocument(QJsonArray{json}).toJson(QJsonDocument::Compact);
        // Strip the array brackets: the dock parses the value itself.
        const QString payload = QString::fromUtf8(encoded.mid(1, encoded.size() - 2));
        Proc::run(this, "omarchy-shell", {"agentdock", "set", key, payload}, [this, key](const Proc::Result &result) {
            if (!result.ok() || result.out.trimmed() != "ok")
                setError(QString("The dock didn't take the %1 change (%2). It needs `set` in its IPC: restart "
                                 "the shell once after updating the plugin.")
                             .arg(key, result.message().isEmpty() ? "no answer" : result.message()));
        });
        return;
    }
    QString problem;
    if (!Proc::writeAtomically(statePath(), QJsonDocument(m_state).toJson(), &problem))
        setError(problem);
}

void AgentDock::setAgentShown(const QString &id, bool shown) {
    QVariantList hidden = m_state.value("hiddenAgents").toArray().toVariantList();
    hidden.removeAll(id);
    if (!shown)
        hidden << id;
    set("hiddenAgents", hidden);
}

void AgentDock::setDock(const QVariantList &items) {
    // Only the saved fields go back, not the labels added for the window.
    QVariantList clean;
    for (const auto &value : items) {
        auto item = value.toMap();
        item.remove("label");
        item.remove("icon");
        item.remove("missing");
        clean << item;
    }
    set("dock", clean);
}

void AgentDock::moveItem(int from, int to) {
    QVariantList items = m_state.value("dock").toArray().toVariantList();
    if (from < 0 || from >= items.size() || to < 0 || to >= items.size() || from == to)
        return;
    items.move(from, to);
    setDock(items);
}

void AgentDock::removeItem(int index) {
    QVariantList items = m_state.value("dock").toArray().toVariantList();
    if (index < 0 || index >= items.size())
        return;
    items.removeAt(index);
    setDock(items);
}

void AgentDock::addSpacer() {
    QVariantList items = m_state.value("dock").toArray().toVariantList();
    items << QVariantMap{{"type", "spacer"}};
    setDock(items);
}

void AgentDock::addDivider() {
    QVariantList items = m_state.value("dock").toArray().toVariantList();
    items << QVariantMap{{"type", "divider"}};
    setDock(items);
}

void AgentDock::addApp(const QString &desktopId) {
    QVariantList items = m_state.value("dock").toArray().toVariantList();
    for (const auto &value : items)
        if (value.toMap().value("type") == "app" && value.toMap().value("id") == desktopId)
            return;
    items << QVariantMap{{"type", "app"}, {"id", desktopId}};
    setDock(items);
}

void AgentDock::addCommand(const QString &name, const QString &glyph, const QString &command) {
    if (name.trimmed().isEmpty() || command.trimmed().isEmpty()) {
        setError("A custom command needs a name and a command.");
        return;
    }
    QVariantList items = m_state.value("dock").toArray().toVariantList();
    items << QVariantMap{{"type", "cmd"}, {"name", name.trimmed()}, {"glyph", glyph.trimmed()},
                         {"command", command.trimmed()}};
    setDock(items);
}

QVariantList AgentDock::apps(const QString &query) const {
    QVariantList found;
    QSet<QString> seen;
    const QString needle = query.trimmed().toLower();
    for (const auto &dir : QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation)) {
        QDirIterator it(dir, {"*.desktop"}, QDir::Files);
        while (it.hasNext()) {
            const QString path = it.next();
            const QString id = QFileInfo(path).completeBaseName();
            if (seen.contains(id))
                continue;
            seen.insert(id);
            const auto entry = desktopEntry(id);
            if (entry.value("hidden").toBool() || entry.value("name").toString().isEmpty())
                continue;
            if (!needle.isEmpty() && !entry.value("name").toString().toLower().contains(needle)
                && !id.toLower().contains(needle))
                continue;
            found << entry;
        }
    }
    std::sort(found.begin(), found.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value("name").toString().compare(b.toMap().value("name").toString(), Qt::CaseInsensitive) < 0;
    });
    return found.mid(0, 60);
}

void AgentDock::writeConfig(const QJsonObject &config) {
    QString problem;
    if (!Proc::writeAtomically(configPath(), QJsonDocument(config).toJson(), &problem)) {
        setError(problem);
        return;
    }
    m_config = config;
    emit changed();
}

void AgentDock::saveAgent(int index, const QVariantMap &agent) {
    const QString id = agent.value("id").toString().trimmed();
    if (id.isEmpty() || agent.value("command").toString().trimmed().isEmpty()) {
        setError("An agent needs an id and a command.");
        return;
    }
    QVariantList list = customAgents() ? m_config.value("agents").toArray().toVariantList() : defaultAgents();
    QVariantMap clean;
    for (const auto &key : {"id", "name", "icon", "command", "install", "cwd"}) {
        const QString value = agent.value(key).toString().trimmed();
        if (!value.isEmpty())
            clean.insert(key, value);
    }
    if (!clean.contains("name"))
        clean["name"] = id;
    if (index >= 0 && index < list.size())
        list[index] = clean;
    else
        list << clean;
    QJsonObject config = m_config;
    config["agents"] = QJsonArray::fromVariantList(list);
    writeConfig(config);
}

void AgentDock::removeAgent(int index) {
    QVariantList list = customAgents() ? m_config.value("agents").toArray().toVariantList() : defaultAgents();
    if (index < 0 || index >= list.size())
        return;
    if (list.size() == 1) {
        setError("The dock needs at least one agent.");
        return;
    }
    list.removeAt(index);
    QJsonObject config = m_config;
    config["agents"] = QJsonArray::fromVariantList(list);
    writeConfig(config);
}

void AgentDock::resetAgents() {
    QJsonObject config = m_config;
    config.remove("agents");
    writeConfig(config);
}

void AgentDock::setMonitor(const QString &name) {
    QJsonObject config = m_config;
    if (name.isEmpty())
        config.remove("monitor");
    else
        config["monitor"] = name;
    writeConfig(config);
    if (running())
        m_notice = "The dock moves to a new monitor after the shell restarts.";
    emit messageChanged();
}

void AgentDock::refreshMonitors() {
    Proc::run(this, "hyprctl", {"monitors", "-j"}, [this](const Proc::Result &result) {
        QStringList names;
        for (const auto &value : QJsonDocument::fromJson(result.out).array())
            names << value.toObject().value("name").toString();
        m_monitors = names;
        emit monitorsChanged();
    });
}

void AgentDock::toggleDock() {
    if (!running()) {
        setError("Side Dock isn't enabled. Enable it on the Plugin Suite page.");
        return;
    }
    Proc::run(this, "omarchy-shell", {"agentdock", "toggle"});
}

void AgentDock::openDockSettings() {
    if (!running()) {
        setError("Side Dock isn't enabled. Enable it on the Plugin Suite page.");
        return;
    }
    Proc::run(this, "omarchy-shell", {"agentdock", "expand"}, [this](const Proc::Result &) {
        Proc::run(this, "omarchy-shell", {"agentdock", "settings"});
    });
}

void AgentDock::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}

void AgentDock::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}
