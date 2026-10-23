#pragma once

#include <QObject>
#include <QStringList>
#include <QWebEngineUrlSchemeHandler>
#include <functional>

// HyprCraft is a React app. Its plugin hosts it in a separate PyQt process
// because the shell can't embed QtWebEngine; OmaCraft is a normal Qt app, so
// it shows the same build in a WebEngineView, served from disk through the
// private hyprcraft:// scheme (module scripts don't load from file://).
class HyprCraft : public QWebEngineUrlSchemeHandler {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(QString appDir READ appDir NOTIFY changed)
    Q_PROPERTY(QString url READ url CONSTANT)
    Q_PROPERTY(QString storagePath READ storagePath CONSTANT)
    Q_PROPERTY(QString downloadDir READ downloadDir CONSTANT)
    // The last Omarchy bundle downloaded (…-omarchy.zip), until it's installed.
    Q_PROPERTY(QString bundle READ bundle NOTIFY bundleChanged)

public:
    // candidates lists the folders that may hold the built app, best first;
    // it's asked again on every refresh, since the plugin can move.
    explicit HyprCraft(std::function<QStringList()> candidates, QObject *parent = nullptr);

    // Registers the scheme. Must run before the QGuiApplication exists.
    static void registerScheme();

    bool available() const { return !m_appDir.isEmpty(); }
    QString appDir() const { return m_appDir; }
    QString url() const { return "hyprcraft://app/index.html"; }
    QString storagePath() const;
    QString downloadDir() const;

    // The file a request path maps to inside root, or empty when it would
    // leave root or doesn't exist.
    static QString resolve(const QString &root, const QString &requestPath);
    static QByteArray mimeType(const QString &path);

    void requestStarted(QWebEngineUrlRequestJob *job) override;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void downloaded(const QString &path, bool ok, const QString &reason);
    Q_INVOKABLE void openDownloads();
    QString bundle() const { return m_bundle; }
    // Unpacks the bundle and runs its install.sh in a terminal, where its
    // output (and Hyprland's config check) can be read.
    Q_INVOKABLE void installBundle();
    Q_INVOKABLE void dismissBundle();

    // Whether a download is an Omarchy bundle HyprCraft made.
    static bool isOmarchyBundle(const QString &path);

signals:
    void changed();
    void bundleChanged();

private:
    std::function<QStringList()> m_candidates;
    QString m_appDir;
    QString m_bundle;
};
