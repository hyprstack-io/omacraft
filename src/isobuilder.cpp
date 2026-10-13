#include "isobuilder.h"

#include <QCoreApplication>
#include <QDate>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QStorageInfo>
#include <unistd.h>

#include "filepicker.h"

namespace {

constexpr int maxUndo = 200;
constexpr qint64 gigabyte = 1000LL * 1000 * 1000;

// mkarchiso's work directory for the releng profile peaks around 6 GB; ask
// for headroom so a build doesn't fail an hour in with a full disk.
constexpr qint64 workSpaceNeeded = 10 * gigabyte;
constexpr qint64 isoSpaceNeeded = 2 * gigabyte;

QString defaultOutputDir() {
    const QString downloads = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    return QDir(downloads).exists() ? downloads : QDir::homePath();
}

QString readResource(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QString::fromUtf8(file.readAll());
}

}

IsoBuilder::IsoBuilder(FilePicker *picker, const QString &configPath, const QString &configsDir, QObject *parent)
    : QObject(parent),
      m_picker(picker),
      m_configPath(configPath.isEmpty()
                       ? QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + "/hyprbuildz/config.json"
                       : configPath),
      m_configsDir(configsDir) {
    m_config.outputDir = defaultOutputDir();
    load();

    m_tick.setInterval(1000);
    connect(&m_tick, &QTimer::timeout, this, &IsoBuilder::progressChanged);

    m_process.setProcessChannelMode(QProcess::MergedChannels);
    connect(&m_process, &QProcess::readyReadStandardOutput, this, [this] {
        appendOutput(m_process.readAllStandardOutput());
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart)
            return;
        const QString program = m_process.program();
        setState("idle");
        removeRun();
        setError(QString("Couldn't start %1. Is it installed?").arg(program));
    });
    connect(&m_process, &QProcess::finished, this, [this](int exitCode, QProcess::ExitStatus status) {
        appendOutput(m_process.readAllStandardOutput());
        if (!m_pendingOutput.isEmpty())
            appendOutput("\n");
        const int code = status == QProcess::NormalExit ? exitCode : -1;
        if (m_state == "checking") {
            const bool cancelled = m_cancelling;
            if (code == 0 && !cancelled) {
                runBuild();
                return;
            }
            const QString output = QString::fromUtf8(m_process.property("output").toByteArray());
            QStringList unknown;
            static const QRegularExpression notFound("target not found: (\\S+)");
            for (auto it = notFound.globalMatch(output); it.hasNext();)
                unknown.append(it.next().captured(1));
            setState("idle");
            setStage({}, 0);
            if (cancelled)
                setNotice("Build cancelled.");
            else if (!unknown.isEmpty())
                setError(QString("Not in your enabled repositories: %1. AUR packages can't go on the ISO, and names must match exactly.")
                             .arg(unknown.join(", ")));
            else
                setError("pacman couldn't check the package list. The log shows why.");
        } else if (m_state == "building") {
            finishBuild(code);
        } else if (m_state == "flashing") {
            finishFlash(code);
        } else if (m_state == "installing") {
            finishInstall(code);
        }
    });

    connect(m_picker, &FilePicker::folderSelected, this, [this](const QString &purpose, const QUrl &url) {
        if (purpose == "overlay")
            addOverlay(url.toLocalFile());
        else if (purpose == "output")
            setOutputDir(url.toLocalFile());
    });
    connect(m_picker, &FilePicker::isoSelected, this, [this](const QUrl &url) {
        m_flashIso = url.toLocalFile();
        refreshDrives();
    });
    connect(m_picker, &FilePicker::failed, this, &IsoBuilder::setError);

    connect(&m_du, &QProcess::finished, this, [this] {
        // du prints "bytes<TAB>path" per item; the home prefix comes off.
        const QString prefix = m_system.home + "/";
        for (const QString &line : QString::fromUtf8(m_du.readAllStandardOutput()).split('\n', Qt::SkipEmptyParts)) {
            const QString path = line.section('\t', 1);
            if (path.startsWith(prefix))
                m_homeBytes.insert(path.mid(prefix.size()), line.section('\t', 0, 0).toLongLong());
        }
        emit desktopChanged();
        // A build that was waiting on the sizes goes on, unless it was cancelled.
        if (m_state == "measuring") {
            if (m_cancelling) {
                setState("idle");
                setStage({}, 0);
                setNotice("Build cancelled.");
                // du was stopped partway, so its sizes are short; measure again.
                scanDesktop();
            } else {
                checkPackagesThenBuild();
            }
        }
    });

    checkTools();
    if (m_config.profile == "replica")
        scanDesktop();
}

IsoBuilder::~IsoBuilder() {
    if (m_du.state() != QProcess::NotRunning) {
        m_du.kill();
        m_du.waitForFinished(1000);
    }
    // The privileged job runs as root, so it can't be killed from here; ask it
    // to stop and give it time, rather than leave a half-built tree behind.
    m_process.disconnect(this);
    if (m_process.state() != QProcess::NotRunning) {
        if (!m_run.isEmpty()) {
            QFile flag(m_run + "/cancel");
            if (!flag.open(QIODevice::WriteOnly))
                qWarning("hyprbuildz: couldn't ask the running job to stop");
        }
        m_process.waitForFinished(60000);
    }
    removeRun();
}

