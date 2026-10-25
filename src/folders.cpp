#include "folders.h"

#include <QCollator>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSet>
#include <QSettings>
#include <QStandardPaths>
#include <algorithm>

namespace {

const QStringList kSections{"left", "center", "right"};

QStringList defaultApplicationDirs(const QString &home) {
    QStringList dirs;
    const QString dataHome = qEnvironmentVariable("XDG_DATA_HOME", home + "/.local/share");
    dirs << dataHome + "/applications";
    const QString dataDirs = qEnvironmentVariable("XDG_DATA_DIRS", "/usr/local/share:/usr/share");
    for (const auto &dir : dataDirs.split(':', Qt::SkipEmptyParts))
        dirs << dir + "/applications";
    dirs.removeDuplicates();
    return dirs;
}

// The [Desktop Entry] group of a .desktop file, as key -> value.
QHash<QString, QString> desktopEntry(const QString &path) {
    QHash<QString, QString> out;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return out;
    bool inEntry = false;
    while (!file.atEnd()) {
        const QString line = QString::fromUtf8(file.readLine()).trimmed();
        if (line.startsWith('[')) {
            if (inEntry)
                break;
            inEntry = line == "[Desktop Entry]";
            continue;
        }
        if (!inEntry || line.isEmpty() || line.startsWith('#'))
            continue;
        const int eq = line.indexOf('=');
        if (eq > 0)
            out.insert(line.left(eq).trimmed(), line.mid(eq + 1).trimmed());
    }
    return out;
}

} // namespace

Folders::Folders(const QString &home, QStringList applicationDirs, QObject *parent)
    : QObject(parent),
      m_home(home.isEmpty() ? QDir::homePath() : home),
      m_applicationDirs(applicationDirs.isEmpty() ? defaultApplicationDirs(m_home) : std::move(applicationDirs)) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(150);
    connect(&m_debounce, &QTimer::timeout, this, &Folders::reload);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    reload();
}

QVariantList Folders::foldersIn(const QJsonObject &shell) {
    QVariantList out;
    const QJsonObject layout = shell.value("bar").toObject().value("layout").toObject();
    for (const auto &section : kSections) {
        const QJsonArray entries = layout.value(section).toArray();
        for (int i = 0; i < entries.size(); ++i) {
            const QJsonObject entry = entries.at(i).toObject();
            if (entry.value("id").toString() != kWidgetId)
                continue;
            QVariantMap folder = entry.toVariantMap();
            folder.insert("section", section);
            folder.insert("index", i);
            if (!folder.contains("name"))
                folder.insert("name", "Apps");
            if (!folder.value("apps").canConvert<QVariantList>())
                folder.insert("apps", QVariantList{});
            out.append(folder);
        }
    }
    return out;
}

QVariantList Folders::scanApplications(const QStringList &dirs) {
    QHash<QString, QVariantMap> found;
    QSet<QString> seen;
    for (const auto &dir : dirs) {
        QDirIterator it(dir, {"*.desktop"}, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString path = it.next();
            // The id is the path under applications/, with / as -.
            QString id = QDir(dir).relativeFilePath(path);
            id.chop(8);
            id.replace('/', '-');
            // The first folder that has an id decides it, hidden or not.
            if (seen.contains(id))
                continue;
            seen.insert(id);
            const auto entry = desktopEntry(path);
            if (entry.value("Type") != "Application" || entry.value("NoDisplay") == "true"
                || entry.value("Hidden") == "true" || entry.value("Name").isEmpty())
                continue;
            found.insert(id, QVariantMap{{"id", id},
                                         {"name", entry.value("Name")},
                                         {"icon", entry.value("Icon")},
                                         {"comment", entry.value("Comment", entry.value("GenericName"))}});
        }
    }
    QVariantList out;
    for (const auto &app : found)
        out.append(app);
    QCollator collator;
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(out.begin(), out.end(), [&collator](const QVariant &a, const QVariant &b) {
        return collator.compare(a.toMap().value("name").toString(), b.toMap().value("name").toString()) < 0;
    });
    return out;
}

QVariantList Folders::apps() {
    // Scanning every .desktop file takes a moment; only when first asked.
    // No appsChanged here: the binding asking is the one that would rerun.
    if (!m_appsLoaded) {
        m_apps = scanApplications(m_applicationDirs);
        m_appsLoaded = true;
    }
    return m_apps;
}

void Folders::reloadApps() {
    m_apps = scanApplications(m_applicationDirs);
    m_appsLoaded = true;
    emit appsChanged();
}

