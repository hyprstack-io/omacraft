#include "wallpaper.h"

#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonValue>
#include <QProcess>
#include <QRegularExpression>
#include <QSet>
#include <QUrl>

#include "filepicker.h"
#include "proc.h"

namespace {

// Wallhaven allows 45 API requests a minute; one page per 1.5 s stays under.
constexpr int kPageGapMs = 1500;
// One search's results stop growing here, to bound memory and the thumb cache.
constexpr int kMaxPages = 40;

// The programs behind each colour scheme, and their Arch packages.
struct Tool {
    const char *scheme;
    const char *program;
    const char *package;
    bool aur;
};
constexpr Tool kTools[] = {
    {"pywal", "wal", "python-pywal16", true},
    {"matugen", "matugen", "matugen", false},
    {"flavours", "flavours", "flavours", true},
};

QString cleanMessage(QString message) {
    message.remove(QRegularExpression("^hyprskin:\\s*"));
    return message.trimmed();
}

} // namespace

Wallpaper::Wallpaper(std::function<QString()> pluginDir, FilePicker *picker, bool runCommands, QObject *parent)
    : QObject(parent), m_pluginDir(std::move(pluginDir)), m_picker(picker), m_runCommands(runCommands) {
    m_wasAvailable = available();
    if (m_picker)
        connect(m_picker, &FilePicker::folderSelected, this, [this](const QString &purpose, const QUrl &url) {
            if (purpose != "wallpaper-folder" || !url.isLocalFile())
                return;
            m_queue.append({{"folder", "add", url.toLocalFile()}, "Couldn't add the folder"});
            pumpQueue();
        });

    // The auto-change timer and the Studio hub change the wallpaper behind
    // OmaCraft's back; a light poll keeps the page honest.
    m_poll.setInterval(5000);
    connect(&m_poll, &QTimer::timeout, this, &Wallpaper::refresh);
    if (m_runCommands)
        m_poll.start();
}

Wallpaper::~Wallpaper() {
    // hyprskin calls still running finish here, while this object can still
    // take their answers; QObject's own cleanup would deliver them to a
    // half-destroyed Wallpaper.
    m_poll.stop();
    for (auto *process : findChildren<QProcess *>(Qt::FindDirectChildrenOnly)) {
        process->disconnect();
        process->kill();
        process->waitForFinished(1000);
        delete process;
    }
}

QString Wallpaper::script() const {
    const QString dir = m_pluginDir ? m_pluginDir() : QString();
    if (dir.isEmpty())
        return {};
    const QString path = dir + "/bin/hyprskin";
    return QFileInfo::exists(path) ? path : QString();
}

bool Wallpaper::moreResults() const {
    return m_searched && !m_results.isEmpty() && m_page < m_lastPage && m_page < kMaxPages;
}

QVariantMap Wallpaper::favoriteKeys() const {
    QVariantMap keys;
    for (const auto &entry : m_favorites)
        keys.insert(entry.toMap().value("key").toString(), true);
    return keys;
}

QString Wallpaper::favoriteKey(const QString &target) {
    static const QRegularExpression file("^wallhaven-([a-z0-9]+)\\.\\w+$");
    static const QRegularExpression page("wallhaven\\.cc/w/([a-z0-9]+)");
    static const QRegularExpression id("^[a-z0-9]{6,8}$");
    const QString name = target.contains("://") ? QUrl(target).fileName() : QFileInfo(target).fileName();
    if (auto m = file.match(name); m.hasMatch())
        return m.captured(1);
    if (auto m = page.match(target); m.hasMatch())
        return m.captured(1);
    if (id.match(target).hasMatch())
        return target;
    const QString path = Proc::expandHome(target, QDir::homePath());
    const QString canonical = QFileInfo(path).canonicalFilePath();
    return canonical.isEmpty() ? QFileInfo(path).absoluteFilePath() : canonical;
}

QVariantList Wallpaper::mergeResults(const QVariantList &shown, const QVariantList &incoming, bool restart) {
    QVariantList out = restart ? QVariantList{} : shown;
    QSet<QString> seen;
    for (const auto &entry : out)
        seen.insert(entry.toMap().value("id").toString());
    for (const auto &entry : incoming) {
        const QString id = entry.toMap().value("id").toString();
        if (id.isEmpty() || seen.contains(id))
            continue;
        seen.insert(id);
        out.append(entry);
    }
    return out;
}

