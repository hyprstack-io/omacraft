#pragma once

#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <functional>

class FilePicker;

// Wallpapers and the colours they give the desktop, from the Studio plugin's
// hyprskin command: Wallhaven search, the downloaded library, your own
// folders, favourites, and the wallpaper-driven theme (Material, matugen,
// wallbash, pywal, flavours) that recolours all of Omarchy. Every read and
// write goes through hyprskin, so OmaCraft and the Studio hub always agree;
// the shell's Studio service draws the wallpaper and its transitions.
class Wallpaper : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(QVariantMap status READ status NOTIFY statusChanged)
    Q_PROPERTY(QVariantMap targetInfo READ targetInfo NOTIFY statusChanged)

    Q_PROPERTY(QVariantList results READ results NOTIFY resultsChanged)
    Q_PROPERTY(bool searching READ searching NOTIFY busyChanged)
    Q_PROPERTY(bool searched READ searched NOTIFY resultsChanged)
    Q_PROPERTY(int total READ total NOTIFY resultsChanged)
    Q_PROPERTY(bool moreResults READ moreResults NOTIFY resultsChanged)

    Q_PROPERTY(QVariantList library READ library NOTIFY libraryChanged)
    Q_PROPERTY(QVariantList favorites READ favorites NOTIFY favoritesChanged)
    Q_PROPERTY(QVariantMap favoriteKeys READ favoriteKeys NOTIFY favoritesChanged)

    Q_PROPERTY(QVariantList localResults READ localResults NOTIFY localChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY busyChanged)
    Q_PROPERTY(int localTotal READ localTotal NOTIFY localChanged)
    Q_PROPERTY(bool moreLocal READ moreLocal NOTIFY localChanged)

    Q_PROPERTY(QString busyTarget READ busyTarget NOTIFY busyChanged)
    Q_PROPERTY(bool applying READ applying NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    explicit Wallpaper(std::function<QString()> pluginDir, FilePicker *picker = nullptr, bool runCommands = true,
                       QObject *parent = nullptr);
    ~Wallpaper() override;

    bool available() const { return !script().isEmpty(); }
    QString script() const;
    QVariantMap status() const { return m_status; }
    QVariantMap targetInfo() const { return m_targetInfo; }

    QVariantList results() const { return m_results; }
    bool searching() const { return m_searching; }
    bool searched() const { return m_searched; }
    int total() const { return m_total; }
    bool moreResults() const;

    QVariantList library() const { return m_library; }
    QVariantList favorites() const { return m_favorites; }
    QVariantMap favoriteKeys() const;

    QVariantList localResults() const { return m_localResults; }
    bool scanning() const { return m_scanning; }
    int localTotal() const { return m_localTotal; }
    bool moreLocal() const { return m_localSearched && !m_localResults.isEmpty() && m_localPage < m_localLastPage; }

    QString busyTarget() const { return m_busyTarget; }
    bool applying() const { return !m_busyTarget.isEmpty(); }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }

    // What a Wallhaven wallpaper is known by, whether given its id, its page,
    // or the file it was downloaded to; anything else by its path. The same
    // rule as hyprskin's, so one heart covers all three.
    static QString favoriteKey(const QString &target);
    // One page of `hyprskin search --json` added to what's shown, without
    // repeats (toplists shift between pages).
    static QVariantList mergeResults(const QVariantList &shown, const QVariantList &incoming, bool restart);

    Q_INVOKABLE void refresh();
    // form: query, sorting, topRange, categories, purity, atleast, ratios, color.
    Q_INVOKABLE void search(const QVariantMap &form);
    Q_INVOKABLE void loadMore();
    Q_INVOKABLE void refreshLibrary();
    Q_INVOKABLE void refreshFavorites();
    Q_INVOKABLE void localSearch(const QString &query, const QString &sort, bool rescan = false);
    Q_INVOKABLE void loadMoreLocal();

    // A Wallhaven id, its URL, or a file. withColors false keeps the theme.
    Q_INVOKABLE void apply(const QString &target, bool withColors = true);
    Q_INVOKABLE void next();
    // Rebuild the theme from the current wallpaper with the colour settings.
    Q_INVOKABLE void retheme();
    Q_INVOKABLE void deleteFromLibrary(const QString &path);
    Q_INVOKABLE bool isFavorite(const QString &target) const;
    // meta: the search result, so a favourite keeps its preview.
    Q_INVOKABLE void toggleFavorite(const QString &target, const QVariantMap &meta = {});
    // key like "palette.scheme"; value is written as JSON. retheme rebuilds
    // the theme afterwards when wallpaper colours are in use.
    Q_INVOKABLE void setOption(const QString &key, const QVariant &value, bool retheme = false);
    Q_INVOKABLE void addFolder();
    Q_INVOKABLE void removeFolder(const QString &path);
    Q_INVOKABLE void showInFiles(const QString &path);
    Q_INVOKABLE void openUrl(const QString &url);
    // Installs the program behind a colour scheme: pywal, matugen or flavours.
    Q_INVOKABLE void installTool(const QString &scheme);
    Q_INVOKABLE void dismissMessages();

signals:
    void availableChanged();
    void statusChanged();
    void resultsChanged();
    void libraryChanged();
    void favoritesChanged();
    void localChanged();
    void busyChanged();
    void messageChanged();

private:
    void run(const QStringList &arguments, std::function<void(bool ok, const QByteArray &out, const QString &message)> done,
             int timeoutMs = 120000);
    void runSearch(int page);
    void runLocal(int page);
    void pumpQueue();
    void setError(const QString &message);
    void setNotice(const QString &message);

    std::function<QString()> m_pluginDir;
    FilePicker *m_picker;
    bool m_runCommands;
    bool m_wasAvailable = false;

    QVariantMap m_status;
    QVariantMap m_targetInfo;
    bool m_statusRunning = false;

    QVariantMap m_form;
    QVariantList m_results;
    QString m_seed;
    int m_page = 0;
    int m_lastPage = 1;
    int m_total = 0;
    bool m_searching = false;
    bool m_searched = false;
    bool m_searchPending = false;

    QVariantList m_library;
    QVariantList m_favorites;

    QString m_localQuery;
    QString m_localSort = "newest";
    QVariantList m_localResults;
    QString m_localSeed;
    int m_localPage = 0;
    int m_localLastPage = 1;
    int m_localTotal = 0;
    bool m_scanning = false;
    bool m_localSearched = false;
    bool m_localPending = false;
    bool m_localRescan = false;

    // Writes (settings, favourites, deletes) run one at a time, in order, so
    // quick clicks can't overwrite each other's change to the same file.
    struct Job {
        QStringList arguments;
        QString failure;
        bool retheme = false;
    };
    QList<Job> m_queue;
    bool m_queueRunning = false;

    QString m_busyTarget;
    QString m_error;
    QString m_notice;
    QTimer m_poll;
};
