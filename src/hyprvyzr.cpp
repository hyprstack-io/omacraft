#include "hyprvyzr.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QRegularExpression>

#include <unistd.h>

#include "agentdock.h"
#include "proc.h"
#include "wallpicker.h"

namespace {

constexpr const char *kRequire = "hypr.omacraft_hyprvyzr";
const QStringList kTabs{"all", "remote", "local", "native", "running"};

QJsonObject readObject(const QString &path) {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? QJsonDocument::fromJson(file.readAll()).object() : QJsonObject();
}

// The last line of a failed command, without its "hyprvyzr: " prefix.
QString lastLine(const QString &text, const QString &fallback) {
    const QStringList lines = text.trimmed().split('\n', Qt::SkipEmptyParts);
    QString line = lines.isEmpty() ? fallback : lines.last();
    line.remove(QRegularExpression("^hyprvyzr:\\s*"));
    return line;
}

} // namespace

Hyprvyzr::Hyprvyzr(std::function<QString()> pluginDir, AgentDock *dock, const QString &home, bool runCommands,
                   QObject *parent)
    : QObject(parent), m_pluginDir(std::move(pluginDir)), m_dock(dock),
      m_home(home.isEmpty() ? QDir::homePath() : home), m_runCommands(runCommands) {
    loadSettings();
    readShell();
    m_keys = keysIn([this] {
        QFile file(keysPath());
        return file.open(QIODevice::ReadOnly) ? QString::fromUtf8(file.readAll()) : QString();
    }());
    m_config = readObject(configPath());
    // Sessions come and go from their own windows; the page polls while it's
    // looking at them (the page starts and stops this).
    m_sessionPoll.setInterval(3000);
    connect(&m_sessionPoll, &QTimer::timeout, this, &Hyprvyzr::refreshSessions);
    if (m_dock)
        connect(m_dock, &AgentDock::changed, this, &Hyprvyzr::changed);
}

bool Hyprvyzr::available() const { return QFileInfo(cli()).isFile(); }

QString Hyprvyzr::cli() const {
    const QString dir = m_pluginDir ? m_pluginDir() : QString();
    return dir.isEmpty() ? QString() : dir + "/bin/hyprvyzr";
}

QString Hyprvyzr::cardBorderUrl() const {
    const QString dir = m_pluginDir ? m_pluginDir() : QString();
    const QString path = dir + "/CardBorder.qml";
    return !dir.isEmpty() && QFileInfo::exists(path) ? QUrl::fromLocalFile(path).toString() : QString();
}

QVariantList Hyprvyzr::keyTabs() {
    return {
        QVariantMap{{"tab", "all"}, {"name", "Carousel"}, {"hint", "Every workspace"}, {"suggested", "SUPER + ALT + V"}},
        QVariantMap{{"tab", "remote"}, {"name", "Remote"}, {"hint", "Your Kasm servers elsewhere"}, {"suggested", "SUPER + SHIFT + ALT + V"}},
        QVariantMap{{"tab", "local"}, {"name", "Local"}, {"hint", "The Kasm server on this machine"}, {"suggested", ""}},
        QVariantMap{{"tab", "native"}, {"name", "Native"}, {"hint", "Kasm images in Docker"}, {"suggested", ""}},
        QVariantMap{{"tab", "running"}, {"name", "Running"}, {"hint", "Bring back a minimised session"}, {"suggested", "SUPER + CTRL + ALT + V"}},
    };
}

// ------------------------------------------------------------------ the command

void Hyprvyzr::runCli(const QStringList &args, Done done, const QByteArray &input, int timeoutMs,
                      const QString &busyText) {
    if (!available()) {
        if (done)
            done(-1, {}, "The HyprVYZR plugin isn't installed.");
        return;
    }
    if (!m_runCommands && !qEnvironmentVariableIsSet("OMACRAFT_HYPRVYZR_TEST_RUN")) {
        if (done)
            done(-1, {}, "Not running commands.");
        return;
    }
    if (!busyText.isEmpty())
        setBusy(busyText);
    auto *process = new QProcess(this);
    auto *timer = new QTimer(process);
    timer->setSingleShot(true);
    connect(timer, &QTimer::timeout, process, [process] { process->kill(); });
    connect(process, &QProcess::finished, this, [this, process, done, busyText](int code, QProcess::ExitStatus status) {
        if (!busyText.isEmpty())
            setBusy({});
        const QByteArray out = process->readAllStandardOutput();
        const QString err = QString::fromUtf8(process->readAllStandardError());
        process->deleteLater();
        if (done)
            done(status == QProcess::NormalExit ? code : -1, out, err);
    });
    connect(process, &QProcess::errorOccurred, this, [this, process, done, busyText](QProcess::ProcessError e) {
        if (e != QProcess::FailedToStart)
            return;
        if (!busyText.isEmpty())
            setBusy({});
        process->deleteLater();
        if (done)
            done(-1, {}, "python3 couldn't be started.");
    });
    // -I: the command never picks up modules from wherever it's run.
    process->start("python3", QStringList{"-I", cli(), "--json"} + args);
    // Credentials travel on stdin only.
    if (!input.isEmpty())
        process->write(input);
    process->closeWriteChannel();
    timer->start(timeoutMs);
}