bool Wallpaper::isFavorite(const QString &target) const {
    const QString key = favoriteKey(target);
    for (const auto &entry : m_favorites)
        if (entry.toMap().value("key").toString() == key)
            return true;
    return false;
}

// ---------------------------------------------------------------- running

void Wallpaper::run(const QStringList &arguments,
                    std::function<void(bool, const QByteArray &, const QString &)> done, int timeoutMs) {
    const QString path = script();
    if (path.isEmpty() || !m_runCommands) {
        if (done)
            done(false, {}, "The Studio plugin's hyprskin command wasn't found");
        return;
    }
    Proc::run(this, "python3", QStringList{path} + arguments, [done](const Proc::Result &result) {
        if (done)
            done(result.ok(), result.out, cleanMessage(result.message()));
    }, timeoutMs);
}

void Wallpaper::refresh() {
    if (available() != m_wasAvailable) {
        m_wasAvailable = available();
        emit availableChanged();
    }
    if (!available() || m_statusRunning)
        return;
    m_statusRunning = true;
    run({"status", "--json"}, [this](bool ok, const QByteArray &out, const QString &) {
        if (ok) {
            const QVariantMap status = QJsonDocument::fromJson(out).toVariant().toMap();
            if (!status.isEmpty() && status != m_status) {
                m_status = status;
                emit statusChanged();
            }
        }
        run({"targets", "--json"}, [this](bool ok, const QByteArray &out, const QString &) {
            m_statusRunning = false;
            if (!ok)
                return;
            const QVariantMap info = QJsonDocument::fromJson(out).toVariant().toMap();
            if (!info.isEmpty() && info != m_targetInfo) {
                m_targetInfo = info;
                emit statusChanged();
            }
        });
    }, 20000);
}

// ---------------------------------------------------------------- Wallhaven

void Wallpaper::search(const QVariantMap &form) {
    m_form = form;
    if (m_searching) {
        m_searchPending = true;
        return;
    }
    m_seed.clear();
    m_page = 0;
    m_lastPage = 1;
    runSearch(1);
}

void Wallpaper::loadMore() {
    if (!m_searching && moreResults())
        runSearch(m_page + 1);
}

void Wallpaper::runSearch(int page) {
    QStringList args{"search", "--json", "--page", QString::number(page)};
    const QList<QPair<QString, QString>> flags{
        {"--query", "query"}, {"--sorting", "sorting"}, {"--top-range", "topRange"},
        {"--categories", "categories"}, {"--purity", "purity"}, {"--atleast", "atleast"},
        {"--ratios", "ratios"}, {"--color", "color"}};
    for (const auto &[flag, key] : flags)
        if (m_form.contains(key))
            args << flag << m_form.value(key).toString();
    if (!m_seed.isEmpty())
        args << "--seed" << m_seed;

    m_searching = true;
    emit busyChanged();
    run(args, [this, page](bool ok, const QByteArray &out, const QString &message) {
        m_searching = false;
        if (m_searchPending) {
            m_searchPending = false;
            emit busyChanged();
            search(m_form);
            return;
        }
        m_searched = true;
        if (!ok) {
            setError(message.isEmpty() ? "The Wallhaven search failed" : message);
        } else {
            const QVariantMap data = QJsonDocument::fromJson(out).toVariant().toMap();
            m_results = mergeResults(m_results, data.value("results").toList(), page == 1);
            m_seed = data.value("seed").toString();
            m_page = data.value("page", page).toInt();
            m_lastPage = data.value("lastPage", page).toInt();
            m_total = data.value("total").toInt();
        }
        emit resultsChanged();
        emit busyChanged();
        // Keep the grid filling while there's more, inside the rate limit.
        if (ok && moreResults() && m_results.size() < 96)
            QTimer::singleShot(kPageGapMs, this, &Wallpaper::loadMore);
    });
}

// ---------------------------------------------------------------- library, favourites

void Wallpaper::refreshLibrary() {
    run({"library", "--json"}, [this](bool ok, const QByteArray &out, const QString &) {
        if (!ok)
            return;
        m_library = QJsonDocument::fromJson(out).toVariant().toList();
        emit libraryChanged();
    });
}

