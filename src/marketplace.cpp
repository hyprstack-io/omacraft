#include "marketplace.h"

#include <QAtomicInt>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QNetworkDiskCache>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPointer>
#include <QRegularExpression>
#include <QTextDocumentFragment>
#include <QThreadPool>
#include <QUrl>

#include <algorithm>

#include "proc.h"
#include "plugins.h"

namespace {

const QString kPluginsHost = "https://plugins.omarchy.org/";
const QString kThemesHost = "https://omarchy.org";
const QUrl kCatalogUrl("https://plugins.omarchy.org/catalog.json");
const QUrl kThemesUrl("https://omarchy.org/themes");
constexpr qint64 kMaxDownload = 64 * 1024 * 1024;
constexpr int kFetchTimeoutMs = 60000;
constexpr int kToolTimeoutMs = 5 * 60 * 1000;
constexpr int kPerPage = 24;
constexpr qint64 kStaleSeconds = 6 * 60 * 60;

// Only pictures in the catalogue's own folders, so a listing can't send the
// window off to fetch from anywhere else.
QString pluginImage(const QString &path) {
    static const QRegularExpression allowed(R"(^assets/img/plugins/[A-Za-z0-9._-]+\.(webp|png|jpe?g)$)");
    return allowed.match(path).hasMatch() ? kPluginsHost + path : QString();
}

QString themeImage(const QString &path) {
    static const QRegularExpression allowed(R"(^/assets/themes/[A-Za-z0-9._-]+\.(webp|png|jpe?g)$)");
    return allowed.match(path).hasMatch() ? kThemesHost + path : QString();
}

// What git says a theme's folder was cloned from: its origin's URL.
QString originOf(const QString &folder) {
    QFile file(folder + "/.git/config");
    if (!file.open(QIODevice::ReadOnly))
        return {};
    static const QRegularExpression url(R"(\[remote "origin"\][^\[]*?url\s*=\s*(\S+))");
    return url.match(QString::fromUtf8(file.readAll())).captured(1);
}

} // namespace

QNetworkAccessManager *Marketplace::ImageCache::create(QObject *parent) {
    // One cache folder per manager: QML makes one for each thread it loads on.
    static QAtomicInt count;
    auto *manager = new QNetworkAccessManager(parent);
    auto *cache = new QNetworkDiskCache(manager);
    cache->setCacheDirectory(m_dir + "/" + QString::number(count.fetchAndAddRelaxed(1)));
    cache->setMaximumCacheSize(256 * 1024 * 1024);
    manager->setCache(cache);
    manager->setRedirectPolicy(QNetworkRequest::NoLessSafeRedirectPolicy);
    return manager;
}

Marketplace::Marketplace(const QString &home, bool runCommands, QObject *parent)
    : QObject(parent), m_home(home.isEmpty() ? QDir::homePath() : home), m_runCommands(runCommands),
      m_imageCache(m_home + "/.cache/omacraft/market/images") {
    m_network.setRedirectPolicy(QNetworkRequest::NoLessSafeRedirectPolicy);
}

QString Marketplace::cachePath(const QString &kind) const {
    return m_home + "/.cache/omacraft/market/" + (kind == "themes" ? "themes.html" : "catalog.json");
}

// ---------------------------------------------------------------- parsing

QString Marketplace::safeRepository(const QString &url) {
    static const QRegularExpression repository(R"(^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$)");
    QString out = url.trimmed();
    while (out.endsWith('/'))
        out.chop(1);
    if (out.endsWith(".git"))
        out.chop(4);
    if (!repository.match(out).hasMatch() || out.contains(".."))
        return {};
    return out;
}

QString Marketplace::themeNameFor(const QString &repository) {
    QString name = safeRepository(repository).section('/', -1).toLower();
    if (name.startsWith("omarchy-"))
        name.remove(0, 8);
    if (name.endsWith("-theme"))
        name.chop(6);
    static const QRegularExpression usable("^[a-z0-9_][a-z0-9._+-]*$");
    return usable.match(name).hasMatch() ? name : QString();
}