void Hyprvyzr::inTerminal(const QStringList &args, const QString &title) {
    if (!available()) {
        setError("The HyprVYZR plugin isn't installed.");
        return;
    }
    QStringList quoted{Proc::shellQuote("python3"), "-I", Proc::shellQuote(cli())};
    for (const auto &arg : args)
        quoted << Proc::shellQuote(arg);
    const QString command = quoted.join(' ') + "; status=$?; echo; [ $status = 0 ] || read -r -p 'Press Enter to close.' _";
    if (!m_runCommands || !Proc::inTerminal(command))
        setError("Couldn't open a terminal for " + title + ".");
    else
        setNotice(title + " is running in a terminal.");
}

void Hyprvyzr::refresh() {
    m_config = readObject(configPath());
    readShell();
    runCli({"servers"}, [this](int code, const QByteArray &out, const QString &) {
        if (code == 0) {
            m_servers = QJsonDocument::fromJson(out).array().toVariantList();
            emit changed();
        }
    });
    runCli({"local", "status"}, [this](int code, const QByteArray &out, const QString &) {
        if (code == 0) {
            m_local = QJsonDocument::fromJson(out).object().toVariantMap();
            emit changed();
        }
    });
    refreshWorkspaces(false);
    refreshSessions();
    emit changed();
}

void Hyprvyzr::refreshWorkspaces(bool force) {
    runCli(force ? QStringList{"workspaces", "--refresh"} : QStringList{"workspaces"},
           [this](int code, const QByteArray &out, const QString &err) {
               if (code != 0) {
                   m_workspaceErrors = {lastLine(err, "Couldn't list the workspaces.")};
               } else {
                   const QJsonObject data = QJsonDocument::fromJson(out).object();
                   m_workspaces = data.value("workspaces").toArray().toVariantList();
                   m_workspaceErrors.clear();
                   for (const auto &e : data.value("errors").toArray())
                       m_workspaceErrors << e.toString();
               }
               emit changed();
           },
           {}, 90000, force ? "Asking your servers for their workspaces…" : QString());
}

void Hyprvyzr::refreshSessions() {
    runCli({"sessions"}, [this](int code, const QByteArray &out, const QString &) {
        if (code != 0)
            return;
        const QVariantList sessions = QJsonDocument::fromJson(out).array().toVariantList();
        if (sessions != m_sessions) {
            m_sessions = sessions;
            emit changed();
        }
    });
    if (!m_sessionPoll.isActive() && m_runCommands)
        m_sessionPoll.start();
}

// ------------------------------------------------------------------ servers

void Hyprvyzr::addServer(const QVariantMap &fields) {
    const QString name = fields.value("name").toString().trimmed();
    QString url = fields.value("url").toString().trimmed();
    while (url.endsWith('/'))
        url.chop(1);
    if (!url.isEmpty() && !url.contains("://"))
        url.prepend("https://");
    const QString user = fields.value("user").toString().trimmed();
    const QString key = fields.value("apiKey").toString().trimmed();
    const QString secret = fields.value("apiSecret").toString().trimmed();
    if (name.isEmpty() || url.isEmpty() || user.isEmpty() || key.isEmpty() || secret.isEmpty()) {
        setError("A server needs a name, its address, the Kasm user to start sessions as, and the API key and secret.");
        return;
    }
    QStringList args{"server", "add", "--name", name, "--url", url, "--user", user, "--kind",
                     fields.value("kind").toString() == "local" ? "local" : "remote"};
    if (fields.value("insecure").toBool())
        args << "--insecure";
    const QString ssh = fields.value("ssh").toString().trimmed();
    if (!ssh.isEmpty())
        args << "--ssh" << ssh;
    const QByteArray input = QJsonDocument(QJsonObject{{"api_key", key}, {"api_key_secret", secret}}).toJson(QJsonDocument::Compact);
    runCli(args, [this, name](int code, const QByteArray &out, const QString &err) {
        if (code != 0) {
            setError(lastLine(err, "Couldn't add " + name + "."));
            return;
        }
        const QJsonObject result = QJsonDocument::fromJson(out).object();
        const QString id = result.value("id").toString();
        setNotice(QString("Added %1. Its API key is kept in the %2.")
                      .arg(name, result.value("secretStore").toString() == "keyring" ? "keyring" : "private file ~/.local/share/hyprvyzr/secrets.json"));
        emit serverAdded(id);
        refresh();
        testServer(id);
    }, input, 30000, "Saving " + name + "…");
}