int IsoBuilder::packageCount() const {
    return Profile::extraPackages(m_config).size();
}

void IsoBuilder::change(const BuildConfig &next) {
    if (next == m_config)
        return;
    m_undo.append(m_config);
    if (m_undo.size() > maxUndo)
        m_undo.removeFirst();
    m_redo.clear();
    m_config = next;
    save();
    emit configChanged();
}

void IsoBuilder::setProfile(const QString &value) {
    if (value != "releng" && value != "baseline" && value != "replica")
        return;
    BuildConfig next = m_config;
    next.profile = value;
    change(next);
    if (value == "replica" && !m_desktopScanned)
        scanDesktop();
}

void IsoBuilder::setIsoName(const QString &value) {
    BuildConfig next = m_config;
    next.isoName = value.trimmed();
    change(next);
}

void IsoBuilder::setHostname(const QString &value) {
    BuildConfig next = m_config;
    next.hostname = value.trimmed();
    change(next);
}

void IsoBuilder::setPackages(const QString &value) {
    BuildConfig next = m_config;
    next.packages = value;
    change(next);
}

QVariantList IsoBuilder::overlays() const {
    QVariantList list;
    for (const Overlay &overlay : m_config.overlays) {
        list.append(QVariantMap{
            {"source", overlay.source},
            {"target", overlay.target},
            {"name", QFileInfo(overlay.source).fileName()},
            {"exists", QFileInfo(overlay.source).isDir()},
        });
    }
    return list;
}

void IsoBuilder::addOverlay(const QString &source, const QString &target) {
    if (source.isEmpty())
        return;
    for (const Overlay &overlay : m_config.overlays) {
        if (overlay.source == source && overlay.target == target)
            return;
    }
    BuildConfig next = m_config;
    next.overlays.append({source, target.isEmpty() ? "/" : target});
    change(next);
}

void IsoBuilder::removeOverlay(int index) {
    if (index < 0 || index >= m_config.overlays.size())
        return;
    BuildConfig next = m_config;
    next.overlays.removeAt(index);
    change(next);
}

void IsoBuilder::setOverlayTarget(int index, const QString &target) {
    if (index < 0 || index >= m_config.overlays.size())
        return;
    QString cleaned = target.trimmed();
    if (cleaned.isEmpty())
        cleaned = "/";
    if (!cleaned.startsWith('/'))
        cleaned.prepend('/');
    if (cleaned.size() > 1 && cleaned.endsWith('/'))
        cleaned.chop(1);
    BuildConfig next = m_config;
    next.overlays[index].target = cleaned;
    change(next);
}

void IsoBuilder::clearOverlays() {
    BuildConfig next = m_config;
    next.overlays.clear();
    change(next);
}

void IsoBuilder::setTimezone(const QString &value) {
    BuildConfig next = m_config;
    next.timezone = value.trimmed();
    change(next);
}

void IsoBuilder::setKeymap(const QString &value) {
    BuildConfig next = m_config;
    next.keymap = value.trimmed();
    change(next);
}

void IsoBuilder::setServices(const QString &value) {
    BuildConfig next = m_config;
    next.services = value;
    change(next);
}

void IsoBuilder::setKernelParams(const QString &value) {
    BuildConfig next = m_config;
    next.kernelParams = value.simplified();
    change(next);
}

void IsoBuilder::setCompression(const QString &value) {
    if (value != "default" && value != "fast" && value != "small")
        return;
    BuildConfig next = m_config;
    next.compression = value;
    change(next);
}

void IsoBuilder::useHostTimezone() {
    if (const QString zone = Profile::hostTimezone(); !zone.isEmpty())
        setTimezone(zone);
}

void IsoBuilder::useHostKeymap() {
    if (const QString keymap = Profile::hostKeymap(); !keymap.isEmpty())
        setKeymap(keymap);
}

QStringList IsoBuilder::timezones() const {
    static const QStringList zones = [] {
        QProcess timedatectl;
        timedatectl.start("timedatectl", {"list-timezones", "--no-pager"});
        timedatectl.waitForFinished(5000);
        return QString::fromUtf8(timedatectl.readAllStandardOutput()).split('\n', Qt::SkipEmptyParts);
    }();
    return zones;
}

QStringList IsoBuilder::keymaps() const {
    static const QStringList maps = [] {
        QProcess localectl;
        localectl.start("localectl", {"list-keymaps", "--no-pager"});
        localectl.waitForFinished(5000);
        return QString::fromUtf8(localectl.readAllStandardOutput()).split('\n', Qt::SkipEmptyParts);
    }();
    return maps;
}

