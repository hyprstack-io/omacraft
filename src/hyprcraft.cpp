#include "hyprcraft.h"

#include <QBuffer>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QWebEngineUrlRequestJob>
#include <QWebEngineUrlScheme>

#include "proc.h"

HyprCraft::HyprCraft(std::function<QStringList()> candidates, QObject *parent)
    : QWebEngineUrlSchemeHandler(parent), m_candidates(std::move(candidates)) {
    refresh();
}

void HyprCraft::registerScheme() {
    QWebEngineUrlScheme scheme("hyprcraft");
    // Host syntax gives the page a real origin, so localStorage keeps the
    // editor's work between runs; Secure and CORS let module scripts load.
    scheme.setSyntax(QWebEngineUrlScheme::Syntax::Host);
    scheme.setFlags(QWebEngineUrlScheme::SecureScheme | QWebEngineUrlScheme::LocalScheme
                    | QWebEngineUrlScheme::LocalAccessAllowed | QWebEngineUrlScheme::CorsEnabled
                    | QWebEngineUrlScheme::FetchApiAllowed);
    QWebEngineUrlScheme::registerScheme(scheme);
}

QString HyprCraft::storagePath() const {
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/omacraft/hyprcraft";
}

QString HyprCraft::downloadDir() const {
    // Where the plugin saves exports too, so they're in one place.
    return QDir::homePath() + "/Downloads/HyprCraft";
}

void HyprCraft::refresh() {
    QString found;
    for (const auto &dir : m_candidates ? m_candidates() : QStringList())
        if (!dir.isEmpty() && QFileInfo::exists(dir + "/index.html")) {
            found = QFileInfo(dir).canonicalFilePath();
            break;
        }
    if (found != m_appDir) {
        m_appDir = found;
        emit changed();
    }
}

QString HyprCraft::resolve(const QString &root, const QString &requestPath) {
    if (root.isEmpty())
        return {};
    QString relative = QDir::cleanPath(requestPath);
    while (relative.startsWith('/'))
        relative.remove(0, 1);
    if (relative.isEmpty())
        relative = "index.html";
    const QString canonicalRoot = QFileInfo(root).canonicalFilePath();
    const QString path = QFileInfo(canonicalRoot + "/" + relative).canonicalFilePath();
    // canonicalFilePath is empty for missing files, and anything outside the
    // app folder (through .. or a link) is refused.
    if (path.isEmpty() || !path.startsWith(canonicalRoot + "/") || !QFileInfo(path).isFile())
        return {};
    return path;
}

QByteArray HyprCraft::mimeType(const QString &path) {
    static const QHash<QString, QByteArray> types{
        {"html", "text/html"}, {"js", "text/javascript"}, {"mjs", "text/javascript"}, {"css", "text/css"},
        {"json", "application/json"}, {"svg", "image/svg+xml"}, {"png", "image/png"}, {"jpg", "image/jpeg"},
        {"jpeg", "image/jpeg"}, {"webp", "image/webp"}, {"gif", "image/gif"}, {"ico", "image/x-icon"},
        {"woff", "font/woff"}, {"woff2", "font/woff2"}, {"ttf", "font/ttf"}, {"txt", "text/plain"},
        {"wasm", "application/wasm"},
    };
    return types.value(QFileInfo(path).suffix().toLower(), "application/octet-stream");
}

void HyprCraft::requestStarted(QWebEngineUrlRequestJob *job) {
    const QString path = resolve(m_appDir, job->requestUrl().path());
    if (path.isEmpty()) {
        job->fail(QWebEngineUrlRequestJob::UrlNotFound);
        return;
    }
    auto *file = new QFile(path, job);
    if (!file->open(QIODevice::ReadOnly)) {
        job->fail(QWebEngineUrlRequestJob::RequestFailed);
        return;
    }
    job->reply(mimeType(path), file);
}

bool HyprCraft::isOmarchyBundle(const QString &path) {
    return QFileInfo(path).fileName().endsWith("-omarchy.zip");
}

void HyprCraft::downloaded(const QString &path, bool ok, const QString &reason) {
    if (ok && isOmarchyBundle(path)) {
        m_bundle = path;
        emit bundleChanged();
    }
    if (ok)
        Proc::detach("notify-send", {"-a", "OmaCraft", "Dotfile Generator export saved", path});
    else
        Proc::detach("notify-send", {"-a", "OmaCraft", "-u", "critical", "Dotfile Generator export failed", reason});
}

void HyprCraft::installBundle() {
    if (m_bundle.isEmpty())
        return;
    // Unpacked beside OmaCraft's other HyprCraft data, one folder per bundle;
    // python's zipfile refuses paths that leave the folder.
    const QString dest = storagePath() + "/bundles/" + QFileInfo(m_bundle).completeBaseName();
    const QString script = QString(
        "set -e; rm -rf %2; mkdir -p %2; "
        "python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' %1 %2; "
        "dir=$(dirname \"$(find %2 -maxdepth 2 -name install.sh | head -1)\"); "
        "bash \"$dir/install.sh\"; echo; read -r -p 'Press Enter to close' _")
        .arg(Proc::shellQuote(m_bundle), Proc::shellQuote(dest));
    if (Proc::inTerminal(script)) {
        m_bundle.clear();
        emit bundleChanged();
    }
}

void HyprCraft::dismissBundle() {
    m_bundle.clear();
    emit bundleChanged();
}

void HyprCraft::openDownloads() {
    QDir().mkpath(downloadDir());
    Proc::detach("xdg-open", {downloadDir()});
}