QString Marketplace::themeState(const QString &name, const QString &repository,
                                const QHash<QString, QString> &installed, const QString &current) {
    if (!installed.contains(name))
        return "available";
    if (safeRepository(installed.value(name)).compare(repository, Qt::CaseInsensitive) != 0)
        return "taken";
    return name == current ? "current" : "installed";
}

QList<Marketplace::Entry> Marketplace::parsePlugins(const QByteArray &json) {
    QList<Entry> out;
    const QJsonArray plugins = QJsonDocument::fromJson(json).object().value("plugins").toArray();
    out.reserve(plugins.size());
    for (const auto &value : plugins) {
        const QJsonObject p = value.toObject();
        const QString repo = safeRepository(p.value("repo").toString());
        const QString id = p.value("id").toString();
        // Built-in ones come with Omarchy, so there's nothing to fetch.
        if (repo.isEmpty() || id.isEmpty() || p.value("sourceType").toString() == "builtin")
            continue;
        QStringList tags;
        for (const auto &tag : p.value("tags").toArray())
            tags << tag.toString();
        const QString name = p.value("name").toString(id);
        const QString about = p.value("description").toString();
        const QString author = p.value("author").toString();
        Entry entry;
        entry.data = {{"id", id},
                      {"name", name},
                      {"description", about},
                      {"author", author},
                      {"category", p.value("category").toString()},
                      {"tags", tags},
                      {"kind", p.value("kind").toString()},
                      {"status", p.value("status").toString()},
                      {"repo", repo},
                      {"canInstall", p.value("installAvailable").toBool()},
                      {"note", p.value("installNote").toString()},
                      {"verified", p.value("verificationStatus").toString() == "verified"},
                      {"stars", p.value("stars").toInt()},
                      {"added", p.value("listedAt").toString(p.value("addedAt").toString())},
                      {"version", p.value("version").toString()},
                      {"license", p.value("license").toString()},
                      {"initials", p.value("initials").toString(name.left(2).toUpper())},
                      {"thumbnail", pluginImage(p.value("previewThumbnail").toString())},
                      {"image", pluginImage(p.value("previewImage").toString())}};
        entry.search = (name + ' ' + about + ' ' + author + ' ' + id + ' ' + tags.join(' ')).toLower();
        out << entry;
    }
    return out;
}