namespace {

// Files people commonly change on a live ISO, as starting points.
struct Suggestion {
    const char *path;
    const char *detail;
};
constexpr Suggestion suggestions[] = {
    {"/etc/motd", "Shown after logging in"},
    {"/etc/issue", "Shown above the login prompt"},
    {"/root/.zlogin", "Runs when root logs in on the live ISO"},
    {"/root/.zshrc", "The live shell's settings"},
    {"/etc/hosts", "Static host names"},
    {"/etc/environment", "Environment variables for every session"},
    {"/etc/ssh/sshd_config.d/10-hyprbuildz.conf", "SSH server settings"},
    {"/etc/systemd/network/20-ethernet.network", "Wired networking"},
    {"/usr/local/bin/welcome", "A script of your own, made runnable"},
    {"profile:pacman.conf", "Repositories and options used to build the ISO"},
    {"profile:packages.x86_64", "The profile's whole package list"},
    {"profile:profiledef.sh", "ISO metadata, boot modes, permissions"},
    {"profile:grub/grub.cfg", "GRUB boot menu"},
    {"profile:efiboot/loader/loader.conf", "systemd-boot menu: timeout, default entry"},
    {"profile:syslinux/archiso_sys-linux.cfg", "BIOS boot menu entries"},
};

QString displayName(const QString &path) {
    return path.startsWith(Profile::profilePrefix) ? "Profile · " + path.mid(Profile::profilePrefix.size()) : path;
}

// The path without "profile:", for the editor's narrow file list.
QString shortName(const QString &path) {
    return path.startsWith(Profile::profilePrefix) ? path.mid(Profile::profilePrefix.size()) : path;
}

}

QVariantList IsoBuilder::editedFiles() const {
    QVariantList list;
    for (const EditedFile &file : m_config.files) {
        list.append(QVariantMap{
            {"path", file.path},
            {"name", displayName(file.path)},
            {"short", shortName(file.path)},
            {"inProfile", file.path.startsWith(Profile::profilePrefix)},
            {"lines", file.content.isEmpty() ? 0 : file.content.count('\n') + (file.content.endsWith('\n') ? 0 : 1)},
            {"language", languageFor(file.path, file.content)},
        });
    }
    return list;
}

QVariantList IsoBuilder::fileSuggestions() const {
    const QString stock = m_configsDir + "/" + Profile::baseProfile(m_config);
    QVariantList list;
    for (const Suggestion &suggestion : suggestions) {
        const QString path = QString::fromLatin1(suggestion.path);
        // Profile files only make sense where the profile has them.
        if (path.startsWith(Profile::profilePrefix) && !QFileInfo::exists(stock + "/" + path.mid(Profile::profilePrefix.size())))
            continue;
        if (isFileEdited(path))
            continue;
        list.append(QVariantMap{{"path", path}, {"name", displayName(path)}, {"short", shortName(path)},
                                {"inProfile", path.startsWith(Profile::profilePrefix)},
                                {"detail", QString::fromUtf8(suggestion.detail)}});
    }
    return list;
}

bool IsoBuilder::isFileEdited(const QString &path) const {
    return std::any_of(m_config.files.cbegin(), m_config.files.cend(), [&](const EditedFile &f) { return f.path == path; });
}

QString IsoBuilder::fileContent(const QString &path) const {
    for (const EditedFile &file : m_config.files) {
        if (file.path == path)
            return file.content;
    }
    return Profile::stockContent(m_configsDir + "/" + Profile::baseProfile(m_config), path);
}

QString IsoBuilder::stockFileContent(const QString &path) const {
    return Profile::stockContent(m_configsDir + "/" + Profile::baseProfile(m_config), path);
}

QString IsoBuilder::normalizeFilePath(const QString &path) const {
    QString cleaned = path.trimmed();
    if (cleaned.startsWith(Profile::profilePrefix))
        return cleaned;
    if (cleaned.startsWith("~/"))
        cleaned = "/root" + cleaned.mid(1);
    if (!cleaned.isEmpty() && !cleaned.startsWith('/'))
        cleaned.prepend('/');
    return cleaned;
}

QString IsoBuilder::filePathProblem(const QString &path) const {
    if (path.isEmpty())
        return "Type a path, like /etc/motd.";
    if (path.startsWith(Profile::profilePrefix)) {
        if (!Profile::isValidProfilePath(path.mid(Profile::profilePrefix.size())))
            return "A profile path is relative, like profile:pacman.conf.";
        return {};
    }
    if (!Profile::isValidLivePath(path) || path == "/" || path.endsWith('/'))
        return "That isn't a file path. Use a full path like /etc/motd, without “..”.";
    return {};
}

void IsoBuilder::saveFile(const QString &path, const QString &content) {
    if (!filePathProblem(path).isEmpty())
        return;
    BuildConfig next = m_config;
    const auto existing = std::find_if(next.files.begin(), next.files.end(), [&](const EditedFile &f) { return f.path == path; });
    if (existing != next.files.end())
        existing->content = content;
    else
        next.files.append({path, content});
    change(next);
}

void IsoBuilder::removeFile(const QString &path) {
    BuildConfig next = m_config;
    next.files.removeIf([&](const EditedFile &f) { return f.path == path; });
    change(next);
}