void Wallpaper::refreshFavorites() {
    run({"favorites", "--json"}, [this](bool ok, const QByteArray &out, const QString &) {
        // A heart clicked while this ran is still queued; keep what's shown.
        if (!ok || m_queueRunning || !m_queue.isEmpty())
            return;
        m_favorites = QJsonDocument::fromJson(out).toVariant().toList();
        emit favoritesChanged();
    });
}

void Wallpaper::toggleFavorite(const QString &target, const QVariantMap &meta) {
    const QString key = favoriteKey(target);
    const bool on = !isFavorite(target);
    // Flip it straight away, so the heart answers under the cursor.
    if (on) {
        QVariantMap entry{{"key", key}, {"target", target}, {"local", meta.isEmpty()},
                          {"thumb", meta.value("thumb", target)}};
        m_favorites.prepend(entry);
    } else {
        for (int i = m_favorites.size() - 1; i >= 0; --i)
            if (m_favorites[i].toMap().value("key").toString() == key)
                m_favorites.removeAt(i);
    }
    emit favoritesChanged();

    QVariantMap kept;
    for (const char *field : {"full", "thumbRemote", "url", "resolution", "colors"})
        if (meta.contains(field))
            kept.insert(field, meta.value(field));
    m_queue.append({{"favorite", on ? "add" : "remove", target, "--meta",
                     QString::fromUtf8(QJsonDocument::fromVariant(kept).toJson(QJsonDocument::Compact))},
                    "Couldn't update favourites"});
    pumpQueue();
}

void Wallpaper::deleteFromLibrary(const QString &path) {
    for (int i = m_library.size() - 1; i >= 0; --i)
        if (m_library[i].toMap().value("path").toString() == path)
            m_library.removeAt(i);
    emit libraryChanged();
    m_queue.append({{"delete", path}, "Couldn't delete " + QFileInfo(path).fileName()});
    pumpQueue();
}

// ---------------------------------------------------------------- your folders

void Wallpaper::localSearch(const QString &query, const QString &sort, bool rescan) {
    m_localQuery = query.trimmed();
    m_localSort = sort.isEmpty() ? "newest" : sort;
    m_localRescan = m_localRescan || rescan;
    if (m_scanning) {
        m_localPending = true;
        return;
    }
    m_localSeed.clear();
    runLocal(1);
}

void Wallpaper::loadMoreLocal() {
    if (!m_scanning && moreLocal())
        runLocal(m_localPage + 1);
}

void Wallpaper::runLocal(int page) {
    QStringList args{"local", "--json", "--query", m_localQuery, "--sort", m_localSort, "--page", QString::number(page)};
    if (!m_localSeed.isEmpty())
        args << "--seed" << m_localSeed;
    if (m_localRescan && page == 1) {
        args << "--refresh";
        m_localRescan = false;
    }
    m_scanning = true;
    emit busyChanged();
    run(args, [this, page](bool ok, const QByteArray &out, const QString &message) {
        m_scanning = false;
        if (m_localPending) {
            m_localPending = false;
            emit busyChanged();
            localSearch(m_localQuery, m_localSort);
            return;
        }
        m_localSearched = true;
        if (!ok) {
            setError(message.isEmpty() ? "Couldn't read your wallpaper folders" : message);
        } else {
            const QVariantMap data = QJsonDocument::fromJson(out).toVariant().toMap();
            const QVariantList incoming = data.value("results").toList();
            m_localResults = page == 1 ? incoming : m_localResults + incoming;
            m_localSeed = data.value("seed").toString();
            m_localPage = data.value("page", page).toInt();
            m_localLastPage = data.value("lastPage", page).toInt();
            m_localTotal = data.value("total").toInt();
            const QStringList missing = data.value("missing").toStringList();
            if (!missing.isEmpty())
                setError("Folder not found: " + missing.join(", "));
        }
        emit localChanged();
        emit busyChanged();
        // Local pages cost nothing to fetch, so they stream in.
        if (ok && moreLocal() && m_localResults.size() < 480)
            QTimer::singleShot(200, this, &Wallpaper::loadMoreLocal);
    }, 300000);
}

void Wallpaper::addFolder() {
    if (m_picker)
        m_picker->chooseFolder("wallpaper-folder", "Add a wallpaper folder", QDir::homePath() + "/Pictures");
}

void Wallpaper::removeFolder(const QString &path) {
    m_queue.append({{"folder", "remove", path}, "Couldn't remove the folder"});
    pumpQueue();
}

