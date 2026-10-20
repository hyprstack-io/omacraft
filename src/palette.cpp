// Theme watching follows Omacut (MIT, David Heinemeier Hansson).
#include "palette.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <algorithm>
#include <cmath>

namespace {

// How far apart two hues are round the wheel, 0 to 0.5.
double hueDistance(const QColor &a, const QColor &b) {
    const double d = std::abs(a.hsvHueF() - b.hsvHueF());
    return std::min(d, 1.0 - d);
}

// Colours a keyboard can show well: saturated enough to read as a hue and
// bright enough to light. Greys and near-blacks wash out on the leds.
bool vivid(const QColor &c) {
    return c.hsvSaturationF() > 0.25 && c.valueF() > 0.35;
}

// The theme's hue names, in a stable order so the same theme always gives
// the same slots.
const QStringList hueNames{
    "red", "orange", "yellow", "green", "cyan", "blue", "magenta",
    "bright_red", "bright_yellow", "bright_green", "bright_cyan", "bright_blue", "bright_magenta",
    "color1", "color2", "color3", "color4", "color5", "color6",
    "color9", "color10", "color11", "color12", "color13", "color14",
};

} // namespace

ThemePalette ThemePalette::read(const QString &path) {
    ThemePalette palette;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return palette;
    const QRegularExpression line(R"re(^\s*([A-Za-z0-9_]+)\s*=\s*["'](#[0-9a-fA-F]{6})["'])re",
                                  QRegularExpression::MultilineOption);
    auto it = line.globalMatch(QString::fromUtf8(file.readAll()));
    while (it.hasNext()) {
        const auto match = it.next();
        palette.named.insert(match.captured(1), QColor(match.captured(2)));
    }
    if (palette.named.contains("accent"))
        palette.accent = palette.named.value("accent");
    if (palette.named.contains("background"))
        palette.background = palette.named.value("background");
    else if (palette.named.contains("color0"))
        palette.background = palette.named.value("color0");
    if (palette.named.contains("foreground"))
        palette.foreground = palette.named.value("foreground");
    return palette;
}

QList<QColor> ThemePalette::slotColors() const {
    QList<QColor> hues;
    for (const auto &name : hueNames)
        if (named.contains(name) && vivid(named.value(name)))
            hues << named.value(name);

    // The hue furthest from the accent, then the one furthest from both.
    auto furthest = [&hues](const QList<QColor> &from) {
        QColor best;
        double bestScore = -1;
        for (const auto &c : hues) {
            double score = 1;
            for (const auto &f : from)
                score = std::min(score, hueDistance(c, f));
            // A brighter colour wins a near tie, since it lights better.
            score += c.valueF() * 0.02;
            if (score > bestScore) {
                bestScore = score;
                best = c;
            }
        }
        return best;
    };

    QColor second = furthest({accent});
    if (!second.isValid())
        second = QColor::fromHsvF(std::fmod(accent.hsvHueF() + 0.5, 1.0), 0.8, 1.0);
    QColor third = furthest({accent, second});
    if (!third.isValid() || third == second)
        third = QColor::fromHsvF(std::fmod(accent.hsvHueF() + 0.25, 1.0), 0.8, 1.0);

    // The glow between the lit keys: the accent, turned right down.
    QColor glow = QColor::fromHsvF(std::max(0.0, double(accent.hsvHueF())), accent.hsvSaturationF(), 0.1);
    return {accent, second, third, glow};
}

QList<QColor> ThemePalette::cycle() const {
    QList<QColor> hues{accent};
    for (const auto &name : hueNames) {
        const QColor c = named.value(name);
        if (!c.isValid() || !vivid(c))
            continue;
        // Skip colours too close to one already in, so the cycle visits
        // distinct hues rather than three shades of blue.
        bool close = false;
        for (const auto &h : hues)
            close = close || hueDistance(c, h) < 0.04;
        if (!close)
            hues << c;
    }
    if (hues.size() < 3) {
        for (int i = 1; i < 6; ++i)
            hues << QColor::fromHsvF(std::fmod(accent.hsvHueF() + i / 6.0, 1.0), 0.85, 1.0);
    }
    const double start = std::max(0.0, double(accent.hsvHueF()));
    auto turn = [start](const QColor &c) { return std::fmod(std::max(0.0, double(c.hsvHueF())) - start + 1.0, 1.0); };
    std::stable_sort(hues.begin() + 1, hues.end(), [&turn](const QColor &a, const QColor &b) { return turn(a) < turn(b); });
    return hues;
}

bool ThemePalette::operator==(const ThemePalette &other) const {
    return accent == other.accent && background == other.background && foreground == other.foreground
           && named == other.named;
}

PaletteWatcher::PaletteWatcher(const QString &directory, QObject *parent)
    : QObject(parent),
      m_directory(directory.isEmpty() ? QDir::homePath() + "/.local/state/omarchy/current" : directory) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(120);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(); });
    connect(&m_debounce, &QTimer::timeout, this, &PaletteWatcher::reload);
    m_palette = ThemePalette::read(colorsPath());
    reload();
}

void PaletteWatcher::reload() {
    const auto paths = m_watcher.files() + m_watcher.directories();
    if (!paths.isEmpty())
        m_watcher.removePaths(paths);

    // Watching the nearest existing ancestor means installing Omarchy later
    // works without restarting.
    QString ancestor = m_directory;
    while (!QFileInfo::exists(ancestor) && ancestor != "/")
        ancestor = QFileInfo(ancestor).absolutePath();
    QStringList candidates{ancestor, QFileInfo(ancestor).absolutePath(), m_directory,
                           m_directory + "/theme", colorsPath()};
    candidates.removeDuplicates();
    for (const auto &path : candidates)
        if (QFileInfo::exists(path))
            m_watcher.addPath(path);

    const auto palette = ThemePalette::read(colorsPath());
    if (palette != m_palette) {
        m_palette = palette;
        emit changed();
    }
}