QString IsoBuilder::languageFor(const QString &path, const QString &content) {
    const QString name = QFileInfo(path.mid(path.startsWith(Profile::profilePrefix) ? Profile::profilePrefix.size() : 0)).fileName();
    const QString suffix = QFileInfo(name).suffix().toLower();
    if (name.startsWith("packages.") || name == "bootstrap_packages")
        return "packages";
    if (suffix == "sh" || suffix == "bash" || suffix == "zsh"
        || QStringList{".zshrc", ".zlogin", ".zprofile", ".bashrc", ".bash_profile", ".profile", "PKGBUILD"}.contains(name)
        || content.startsWith("#!/bin/sh") || content.startsWith("#!/bin/bash") || content.startsWith("#!/usr/bin/env bash")
        || content.startsWith("#!/usr/bin/env sh") || content.startsWith("#!/bin/zsh") || content.startsWith("#!/usr/bin/env zsh"))
        return "shell";
    if (suffix == "json" || suffix == "jsonc")
        return "json";
    if (suffix == "lua")
        return "lua";
    if (suffix == "css" || suffix == "qss")
        return "css";
    if (QStringList{"conf", "ini", "cfg", "toml", "service", "socket", "timer", "target", "mount", "network",
                    "netdev", "link", "desktop", "rules", "preset"}.contains(suffix)
        || QStringList{"environment", "hosts", "fstab", "locale.conf", "vconsole.conf", "sshd_config", "pacman.conf"}.contains(name))
        return "ini";
    return "plain";
}

void IsoBuilder::setOmarchySetup(bool value) {
    BuildConfig next = m_config;
    next.omarchySetup = value;
    change(next);
}

void IsoBuilder::setReplicaSecrets(bool value) {
    BuildConfig next = m_config;
    next.replicaSecrets = value;
    change(next);
}

void IsoBuilder::scanDesktop() {
    m_system = Replica::readSystem();
    m_homeItems = m_system.home.isEmpty() ? QList<Replica::HomeItem>() : Replica::classifyHome(m_system.home);
    m_homeBytes.clear();
    m_desktopScanned = true;
    if (m_du.state() == QProcess::NotRunning && !m_homeItems.isEmpty()) {
        QStringList arguments{"-s", "-b", "-x"};
        for (const QString &name : Replica::cacheNames())
            arguments << "--exclude=" + name;
        arguments << "--";
        for (const Replica::HomeItem &item : m_homeItems)
            arguments << m_system.home + "/" + item.path;
        m_du.start("du", arguments);
    }
    emit desktopChanged();
}

namespace {
QString kindName(Replica::Kind kind) {
    switch (kind) {
    case Replica::Kind::Secret: return "secret";
    case Replica::Kind::Cache: return "cache";
    case Replica::Kind::Personal: return "personal";
    case Replica::Kind::Settings: break;
    }
    return "settings";
}
}

QVariantList IsoBuilder::homeItems() const {
    QVariantList list;
    for (const Replica::HomeItem &item : m_homeItems) {
        const qint64 bytes = m_homeBytes.value(item.path, -1);
        list.append(QVariantMap{
            {"path", item.path},
            {"kind", kindName(item.kind)},
            {"on", Replica::included(item, m_config.homeChoices)},
            {"size", bytes < 0 ? QString() : Drives::formatSize(bytes)},
        });
    }
    return list;
}

qint64 IsoBuilder::includedHomeBytes() const {
    qint64 total = 0;
    for (const Replica::HomeItem &item : m_homeItems) {
        if (Replica::included(item, m_config.homeChoices))
            total += qMax<qint64>(0, m_homeBytes.value(item.path, 0));
    }
    return total;
}

QString IsoBuilder::homeSize() const {
    return sizing() ? QString() : Drives::formatSize(includedHomeBytes());
}

void IsoBuilder::setHomeItem(const QString &path, bool on) {
    const auto item = std::find_if(m_homeItems.cbegin(), m_homeItems.cend(),
                                   [&](const Replica::HomeItem &i) { return i.path == path; });
    if (item == m_homeItems.cend())
        return;
    BuildConfig next = m_config;
    // Only differences from the default are kept, so new defaults still apply.
    if (on == item->on())
        next.homeChoices.remove(path);
    else
        next.homeChoices.insert(path, on);
    change(next);
    emit desktopChanged();
}

void IsoBuilder::setHomeKind(const QString &kind, bool on) {
    BuildConfig next = m_config;
    for (const Replica::HomeItem &item : m_homeItems) {
        if (kindName(item.kind) != kind)
            continue;
        if (on == item.on())
            next.homeChoices.remove(item.path);
        else
            next.homeChoices.insert(item.path, on);
    }
    change(next);
    emit desktopChanged();
}

void IsoBuilder::setOutputDir(const QString &value) {
    BuildConfig next = m_config;
    next.outputDir = value;
    change(next);
}

