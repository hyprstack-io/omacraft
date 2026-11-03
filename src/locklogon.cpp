#include "locklogon.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>
#include <algorithm>

#include "filepicker.h"
#include "plugins.h"
#include "proc.h"
#include "theme.h"

namespace {
constexpr int kUndoDepth = 40;
const QStringList kImageSuffixes{"jpg", "jpeg", "png", "webp"};

QVariantMap readLook(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object().toVariantMap();
}
}

LockLogon::LockLogon(Plugins *plugins, FilePicker *picker, const QString &home, const QString &etc,
                     const QString &themesDir, bool runCommands, QObject *parent)
    : QObject(parent), m_plugins(plugins), m_picker(picker), m_home(home.isEmpty() ? QDir::homePath() : home),
      m_etc(etc), m_themesDir(themesDir), m_runCommands(runCommands) {
    if (m_picker) {
        connect(m_picker, &FilePicker::folderSelected, this, [this](const QString &purpose, const QUrl &url) {
            const QStringList parts = purpose.split(':');
            if (parts.size() == 3 && parts.at(0) == "lock-logon")
                set(parts.at(1), parts.at(2), url.toLocalFile());
        });
    }
    if (m_plugins)
        connect(m_plugins, &Plugins::changed, this, &LockLogon::reload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &LockLogon::reload);
    reload();
}

QVariantMap LockLogon::themeColors() const {
    const auto colors = Theme::readColors(m_home + "/.local/state/omarchy/current/theme/colors.toml");
    const auto pick = [&](const char *key, const char *fallback) {
        const QString value = colors.value(key);
        return value.isEmpty() ? QString(fallback) : value;
    };
    const QString accent = pick("accent", "#7aa2f7");
    return {{"background", pick("background", "#1a1b26")}, {"foreground", pick("foreground", "#c0caf5")},
            {"accent", accent}, {"accent2", accent}, {"urgent", pick("color1", "#f7768e")}};
}

QString LockLogon::wallpaper() const {
    return QFileInfo(m_home + "/.local/state/omarchy/current/background").canonicalFilePath();
}

QVariantList LockLogon::folderImages() const {
    const QString folder = lockLook().value("bgFolder").toString();
    QVariantList images;
    if (folder.isEmpty())
        return images;
    const QDir dir(folder);
    for (const auto &name : dir.entryList({"*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG"}, QDir::Files, QDir::Name))
        images << dir.filePath(name);
    return images;
}

QString LockLogon::lockInUseName() const {
    if (m_lockInUse == Plugins::kLockId)
        return "OmaCraft";
    if (m_lockInUse == "omarchy.lock")
        return "Omarchy's own";
    if (m_lockInUse.isEmpty())
        return "None";
    const auto manifest = QJsonDocument::fromJson([&] {
        QFile file(m_home + "/.config/omarchy/plugins/" + m_lockInUse + "/manifest.json");
        return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
    }()).object();
    return manifest.value("name").toString(m_lockInUse);
}

bool LockLogon::stayAwake() const { return QFileInfo::exists(stayAwakePath()); }
bool LockLogon::loginThemeInstalled() const { return QFileInfo::exists(m_themesDir + "/omacraft/Main.qml"); }
bool LockLogon::helperInstalled() const { return QFileInfo(kHelper).isExecutable(); }
bool LockLogon::autologinOverridden() const { return QFileInfo::exists(m_etc + "/sddm.conf.d/" + kAutologinOverride); }

bool LockLogon::loginApplied() const {
    return !m_applied.isEmpty() && m_applied == lookBytes(loginLook());
}