void Folders::watch() {
    const auto paths = m_watcher.files() + m_watcher.directories();
    if (!paths.isEmpty())
        m_watcher.removePaths(paths);
    for (const auto &path : {shellPath(), QFileInfo(shellPath()).absolutePath()})
        if (QFileInfo::exists(path))
            m_watcher.addPath(path);
}

void Folders::reload() {
    QFile file(shellPath());
    QJsonObject shell;
    if (file.open(QIODevice::ReadOnly))
        shell = QJsonDocument::fromJson(file.readAll()).object();
    const QVariantList folders = foldersIn(shell);
    if (folders != m_folders) {
        m_folders = folders;
        emit changed();
    }
    watch();
}

// ---------------------------------------------------------------- editing

bool Folders::mutate(const std::function<QString(QJsonObject &)> &edit) {
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
    const QString problem = edit(shell);
    if (!problem.isEmpty()) {
        setError(problem);
        return false;
    }
    // In place, not through a rename: the shell's file watcher stays on it.
    const QByteArray bytes = QJsonDocument(shell).toJson(QJsonDocument::Indented);
    if (!file.seek(0) || file.write(bytes) != bytes.size() || !file.resize(bytes.size())) {
        setError("Couldn't save " + shellPath() + ": " + file.errorString());
        return false;
    }
    file.close();
    if (!m_error.isEmpty()) {
        m_error.clear();
        emit messageChanged();
    }
    reload();
    return true;
}

QString Folders::folderAt(QJsonObject &shell, const QString &section, int index, QJsonObject *entry) {
    const QJsonArray entries = shell.value("bar").toObject().value("layout").toObject().value(section).toArray();
    if (index < 0 || index >= entries.size()
        || entries.at(index).toObject().value("id").toString() != kWidgetId)
        return "That folder moved on the bar in the meantime; try again.";
    *entry = entries.at(index).toObject();
    return {};
}

void Folders::putFolder(QJsonObject &shell, const QString &section, int index, const QJsonObject &entry) {
    QJsonObject bar = shell.value("bar").toObject();
    QJsonObject layout = bar.value("layout").toObject();
    QJsonArray entries = layout.value(section).toArray();
    entries.replace(index, entry);
    layout.insert(section, entries);
    bar.insert("layout", layout);
    shell.insert("bar", bar);
}

int Folders::add(const QString &name, const QString &section) {
    const QString where = kSections.contains(section) ? section : "right";
    int added = -1;
    mutate([&](QJsonObject &shell) -> QString {
        QJsonObject bar = shell.value("bar").toObject();
        QJsonObject layout = bar.value("layout").toObject();
        if (layout.isEmpty())
            return "shell.json has no bar layout yet. Open the bar once (omarchy bar defaults), then add folders.";
        QJsonArray entries = layout.value(where).toArray();
        entries.append(QJsonObject{{"id", kWidgetId},
                                   {"name", name.trimmed().isEmpty() ? "Apps" : name.trimmed()},
                                   {"icon", QString::fromUcs4(U"\U000F024B")},
                                   {"apps", QJsonArray{}}});
        added = entries.size() - 1;
        layout.insert(where, entries);
        bar.insert("layout", layout);
        shell.insert("bar", bar);
        return {};
    });
    return added;
}

void Folders::update(const QString &section, int index, const QVariantMap &changes) {
    static const QSet<QString> allowed{"name", "icon", "apps", "open", "side", "closeOnLaunch", "showLabel", "autoClose"};
    mutate([&](QJsonObject &shell) -> QString {
        QJsonObject entry;
        if (const QString problem = folderAt(shell, section, index, &entry); !problem.isEmpty())
            return problem;
        for (auto it = changes.begin(); it != changes.end(); ++it)
            if (allowed.contains(it.key()))
                entry.insert(it.key(), QJsonValue::fromVariant(it.value()));
        putFolder(shell, section, index, entry);
        return {};
    });
}

void Folders::remove(const QString &section, int index) {
    mutate([&](QJsonObject &shell) -> QString {
        QJsonObject entry;
        if (const QString problem = folderAt(shell, section, index, &entry); !problem.isEmpty())
            return problem;
        QJsonObject bar = shell.value("bar").toObject();
        QJsonObject layout = bar.value("layout").toObject();
        QJsonArray entries = layout.value(section).toArray();
        entries.removeAt(index);
        layout.insert(section, entries);
        bar.insert("layout", layout);
        shell.insert("bar", bar);
        return {};
    });
}