void IsoBuilder::undo() {
    if (m_undo.isEmpty())
        return;
    m_redo.append(m_config);
    m_config = m_undo.takeLast();
    save();
    emit configChanged();
    emit desktopChanged();
    if (m_config.profile == "replica" && !m_desktopScanned)
        scanDesktop();
}

void IsoBuilder::redo() {
    if (m_redo.isEmpty())
        return;
    m_undo.append(m_config);
    m_config = m_redo.takeLast();
    save();
    emit configChanged();
    emit desktopChanged();
    if (m_config.profile == "replica" && !m_desktopScanned)
        scanDesktop();
}

// Written beside the target and renamed into place, so a crash mid-write
// never leaves a truncated config.
void IsoBuilder::save() const {
    QDir().mkpath(QFileInfo(m_configPath).absolutePath());
    QSaveFile file(m_configPath);
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(QJsonDocument(m_config.toJson()).toJson());
    file.commit();
}

void IsoBuilder::load() {
    QFile file(m_configPath);
    if (!file.open(QIODevice::ReadOnly))
        return;
    m_config = BuildConfig::fromJson(QJsonDocument::fromJson(file.readAll()).object(), m_config);
}

QString IsoBuilder::elapsed() const {
    if (!busy() || !m_clock.isValid())
        return {};
    const qint64 seconds = m_clock.elapsed() / 1000;
    if (seconds >= 3600)
        return QString("%1:%2:%3").arg(seconds / 3600).arg(seconds / 60 % 60, 2, 10, QChar('0')).arg(seconds % 60, 2, 10, QChar('0'));
    return QString("%1:%2").arg(seconds / 60).arg(seconds % 60, 2, 10, QChar('0'));
}

void IsoBuilder::setState(const QString &state) {
    if (state == m_state)
        return;
    m_state = state;
    if (state == "idle") {
        m_cancelling = false;
        m_tick.stop();
        m_clock.invalidate();
    } else {
        m_tick.start();
        if (!m_clock.isValid())
            m_clock.start();
    }
    emit stateChanged();
    emit progressChanged();
    if (state == "idle" && m_quitWhenIdle)
        QCoreApplication::quit();
}

void IsoBuilder::setStage(const QString &stage, double progress) {
    m_stage = stage;
    m_progress = progress;
    emit progressChanged();
}

void IsoBuilder::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}

void IsoBuilder::setNotice(const QString &message) {
    m_notice = message;
    m_error.clear();
    emit messageChanged();
}

void IsoBuilder::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}

void IsoBuilder::checkTools() {
    QStringList missing;
    m_archisoMissing = QStandardPaths::findExecutable("mkarchiso").isEmpty()
                       || !QFileInfo(m_configsDir + "/releng/profiledef.sh").isFile();
    if (m_archisoMissing)
        missing.append("archiso");
    for (const char *tool : {"pkexec", "pacman", "setpriv", "lsblk", "dd"}) {
        if (QStandardPaths::findExecutable(QString::fromLatin1(tool)).isEmpty())
            missing.append(QString::fromLatin1(tool));
    }
    m_missing = missing.isEmpty() ? QString()
                                  : QString("hyprbuildz needs %1, which %2 installed.")
                                        .arg(missing.join(", "), missing.size() == 1 ? "isn't" : "aren't");
    emit toolsChanged();
}

QString IsoBuilder::remaining() const {
    if (m_state != "building" || !m_clock.isValid() || m_progress < 0.08 || m_progress >= 1 || m_cancelling)
        return {};
    const qint64 seconds = m_clock.elapsed() / 1000;
    if (seconds < 90)
        return {};
    const qint64 left = qint64(seconds * (1 - m_progress) / m_progress);
    if (left < 60)
        return "under a minute left";
    return QString("about %1 min left").arg((left + 59) / 60);
}

bool IsoBuilder::refineProgress(const QString &line, BuildProgress *state, QString *stage, double *progress, bool *quiet) {
    static const QRegularExpression packageCount("^Packages? \\((\\d+)\\)");
    static const QRegularExpression installing("^\\((\\d+)/(\\d+)\\) (installing|upgrading|reinstalling) ");
    static const QRegularExpression squashfs("^\\[.*\\]\\s+\\d+/\\d+\\s+(\\d+)%$");
    *quiet = false;

    if (const auto match = packageCount.match(line); match.hasMatch()) {
        state->packages = match.captured(1).toInt();
        state->downloaded = 0;
        return false;
    }
    // pacman without a terminal prints one "name downloading..." per package,
    // after it lists them; downloads take the build from 5% to 20%.
    if (state->packages > 0 && line.endsWith(" downloading...")) {
        state->downloaded = qMin(state->downloaded + 1, state->packages);
        *stage = QString("Downloading packages (%1 of %2)").arg(state->downloaded).arg(state->packages);
        *progress = .05 + .15 * state->downloaded / state->packages;
        return true;
    }
    // Installing them takes it on to 50%.
    if (const auto match = installing.match(line); match.hasMatch()) {
        const int done = match.captured(1).toInt();
        const int total = qMax(1, match.captured(2).toInt());
        *stage = QString("Installing packages (%1 of %2)").arg(done).arg(total);
        *progress = .20 + .30 * qMin(done, total) / total;
        return true;
    }
    // mksquashfs redraws its bar, so those lines stay out of the log.
    if (const auto match = squashfs.match(line); match.hasMatch()) {
        *quiet = true;
        const int percent = qBound(0, match.captured(1).toInt(), 100);
        *stage = QString("Compressing the live system (%1%)").arg(percent);
        *progress = .60 + .30 * percent / 100;
        return true;
    }
    return false;
}