QVariantMap LockLogon::readSddmConfig(const QString &confDir) {
    QString theme;
    QString user;
    const QDir dir(confDir);
    for (const auto &name : dir.entryList({"*.conf"}, QDir::Files, QDir::Name)) {
        // QSettings would take these for its own format; they're plain enough.
        QFile file(dir.filePath(name));
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
            continue;
        QString section;
        for (const auto &raw : QString::fromUtf8(file.readAll()).split('\n')) {
            const QString line = raw.trimmed();
            if (line.startsWith('[') && line.endsWith(']')) {
                section = line.mid(1, line.size() - 2);
            } else if (const int equals = line.indexOf('='); equals > 0 && !line.startsWith('#')) {
                const QString key = line.left(equals).trimmed();
                const QString value = line.mid(equals + 1).trimmed();
                if (section == "Theme" && key == "Current")
                    theme = value;
                else if (section == "Autologin" && key == "User")
                    user = value;
            }
        }
    }
    return {{"theme", theme}, {"autologinUser", user}};
}

void LockLogon::readShell() {
    QFile file(shellPath());
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonObject shell = QJsonDocument::fromJson(file.readAll()).object();
    const QJsonObject idle = shell.value("idle").toObject();
    m_screensaverSeconds = idle.value("screensaver").toInt(150);
    m_lockSeconds = idle.value("lock").toInt(300);

    // The lock in use: a clone of omarchy.lock that's listed, else the stock one
    // unless that's been turned off.
    m_lockInUse.clear();
    for (const auto &value : shell.value("plugins").toArray()) {
        const QString id = value.toObject().value("id").toString();
        QFile manifest(m_home + "/.config/omarchy/plugins/" + id + "/manifest.json");
        if (!manifest.open(QIODevice::ReadOnly))
            continue;
        if (QJsonDocument::fromJson(manifest.readAll()).object().value("omarchy").toObject().value("clonedFrom").toString() == "omarchy.lock") {
            m_lockInUse = id;
            break;
        }
    }
    if (m_lockInUse.isEmpty() && !shell.value("disabledPlugins").toArray().contains(QJsonValue("omarchy.lock")))
        m_lockInUse = "omarchy.lock";
}

void LockLogon::reload() {
    m_look["lock"] = readLook(lockPath());
    m_look["login"] = readLook(loginPath());
    QFile applied(appliedPath());
    m_applied = applied.open(QIODevice::ReadOnly) ? applied.readAll() : QByteArray();
    readShell();
    const auto sddm = readSddmConfig(m_etc + "/sddm.conf.d");
    m_loginTheme = sddm.value("theme").toString();
    m_autologinUser = sddm.value("autologinUser").toString();

    const QStringList folders{m_home + "/.config/omarchy", m_home + "/.local/state/omarchy/indicators", m_etc + "/sddm.conf.d"};
    for (const auto &folder : folders)
        if (QDir(folder).exists() && !m_watcher.directories().contains(folder))
            m_watcher.addPath(folder);
    emit lookChanged();
    emit systemChanged();
}

QByteArray LockLogon::lookBytes(const QVariantMap &look) const {
    return QJsonDocument(QJsonObject::fromVariantMap(look)).toJson(QJsonDocument::Compact);
}

void LockLogon::remember(const QString &target) {
    auto &stack = m_undo[target];
    stack << m_look.value(target);
    if (stack.size() > kUndoDepth)
        stack.removeFirst();
}

void LockLogon::store(const QString &target, const QVariantMap &look) {
    m_look[target] = look;
    QString problem;
    if (target == "lock") {
        // In place, with the folder made first: the plugin's file watcher stays
        // on it, and a half-read file only keeps the last good settings.
        QDir().mkpath(QFileInfo(lockPath()).absolutePath());
        QFile file(lockPath());
        const QByteArray bytes = QJsonDocument(QJsonObject::fromVariantMap(look)).toJson();
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate) || file.write(bytes) != bytes.size())
            problem = "Couldn't save " + lockPath() + ": " + file.errorString();
    } else {
        Proc::writeAtomically(loginPath(), QJsonDocument(QJsonObject::fromVariantMap(look)).toJson(), &problem);
    }
    if (!problem.isEmpty())
        setError(problem);
    emit lookChanged();
}

void LockLogon::set(const QString &target, const QString &key, const QVariant &value) {
    setMany(target, {{key, value}});
}