void Folders::moveTo(const QString &section, int index, const QString &toSection) {
    if (!kSections.contains(toSection) || toSection == section)
        return;
    mutate([&](QJsonObject &shell) -> QString {
        QJsonObject entry;
        if (const QString problem = folderAt(shell, section, index, &entry); !problem.isEmpty())
            return problem;
        QJsonObject bar = shell.value("bar").toObject();
        QJsonObject layout = bar.value("layout").toObject();
        QJsonArray from = layout.value(section).toArray();
        QJsonArray to = layout.value(toSection).toArray();
        from.removeAt(index);
        to.append(entry);
        layout.insert(section, from);
        layout.insert(toSection, to);
        bar.insert("layout", layout);
        shell.insert("bar", bar);
        return {};
    });
}

void Folders::shift(const QString &section, int index, int step) {
    mutate([&](QJsonObject &shell) -> QString {
        QJsonObject entry;
        if (const QString problem = folderAt(shell, section, index, &entry); !problem.isEmpty())
            return problem;
        QJsonObject bar = shell.value("bar").toObject();
        QJsonObject layout = bar.value("layout").toObject();
        QJsonArray entries = layout.value(section).toArray();
        const int target = std::clamp(index + (step < 0 ? -1 : 1), 0, int(entries.size()) - 1);
        if (target == index)
            return {};
        // Past whichever widget is next to it, whatever that is.
        const QJsonValue other = entries.at(target);
        entries.replace(target, entry);
        entries.replace(index, other);
        layout.insert(section, entries);
        bar.insert("layout", layout);
        shell.insert("bar", bar);
        return {};
    });
}

void Folders::addApp(const QString &section, int index, const QString &desktopId) {
    QString id = desktopId.trimmed();
    if (id.endsWith(".desktop"))
        id.chop(8);
    if (id.isEmpty())
        return;
    mutate([&](QJsonObject &shell) -> QString {
        QJsonObject entry;
        if (const QString problem = folderAt(shell, section, index, &entry); !problem.isEmpty())
            return problem;
        QJsonArray apps = entry.value("apps").toArray();
        for (const auto &app : apps)
            if (app.toString() == id)
                return {};
        apps.append(id);
        entry.insert("apps", apps);
        putFolder(shell, section, index, entry);
        return {};
    });
}

void Folders::addCommand(const QString &section, int index, const QString &name, const QString &icon,
                         const QString &command) {
    if (command.trimmed().isEmpty())
        return;
    mutate([&](QJsonObject &shell) -> QString {
        QJsonObject entry;
        if (const QString problem = folderAt(shell, section, index, &entry); !problem.isEmpty())
            return problem;
        QJsonArray apps = entry.value("apps").toArray();
        apps.append(QJsonObject{{"name", name.trimmed().isEmpty() ? command.trimmed() : name.trimmed()},
                                {"icon", icon.trimmed().isEmpty() ? "utilities-terminal" : icon.trimmed()},
                                {"command", command.trimmed()}});
        entry.insert("apps", apps);
        putFolder(shell, section, index, entry);
        return {};
    });
}

void Folders::removeApp(const QString &section, int index, int appIndex) {
    mutate([&](QJsonObject &shell) -> QString {
        QJsonObject entry;
        if (const QString problem = folderAt(shell, section, index, &entry); !problem.isEmpty())
            return problem;
        QJsonArray apps = entry.value("apps").toArray();
        if (appIndex < 0 || appIndex >= apps.size())
            return {};
        apps.removeAt(appIndex);
        entry.insert("apps", apps);
        putFolder(shell, section, index, entry);
        return {};
    });
}

void Folders::moveApp(const QString &section, int index, int appIndex, int step) {
    mutate([&](QJsonObject &shell) -> QString {
        QJsonObject entry;
        if (const QString problem = folderAt(shell, section, index, &entry); !problem.isEmpty())
            return problem;
        QJsonArray apps = entry.value("apps").toArray();
        const int target = appIndex + (step < 0 ? -1 : 1);
        if (appIndex < 0 || appIndex >= apps.size() || target < 0 || target >= apps.size())
            return {};
        const QJsonValue moving = apps.at(appIndex);
        apps.replace(appIndex, apps.at(target));
        apps.replace(target, moving);
        entry.insert("apps", apps);
        putFolder(shell, section, index, entry);
        return {};
    });
}

void Folders::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}

void Folders::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}