bool IsoBuilder::stageForLine(const QString &line, QString *stage, double *progress) {
    static const QList<std::tuple<QString, QString, double>> stages{
        {"hyprbuildz: Collecting the system settings", "Collecting your system settings", .01},
        {"hyprbuildz: Collecting your home", "Collecting your home folder", .02},
        {"hyprbuildz: Repackaging", "Repackaging your AUR packages", .03},
        {"Copying custom pacman.conf", "Preparing the profile", .04},
        {"Installing packages to", "Downloading and installing packages", .05},
        {"Packages installed successfully", "Packages installed", .50},
        {"Running customize_airootfs", "Putting your desktop in place", .52},
        {"Copying /boot out of the airootfs", "Setting up boot loaders", .55},
        {"Creating SquashFS image", "Compressing the live system, the slow part", .60},
        {"Creating EROFS image", "Compressing the live system, the slow part", .60},
        {"Creating checksum file", "Checksumming the live system", .90},
        {"Creating ISO image", "Writing the ISO image", .94},
        {"hyprbuildz: Copying the ISO", "Saving the ISO", .98},
        {"hyprbuildz: Cancelling", "Cancelling", -1},
    };
    for (const auto &[marker, name, fraction] : stages) {
        if (line.contains(marker)) {
            *stage = name;
            *progress = fraction;
            return true;
        }
    }
    return false;
}

QString IsoBuilder::uniqueIsoPath(const QString &dir, const QString &isoName, const QString &date) {
    const QString base = QString("%1/%2-%3-x86_64").arg(dir, isoName, date);
    QString path = base + ".iso";
    for (int n = 2; QFileInfo::exists(path) || QFileInfo::exists(path + ".part"); ++n)
        path = QString("%1-%2.iso").arg(base).arg(n);
    return path;
}

void IsoBuilder::appendOutput(const QByteArray &bytes) {
    m_pendingOutput += bytes;
    if (m_state == "checking")
        m_process.setProperty("output", m_process.property("output").toByteArray() + bytes);

    // dd and pacman redraw progress with \r, so both end a line.
    qsizetype start = 0;
    for (qsizetype i = 0; i < m_pendingOutput.size(); ++i) {
        const char c = m_pendingOutput.at(i);
        if (c != '\n' && c != '\r')
            continue;
        const QString line = QString::fromUtf8(m_pendingOutput.mid(start, i - start)).trimmed();
        start = i + 1;
        if (line.isEmpty())
            continue;

        if (m_state == "flashing") {
            const qint64 written = Drives::parseDdProgress(line);
            if (written >= 0) {
                const double fraction = m_flashIsoBytes > 0 ? double(written) / m_flashIsoBytes : 0;
                setStage(QString("Writing %1 of %2").arg(Drives::formatSize(written), Drives::formatSize(m_flashIsoBytes)),
                         qMin(fraction, 1.0));
                continue;
            }
        } else if (m_state == "building") {
            QString stage;
            double fraction;
            bool quiet = false;
            if (stageForLine(line, &stage, &fraction))
                setStage(stage, fraction < 0 ? m_progress : qMax(fraction, m_progress));
            else if (refineProgress(line, &m_buildProgress, &stage, &fraction, &quiet))
                setStage(stage, qMax(fraction, m_progress));
            if (quiet)
                continue;
        }
        emit logAppended(line);
    }
    m_pendingOutput.remove(0, start);
}

void IsoBuilder::startPrivileged(const QString &state, const QString &scriptResource, const QStringList &arguments) {
    m_pendingOutput.clear();
    emit logCleared();
    setState(state);
    QStringList pkexecArguments;
    if (scriptResource.isEmpty())
        pkexecArguments = arguments;
    else
        pkexecArguments = QStringList{"/bin/sh", "-c", readResource(scriptResource), "hyprbuildz"} + arguments;
    m_process.start("pkexec", pkexecArguments);
}

QString IsoBuilder::pkexecError(int exitCode) {
    if (exitCode == 126)
        return "The password prompt was dismissed, so nothing ran.";
    if (exitCode == 127)
        return "pkexec couldn't get authorization. Omarchy runs a polkit agent at login; is it still running?";
    return {};
}

QString IsoBuilder::runDirectory() const {
    return QString("%1/hyprbuildz/run-%2")
        .arg(QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation),
             QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss"));
}

void IsoBuilder::removeRun() {
    if (!m_run.isEmpty())
        QDir(m_run).removeRecursively();
    m_run.clear();
}