void Hyprvyzr::removeServer(const QString &id) {
    runCli({"server", "remove", id}, [this, id](int code, const QByteArray &, const QString &err) {
        if (code != 0)
            setError(lastLine(err, "Couldn't remove " + id + "."));
        else
            setNotice("Removed " + id + " and its key.");
        refresh();
    });
}

void Hyprvyzr::testServer(const QString &id) {
    runCli({"server", "test", id}, [this, id](int code, const QByteArray &out, const QString &err) {
        if (code != 0) {
            setError(lastLine(err, "Couldn't reach " + id + "."));
            return;
        }
        const QJsonObject r = QJsonDocument::fromJson(out).object();
        setNotice(QString("%1 answered: %2 workspaces, and the user is there.").arg(id).arg(r.value("images").toInt()));
        refreshWorkspaces(true);
    }, {}, 30000, "Checking " + id + "…");
}

void Hyprvyzr::openDashboard(const QString &id) {
    runCli({"dashboard", id}, [this](int code, const QByteArray &, const QString &err) {
        if (code != 0)
            setError(lastLine(err, "Couldn't open the dashboard."));
    });
}

// ------------------------------------------------------------------ sessions

void Hyprvyzr::launch(const QString &key) {
    QString name = key;
    for (const auto &w : m_workspaces)
        if (w.toMap().value("key") == key)
            name = w.toMap().value("name").toString();
    runCli({"launch", key}, [this, name](int code, const QByteArray &, const QString &err) {
        if (code != 0)
            setError(lastLine(err, "Couldn't start " + name + "."));
        else
            setNotice(name + " is open in its own window.");
        refreshSessions();
    }, {}, 300000, "Starting " + name + "…");
}

void Hyprvyzr::sessionAction(const QString &action, const QString &id) {
    static const QStringList actions{"show", "hide", "toggle", "float", "tile", "end"};
    if (!actions.contains(action))
        return;
    runCli({action, id}, [this](int code, const QByteArray &, const QString &err) {
        if (code != 0)
            setError(lastLine(err, "That didn't work."));
        refreshSessions();
    });
}

void Hyprvyzr::openCarousel(const QString &tab) {
    if (!m_runCommands)
        return;
    const QString payload = QString::fromUtf8(
        QJsonDocument(QJsonObject{{"tab", kTabs.contains(tab) ? tab : "all"}}).toJson(QJsonDocument::Compact));
    Proc::run(this, "omarchy-shell", {"shell", "summon", kPluginId, payload}, [this](const Proc::Result &result) {
        if (!result.ok() || result.out.trimmed() == "false")
            setError("The carousel didn't open. Install and enable HyprVYZR above, then try again.");
    });
}

// ------------------------------------------------------------------ keys

QString Hyprvyzr::carouselCommand(const QString &tab) {
    return QString("omarchy-shell shell toggle %1 '{\"tab\":\"%2\"}'").arg(kPluginId, kTabs.contains(tab) ? tab : "all");
}

QString Hyprvyzr::keysFile(const QVariantMap &keys) {
    QString out = "-- Generated by OmaCraft (HyprVYZR › Keys). Edit the keys there.\n"
                  "-- Each opens the omacraft.hyprvyzr carousel on one tab: every Kasm workspace,\n"
                  "-- the remote servers, the local one, native Docker images, or what's running.\n";
    for (const QString &tab : kTabs) {
        const QString key = keys.value(tab).toString();
        if (key.isEmpty())
            continue;
        // normalizeKey lets no quote or backslash through, so it quotes as is.
        const QString quoted = '"' + key + '"';
        QString command = carouselCommand(tab);
        command.replace("\"", "\\\"");
        out += QString("hl.unbind(%1)\no.bind(%1, \"HyprVYZR: %2\", \"%3\")\n").arg(quoted, tab, command);
    }
    return out;
}

