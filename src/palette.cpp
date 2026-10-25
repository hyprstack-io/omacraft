// Theme watching follows Omacut (MIT, David Heinemeier Hansson).
#include "palette.h"

#include <QDir>
#include <QFile>
#include <QDateTime>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
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

// A wallpaper colour as the keys should light it: the same hue, saturated
// and at full brightness. Screen palettes run soft and dim, and LEDs wash
// soft colours out to white, so a theme's tan lights orange and its slate
// blue lights blue. Near-greys stay white rather than taking a stray hue.
QColor lit(const QColor &c) {
    if (c.hsvSaturationF() < 0.08)
        return QColor::fromHsvF(0, 0, 1.0);
    return QColor::fromHsvF(std::max(0.0, double(c.hsvHueF())), std::max(0.92, double(c.hsvSaturationF())), 1.0);
}

// The theme's hue names, in a stable order so the same theme always gives
// the same slots.
const QStringList hueNames{
    "red", "orange", "yellow", "green", "cyan", "blue", "magenta",
    "bright_red", "bright_yellow", "bright_green", "bright_cyan", "bright_blue", "bright_magenta",
    "color1", "color2", "color3", "color4", "color5", "color6",
    "color9", "color10", "color11", "color12", "color13", "color14",
};

// Hue of a colour 0..1, 0 for greys (whose hue Qt reports as -1).
double hueOf(const QColor &c) { return std::max(0.0, double(c.hsvHueF())); }

// Shades of a colour the keys can still show, for a wallpaper with too few
// hues to fill the slots: the same hue dimmer, and paler.
QColor dimmer(const QColor &c) { return QColor::fromHsvF(hueOf(c), c.hsvSaturationF(), 0.55); }
QColor paler(const QColor &c) { return QColor::fromHsvF(hueOf(c), c.hsvSaturationF() * 0.45, 1.0); }

// The hue in `from` furthest from every colour in `away`; a brighter colour
// wins a near tie, since it lights better. Invalid when `from` is empty.
QColor furthestHue(const QList<QColor> &from, const QList<QColor> &away) {
    QColor best;
    double bestScore = -1;
    for (const auto &c : from) {
        double score = 1;
        for (const auto &f : away)
            score = std::min(score, hueDistance(c, f));
        score += c.valueF() * 0.02;
        if (score > bestScore) {
            bestScore = score;
            best = c;
        }
    }
    return best;
}

} // namespace

QList<QColor> ThemePalette::wallpaperColors(const QString &image) {
    // Decoding a 4K wallpaper takes a moment, and the theme folder changes
    // several times in one switch: keep the last answer while the file is
    // the same.
    static QString cachedKey;
    static QList<QColor> cached;
    const QFileInfo info(image);
    if (image.isEmpty() || !info.exists())
        return {};
    const QString key = info.canonicalFilePath() + '|' + QString::number(info.size()) + '|'
                        + QString::number(info.lastModified().toMSecsSinceEpoch());
    if (key == cachedKey)
        return cached;

    QImageReader reader(info.canonicalFilePath());
    reader.setAutoTransform(true);
    const QSize size = reader.size();
    // A small copy is plenty to tell which colours are there.
    if (size.isValid() && std::max(size.width(), size.height()) > 160)
        reader.setScaledSize(size.scaled(160, 160, Qt::KeepAspectRatio));
    QImage picture = reader.read();
    if (picture.isNull())
        return {};
    picture = picture.convertToFormat(QImage::Format_RGB32);
    if (std::max(picture.width(), picture.height()) > 160)
        picture = picture.scaled(160, 160, Qt::KeepAspectRatio, Qt::FastTransformation);

    // Coloured pixels go into hue bins; greys and near-blacks don't count as
    // a hue. Each bin keeps the average of its pixels, so the colour it gives
    // is one the picture really has.
    constexpr int bins = 36;
    struct Bin { double weight = 0, r = 0, g = 0, b = 0; int count = 0; };
    QList<Bin> hue(bins);
    int pixels = 0;
    double greyValue = 0;
    int greys = 0;
    for (int y = 0; y < picture.height(); ++y) {
        const auto *line = reinterpret_cast<const QRgb *>(picture.constScanLine(y));
        for (int x = 0; x < picture.width(); ++x) {
            const QColor c(line[x]);
            ++pixels;
            const double s = c.hsvSaturationF(), v = c.valueF();
            if (s < 0.2 || v < 0.18) {
                greyValue += v;
                ++greys;
                continue;
            }
            Bin &bin = hue[std::min(bins - 1, int(hueOf(c) * bins))];
            // Vivid, bright pixels say more about a hue than murky ones.
            const double w = s * v;
            bin.weight += w;
            bin.r += c.redF() * w;
            bin.g += c.greenF() * w;
            bin.b += c.blueF() * w;
            ++bin.count;
        }
    }

    QList<int> order;
    for (int i = 0; i < bins; ++i)
        order << i;
    std::stable_sort(order.begin(), order.end(), [&hue](int a, int b) { return hue[a].weight > hue[b].weight; });

    QList<QColor> out;
    for (int i : order) {
        const Bin &bin = hue[i];
        if (out.size() == 6 || bin.count == 0)
            break;
        // A hue has to be more than a few stray pixels to be the wallpaper's,
        // though a small vivid part counts: red eyes on a teal skull.
        const bool large = bin.count >= std::max(4, pixels / 250);
        const bool striking = bin.count >= std::max(6, pixels / 1000) && bin.weight / bin.count >= 0.35;
        if (!large && !striking)
            continue;
        const QColor c = QColor::fromRgbF(bin.r / bin.weight, bin.g / bin.weight, bin.b / bin.weight);
        bool close = false;
        for (const auto &o : out)
            close = close || hueDistance(c, o) < 0.06;
        if (!close)
            out << c;
    }
    // A black-and-white wallpaper lights in its own grey.
    if (out.isEmpty())
        out << QColor::fromHsvF(0, 0, greys ? std::clamp(greyValue / greys, 0.3, 1.0) : 1.0);

    cachedKey = key;
    cached = out;
    return out;
}