void IsoBuilder::build() {
    if (busy())
        return;
    dismissMessages();
    checkTools();
    if (m_archisoMissing) {
        setError("archiso isn't installed, so there's nothing to build with. Press I to install it.");
        return;
    }
    if (!m_missing.isEmpty()) {
        setError(m_missing);
        return;
    }
    if (const QString problem = Profile::validate(m_config, m_configsDir); !problem.isEmpty()) {
        setError(problem);
        return;
    }

    if (m_config.profile == "replica") {
        // Read the machine fresh: what's installed now is what gets copied.
        // That re-measures home, and the space check needs the sizes, so the
        // build waits for du and carries on from its finished handler.
        scanDesktop();
        if (!m_system.error.isEmpty()) {
            setError(m_system.error);
            return;
        }
        if (sizing()) {
            emit logCleared();
            setState("measuring");
            setStage("Measuring your home folder", 0);
            return;
        }
    }
    checkPackagesThenBuild();
}

void IsoBuilder::checkPackagesThenBuild() {
    QStringList packages = Profile::extraPackages(m_config);
    if (m_config.profile == "replica") {
        // The foreign packages aren't in any repo; the build repackages them.
        packages = Replica::essentialPackages(m_system.kernel) + m_system.native + packages;
        packages.removeDuplicates();
    }
    if (packages.isEmpty()) {
        runBuild();
        return;
    }
    // Catch typos and AUR names now, not twenty minutes into pacstrap.
    m_pendingOutput.clear();
    m_process.setProperty("output", QByteArray());
    emit logCleared();
    setState("checking");
    setStage("Checking packages", 0);
    m_process.start("pacman", QStringList{"-Sp", "--print-format", "%n", "--"} + packages);
}

void IsoBuilder::runBuild() {
    const bool replica = m_config.profile == "replica";
    // A copy of a desktop installs every package the machine has and carries
    // the home folder through three copies: archive, airootfs, image.
    const qint64 home = replica ? includedHomeBytes() : 0;
    const qint64 workNeeded = replica ? 30 * gigabyte + 3 * home : workSpaceNeeded;
    const qint64 isoNeeded = replica ? 8 * gigabyte + home : isoSpaceNeeded;
    const QStorageInfo work("/var/tmp");
    if (work.bytesAvailable() < workNeeded) {
        setState("idle");
        setError(QString("Building needs about %1 free in /var/tmp, and there's %2.")
                     .arg(Drives::formatSize(workNeeded), Drives::formatSize(work.bytesAvailable())));
        return;
    }
    const QStorageInfo output(m_config.outputDir);
    if (output.bytesAvailable() < isoNeeded) {
        setState("idle");
        setError(QString("%1 has %2 free; the ISO needs about %3.")
                     .arg(m_config.outputDir, Drives::formatSize(output.bytesAvailable()), Drives::formatSize(isoNeeded)));
        return;
    }

    m_run = runDirectory();
    const QString base = m_configsDir + "/" + Profile::baseProfile(m_config);
    const QString error = replica ? Replica::prepare(base, m_run + "/profile", m_config, m_system)
                                  : Profile::prepare(base, m_run + "/profile", m_config);
    if (!error.isEmpty()) {
        removeRun();
        setState("idle");
        setError(error);
        return;
    }

    m_buildProgress = {};
    m_finalIso = uniqueIsoPath(m_config.outputDir, m_config.isoName, QDate::currentDate().toString("yyyy.MM.dd"));
    setStage("Waiting for your password", 0);
    startPrivileged("building", ":/build.sh",
                    {m_run + "/profile", m_run + "/cancel", m_finalIso,
                     QString::number(getuid()), QString::number(getgid())});
}

void IsoBuilder::finishBuild(int exitCode) {
    const bool cancelled = m_cancelling;
    removeRun();
    setState("idle");
    if (exitCode == 0) {
        m_builtIso = m_finalIso;
        m_flashIso = m_finalIso;
        emit builtIsoChanged();
        emit flashChanged();
        setStage("Done", 1);
        setNotice(QString("Saved %1.").arg(m_finalIso));
    } else if (exitCode == 130 || cancelled) {
        setStage({}, 0);
        setNotice("Build cancelled. Nothing was saved.");
    } else if (const QString message = pkexecError(exitCode); !message.isEmpty()) {
        setStage({}, 0);
        setError(message);
    } else {
        setError(QString("The build failed (exit status %1). The log shows where.").arg(exitCode));
    }
}

void IsoBuilder::cancel() {
    if (m_state == "measuring") {
        m_cancelling = true;
        emit stateChanged();
        m_du.kill();
    } else if (m_state == "checking") {
        m_cancelling = true;
        emit stateChanged();
        m_process.kill();
    } else if ((m_state == "building" || m_state == "flashing") && !m_run.isEmpty()) {
        // The job runs as root and can't be signalled from here, so it watches
        // for this file and stops itself, cleaning up as it goes.
        QFile flag(m_run + "/cancel");
        if (flag.open(QIODevice::WriteOnly)) {
            m_cancelling = true;
            emit stateChanged();
        } else {
            setError(QString("Couldn't ask the job to stop: %1").arg(flag.errorString()));
        }
    }
}