void LockLogon::setMany(const QString &target, const QVariantMap &values) {
    if (target != "lock" && target != "login")
        return;
    remember(target);
    QVariantMap look = m_look.value(target);
    for (auto it = values.begin(); it != values.end(); ++it)
        look.insert(it.key(), it.value());
    store(target, look);
}

void LockLogon::replace(const QString &target, const QVariantMap &values) {
    if (target != "lock" && target != "login")
        return;
    remember(target);
    store(target, values);
}

void LockLogon::undo(const QString &target) {
    auto &stack = m_undo[target];
    if (stack.isEmpty())
        return;
    store(target, stack.takeLast());
}

void LockLogon::copyLockToLogin() {
    remember("login");
    QVariantMap look = lockLook();
    look.remove("blankSeconds");
    store("login", look);
    setNotice("The login design matches the lock now. Apply it when you're ready.");
}

void LockLogon::choosePicture(const QString &target, const QString &key) {
    if (m_picker)
        m_picker->chooseImage("lock-logon:" + target + ":" + key, "Choose a picture", m_home + "/Pictures");
}

void LockLogon::chooseFolder(const QString &target, const QString &key) {
    if (m_picker)
        m_picker->chooseFolder("lock-logon:" + target + ":" + key, "Choose a folder of pictures", m_home + "/Pictures");
}

void LockLogon::useOurLock(bool on) {
    if (!m_plugins)
        return;
    dismissMessages();
    if (!m_plugins->isInstalled(Plugins::kLockId)) {
        if (!on)
            return;
        // setEnabled needs it listed as installed, which Plugins::changed tells us.
        auto *once = new QObject(this);
        connect(m_plugins, &Plugins::changed, once, [this, once] {
            if (m_plugins->isInstalled(Plugins::kLockId)) {
                once->deleteLater();
                m_plugins->setEnabled(Plugins::kLockId, true);
            }
        });
        m_plugins->install(Plugins::kLockId);
        return;
    }
    m_plugins->setEnabled(Plugins::kLockId, on);
}

void LockLogon::previewLock() {
    if (m_runCommands)
        Proc::run(this, "omarchy-shell", {"lock", "preview"}, [this](const Proc::Result &result) {
            if (!result.ok())
                setError("The shell didn't show the preview: " + result.message());
        });
}

void LockLogon::lockNow() {
    if (m_runCommands)
        Proc::detach("omarchy-system-lock", {});
}

void LockLogon::setIdle(const QString &key, int seconds) {
    if (key != "screensaver" && key != "lock")
        return;
    seconds = std::clamp(seconds, 0, 86400);
    QFile file(shellPath());
    if (!file.open(QIODevice::ReadWrite)) {
        setError("Couldn't open " + shellPath() + ": " + file.errorString());
        return;
    }
    const QByteArray before = file.readAll();
    QJsonParseError parseError;
    QJsonObject shell = QJsonDocument::fromJson(before.trimmed().isEmpty() ? "{}" : before, &parseError).object();
    if (parseError.error != QJsonParseError::NoError) {
        setError("shell.json doesn't read as JSON (" + parseError.errorString() + "), so the time wasn't saved.");
        return;
    }
    QJsonObject idle = shell.value("idle").toObject();
    idle[key] = seconds;
    shell["idle"] = idle;
    // In place, not through a rename: the shell's file watcher stays on it.
    const QByteArray bytes = QJsonDocument(shell).toJson(QJsonDocument::Indented);
    if (!file.seek(0) || file.write(bytes) != bytes.size() || !file.resize(bytes.size())) {
        setError("Couldn't save " + shellPath() + ": " + file.errorString());
        return;
    }
    (key == "lock" ? m_lockSeconds : m_screensaverSeconds) = seconds;
    emit systemChanged();
    emit idleChanged();
}

void LockLogon::setStayAwake(bool on) {
    if (!m_runCommands)
        return;
    Proc::run(this, "omarchy", {"toggle", "idle", on ? "stay-awake" : "allow-idle"}, [this](const Proc::Result &result) {
        if (!result.ok())
            setError("Couldn't change that: " + result.message());
        emit systemChanged();
    });
}