// ---------------------------------------------------------------- applying

void Wallpaper::apply(const QString &target, bool withColors) {
    if (applying() || target.isEmpty())
        return;
    m_busyTarget = target;
    emit busyChanged();
    QStringList args{"apply", target};
    if (!withColors)
        args << "--no-theme";
    run(args, [this](bool ok, const QByteArray &, const QString &message) {
        m_busyTarget.clear();
        emit busyChanged();
        if (!ok)
            setError(message.isEmpty() ? "Couldn't set the wallpaper" : message);
        refresh();
        refreshLibrary();
        refreshFavorites();
    }, 180000);
}

void Wallpaper::next() {
    if (applying())
        return;
    m_busyTarget = "next";
    emit busyChanged();
    run({"next"}, [this](bool ok, const QByteArray &, const QString &message) {
        m_busyTarget.clear();
        emit busyChanged();
        if (!ok)
            setError(message.isEmpty() ? "Couldn't change the wallpaper" : message);
        refresh();
        refreshLibrary();
    }, 180000);
}

void Wallpaper::retheme() {
    if (applying())
        return;
    m_busyTarget = "theme";
    emit busyChanged();
    run({"theme"}, [this](bool ok, const QByteArray &, const QString &message) {
        m_busyTarget.clear();
        emit busyChanged();
        if (!ok) {
            setError(message.isEmpty() ? "Couldn't build the colours" : message);
        } else {
            setNotice("Omarchy now follows the wallpaper's colours.");
        }
        refresh();
    }, 180000);
}

void Wallpaper::setOption(const QString &key, const QVariant &value, bool retheme) {
    const QString json = QString::fromUtf8(QJsonDocument::fromVariant(QVariantList{value}).toJson(QJsonDocument::Compact));
    // fromVariant needs a container; take the value back out of "[...]".
    m_queue.append({{"set", key, json.mid(1, json.size() - 2)}, "Couldn't save " + key, retheme});
    pumpQueue();
}

void Wallpaper::pumpQueue() {
    if (m_queueRunning || m_queue.isEmpty())
        return;
    const Job job = m_queue.takeFirst();
    m_queueRunning = true;
    run(job.arguments, [this, job](bool ok, const QByteArray &, const QString &message) {
        m_queueRunning = false;
        if (!ok)
            setError(message.isEmpty() ? job.failure : job.failure + ": " + message);
        const QString verb = job.arguments.value(0);
        if (!m_queue.isEmpty()) {
            pumpQueue();
        } else {
            if (verb == "favorite")
                refreshFavorites();
            if (verb == "delete")
                refreshLibrary();
            if (verb == "folder")
                localSearch(m_localQuery, m_localSort, true);
        }
        // Colour settings show on screen only after a rebuild; do it once
        // the last queued change is saved, and only while the wallpaper's
        // colours are the theme (otherwise the next wallpaper uses them).
        const bool live = m_status.value("themeIsDynamic").toBool()
                          || m_status.value("settings").toMap().value("dynamicColors").toBool();
        if (ok && job.retheme && live && m_queue.isEmpty())
            retheme();
        else
            refresh();
    });
}

void Wallpaper::showInFiles(const QString &path) {
    Proc::detach("xdg-open", {QFileInfo(path).absolutePath()});
}

void Wallpaper::openUrl(const QString &url) {
    if (!url.isEmpty())
        Proc::detach("xdg-open", {url});
}

void Wallpaper::installTool(const QString &scheme) {
    for (const auto &tool : kTools) {
        if (scheme != tool.scheme)
            continue;
        const QString command = QString("omarchy pkg %1add %2 && echo && echo 'Done. Back in OmaCraft, rebuild the colours.' && read -r -p 'Press Enter to close' _")
                                    .arg(tool.aur ? "aur " : "", tool.package);
        if (!Proc::inTerminal(command))
            setError(QString("Couldn't open a terminal. Install %1 with: omarchy pkg %2add %1").arg(tool.package, tool.aur ? "aur " : ""));
        else
            setNotice(QString("Installing %1 in a terminal. Rebuild the colours once it's done.").arg(tool.package));
        return;
    }
}

void Wallpaper::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}

void Wallpaper::setNotice(const QString &message) {
    m_notice = message;
    m_error.clear();
    emit messageChanged();
}

void Wallpaper::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}