void IsoBuilder::cancelAndQuit() {
    m_quitWhenIdle = true;
    if (!busy()) {
        QCoreApplication::quit();
        return;
    }
    cancel();
}

void IsoBuilder::chooseOverlay() {
    m_picker->chooseFolder("overlay", "Choose a folder of files to put on the ISO",
                           m_config.overlays.isEmpty() ? QDir::homePath() : m_config.overlays.last().source);
}

void IsoBuilder::chooseOutput() {
    m_picker->chooseFolder("output", "Choose where to save the ISO", m_config.outputDir);
}

void IsoBuilder::chooseFlashIso() {
    m_picker->chooseIso(m_flashIso.isEmpty() ? m_config.outputDir : QFileInfo(m_flashIso).absolutePath());
}

void IsoBuilder::installArchiso() {
    if (busy())
        return;
    dismissMessages();
    setStage("Installing archiso", 0);
    startPrivileged("installing", {}, {"pacman", "-S", "--needed", "--noconfirm", "archiso"});
}

void IsoBuilder::finishInstall(int exitCode) {
    setState("idle");
    setStage({}, 0);
    checkTools();
    if (exitCode == 0 && !m_archisoMissing)
        setNotice("archiso is installed. Press Space to build.");
    else if (const QString message = pkexecError(exitCode); !message.isEmpty())
        setError(message);
    else
        setError("pacman couldn't install archiso. The log shows why.");
}

QString IsoBuilder::flashIsoSize() const {
    return m_flashIsoBytes > 0 ? Drives::formatSize(m_flashIsoBytes) : QString();
}

QVariantList IsoBuilder::drives() const {
    QVariantList list;
    for (const Drive &drive : m_drives) {
        list.append(QVariantMap{
            {"path", drive.path},
            {"name", drive.name},
            {"model", drive.model.isEmpty() ? "Unnamed drive" : drive.model},
            {"transport", drive.transport.toUpper()},
            {"size", Drives::formatSize(drive.size)},
            {"mountpoints", drive.mountpoints.join(", ")},
            {"blocker", drive.blocker},
        });
    }
    return list;
}

void IsoBuilder::openFlash() {
    if (m_flashIso.isEmpty())
        m_flashIso = m_builtIso;
    refreshDrives();
}

void IsoBuilder::refreshDrives() {
    m_flashIsoBytes = m_flashIso.isEmpty() ? 0 : QFileInfo(m_flashIso).size();
    QProcess lsblk;
    lsblk.start("lsblk", Drives::lsblkArguments());
    if (!lsblk.waitForFinished(5000) || lsblk.exitCode() != 0) {
        m_drives.clear();
        setError("lsblk couldn't list the drives.");
    } else {
        m_drives = Drives::parse(lsblk.readAllStandardOutput(), m_flashIso, m_flashIsoBytes);
    }
    emit flashChanged();
}

void IsoBuilder::flash(const QString &devicePath, const QString &confirmation) {
    if (busy())
        return;
    dismissMessages();
    if (m_flashIso.isEmpty() || !QFileInfo(m_flashIso).isFile()) {
        setError("Choose an ISO to write first.");
        return;
    }
    refreshDrives();
    const auto drive = std::find_if(m_drives.cbegin(), m_drives.cend(),
                                    [&](const Drive &d) { return d.path == devicePath; });
    if (drive == m_drives.cend()) {
        setError("That drive is gone. Plug it back in and choose it again.");
        return;
    }
    if (!drive->blocker.isEmpty()) {
        setError(drive->blocker);
        return;
    }
    if (confirmation.trimmed() != drive->name) {
        setError(QString("Type %1 to confirm you want everything on it erased.").arg(drive->name));
        return;
    }

    m_flashDevice = drive->path;
    m_run = runDirectory();
    QDir().mkpath(m_run);
    setStage("Waiting for your password", 0);
    startPrivileged("flashing", ":/flash.sh",
                    {m_flashIso, drive->path, QString::number(drive->size), m_run + "/cancel"});
}

void IsoBuilder::finishFlash(int exitCode) {
    const bool cancelled = m_cancelling;
    removeRun();
    setState("idle");
    refreshDrives();
    if (exitCode == 0) {
        setStage("Done", 1);
        setNotice(QString("%1 is written and ready to boot. You can unplug it.").arg(m_flashDevice));
    } else if (exitCode == 130 || cancelled) {
        setStage({}, 0);
        setNotice(QString("Stopped writing. %1 is only partly written and won't boot.").arg(m_flashDevice));
    } else if (const QString message = pkexecError(exitCode); !message.isEmpty()) {
        setStage({}, 0);
        setError(message);
    } else {
        setError(QString("Writing to %1 failed. The log shows why.").arg(m_flashDevice));
    }
    emit flashFinished(exitCode == 0);
}
