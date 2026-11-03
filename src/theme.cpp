// Theme watching follows Omacut (MIT, David Heinemeier Hansson).
#include "theme.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QPalette>
#include <QRegularExpression>
#include <cmath>

namespace {

double luminance(const QColor &c) {
    auto linear = [](double v) { return v <= .04045 ? v / 12.92 : std::pow((v + .055) / 1.055, 2.4); };
    return .2126 * linear(c.redF()) + .7152 * linear(c.greenF()) + .0722 * linear(c.blueF());
}

double contrast(const QColor &a, const QColor &b) {
    const double la = luminance(a), lb = luminance(b);
    return (std::max(la, lb) + .05) / (std::min(la, lb) + .05);
}

QColor named(const QHash<QString, QString> &colors, const QString &key, const QColor &fallback) {
    const QColor c(colors.value(key));
    return c.isValid() ? c : fallback;
}

} // namespace

Theme::Theme(const QString &directory, QObject *parent)
    : QObject(parent),
      m_directory(directory.isEmpty() ? QDir::homePath() + "/.local/state/omarchy/current" : directory) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(80);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(); });
    connect(&m_debounce, &QTimer::timeout, this, &Theme::reload);
    // Markdown text takes its link colour from the application's palette.
    connect(this, &Theme::changed, this, [this] {
        if (auto *app = qobject_cast<QGuiApplication *>(QCoreApplication::instance())) {
            QPalette palette = QGuiApplication::palette();
            palette.setColor(QPalette::Link, QColor(accent()));
            palette.setColor(QPalette::LinkVisited, QColor(accent()));
            app->setPalette(palette);
        }
    });
    reload();
}

QHash<QString, QString> Theme::readColors(const QString &path) {
    QHash<QString, QString> out;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return out;
    static const QRegularExpression line(R"re(^\s*([a-z_]+)\s*=\s*["']([^"']*)["'])re",
                                         QRegularExpression::MultilineOption);
    auto it = line.globalMatch(QString::fromUtf8(file.readAll()));
    while (it.hasNext()) {
        const auto match = it.next();
        out.insert(match.captured(1), match.captured(2).trimmed());
    }
    return out;
}

QString Theme::readAccent(const QString &path) {
    const QColor accent(readColors(path).value("accent"));
    return accent.isValid() && QString(readColors(path).value("accent")).startsWith('#')
               ? accent.name(QColor::HexRgb)
               : QString("#FFD60A");
}

bool Theme::isDark(const QHash<QString, QString> &colors) {
    const QString mode = colors.value("mode").toLower();
    if (mode == "dark" || mode == "light")
        return mode == "dark";
    const QColor background(colors.value("background"));
    return !background.isValid() || luminance(background) < .4;
}

QColor Theme::mix(const QColor &a, const QColor &b, double t) {
    return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * t, a.greenF() + (b.greenF() - a.greenF()) * t,
                            a.blueF() + (b.blueF() - a.blueF()) * t);
}

QColor Theme::readable(const QColor &color, const QColor &against, double minimum) {
    QColor out = color;
    const QColor goal = luminance(against) > .4 ? QColor(Qt::black) : QColor(Qt::white);
    for (int i = 1; i <= 20 && contrast(out, against) < minimum; ++i)
        out = mix(color, goal, i * .05);
    return out;
}

double Theme::contrastRatio(const QColor &a, const QColor &b) { return contrast(a, b); }

// Black or white, whichever reads on the accent (WCAG relative luminance).
QString Theme::accentForeground() const {
    return luminance(QColor(m_accent)) > .179 ? "black" : "white";
}

void Theme::reload() {
    const auto paths = m_watcher.files() + m_watcher.directories();
    if (!paths.isEmpty())
        m_watcher.removePaths(paths);

    // A theme switch replaces symlinks and files, so watch the parents too and
    // re-arm after every change. Watching the nearest existing ancestor means
    // installing Omarchy later works without restarting the app.
    QString ancestor = m_directory;
    while (!QFileInfo::exists(ancestor) && ancestor != "/")
        ancestor = QFileInfo(ancestor).absolutePath();
    QStringList candidates{ancestor, QFileInfo(ancestor).absolutePath(), m_directory,
                           m_directory + "/theme", m_directory + "/theme/colors.toml"};
    candidates.removeDuplicates();
    for (const auto &path : candidates)
        if (QFileInfo::exists(path))
            m_watcher.addPath(path);

    const auto colors = readColors(m_directory + "/theme/colors.toml");
    const bool dark = isDark(colors);
    // Without a theme: OmaCraft's own dark look.
    const QColor background = named(colors, "background", dark ? QColor("#0e0e10") : QColor("#f4f4f5"));
    QColor foreground = named(colors, "foreground", dark ? QColor("#f2f2f4") : QColor("#18181b"));
    // A theme's foreground is meant for body text; make sure it stays clear.
    foreground = readable(foreground, background, 7);
    const QString accent = readAccent(m_directory + "/theme/colors.toml");
    const QColor red = readable(named(colors, "red", QColor("#e5534b")), background, 3.5);
    const QColor yellow = readable(named(colors, "yellow", QColor("#c9a227")), background, 3);
    const QColor green = readable(named(colors, "green", QColor("#57ab5a")), background, 3);

    if (accent == m_accent && dark == m_dark && background == m_background && foreground == m_foreground
        && red == m_red && yellow == m_yellow && green == m_green)
        return;
    m_accent = accent;
    m_dark = dark;
    m_background = background;
    m_foreground = foreground;
    m_red = red;
    m_yellow = yellow;
    m_green = green;
    emit changed();
}
