#pragma once

#include <QDateTime>
#include <QHash>
#include <QList>
#include <QNetworkAccessManager>
#include <QObject>
#include <QQmlNetworkAccessManagerFactory>
#include <QSet>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

// Omarchy's two community catalogues, browsed in OmaCraft:
//
//   plugins  https://plugins.omarchy.org/catalog.json
//   themes   https://omarchy.org/themes, which is a page, so it's read for its
//            links: there is no catalogue file behind it
//
// A copy of each is kept in ~/.cache/omacraft/market and shown at once, then
// refreshed from the network when it's old. Installing goes through Omarchy's
// own tools, which check the URL, clone, validate and place what they fetch:
// `omarchy plugin add|remove|update|enable|disable`, `omarchy-theme-install`,
// `omarchy-theme-set` and `omarchy-theme-remove`. Everything the catalogues
// say is treated as untrusted: only https GitHub repositories and images on
// Omarchy's own hosts get through, and the page draws their text as plain text.
class Marketplace : public QObject {
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)
    Q_PROPERTY(QString working READ working NOTIFY revisionChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    struct Entry {
        QVariantMap data;
        QString search; // lower case: what a query looks through
    };

    // The disk cache behind the catalogues' pictures, for QML's Image.
    class ImageCache : public QQmlNetworkAccessManagerFactory {
    public:
        explicit ImageCache(const QString &dir) : m_dir(dir) {}
        QNetworkAccessManager *create(QObject *parent) override;

    private:
        QString m_dir;
    };

    // home: tests pass a temp directory and set runCommands to false.
    explicit Marketplace(const QString &home = {}, bool runCommands = true, QObject *parent = nullptr);

    int revision() const { return m_revision; }
    // What's being installed or changed right now, by id or theme name.
    QString working() const { return m_working; }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }
    ImageCache &imageCache() { return m_imageCache; }

    // kind: plugins or themes. Reads the cached copy, then fetches when it's
    // old or force is set. Does nothing while a fetch is under way.
    Q_INVOKABLE void load(const QString &kind, bool force = false);
    Q_INVOKABLE bool loading(const QString &kind) const { return m_fetching.contains(kind); }
    Q_INVOKABLE bool loaded(const QString &kind) const { return !entries(kind).isEmpty(); }
    // Why the last fetch failed, or "".
    Q_INVOKABLE QString problem(const QString &kind) const { return m_problems.value(kind); }
    // When the list on show was fetched, as "2 hours ago", or "".
    Q_INVOKABLE QString age(const QString &kind) const;
    // Plugin categories with how many are in each: {id, name}.
    Q_INVOKABLE QVariantList categories() const;
    // One page of what matches: {items, total, page, pages}. sort: stars,
    // recent or name. filter: all, verified, installable or installed.
    Q_INVOKABLE QVariantMap browse(const QString &kind, const QString &query, const QString &category,
                                   const QString &sort, const QString &filter, int page) const;

    Q_INVOKABLE void installPlugin(const QString &id, bool enable);
    Q_INVOKABLE void setPluginEnabled(const QString &id, bool on);
    Q_INVOKABLE void updatePlugin(const QString &id);
    Q_INVOKABLE void removePlugin(const QString &id);
    // Installing also applies it: that's what omarchy-theme-install does.
    Q_INVOKABLE void installTheme(const QString &name);
    Q_INVOKABLE void applyTheme(const QString &name);
    Q_INVOKABLE void updateTheme(const QString &name);
    Q_INVOKABLE void removeTheme(const QString &name);
    Q_INVOKABLE void openRepository(const QString &url);
    // Reads what's installed again.
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void dismissMessages();

    static QList<Entry> parsePlugins(const QByteArray &json);
    static QList<Entry> parseThemes(const QByteArray &html);
    // The folder omarchy-theme-install clones a repository into, or "" when
    // it would refuse the name.
    static QString themeNameFor(const QString &repository);
    // An https GitHub repository's URL without trailing slash or .git, or ""
    // if it's anything else.
    static QString safeRepository(const QString &url);
    // available, installed, current or taken: taken means another theme has
    // that folder, which installing would delete.
    static QString themeState(const QString &name, const QString &repository, const QHash<QString, QString> &installed,
                              const QString &current);
    // Filled in tests; otherwise from `omarchy plugin list --json`.
    void setInstalledPlugins(const QHash<QString, bool> &enabled) { m_plugins = enabled; }

signals:
    void revisionChanged();
    void messageChanged();
    // A plugin came, went or was switched.
    void installedChanged();

private:
    const QList<Entry> &entries(const QString &kind) const { return kind == "themes" ? m_themes : m_catalog; }
    QString cachePath(const QString &kind) const;
    void readCache(const QString &kind);
    void fetch(const QString &kind);
    void store(const QString &kind, const QList<Entry> &list, const QDateTime &when, bool keepOld);
    void readInstalledThemes();
    QVariantMap withState(const QString &kind, QVariantMap item) const;
    const Entry *find(const QString &kind, const QString &key, const QString &field) const;
    // Runs one tool for name; nothing else starts until it's done.
    void perform(const QString &name, const QString &program, const QStringList &arguments, const QString &doneNotice);
    bool ready(const QString &name);
    void bump();
    void setError(const QString &message);
    void setNotice(const QString &message);

    QString m_home;
    bool m_runCommands;
    ImageCache m_imageCache;
    QNetworkAccessManager m_network;
    QList<Entry> m_catalog;
    QList<Entry> m_themes;
    QHash<QString, QDateTime> m_fetched;
    QSet<QString> m_fetching;
    QHash<QString, QString> m_problems;
    QHash<QString, bool> m_plugins;        // id to enabled
    QHash<QString, QString> m_installed;   // theme folder to its origin URL
    QString m_currentTheme;
    int m_revision = 0;
    QString m_working;
    QString m_error;
    QString m_notice;
};