QStringList LockLogon::loginArguments() const {
    QVariantMap look = loginLook();
    for (const auto &key : {"bgImage", "bgFolder", "avatar", "blankSeconds"})
        look.remove(key);
    // No folder to pick from at login, and no wallpaper link to follow: the
    // picture is whichever file is copied in.
    if (look.value("bgMode").toString() == "folder")
        look.remove("bgMode");
    const auto colors = themeColors();
    QStringList arguments;
    for (auto it = look.begin(); it != look.end(); ++it)
        arguments << it.key() + "=" + it.value().toString();
    arguments << "themeBackground=" + colors.value("background").toString()
              << "themeForeground=" + colors.value("foreground").toString()
              << "themeAccent=" + colors.value("accent").toString()
              << "themeUrgent=" + colors.value("urgent").toString();
    return arguments;
}

QString LockLogon::loginBackgroundFile(QString *why) const {
    const QString mode = loginLook().value("bgMode", "wallpaper").toString();
    if (mode == "solid" || mode == "gradient")
        return {};
    const QString file = mode == "image" ? loginLook().value("bgImage").toString() : wallpaper();
    if (!kImageSuffixes.contains(QFileInfo(file).suffix().toLower())) {
        if (why)
            *why = "The login screen needs a JPEG, PNG or WebP picture, so pick an image: a video wallpaper won't copy over.";
        return {};
    }
    return file;
}

void LockLogon::privileged(const QStringList &arguments, const QString &done, const std::function<void()> &after) {
    if (!helperInstalled()) {
        setError("The login helper comes with the OmaCraft package. Install it with bin/install, then try again.");
        return;
    }
    if (!m_runCommands)
        return;
    m_busy = true;
    emit systemChanged();
    Proc::run(this, "pkexec", QStringList{kHelper} + arguments, [this, done, after](const Proc::Result &result) {
        m_busy = false;
        if (result.exitCode == 126)
            setError("The password prompt was dismissed, so nothing changed.");
        else if (result.exitCode == 127)
            setError("pkexec couldn't get authorization. Omarchy runs a polkit agent at login; is it still running?");
        else if (!result.ok())
            setError(result.message());
        else {
            if (after)
                after();
            setNotice(done);
        }
        reload();
    }, 120000);
}

void LockLogon::applyLogin() {
    dismissMessages();
    QString why;
    const QString background = loginBackgroundFile(&why);
    if (!why.isEmpty()) {
        setError(why);
        return;
    }
    const QString avatar = loginLook().value("showAvatar").toBool() ? loginLook().value("avatar").toString() : QString();
    const QByteArray look = lookBytes(loginLook());
    privileged(QStringList{"apply", background.isEmpty() ? "-" : background, avatar.isEmpty() ? "-" : avatar} + loginArguments(),
               loginTheme() == "omacraft" ? "Applied. You'll see it at the next login." : "Saved. Switch the login theme on to use it.",
               [this, look] { Proc::writeAtomically(appliedPath(), look); });
}

void LockLogon::useLoginTheme(bool on) {
    dismissMessages();
    privileged({"theme", on ? "omacraft" : "omarchy"},
               on ? "SDDM will use OmaCraft's login theme from the next login." : "Back to Omarchy's own login screen.");
}

void LockLogon::setAutologin(bool on) {
    dismissMessages();
    privileged({"autologin", on ? "on" : "off"},
               on ? "Omarchy's automatic login is back." : "Automatic login is off, so the login screen will show at boot.");
}

void LockLogon::tryGreeter() {
    if (!loginThemeInstalled()) {
        setError("The login theme comes with the OmaCraft package. Install it with bin/install, then try again.");
        return;
    }
    if (m_runCommands)
        Proc::detach("sddm-greeter-qt6", {"--test-mode", "--theme", m_themesDir + "/omacraft"});
}

void LockLogon::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}

void LockLogon::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}

void LockLogon::setNotice(const QString &message) {
    m_notice = message;
    m_error.clear();
    emit messageChanged();
}