QVariantMap Hyprvyzr::keysIn(const QString &file) {
    static const QRegularExpression bind("^o\\.bind\\(\"([^\"]+)\", \"HyprVYZR: (\\w+)\"", QRegularExpression::MultilineOption);
    QVariantMap keys;
    auto it = bind.globalMatch(file);
    while (it.hasNext()) {
        const auto m = it.next();
        if (kTabs.contains(m.captured(2)))
            keys.insert(m.captured(2), m.captured(1));
    }
    return keys;
}

bool Hyprvyzr::bindKey(const QString &tab, const QString &key) {
    if (!kTabs.contains(tab))
        return false;
    QVariantMap keys = m_keys;
    if (key.trimmed().isEmpty()) {
        keys.remove(tab);
    } else {
        const QString normalized = WallPicker::normalizeKey(key);
        if (normalized.isEmpty()) {
            setError(QString("\"%1\" isn't a key Hyprland can bind. Write it like SUPER + ALT + V.").arg(key.trimmed()));
            return false;
        }
        for (auto it = keys.begin(); it != keys.end(); ++it)
            if (it.key() != tab && it.value().toString() == normalized) {
                setError(normalized + " already opens the " + it.key() + " tab.");
                return false;
            }
        keys.insert(tab, normalized);
    }
    QString problem;
    if (!Proc::writeAtomically(keysPath(), keysFile(keys).toUtf8(), &problem)) {
        setError(problem);
        return false;
    }
    // hyprland.lua loads the file once; the line goes in a single time.
    const QString main = m_home + "/.config/hypr/hyprland.lua";
    QFile file(main);
    if (file.open(QIODevice::ReadOnly)) {
        const QByteArray contents = file.readAll();
        file.close();
        if (!contents.contains(kRequire)) {
            QFile::copy(main, QString("%1.before-hyprvyzr-%2").arg(main).arg(QDateTime::currentSecsSinceEpoch()));
            if (!file.open(QIODevice::Append)) {
                setError("Can't add HyprVYZR's keys to " + main + ": " + file.errorString());
                return false;
            }
            file.write(QString("\n-- HyprVYZR's carousel keys, set in OmaCraft.\npcall(require, \"%1\")\n").arg(kRequire).toUtf8());
        }
    }
    if (m_runCommands)
        Proc::detach("hyprctl", {"reload"});
    m_keys = keys;
    m_error.clear();
    emit messageChanged();
    emit changed();
    return true;
}

// ------------------------------------------------------------------ placement

void Hyprvyzr::readShell() { m_shell = readObject(shellPath()); }

bool Hyprvyzr::onBar() const {
    const QJsonObject layout = m_shell.value("bar").toObject().value("layout").toObject();
    for (const auto &section : {"left", "center", "right"})
        for (const auto &entry : layout.value(section).toArray())
            if (entry.toObject().value("id").toString() == kPluginId)
                return true;
    return false;
}

bool Hyprvyzr::editShell(const std::function<QString(QJsonObject &)> &edit) {
    QFile file(shellPath());
    if (!file.open(QIODevice::ReadWrite)) {
        setError("Couldn't open " + shellPath() + ": " + file.errorString());
        return false;
    }
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        setError("shell.json isn't valid JSON (" + parseError.errorString() + "), so it was left alone.");
        return false;
    }
    QJsonObject shell = doc.object();
    if (const QString problem = edit(shell); !problem.isEmpty()) {
        setError(problem);
        return false;
    }
    // A copy first, then in place, not through a rename: the shell's file
    // watcher stays on it.
    QFile::remove(shellPath() + ".hyprvyzr-bak");
    QFile::copy(shellPath(), shellPath() + ".hyprvyzr-bak");
    const QByteArray bytes = QJsonDocument(shell).toJson(QJsonDocument::Indented);
    if (!file.seek(0) || file.write(bytes) != bytes.size() || !file.resize(bytes.size())) {
        setError("Couldn't save " + shellPath() + ": " + file.errorString());
        return false;
    }
    file.close();
    readShell();
    emit changed();
    return true;
}