QList<Marketplace::Entry> Marketplace::parseThemes(const QByteArray &html) {
    // <a href="repo" ...><img src="/assets/themes/x.webp" alt="Name theme screenshot" ...
    static const QRegularExpression card(
        R"re(<a href="(https://github\.com/[^"]+)"[^>]*>\s*<img src="(/assets/themes/[^"]+)" alt="([^"]*?) theme screenshot")re");
    QList<Entry> out;
    QSet<QString> seen;
    const QString page = QString::fromUtf8(html);
    for (auto it = card.globalMatch(page); it.hasNext();) {
        const auto match = it.next();
        const QString repo = safeRepository(match.captured(1));
        const QString folder = themeNameFor(repo);
        if (repo.isEmpty() || folder.isEmpty() || seen.contains(repo))
            continue;
        seen.insert(repo);
        const QString name = QTextDocumentFragment::fromHtml(match.captured(3)).toPlainText();
        const QString author = repo.section('/', 3, 3);
        Entry entry;
        entry.data = {{"id", repo},
                      {"name", name},
                      {"folder", folder},
                      {"author", author},
                      {"repo", repo},
                      {"thumbnail", themeImage(match.captured(2))},
                      {"image", themeImage(match.captured(2))}};
        entry.search = (name + ' ' + author + ' ' + folder).toLower();
        out << entry;
    }
    return out;
}

// ---------------------------------------------------------------- loading

void Marketplace::readCache(const QString &kind) {
    QFile file(cachePath(kind));
    if (!entries(kind).isEmpty() || !file.open(QIODevice::ReadOnly))
        return;
    const QByteArray bytes = file.readAll();
    const QDateTime when = QFileInfo(file).lastModified();
    QPointer<Marketplace> self(this);
    m_fetching.insert(kind);
    QThreadPool::globalInstance()->start([self, kind, bytes, when] {
        const auto list = kind == "themes" ? parseThemes(bytes) : parsePlugins(bytes);
        if (self)
            QMetaObject::invokeMethod(self.data(), [self, kind, list, when] {
                if (!self) return;
                self->m_fetching.remove(kind);
                self->store(kind, list, when, false);
                if (list.isEmpty() || when.secsTo(QDateTime::currentDateTime()) > kStaleSeconds)
                    self->fetch(kind);
            }, Qt::QueuedConnection);
    });
}

void Marketplace::load(const QString &kind, bool force) {
    if (m_fetching.contains(kind))
        return;
    refresh();
    if (force) {
        fetch(kind);
    } else if (entries(kind).isEmpty()) {
        if (QFileInfo::exists(cachePath(kind)))
            readCache(kind);
        else
            fetch(kind);
    }
}

void Marketplace::fetch(const QString &kind) {
    if (!m_runCommands || m_fetching.contains(kind))
        return;
    m_fetching.insert(kind);
    m_problems.remove(kind);
    bump();
    QNetworkRequest request(kind == "themes" ? kThemesUrl : kCatalogUrl);
    request.setHeader(QNetworkRequest::UserAgentHeader, "OmaCraft/0.2");
    request.setTransferTimeout(kFetchTimeoutMs);
    QNetworkReply *reply = m_network.get(request);
    connect(reply, &QNetworkReply::downloadProgress, reply, [reply](qint64 received, qint64) {
        if (received > kMaxDownload)
            reply->abort();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, kind] {
        reply->deleteLater();
        const QByteArray bytes = reply->readAll();
        const QString failure = reply->error() == QNetworkReply::NoError ? QString() : reply->errorString();
        QPointer<Marketplace> self(this);
        const QString path = cachePath(kind);
        QThreadPool::globalInstance()->start([self, kind, bytes, failure, path] {
            const auto list = failure.isEmpty() ? (kind == "themes" ? parseThemes(bytes) : parsePlugins(bytes)) : QList<Entry>();
            // A page that no longer reads as it did mustn't replace a good copy.
            if (!list.isEmpty())
                Proc::writeAtomically(path, bytes);
            if (self)
                QMetaObject::invokeMethod(self.data(), [self, kind, list, failure] {
                    if (!self) return;
                    self->m_fetching.remove(kind);
                    if (list.isEmpty())
                        self->m_problems[kind] = failure.isEmpty()
                            ? "The catalogue came back in a form OmaCraft can't read." : failure;
                    self->store(kind, list, QDateTime::currentDateTime(), true);
                }, Qt::QueuedConnection);
        });
    });
}

void Marketplace::store(const QString &kind, const QList<Entry> &list, const QDateTime &when, bool keepOld) {
    if (!list.isEmpty() || !keepOld) {
        (kind == "themes" ? m_themes : m_catalog) = list;
        m_fetched[kind] = when;
    }
    bump();
}

QString Marketplace::age(const QString &kind) const {
    if (!m_fetched.contains(kind))
        return {};
    const qint64 seconds = m_fetched.value(kind).secsTo(QDateTime::currentDateTime());
    if (seconds < 90)
        return "just now";
    if (seconds < 5400)
        return QString("%1 minutes ago").arg(seconds / 60);
    if (seconds < 129600)
        return QString("%1 hours ago").arg(seconds / 3600);
    return QString("%1 days ago").arg(seconds / 86400);
}

void Marketplace::refresh() {
    readInstalledThemes();
    if (!m_runCommands)
        return bump();
    Proc::run(this, "omarchy", {"plugin", "list", "--json"}, [this](const Proc::Result &result) {
        if (result.ok()) {
            m_plugins.clear();
            for (const auto &value : QJsonDocument::fromJson(result.out).array()) {
                const QJsonObject plugin = value.toObject();
                m_plugins.insert(plugin.value("id").toString(), plugin.value("enabled").toBool());
            }
        }
        bump();
    });
}

void Marketplace::readInstalledThemes() {
    const QString root = m_home + "/.config/omarchy/themes";
    m_installed.clear();
    for (const QFileInfo &info : QDir(root).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot))
        m_installed.insert(info.fileName(), info.isSymLink() ? QString() : originOf(info.filePath()));
    QFile current(m_home + "/.local/state/omarchy/current/theme.name");
    m_currentTheme = current.open(QIODevice::ReadOnly) ? QString::fromUtf8(current.readAll()).trimmed() : QString();
}

// ---------------------------------------------------------------- browsing

QVariantMap Marketplace::withState(const QString &kind, QVariantMap item) const {
    if (kind == "themes") {
        const QString state = themeState(item.value("folder").toString(), item.value("repo").toString(), m_installed, m_currentTheme);
        item["state"] = state;
    } else {
        const QString id = item.value("id").toString();
        const bool have = m_plugins.contains(id);
        item["state"] = !have ? "available" : m_plugins.value(id) ? "enabled" : "disabled";
        // Plugin Suite looks after its own: their folders are often links.
        const auto ours = Plugins::definitions();
        item["managed"] = std::any_of(ours.cbegin(), ours.cend(), [&id](const Plugins::Definition &d) { return d.id == id; });
    }
    return item;
}

QVariantList Marketplace::categories() const {
    QMap<QString, int> counts;
    for (const Entry &entry : m_catalog)
        ++counts[entry.data.value("category").toString()];
    QVariantList out;
    for (auto it = counts.cbegin(); it != counts.cend(); ++it)
        if (!it.key().isEmpty())
            out << QVariantMap{{"id", it.key()}, {"name", it.key()}, {"count", it.value()}};
    return out;
}

QVariantMap Marketplace::browse(const QString &kind, const QString &query, const QString &category,
                                const QString &sort, const QString &filter, int page) const {
    const QStringList words = query.toLower().split(' ', Qt::SkipEmptyParts);
    QList<const Entry *> found;
    for (const Entry &entry : entries(kind)) {
        if (!category.isEmpty() && entry.data.value("category").toString() != category)
            continue;
        if (!std::all_of(words.cbegin(), words.cend(), [&entry](const QString &w) { return entry.search.contains(w); }))
            continue;
        if (filter == "verified" && !entry.data.value("verified").toBool())
            continue;
        if (filter == "installable" && !entry.data.value("canInstall").toBool())
            continue;
        if (filter == "installed" && withState(kind, entry.data).value("state").toString().contains("ailable"))
            continue;
        found << &entry;
    }
    const auto name = [](const Entry *e) { return e->data.value("name").toString().toLower(); };
    std::stable_sort(found.begin(), found.end(), [&](const Entry *a, const Entry *b) {
        if (sort == "stars" && a->data.value("stars").toInt() != b->data.value("stars").toInt())
            return a->data.value("stars").toInt() > b->data.value("stars").toInt();
        if (sort == "recent" && a->data.value("added").toString() != b->data.value("added").toString())
            return a->data.value("added").toString() > b->data.value("added").toString();
        return name(a) < name(b);
    });
    const int pages = std::max<int>(1, (found.size() + kPerPage - 1) / kPerPage);
    const int at = std::clamp(page, 1, pages);
    QVariantList items;
    for (qsizetype i = (at - 1) * kPerPage; i < found.size() && i < at * kPerPage; ++i)
        items << withState(kind, found.at(i)->data);
    return {{"items", items}, {"total", found.size()}, {"page", at}, {"pages", pages}};
}

const Marketplace::Entry *Marketplace::find(const QString &kind, const QString &key, const QString &field) const {
    for (const Entry &entry : entries(kind))
        if (entry.data.value(field).toString() == key)
            return &entry;
    return nullptr;
}

// ---------------------------------------------------------------- changing

bool Marketplace::ready(const QString &name) {
    if (!m_working.isEmpty()) {
        setError("Still working on " + m_working + ".");
        return false;
    }
    return !name.isEmpty();
}

void Marketplace::perform(const QString &name, const QString &program, const QStringList &arguments, const QString &doneNotice) {
    if (!m_runCommands)
        return;
    m_working = name;
    bump();
    Proc::run(this, program, arguments, [this, doneNotice](const Proc::Result &result) {
        m_working.clear();
        if (result.ok())
            setNotice(doneNotice);
        else
            setError(result.message());
        refresh();
        emit installedChanged();
    }, kToolTimeoutMs);
}

void Marketplace::installPlugin(const QString &id, bool enable) {
    const Entry *entry = find("plugins", id, "id");
    if (!ready(id) || !entry || !entry->data.value("canInstall").toBool())
        return;
    const QString repo = safeRepository(entry->data.value("repo").toString());
    if (repo.isEmpty())
        return setError("That listing's repository isn't one OmaCraft will fetch.");
    // --yes stands in for the prompt: the page has already shown the warning.
    QStringList arguments{"GIT_TERMINAL_PROMPT=0", "omarchy", "plugin", "add", repo + ".git", "--yes"};
    if (enable)
        arguments << "--enable";
    perform(id, "env", arguments, entry->data.value("name").toString() + (enable ? " is installed and on." : " is installed."));
}

void Marketplace::setPluginEnabled(const QString &id, bool on) {
    if (ready(id) && m_plugins.contains(id))
        perform(id, "omarchy", {"plugin", on ? "enable" : "disable", id}, id + (on ? " is on." : " is off."));
}

void Marketplace::updatePlugin(const QString &id) {
    if (ready(id) && m_plugins.contains(id))
        perform(id, "omarchy", {"plugin", "update", id, "--yes"}, id + " is up to date.");
}

void Marketplace::removePlugin(const QString &id) {
    if (!ready(id) || !m_plugins.contains(id))
        return;
    const auto ours = Plugins::definitions();
    if (std::any_of(ours.cbegin(), ours.cend(), [&id](const Plugins::Definition &d) { return d.id == id; }))
        return setError(id + " belongs to OmaCraft: remove it on the Plugin Suite page.");
    perform(id, "omarchy", {"plugin", "remove", id, "--yes"}, id + " is removed.");
}

void Marketplace::installTheme(const QString &name) {
    const Entry *entry = find("themes", name, "folder");
    if (!ready(name) || !entry)
        return;
    readInstalledThemes();
    // omarchy-theme-install deletes whatever has that folder, so only a free name goes through.
    if (m_installed.contains(name))
        return setError("A theme called " + name + " is already there, and installing would replace it.");
    perform(name, "env", {"GIT_TERMINAL_PROMPT=0", "omarchy-theme-install", entry->data.value("repo").toString() + ".git"},
            entry->data.value("name").toString() + " is installed and applied.");
}

void Marketplace::applyTheme(const QString &name) {
    if (ready(name) && m_installed.contains(name))
        perform(name, "omarchy-theme-set", {name}, name + " is applied.");
}

void Marketplace::updateTheme(const QString &name) {
    if (ready(name) && !m_installed.value(name).isEmpty())
        perform(name, "env", {"GIT_TERMINAL_PROMPT=0", "git", "-C", m_home + "/.config/omarchy/themes/" + name, "pull", "--ff-only"},
                name + " is up to date.");
}

void Marketplace::removeTheme(const QString &name) {
    if (!ready(name) || !m_installed.contains(name))
        return;
    if (name == m_currentTheme)
        return setError("That's the theme in use. Apply another one first.");
    perform(name, "omarchy-theme-remove", {name}, name + " is removed.");
}

void Marketplace::openRepository(const QString &url) {
    const QString repo = safeRepository(url);
    if (!repo.isEmpty())
        QDesktopServices::openUrl(QUrl(repo));
}

void Marketplace::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}

void Marketplace::bump() {
    ++m_revision;
    emit revisionChanged();
}

void Marketplace::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}

void Marketplace::setNotice(const QString &message) {
    m_notice = message;
    m_error.clear();
    emit messageChanged();
}