ThemePalette ThemePalette::read(const QString &path, const QString &wallpaperImage) {
    ThemePalette palette;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        palette.wallpaper = wallpaperColors(wallpaperImage);
        return palette;
    }
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
    palette.wallpaper = wallpaperColors(wallpaperImage);
    return palette;
}

QList<QColor> ThemePalette::slotColors() const {
    if (!wallpaper.isEmpty()) {
        const QColor main = lit(wallpaper.first());
        QList<QColor> rest;
        for (int i = 1; i < wallpaper.size(); ++i)
            rest << lit(wallpaper[i]);
        QColor second = furthestHue(rest, {main});
        rest.removeAll(second);
        QColor third = furthestHue(rest, {main, second});
        // Too few hues: shades of the ones there are, never a made-up hue.
        if (!second.isValid())
            second = dimmer(main);
        if (!third.isValid())
            third = paler(main);
        return {main, second, third, QColor::fromHsvF(hueOf(main), main.hsvSaturationF(), 0.1)};
    }

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
    const QColor key = lit(accent);
    QColor glow = QColor::fromHsvF(std::max(0.0, double(key.hsvHueF())), key.hsvSaturationF(), 0.1);
    return {key, lit(second), lit(third), glow};
}

QList<QColor> ThemePalette::cycle() const {
    if (!wallpaper.isEmpty()) {
        QList<QColor> hues;
        for (const auto &c : wallpaper)
            hues << lit(c);
        const double start = hueOf(hues.first());
        auto turn = [start](const QColor &c) { return std::fmod(hueOf(c) - start + 1.0, 1.0); };
        std::stable_sort(hues.begin() + 1, hues.end(), [&turn](const QColor &a, const QColor &b) { return turn(a) < turn(b); });
        // An animation needs a few stops to travel; shades of the wallpaper's
        // own hues make them up.
        for (int i = 0, n = int(hues.size()); hues.size() < 3; ++i)
            hues << (i < n ? dimmer(hues[i]) : paler(hues[i - n]));
        return hues;
    }

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
    for (auto &c : hues)
        c = lit(c);
    return hues;
}

bool ThemePalette::operator==(const ThemePalette &other) const {
    return accent == other.accent && background == other.background && foreground == other.foreground
           && named == other.named && wallpaper == other.wallpaper;
}

PaletteWatcher::PaletteWatcher(const QString &directory, QObject *parent)
    : QObject(parent),
      m_directory(directory.isEmpty() ? QDir::homePath() + "/.local/state/omarchy/current" : directory) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(120);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(); });
    connect(&m_debounce, &QTimer::timeout, this, &PaletteWatcher::reload);
    m_palette = ThemePalette::read(colorsPath(), backgroundPath());
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

    const auto palette = ThemePalette::read(colorsPath(), backgroundPath());
    if (palette != m_palette) {
        m_palette = palette;
        emit changed();
    }
}