void Hyprvyzr::setOnBar(bool on) {
    if (on == onBar())
        return;
    editShell([on](QJsonObject &shell) -> QString {
        QJsonObject bar = shell.value("bar").toObject();
        QJsonObject layout = bar.value("layout").toObject();
        if (layout.isEmpty())
            return "shell.json has no bar layout yet. Open the bar once (omarchy bar defaults), then try again.";
        for (const auto &section : {"left", "center", "right"}) {
            QJsonArray entries = layout.value(section).toArray(), kept;
            for (const auto &entry : entries)
                if (entry.toObject().value("id").toString() != kPluginId)
                    kept << entry;
            layout.insert(section, kept);
        }
        if (on) {
            // Just before the tray end of the right side.
            QJsonArray right = layout.value("right").toArray();
            right.insert(0, QJsonObject{{"id", kPluginId}});
            layout.insert("right", right);
        }
        bar.insert("layout", layout);
        shell.insert("bar", bar);
        return {};
    });
}

bool Hyprvyzr::onDock() const {
    if (!m_dock)
        return false;
    for (const auto &item : m_dock->dock())
        if (item.toMap().value("command").toString().contains("omacraft.hyprvyzr"))
            return true;
    return false;
}

void Hyprvyzr::setOnDock(bool on) {
    if (!m_dock) {
        setError("The Side Dock isn't installed.");
        return;
    }
    if (on && !onDock()) {
        m_dock->addCommand("HyprVYZR", QString::fromUcs4(U"\U000F0379"), carouselCommand("all"));
    } else if (!on) {
        // From the end, so the indices stay put.
        const QVariantList items = m_dock->dock();
        for (int i = items.size() - 1; i >= 0; --i)
            if (items.at(i).toMap().value("command").toString().contains("omacraft.hyprvyzr"))
                m_dock->removeItem(i);
    }
    emit changed();
}

// ------------------------------------------------------------------ settings

void Hyprvyzr::setConfig(const QString &key, const QVariant &value) {
    static const QStringList allowed{"native.enabled", "native.tag", "native.shm", "window", "size", "local.port"};
    if (!allowed.contains(key))
        return;
    QJsonObject config = readObject(configPath());
    const QJsonValue json = QJsonValue::fromVariant(value);
    if (key.contains('.')) {
        const QString group = key.section('.', 0, 0), name = key.section('.', 1);
        QJsonObject sub = config.value(group).toObject();
        sub.insert(name, json);
        config.insert(group, sub);
    } else {
        config.insert(key, json);
    }
    QString problem;
    QDir().mkpath(QFileInfo(configPath()).absolutePath());
    QFile::setPermissions(QFileInfo(configPath()).absolutePath(), QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
    if (!Proc::writeAtomically(configPath(), QJsonDocument(config).toJson(), &problem)) {
        setError(problem);
        return;
    }
    QFile::setPermissions(configPath(), QFile::ReadOwner | QFile::WriteOwner);
    m_config = config;
    emit changed();
    if (key.startsWith("native"))
        refreshWorkspaces(false);
}

void Hyprvyzr::loadSettings() {
    const QJsonObject s = readObject(settingsPath());
    m_cardEffect = s.value("cardEffect").toString("trace");
    const double speed = s.value("cardSpeed").toDouble(1.0);
    m_cardSpeed = speed > 0 ? qBound(0.25, speed, 3.0) : 1.0;
    m_showTitle = s.value("showTitle").toBool(true);
}

void Hyprvyzr::saveSettings() {
    // In place, not through a rename: the carousel's FileView follows it.
    QJsonObject settings = readObject(settingsPath());
    settings.insert("cardEffect", m_cardEffect);
    settings.insert("cardSpeed", m_cardSpeed);
    settings.insert("showTitle", m_showTitle);
    QDir().mkpath(QFileInfo(settingsPath()).absolutePath());
    QFile file(settingsPath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        setError("Can't write " + settingsPath() + ": " + file.errorString());
        return;
    }
    file.write(QJsonDocument(settings).toJson(QJsonDocument::Indented));
    emit changed();
}

void Hyprvyzr::setCardEffect(const QString &id) {
    for (const auto &effect : WallPicker::cardEffects())
        if (effect.toMap().value("id").toString() == id && id != m_cardEffect) {
            m_cardEffect = id;
            saveSettings();
        }
}

void Hyprvyzr::setCardSpeed(double speed) {
    speed = qBound(0.25, speed, 3.0);
    if (qFuzzyCompare(speed, m_cardSpeed))
        return;
    m_cardSpeed = speed;
    saveSettings();
}

void Hyprvyzr::setShowTitle(bool on) {
    if (on == m_showTitle)
        return;
    m_showTitle = on;
    saveSettings();
}

// ------------------------------------------------------------------ local, native, theme

void Hyprvyzr::installLocal() { inTerminal({"local", "install"}, "The Kasm install"); }

void Hyprvyzr::openLocal() {
    runCli({"local", "open"}, [this](int code, const QByteArray &, const QString &err) {
        if (code != 0)
            setError(lastLine(err, "Couldn't open the local dashboard."));
    });
}

void Hyprvyzr::pullNative(const QString &name) {
    static const QRegularExpression image("^[a-z0-9][a-z0-9._-]{0,60}$");
    if (image.match(name).hasMatch())
        inTerminal({"native", "pull", name}, "Downloading " + name);
}

void Hyprvyzr::removeNative(const QString &name) {
    static const QRegularExpression image("^[a-z0-9][a-z0-9._-]{0,60}$");
    if (!image.match(name).hasMatch())
        return;
    runCli({"native", "remove", name}, [this, name](int code, const QByteArray &, const QString &err) {
        if (code != 0)
            setError(lastLine(err, "Couldn't remove " + name + "."));
        else
            setNotice("Removed the " + name + " image. It downloads again the next time it starts.");
        refreshWorkspaces(false);
    }, {}, 120000, "Removing " + name + "…");
}

void Hyprvyzr::applyTheme(const QString &serverId) {
    inTerminal({"theme", "apply", serverId}, "The dashboard theme");
}

// ------------------------------------------------------------------ messages

void Hyprvyzr::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}

void Hyprvyzr::setNotice(const QString &message) {
    m_notice = message;
    m_error.clear();
    emit messageChanged();
}

void Hyprvyzr::setBusy(const QString &text) {
    if (m_busy == text)
        return;
    m_busy = text;
    emit busyChanged();
}

void Hyprvyzr::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}

// ================================================================== KasmView

KasmView::KasmView(const QString &specPath, QObject *parent) : QObject(parent) {
    QFile file(specPath);
    const QFileInfo info(specPath);
    // Only a private spec in hyprvyzr's runtime folder, owned by this user.
    const QString runtime = qEnvironmentVariable("XDG_RUNTIME_DIR") + "/hyprvyzr";
    if (!info.exists() || info.canonicalPath() != QFileInfo(runtime).canonicalFilePath()
        || info.ownerId() != static_cast<uint>(getuid())
        || (info.permissions() & (QFile::ReadGroup | QFile::ReadOther))) {
        m_problem = "This session's link wasn't found, or wasn't private. Start it again from HyprVYZR.";
        return;
    }
    if (!file.open(QIODevice::ReadOnly)) {
        m_problem = "Couldn't read this session's link.";
        return;
    }
    const QJsonObject spec = QJsonDocument::fromJson(file.readAll()).object();
    file.close();
    file.remove();
    m_id = spec.value("id").toString();
    m_title = spec.value("title").toString("Kasm");
    m_server = spec.value("server").toString();
    m_kind = spec.value("kind").toString();
    m_url = QUrl(spec.value("url").toString());
    m_cli = spec.value("cli").toString();
    m_insecureLocal = spec.value("insecureLocal").toBool();
    const QJsonObject auth = spec.value("auth").toObject();
    m_user = auth.value("user").toString();
    m_password = auth.value("password").toString();
    if (m_url.scheme() != "https" || m_url.host().isEmpty())
        m_problem = "This session's link isn't an https address.";
    static const QRegularExpression id("^[0-9a-f]{6,32}$");
    if (!id.match(m_id).hasMatch())
        m_problem = "This session's link is malformed.";
}

bool KasmView::isLoopback(const QUrl &url) {
    const QString host = url.host();
    return host == "localhost" || host == "127.0.0.1" || host == "::1";
}

bool KasmView::acceptCertificate(const QUrl &url) const {
    return m_insecureLocal && isLoopback(url) && isLoopback(m_url) && url.port() == m_url.port();
}

void KasmView::act(const QString &action) {
    static const QStringList actions{"hide", "float", "tile", "end"};
    if (!actions.contains(action) || m_cli.isEmpty() || !QFileInfo(m_cli).isFile())
        return;
    Proc::detach("python3", {"-I", m_cli, action, m_id});
}
