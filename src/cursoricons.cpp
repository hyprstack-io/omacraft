#include "cursoricons.h"

#include "filepicker.h"
#include "proc.h"
#include "theme.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QSet>
#include <QTimer>
#include <QUrl>
#include <QtEndian>
#include <algorithm>
#include <cmath>

// ================================================================ XCursor

namespace XCursor {

namespace {
constexpr quint32 kMagic = 0x72756358; // "Xcur", read little-endian
constexpr quint32 kImage = 0xfffd0002;
constexpr int kImageHeader = 36;
constexpr int kMaxSide = 1024;

quint32 word(const QByteArray &file, qsizetype at) {
    if (at < 0 || at + 4 > file.size())
        return 0;
    // Byte by byte, through at(), so the bounds are plain to the compiler too.
    return quint32(quint8(file.at(at))) | quint32(quint8(file.at(at + 1))) << 8
         | quint32(quint8(file.at(at + 2))) << 16 | quint32(quint8(file.at(at + 3))) << 24;
}

double luminance(int r, int g, int b) { return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0; }
} // namespace

QList<Frame> frames(const QByteArray &file) {
    QList<Frame> out;
    if (file.size() < 16 || word(file, 0) != kMagic)
        return out;
    const quint32 headerSize = word(file, 4);
    const quint32 count = word(file, 12);
    // A table bigger than the file is a broken or hostile file, not a cursor.
    if (headerSize < 16 || count > 4096 || headerSize + qsizetype(count) * 12 > file.size())
        return out;
    for (quint32 i = 0; i < count; ++i) {
        const qsizetype entry = headerSize + qsizetype(i) * 12;
        if (word(file, entry) != kImage)
            continue;
        const qsizetype at = word(file, entry + 8);
        if (word(file, at) != kImageHeader || word(file, at + 4) != kImage)
            continue;
        Frame frame;
        frame.nominal = int(word(file, at + 8));
        frame.width = int(word(file, at + 16));
        frame.height = int(word(file, at + 20));
        frame.delay = int(word(file, at + 32));
        frame.offset = at + kImageHeader;
        if (frame.width <= 0 || frame.height <= 0 || frame.width > kMaxSide || frame.height > kMaxSide)
            continue;
        if (frame.offset + qsizetype(frame.width) * frame.height * 4 > file.size())
            continue;
        out << frame;
    }
    return out;
}

QList<Frame> framesNear(const QList<Frame> &all, int wanted) {
    int best = -1;
    for (const Frame &frame : all)
        // Ties go up, so a HiDPI preview isn't drawn from a smaller picture.
        if (best < 0 || std::abs(frame.nominal - wanted) < std::abs(best - wanted)
            || (std::abs(frame.nominal - wanted) == std::abs(best - wanted) && frame.nominal > best))
            best = frame.nominal;
    QList<Frame> out;
    for (const Frame &frame : all)
        if (frame.nominal == best)
            out << frame;
    return out;
}

QImage image(const QByteArray &file, const Frame &frame) {
    QImage out(frame.width, frame.height, QImage::Format_ARGB32_Premultiplied);
    const char *pixels = file.constData() + frame.offset;
    for (int y = 0; y < frame.height; ++y) {
        auto *line = reinterpret_cast<quint32 *>(out.scanLine(y));
        for (int x = 0; x < frame.width; ++x)
            line[x] = qFromLittleEndian<quint32>(pixels + (qsizetype(y) * frame.width + x) * 4);
    }
    return out;
}

bool darkBody(const QByteArray &file) {
    const QList<Frame> near = framesNear(frames(file), 32);
    if (near.isEmpty())
        return true;
    const Frame &frame = near.first();
    const auto at = [&](int x, int y) {
        return qFromLittleEndian<quint32>(file.constData() + frame.offset + (qsizetype(y) * frame.width + x) * 4);
    };
    const auto solid = [&](int x, int y) {
        return x >= 0 && y >= 0 && x < frame.width && y < frame.height && (at(x, y) >> 24) >= 200;
    };
    // The body is what's inside: pixels with solid ground two steps away on
    // every side. A thick outline (Yaru's) would otherwise outvote it.
    double inside = 0, all = 0;
    int insideCount = 0, allCount = 0;
    for (int y = 0; y < frame.height; ++y) {
        for (int x = 0; x < frame.width; ++x) {
            if (!solid(x, y))
                continue;
            const quint32 p = at(x, y);
            const int a = p >> 24;
            const double l = luminance((p >> 16 & 0xff) * 255 / a, (p >> 8 & 0xff) * 255 / a, (p & 0xff) * 255 / a);
            all += l;
            ++allCount;
            if (solid(x - 2, y) && solid(x + 2, y) && solid(x, y - 2) && solid(x, y + 2)) {
                inside += l;
                ++insideCount;
            }
        }
    }
    if (insideCount >= 6)
        return inside / insideCount < 0.5;
    return allCount == 0 || all / allCount < 0.5;
}

quint32 tintPixel(quint32 argb, const QColor &fill, bool dark) {
    const int a = argb >> 24;
    if (a == 0)
        return argb;
    const int r = std::min(255, int(argb >> 16 & 0xff) * 255 / a);
    const int g = std::min(255, int(argb >> 8 & 0xff) * 255 / a);
    const int b = std::min(255, int(argb & 0xff) * 255 / a);
    const QColor original(r, g, b);

    QColor out;
    if (original.hsvSaturationF() > 0.35 && original.valueF() > 0.2 && fill.hsvHueF() >= 0) {
        // Coloured details (a spinner's segments, a help badge) keep their
        // brightness and take fill's hue.
        out = QColor::fromHsvF(fill.hsvHueF(), std::max(0.45f, fill.hsvSaturationF()), original.valueF());
    } else {
        // Along the body-to-outline ramp: the body becomes fill, the outline
        // stays, and the shading in between blends the two.
        double t = luminance(r, g, b);
        if (!dark)
            t = 1.0 - t;
        t = std::clamp(t, 0.0, 1.0);
        t = t * t * (3 - 2 * t);
        out = ::Theme::mix(fill, original, t);
    }
    const auto premultiply = [a](int c) { return quint32((c * a + 127) / 255); };
    return quint32(a) << 24 | premultiply(out.red()) << 16 | premultiply(out.green()) << 8 | premultiply(out.blue());
}

QByteArray tinted(const QByteArray &file, const QColor &fill, bool dark) {
    QByteArray out = file;
    char *data = out.data();
    for (const Frame &frame : frames(file)) {
        for (qsizetype i = 0; i < qsizetype(frame.width) * frame.height; ++i) {
            char *at = data + frame.offset + i * 4;
            qToLittleEndian<quint32>(tintPixel(qFromLittleEndian<quint32>(at), fill, dark), at);
        }
    }
    return out;
}

} // namespace XCursor

QImage CursorImageProvider::requestImage(const QString &id, QSize *size, const QSize &requested) {
    // <frame>/<nominal>/<hex path>
    const QStringList parts = id.split('/');
    QImage out;
    if (parts.size() == 3) {
        const QString path = QString::fromUtf8(QByteArray::fromHex(parts.at(2).toLatin1()));
        QFile file(path);
        // Cursor files are small; anything this big isn't one.
        if (file.size() < 32 * 1024 * 1024 && file.open(QIODevice::ReadOnly)) {
            const QByteArray bytes = file.readAll();
            const QList<XCursor::Frame> near = XCursor::framesNear(XCursor::frames(bytes), parts.at(1).toInt());
            if (!near.isEmpty())
                out = XCursor::image(bytes, near.at(parts.at(0).toInt() % near.size()));
        }
    }
    if (out.isNull()) {
        out = QImage(1, 1, QImage::Format_ARGB32_Premultiplied);
        out.fill(Qt::transparent);
    }
    if (requested.isValid() && requested != out.size() && requested.width() > 0 && requested.height() > 0)
        out = out.scaled(requested, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    if (size)
        *size = out.size();
    return out;
}

// ================================================================ helpers

namespace {

const QHash<QString, QString> &colorNames() {
    // Variant names as icon themes spell them, and roughly the hue each means.
    static const QHash<QString, QString> table{
        {"blue", "#0073e5"}, {"red", "#da3450"}, {"magenta", "#b34cb3"}, {"purple", "#7764d8"},
        {"olive", "#4b8501"}, {"prussiangreen", "#308280"}, {"sage", "#657b69"}, {"wartybrown", "#b39169"},
        {"yellow", "#c88800"}, {"bark", "#787859"}, {"viridian", "#03875b"}, {"orange", "#e95420"},
        {"green", "#26a269"}, {"teal", "#2190a4"}, {"cyan", "#00acc1"}, {"pink", "#e64980"},
        {"grey", "#8a8a8a"}, {"gray", "#8a8a8a"}, {"black", "#303030"}, {"white", "#f0f0f0"},
        {"brown", "#865e3c"}, {"indigo", "#3f51b5"}, {"violet", "#8f3ff0"}, {"nord", "#5e81ac"},
        {"dracula", "#bd93f9"}, {"lime", "#8bc34a"}, {"mint", "#3eb489"}, {"sky", "#39a5dc"},
        {"aqua", "#00c4cc"}, {"amber", "#ffbf00"}, {"deeporange", "#ff5722"}, {"deeppurple", "#673ab7"},
        {"lightblue", "#03a9f4"}, {"carmine", "#960018"}, {"bluegrey", "#607d8b"}, {"darkcyan", "#008b8b"},
        {"palebrown", "#b08d57"}, {"paleorange", "#eebd77"}, {"yaru", "#e95420"}, {"ubuntu", "#e95420"},
        {"rose", "#e8467c"}, {"crimson", "#dc143c"}, {"gold", "#d4a017"}, {"emerald", "#2ecc71"},
    };
    return table;
}

// The colour a family's unsuffixed theme is, where it's known.
const QHash<QString, QString> &familyColors() {
    static const QHash<QString, QString> table{
        {"yaru", "orange"}, {"tela", "blue"}, {"papirus", "blue"}, {"colloid", "blue"},
        {"fluent", "blue"}, {"qogir", "blue"}, {"reversal", "blue"}, {"we10x", "blue"},
    };
    return table;
}

const QStringList kSuffixes{"dark", "light", "darker", "lighter", "dim", "nord", "dracula"};

// Oklab, so "nearest colour" means what it looks like.
struct Lab { double l, a, b; };
Lab oklab(const QColor &c) {
    auto lin = [](double v) { return v <= 0.04045 ? v / 12.92 : std::pow((v + 0.055) / 1.055, 2.4); };
    const double r = lin(c.redF()), g = lin(c.greenF()), b = lin(c.blueF());
    const double l = std::cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const double m = std::cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const double s = std::cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return {0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s};
}
double distance(const QColor &x, const QColor &y) {
    const Lab p = oklab(x), q = oklab(y);
    // Hue matters more than lightness here: a dark blue accent still wants blue.
    return std::hypot((p.l - q.l) * 0.5, p.a - q.a, p.b - q.b);
}

bool copyTree(const QString &from, const QString &to) {
    if (!QDir().mkpath(to))
        return false;
    QDir source(from);
    for (const QFileInfo &entry : source.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System)) {
        const QString target = to + "/" + entry.fileName();
        if (entry.isSymLink()) {
            if (!QFile::link(entry.readSymLink(), target))
                return false;
        } else if (entry.isDir()) {
            if (!copyTree(entry.filePath(), target))
                return false;
        } else if (entry.isFile()) {
            if (!QFile::copy(entry.filePath(), target))
                return false;
        }
    }
    return true;
}

// Rename where it can, copy where it must (another filesystem).
bool moveTree(const QString &from, const QString &to) {
    QDir().mkpath(QFileInfo(to).absolutePath());
    if (QDir().rename(from, to))
        return true;
    if (!copyTree(from, to)) {
        QDir(to).removeRecursively();
        return false;
    }
    QDir(from).removeRecursively();
    return true;
}

QString luaString(const QString &value) {
    QString out = value;
    out.replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n").replace('\r', "\\r");
    return "\"" + out + "\"";
}

// gtk settings.ini files only get a key changed when they already exist:
// Omarchy sets GTK through gsettings, and an ini nobody had can shadow it.
void setIniKey(const QString &path, const QString &key, const QString &value) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return;
    QStringList lines = QString::fromUtf8(file.readAll()).split('\n');
    file.close();
    bool found = false;
    int settings = -1;
    for (int i = 0; i < lines.size(); ++i) {
        if (lines.at(i).trimmed() == "[Settings]")
            settings = i;
        if (lines.at(i).trimmed().startsWith(key + "=") || lines.at(i).trimmed().startsWith(key + " =")) {
            lines[i] = key + "=" + value;
            found = true;
        }
    }
    if (!found) {
        if (settings < 0)
            return;
        lines.insert(settings + 1, key + "=" + value);
    }
    Proc::writeAtomically(path, lines.join('\n').toUtf8());
}

QString gsettingsGet(const QString &key) {
    QProcess process;
    process.start("gsettings", {"get", "org.gnome.desktop.interface", key});
    if (!process.waitForFinished(2500) || process.exitCode() != 0)
        return {};
    QString value = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
    if (value.startsWith('\'') && value.endsWith('\'') && value.size() >= 2)
        value = value.mid(1, value.size() - 2);
    if (value.startsWith("int32 "))
        value = value.mid(6);
    return value;
}

// The cursors a tile shows, each with the names themes use for it.
struct Role { const char *role; QStringList names; };
const QList<Role> &cursorRoles() {
    static const QList<Role> roles{
        {"pointer", {"left_ptr", "default", "arrow", "top_left_arrow"}},
        {"hand", {"pointer", "hand2", "hand1", "pointing_hand"}},
        {"text", {"text", "xterm", "ibeam"}},
        {"wait", {"wait", "watch"}},
        {"progress", {"progress", "left_ptr_watch", "half-busy"}},
        {"move", {"move", "fleur", "all-scroll", "grabbing"}},
        {"resize", {"nwse-resize", "bd_double_arrow", "size_fdiag", "se-resize"}},
        {"crosshair", {"crosshair", "cross", "tcross"}},
        {"help", {"help", "question_arrow", "left_ptr_help"}},
        {"forbidden", {"not-allowed", "crossed_circle", "circle", "no-drop"}},
    };
    return roles;
}

const QList<QStringList> &iconRoles() {
    static const QList<QStringList> roles{
        {"folder"}, {"user-home", "folder-home"}, {"folder-download", "folder-downloads"},
        {"folder-pictures", "folder-images"}, {"text-x-generic"}, {"image-x-generic"},
        {"audio-x-generic"}, {"utilities-terminal", "org.gnome.Terminal", "terminal"},
        {"web-browser", "internet-web-browser", "firefox"}, {"preferences-system", "org.gnome.Settings", "preferences-desktop"},
        {"accessories-text-editor", "org.gnome.TextEditor", "text-editor"}, {"user-trash", "user-trash-full", "trash-empty"},
    };
    return roles;
}

const QStringList kArchiveSuffixes{".tar", ".tar.gz", ".tgz", ".tar.xz", ".txz", ".tar.zst", ".tzst", ".tar.bz2",
                                   ".tbz2", ".tbz", ".zip", ".7z", ".tar.lz", ".tar.lzma"};

QString archiveStem(const QString &path) {
    const QString name = QFileInfo(path).fileName();
    for (const QString &suffix : kArchiveSuffixes)
        if (name.endsWith(suffix, Qt::CaseInsensitive))
            return name.left(name.size() - suffix.size());
    return QFileInfo(path).completeBaseName();
}

bool safeId(const QString &id) {
    static const QRegularExpression bad(R"([/\\\x00-\x1f])");
    return !id.isEmpty() && id.size() <= 120 && !id.startsWith('.') && id != "default" && !id.contains(bad);
}

} // namespace

// ================================================================ class

CursorsIcons::CursorsIcons(FilePicker *picker, const QString &home, const QStringList &systemDirs, bool runCommands,
                           QObject *parent)
    : QObject(parent), m_picker(picker), m_home(home.isEmpty() ? QDir::homePath() : home), m_systemDirs(systemDirs),
      m_runCommands(runCommands) {
    QFile file(configPath());
    if (file.open(QIODevice::ReadOnly))
        m_config = QJsonDocument::fromJson(file.readAll()).object();
    readApplied();
    reload();

    if (m_picker) {
        connect(m_picker, &FilePicker::folderSelected, this, [this](const QString &purpose, const QUrl &url) {
            if (purpose == "cursoricons-import")
                importFrom(url.toLocalFile());
        });
    }
    // A theme dropped into ~/.local/share/icons by hand shows up too.
    auto *debounce = new QTimer(this);
    debounce->setSingleShot(true);
    debounce->setInterval(400);
    connect(debounce, &QTimer::timeout, this, &CursorsIcons::reload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, debounce, qOverload<>(&QTimer::start));
    QDir().mkpath(userDir());
    for (const QString &dir : {userDir(), m_home + "/.icons"})
        if (QFileInfo(dir).isDir())
            m_watcher.addPath(dir);
}

// ---------------------------------------------------------------- reading

QHash<QString, QString> CursorsIcons::readIndex(const QString &path, const QString &group) {
    QHash<QString, QString> out;
    QFile file(path);
    if (file.size() > 4 * 1024 * 1024 || !file.open(QIODevice::ReadOnly))
        return out;
    QString current;
    for (QString line : QString::fromUtf8(file.readAll()).split('\n')) {
        line = line.trimmed();
        if (line.isEmpty() || line.startsWith('#') || line.startsWith(';'))
            continue;
        if (line.startsWith('[') && line.endsWith(']')) {
            current = line.mid(1, line.size() - 2);
            continue;
        }
        const int eq = line.indexOf('=');
        if (current == group && eq > 0)
            out.insert(line.left(eq).trimmed(), line.mid(eq + 1).trimmed());
    }
    return out;
}

CursorsIcons::Theme CursorsIcons::readTheme(const QString &path, bool user) {
    Theme theme;
    theme.path = path;
    theme.id = QFileInfo(path).fileName();
    theme.user = user;
    const auto index = readIndex(path + "/index.theme");
    theme.name = index.value("Name", theme.id);
    const auto list = [](const QString &value) {
        QStringList out;
        for (const QString &part : value.split(',', Qt::SkipEmptyParts))
            if (!part.trimmed().isEmpty())
                out << part.trimmed();
        return out;
    };
    theme.inherits = list(index.value("Inherits"));
    theme.directories = list(index.value("Directories")) + list(index.value("ScaledDirectories"));
    theme.directories.removeDuplicates();
    theme.icons = !theme.directories.isEmpty() && index.value("Hidden").toLower() != "true";
    const QDir cursors(path + "/cursors");
    theme.xcursor = cursors.exists() && !cursors.entryList(QDir::Files | QDir::System).isEmpty();
    theme.hyprcursor = (QFileInfo::exists(path + "/manifest.hl") || QFileInfo::exists(path + "/manifest.toml"))
                       && QFileInfo(path + "/hyprcursors").isDir();
    theme.generated = theme.id.startsWith(kTintedPrefix) && index.contains("X-OmaCraft-Base");
    return theme;
}

QStringList CursorsIcons::searchDirs() const {
    return QStringList{userDir(), m_home + "/.icons"} + m_systemDirs;
}

QList<CursorsIcons::Theme> CursorsIcons::scan() const {
    QList<Theme> out;
    QSet<QString> seen;
    const QStringList dirs = searchDirs();
    for (int i = 0; i < dirs.size(); ++i) {
        const bool user = i < 2;
        for (const QFileInfo &entry : QDir(dirs.at(i)).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name | QDir::IgnoreCase)) {
            const QString id = entry.fileName();
            // The search path's first copy is the one in use.
            if (seen.contains(id) || id == "default" || id == "hicolor" || id == "locolor")
                continue;
            const Theme theme = readTheme(entry.absoluteFilePath(), user);
            if (!theme.icons && !theme.xcursor && !theme.hyprcursor)
                continue;
            seen.insert(id);
            out << theme;
        }
    }
    return out;
}

QString CursorsIcons::pathOf(const QString &id) const {
    if (!safeId(id))
        return {};
    for (const QString &dir : searchDirs())
        if (QFileInfo(dir + "/" + id).isDir())
            return dir + "/" + id;
    return {};
}

QString CursorsIcons::cursorPathOf(const QString &id) const {
    // "default" is an alias whose index.theme names the real theme, and a
    // theme without pictures of its own borrows its parent's.
    QString current = id;
    for (int hop = 0; hop < 6; ++hop) {
        QString path;
        if (current == "default") {
            for (const QString &dir : searchDirs())
                if (QFileInfo::exists(dir + "/default/index.theme") || QFileInfo(dir + "/default/cursors").isDir()) {
                    path = dir + "/default";
                    break;
                }
        } else {
            path = pathOf(current);
        }
        if (path.isEmpty())
            return {};
        const Theme theme = readTheme(path, false);
        if (theme.xcursor || theme.hyprcursor)
            return path;
        if (theme.inherits.isEmpty() || theme.inherits.first() == current)
            return {};
        current = theme.inherits.first();
    }
    return {};
}

void CursorsIcons::reload() {
    m_iconSamples.clear();
    m_cursorSamples.clear();
    m_iconThemes.clear();
    m_cursorThemes.clear();
    const QList<Theme> themes = scan();
    QStringList ids;
    for (const Theme &theme : themes)
        ids << theme.id;
    for (const Theme &theme : themes) {
        QVariantMap row{{"id", theme.id}, {"name", theme.name}, {"path", theme.path}, {"user", theme.user}};
        if (theme.icons) {
            QVariantMap icons = row;
            const Variant variant = variantOf(theme.id);
            int siblings = 0;
            for (const QString &other : ids)
                if (other != theme.id && variantOf(other).family.compare(variant.family, Qt::CaseInsensitive) == 0
                    && variantOf(other).suffix.compare(variant.suffix, Qt::CaseInsensitive) == 0)
                    ++siblings;
            icons.insert("family", variant.family);
            icons.insert("tintable", siblings > 0);
            icons.insert("swatch", variant.color.isEmpty() ? QString() : variantColor(variant.color).name());
            m_iconThemes << icons;
        }
        if ((theme.xcursor || theme.hyprcursor) && !theme.generated) {
            QVariantMap cursor = row;
            cursor.insert("xcursor", theme.xcursor);
            cursor.insert("hyprcursor", theme.hyprcursor);
            m_cursorThemes << cursor;
        }
    }
    emit themesChanged();
}

void CursorsIcons::readApplied() {
    if (m_runCommands) {
        m_iconTheme = gsettingsGet("icon-theme");
        m_cursorTheme = gsettingsGet("cursor-theme");
        const int size = gsettingsGet("cursor-size").toInt();
        if (size > 0)
            m_cursorSize = size;
    } else {
        const QJsonObject cursor = m_config.value("cursor").toObject();
        m_cursorSize = cursor.value("size").toInt(24);
    }
    emit appliedChanged();
}

// ---------------------------------------------------------------- config

QString CursorsIcons::iconMode() const { return m_config.value("icons").toObject().value("mode").toString("omarchy"); }
QString CursorsIcons::iconPick() const { return m_config.value("icons").toObject().value("pick").toString(); }
QString CursorsIcons::cursorMode() const { return m_config.value("cursor").toObject().value("mode").toString("fixed"); }
QString CursorsIcons::cursorPick() const { return m_config.value("cursor").toObject().value("pick").toString(); }
QString CursorsIcons::tintKey() const { return m_config.value("tint").toString("accent"); }

QVariantMap CursorsIcons::themeColors() const {
    QVariantMap out;
    const auto colors = ::Theme::readColors(colorsPath());
    for (auto it = colors.begin(); it != colors.end(); ++it)
        out.insert(it.key(), it.value());
    return out;
}

QString CursorsIcons::tintColor() const {
    const auto colors = ::Theme::readColors(colorsPath());
    const QColor picked(colors.value(tintKey()));
    if (picked.isValid())
        return picked.name();
    const QColor accent(colors.value("accent"));
    return accent.isValid() ? accent.name() : QStringLiteral("#7aa2f7");
}

void CursorsIcons::saveConfig() {
    QString why;
    if (!Proc::writeAtomically(configPath(), QJsonDocument(m_config).toJson(), &why))
        setError("Can't save " + configPath() + ": " + why);
}

void CursorsIcons::remember() {
    m_undo << m_config;
    if (m_undo.size() > 30)
        m_undo.removeFirst();
}

void CursorsIcons::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}
void CursorsIcons::setNotice(const QString &message) {
    m_notice = message;
    m_error.clear();
    emit messageChanged();
}
void CursorsIcons::setBusy(bool busy) {
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}
void CursorsIcons::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}

// ---------------------------------------------------------------- variants

CursorsIcons::Variant CursorsIcons::variantOf(const QString &id) {
    QStringList parts = id.split('-');
    Variant out;
    if (parts.size() > 1 && kSuffixes.contains(parts.last().toLower())) {
        out.suffix = parts.takeLast();
    }
    if (parts.size() > 1 && colorNames().contains(parts.last().toLower()))
        out.color = parts.takeLast().toLower();
    out.family = parts.join('-');
    if (out.color.isEmpty())
        out.color = familyColors().value(out.family.toLower());
    return out;
}

QColor CursorsIcons::variantColor(const QString &color) {
    return QColor(colorNames().value(color.toLower()));
}

QString CursorsIcons::nearestVariant(const QString &id, const QStringList &installed, const QColor &accent) {
    const Variant self = variantOf(id);
    if (!accent.isValid())
        return id;
    QString best = id;
    double bestDistance = self.color.isEmpty() ? 1e9 : distance(variantColor(self.color), accent);
    for (const QString &other : installed) {
        const Variant variant = variantOf(other);
        if (variant.color.isEmpty() || variant.family.compare(self.family, Qt::CaseInsensitive) != 0
            || variant.suffix.compare(self.suffix, Qt::CaseInsensitive) != 0)
            continue;
        const double d = distance(variantColor(variant.color), accent);
        if (d < bestDistance) {
            bestDistance = d;
            best = other;
        }
    }
    return best;
}

// ---------------------------------------------------------------- samples

QVariantList CursorsIcons::iconSamples(const QString &id) {
    if (m_iconSamples.contains(id))
        return m_iconSamples.value(id);
    // The theme, then what it inherits, then hicolor, as a desktop looks.
    QStringList chain;
    QStringList queue{id};
    while (!queue.isEmpty() && chain.size() < 6) {
        const QString next = queue.takeFirst();
        if (chain.contains(next) || next == "hicolor")
            continue;
        const QString path = pathOf(next);
        if (path.isEmpty())
            continue;
        chain << path;
        queue << readTheme(path, false).inherits;
    }
    const QString hicolor = pathOf("hicolor");
    if (!hicolor.isEmpty())
        chain << hicolor;

    // Each theme's folders, best first: scalable, then nearest 48px.
    QList<QPair<QString, QStringList>> ordered;
    for (const QString &path : chain) {
        const Theme theme = readTheme(path, false);
        QList<QPair<int, QString>> scored;
        for (const QString &dir : theme.directories) {
            const auto section = readIndex(path + "/index.theme", dir);
            const int size = section.value("Size").toInt() * std::max(1, section.value("Scale", "1").toInt());
            const bool scalable = section.value("Type").compare("Scalable", Qt::CaseInsensitive) == 0;
            // Symbolic icons are monochrome glyphs, not what a theme looks like.
            const int penalty = dir.contains("symbolic") ? 1000 : 0;
            scored << qMakePair((scalable ? 0 : 1 + std::abs(size - 48)) + penalty, dir);
        }
        std::stable_sort(scored.begin(), scored.end(), [](const auto &a, const auto &b) { return a.first < b.first; });
        QStringList dirs;
        for (const auto &pair : scored)
            dirs << pair.second;
        ordered << qMakePair(path, dirs);
    }

    QVariantList out;
    for (const QStringList &names : iconRoles()) {
        QString found;
        for (const auto &[path, dirs] : ordered) {
            for (const QString &dir : dirs) {
                for (const QString &name : names) {
                    for (const char *ext : {".svg", ".png"}) {
                        const QString file = path + "/" + dir + "/" + name + ext;
                        if (QFileInfo::exists(file)) {
                            found = file;
                            break;
                        }
                    }
                    if (!found.isEmpty())
                        break;
                }
                if (!found.isEmpty())
                    break;
            }
            if (!found.isEmpty())
                break;
        }
        if (!found.isEmpty())
            out << QVariantMap{{"role", names.first()}, {"source", QUrl::fromLocalFile(found).toString()}};
    }
    m_iconSamples.insert(id, out);
    return out;
}

QVariantList CursorsIcons::cursorSamples(const QString &id, int size) {
    const QString key = id + "@" + QString::number(size);
    if (m_cursorSamples.contains(key))
        return m_cursorSamples.value(key);
    QVariantList out;
    const QString path = cursorPathOf(id);
    if (path.isEmpty())
        return out;
    const Theme theme = readTheme(path, false);
    for (const Role &role : cursorRoles()) {
        if (theme.xcursor) {
            for (const QString &name : role.names) {
                const QString file = path + "/cursors/" + name;
                QFile handle(file);
                if (!handle.exists() || handle.size() > 32 * 1024 * 1024 || !handle.open(QIODevice::ReadOnly))
                    continue;
                const QList<XCursor::Frame> near = XCursor::framesNear(XCursor::frames(handle.readAll()), size);
                if (near.isEmpty())
                    continue;
                QVariantList delays;
                for (const auto &frame : near)
                    delays << std::max(16, frame.delay);
                out << QVariantMap{{"role", role.role},
                                   {"nominal", near.first().nominal},
                                   {"hex", QString::fromLatin1(QFileInfo(file).absoluteFilePath().toUtf8().toHex())},
                                   {"delays", delays},
                                   {"animated", near.size() > 1}};
                break;
            }
        } else if (theme.hyprcursor) {
            // A .hlc is a zip of pictures and a meta file; its first picture
            // stands in for the cursor.
            for (const QString &name : role.names) {
                const QString hlc = path + "/hyprcursors/" + name + ".hlc";
                if (!QFileInfo::exists(hlc))
                    continue;
                const QString cache = m_home + "/.cache/omacraft/hyprcursor/" + id + "/" + name;
                if (!QFileInfo(cache).isDir() && m_runCommands) {
                    QDir().mkpath(cache);
                    QProcess unpack;
                    unpack.start("bsdtar", {"-x", "-f", hlc, "-C", cache});
                    unpack.waitForFinished(4000);
                }
                QString picture;
                for (const QFileInfo &entry : QDir(cache).entryInfoList({"*.svg", "*.png"}, QDir::Files, QDir::Name))
                    if (picture.isEmpty() || entry.fileName().endsWith(".svg"))
                        picture = entry.absoluteFilePath();
                if (picture.isEmpty())
                    continue;
                out << QVariantMap{{"role", role.role}, {"file", QUrl::fromLocalFile(picture).toString()},
                                   {"delays", QVariantList{0}}, {"animated", false}};
                break;
            }
        }
    }
    m_cursorSamples.insert(key, out);
    return out;
}

// ---------------------------------------------------------------- tinting

QString CursorsIcons::writeTinted(const QString &baseId, const QColor &color, QString *why) const {
    const QString base = pathOf(baseId);
    const Theme theme = readTheme(base, false);
    if (base.isEmpty() || !theme.xcursor) {
        if (why)
            *why = baseId + " has no XCursor pictures to tint (Hyprcursor-only themes can't be recoloured yet).";
        return {};
    }
    const QString id = kTintedPrefix + color.name().mid(1);
    const QString target = userDir() + "/" + id;
    const QString build = userDir() + "/.omacraft-tint-" + QString::number(QRandomGenerator::global()->generate(), 16);
    QDir().mkpath(build + "/cursors");

    bool dark = true;
    for (const char *name : {"left_ptr", "default", "arrow"}) {
        QFile file(base + "/cursors/" + name);
        if (file.open(QIODevice::ReadOnly)) {
            dark = XCursor::darkBody(file.readAll());
            break;
        }
    }
    int written = 0;
    for (const QFileInfo &entry : QDir(base + "/cursors").entryInfoList(QDir::Files | QDir::System)) {
        const QString out = build + "/cursors/" + entry.fileName();
        // Aliases stay aliases when they point inside the folder.
        if (entry.isSymLink() && !entry.readSymLink().contains('/')) {
            QFile::link(entry.readSymLink(), out);
            continue;
        }
        QFile in(entry.absoluteFilePath());
        if (in.size() > 32 * 1024 * 1024 || !in.open(QIODevice::ReadOnly))
            continue;
        const QByteArray bytes = in.readAll();
        QFile file(out);
        if (file.open(QIODevice::WriteOnly)) {
            file.write(XCursor::frames(bytes).isEmpty() ? bytes : XCursor::tinted(bytes, color, dark));
            ++written;
        }
    }
    const QString index = QString("[Icon Theme]\nName=OmaCraft tint of %1\nComment=%1 recoloured to the Omarchy theme by OmaCraft\n"
                                  "Inherits=%2\nX-OmaCraft-Base=%2\nX-OmaCraft-Color=%3\n")
                              .arg(theme.name, baseId, color.name());
    Proc::writeAtomically(build + "/index.theme", index.toUtf8());
    if (written == 0) {
        QDir(build).removeRecursively();
        if (why)
            *why = "No cursor in " + baseId + " could be read.";
        return {};
    }
    // Only OmaCraft's own tints are replaced; they're rebuilt from the base.
    for (const QFileInfo &old : QDir(userDir()).entryInfoList({kTintedPrefix + "*"}, QDir::Dirs | QDir::NoDotAndDotDot))
        if (readTheme(old.absoluteFilePath(), true).generated)
            QDir(old.absoluteFilePath()).removeRecursively();
    if (!QDir().rename(build, target)) {
        QDir(build).removeRecursively();
        if (why)
            *why = "Can't write " + target;
        return {};
    }
    return id;
}

// ---------------------------------------------------------------- applying

QString CursorsIcons::resolvedIconTheme() const {
    const QString mode = iconMode();
    if (mode == "omarchy") {
        QFile file(omarchyIconsPath());
        const QString named = file.open(QIODevice::ReadOnly) ? QString::fromUtf8(file.readAll()).trimmed() : QString();
        return safeId(named) ? named : QStringLiteral("Yaru-blue");
    }
    const QString pick = iconPick();
    if (mode == "follow") {
        QStringList installed;
        for (const Theme &theme : scan())
            if (theme.icons)
                installed << theme.id;
        return nearestVariant(pick, installed, QColor(tintColor()));
    }
    return pick;
}

QString CursorsIcons::resolvedCursorTheme(bool write) {
    const QString pick = cursorPick();
    if (cursorMode() != "follow" || pick.isEmpty())
        return pick;
    if (!write)
        return kTintedPrefix + QColor(tintColor()).name().mid(1);
    QString why;
    const QString id = writeTinted(pick, QColor(tintColor()), &why);
    if (id.isEmpty()) {
        setError(why);
        return pick;
    }
    return id;
}

QString CursorsIcons::cursorLua() const {
    const int size = m_config.value("cursor").toObject().value("size").toInt(24);
    const QString theme = m_cursorTheme;
    QString lua = "-- Written by OmaCraft's Cursors & Icons page; it's replaced on every change there.\n"
                  "-- The theme itself is ~/.local/share/icons/default, which Omarchy's XCURSOR_THEME names.\n";
    lua += QString("hl.env(\"XCURSOR_SIZE\", \"%1\")\nhl.env(\"HYPRCURSOR_SIZE\", \"%1\")\n").arg(size);
    const QString path = pathOf(theme);
    if (!path.isEmpty() && readTheme(path, false).hyprcursor)
        lua += QString("hl.env(\"HYPRCURSOR_THEME\", %1)\n").arg(luaString(theme));
    return lua;
}

void CursorsIcons::applyIcons(const QString &id) {
    if (!safeId(id))
        return;
    m_iconTheme = id;
    if (m_runCommands) {
        QProcess::execute("gsettings", {"set", "org.gnome.desktop.interface", "icon-theme", id});
        for (const char *ini : {"/.config/gtk-3.0/settings.ini", "/.config/gtk-4.0/settings.ini"})
            setIniKey(m_home + ini, "gtk-icon-theme-name", id);
    }
    emit appliedChanged();
}

void CursorsIcons::applyCursor(const QString &id, int size) {
    if (!safeId(id))
        return;
    m_cursorTheme = id;
    m_cursorSize = size;

    // Omarchy's XCURSOR_THEME is "default", so this is what X11 apps,
    // XWayland and Hyprland's own fallback load at the next login.
    const QString defaultIndex = userDir() + "/default/index.theme";
    QFile existing(defaultIndex);
    if (existing.open(QIODevice::ReadOnly)) {
        const QByteArray before = existing.readAll();
        existing.close();
        const QString backup = defaultIndex + ".before-omacraft";
        if (!before.contains("X-OmaCraft") && !QFileInfo::exists(backup))
            QFile::copy(defaultIndex, backup);
    }
    Proc::writeAtomically(defaultIndex, QString("[Icon Theme]\nName=Default\nComment=The cursor set in OmaCraft (Cursors & Icons)\n"
                                                "Inherits=%1\nX-OmaCraft=1\n").arg(id).toUtf8());

    // The size, and a Hyprcursor theme, for Hyprland at the next login.
    QString why;
    if (!Proc::writeAtomically(luaPath(), cursorLua().toUtf8(), &why))
        setError("Can't write " + luaPath() + ": " + why);
    const QString main = m_home + "/.config/hypr/hyprland.lua";
    QFile file(main);
    if (file.open(QIODevice::ReadOnly)) {
        const QByteArray contents = file.readAll();
        file.close();
        if (!contents.contains(kRequire.toUtf8())) {
            QFile::copy(main, QString("%1.before-cursor-%2").arg(main).arg(QDateTime::currentSecsSinceEpoch()));
            if (file.open(QIODevice::Append))
                file.write(QString("\n-- The cursor size and theme, set in OmaCraft.\npcall(require, \"%1\")\n").arg(kRequire).toUtf8());
        }
    }

    if (m_runCommands) {
        QProcess::execute("gsettings", {"set", "org.gnome.desktop.interface", "cursor-theme", id});
        QProcess::execute("gsettings", {"set", "org.gnome.desktop.interface", "cursor-size", QString::number(size)});
        for (const char *ini : {"/.config/gtk-3.0/settings.ini", "/.config/gtk-4.0/settings.ini"}) {
            setIniKey(m_home + ini, "gtk-cursor-theme-name", id);
            setIniKey(m_home + ini, "gtk-cursor-theme-size", QString::number(size));
        }
        // The cursor on screen now; hyprctl isn't there outside Hyprland.
        if (!Proc::which("hyprctl").isEmpty())
            QProcess::execute("hyprctl", {"setcursor", id, QString::number(size)});
    }
    emit appliedChanged();
}

void CursorsIcons::apply(bool cursorToo) {
    if (iconMode() != "omarchy" ? !iconPick().isEmpty() : m_config.contains("icons"))
        applyIcons(resolvedIconTheme());
    if (cursorToo && !cursorPick().isEmpty())
        applyCursor(resolvedCursorTheme(true), m_config.value("cursor").toObject().value("size").toInt(24));
}

void CursorsIcons::useIcons(const QString &id) {
    if (pathOf(id).isEmpty())
        return;
    remember();
    QJsonObject icons = m_config.value("icons").toObject();
    if (icons.value("mode").toString("omarchy") == "omarchy")
        icons.insert("mode", "fixed");
    icons.insert("pick", id);
    m_config.insert("icons", icons);
    saveConfig();
    applyIcons(resolvedIconTheme());
    if (iconMode() == "follow" && m_iconTheme != id)
        setNotice(QString("%1 follows the theme, so %2 is in use: the nearest colour to it.").arg(id, m_iconTheme));
}

void CursorsIcons::setIconMode(const QString &mode) {
    if (!QStringList{"omarchy", "fixed", "follow"}.contains(mode) || mode == iconMode())
        return;
    remember();
    QJsonObject icons = m_config.value("icons").toObject();
    icons.insert("mode", mode);
    if (icons.value("pick").toString().isEmpty())
        icons.insert("pick", m_iconTheme);
    m_config.insert("icons", icons);
    saveConfig();
    applyIcons(resolvedIconTheme());
}

void CursorsIcons::useCursor(const QString &id) {
    const QString path = pathOf(id);
    if (path.isEmpty())
        return;
    remember();
    QJsonObject cursor = m_config.value("cursor").toObject();
    cursor.insert("pick", id);
    if (!cursor.contains("size"))
        cursor.insert("size", m_cursorSize);
    if (cursor.value("mode").toString() == "follow" && !readTheme(path, false).xcursor) {
        cursor.insert("mode", "fixed");
        setNotice(id + " is a Hyprcursor-only theme, which can't be tinted, so it's used as it is.");
    }
    m_config.insert("cursor", cursor);
    saveConfig();
    applyCursor(resolvedCursorTheme(true), cursor.value("size").toInt(24));
}

void CursorsIcons::setCursorMode(const QString &mode) {
    if (!QStringList{"fixed", "follow"}.contains(mode) || mode == cursorMode())
        return;
    QJsonObject cursor = m_config.value("cursor").toObject();
    QString pick = cursor.value("pick").toString();
    if (pick.isEmpty() || pick.startsWith(kTintedPrefix))
        pick = m_cursorTheme;
    // Omarchy's "default" is an alias: tint the theme it stands for.
    if (pick == "default" || pick.isEmpty())
        pick = QFileInfo(cursorPathOf(pick.isEmpty() ? "default" : pick)).fileName();
    const QString path = pathOf(pick);
    if (mode == "follow" && (path.isEmpty() || !readTheme(path, false).xcursor)) {
        setError("Pick an XCursor theme first: " + (pick.isEmpty() ? QString("none is chosen") : pick + " has no XCursor pictures") + ".");
        return;
    }
    remember();
    cursor.insert("mode", mode);
    cursor.insert("pick", pick);
    if (!cursor.contains("size"))
        cursor.insert("size", m_cursorSize);
    m_config.insert("cursor", cursor);
    saveConfig();
    applyCursor(resolvedCursorTheme(true), cursor.value("size").toInt(24));
}

void CursorsIcons::setCursorSize(int size) {
    size = std::clamp(size, 16, 128);
    QJsonObject cursor = m_config.value("cursor").toObject();
    if (cursor.value("size").toInt(m_cursorSize) == size && !cursor.value("pick").toString().isEmpty())
        return;
    remember();
    cursor.insert("size", size);
    // The theme on screen, with Omarchy's "default" alias seen through.
    if (cursor.value("pick").toString().isEmpty() && !m_cursorTheme.startsWith(kTintedPrefix))
        cursor.insert("pick", QFileInfo(cursorPathOf(m_cursorTheme.isEmpty() ? QStringLiteral("default") : m_cursorTheme)).fileName());
    m_config.insert("cursor", cursor);
    saveConfig();
    if (cursor.value("pick").toString().isEmpty()) {
        m_cursorSize = size;
        emit appliedChanged();
        return;
    }
    applyCursor(resolvedCursorTheme(cursorMode() == "follow" && !m_cursorTheme.startsWith(kTintedPrefix)), size);
}

void CursorsIcons::setTintKey(const QString &key) {
    if (key == tintKey() || !::Theme::readColors(colorsPath()).contains(key))
        return;
    remember();
    m_config.insert("tint", key);
    saveConfig();
    if (iconMode() == "follow")
        applyIcons(resolvedIconTheme());
    if (cursorMode() == "follow" && !cursorPick().isEmpty())
        applyCursor(resolvedCursorTheme(true), m_config.value("cursor").toObject().value("size").toInt(24));
    emit appliedChanged();
}

void CursorsIcons::undo() {
    if (m_undo.isEmpty())
        return;
    // Only what the undone step had taken over is handed back: a cursor
    // OmaCraft never set isn't reset because an icon change was undone.
    const bool hadIcons = m_config.contains("icons");
    const bool hadCursor = !cursorPick().isEmpty();
    m_config = m_undo.takeLast();
    saveConfig();
    if (hadIcons && !m_config.contains("icons"))
        applyIcons(resolvedIconTheme());
    apply();
    if (hadCursor && cursorPick().isEmpty())
        restoreCursorDefaults();
    emit appliedChanged();
}

void CursorsIcons::restoreCursorDefaults() {
    const QString defaultIndex = userDir() + "/default/index.theme";
    const QString backup = defaultIndex + ".before-omacraft";
    if (QFileInfo::exists(backup)) {
        QFile::remove(defaultIndex);
        QFile::rename(backup, defaultIndex);
    } else {
        QFile file(defaultIndex);
        if (file.open(QIODevice::ReadOnly) && file.readAll().contains("X-OmaCraft")) {
            file.close();
            QFile::remove(defaultIndex);
            QDir().rmdir(userDir() + "/default");
        }
    }
    QFile::remove(luaPath());
    for (const QFileInfo &old : QDir(userDir()).entryInfoList({kTintedPrefix + "*"}, QDir::Dirs | QDir::NoDotAndDotDot))
        if (readTheme(old.absoluteFilePath(), true).generated)
            QDir(old.absoluteFilePath()).removeRecursively();
    m_cursorTheme = "default";
    m_cursorSize = 24;
    if (m_runCommands) {
        QProcess::execute("gsettings", {"reset", "org.gnome.desktop.interface", "cursor-theme"});
        QProcess::execute("gsettings", {"reset", "org.gnome.desktop.interface", "cursor-size"});
        if (!Proc::which("hyprctl").isEmpty())
            QProcess::execute("hyprctl", {"setcursor", "default", "24"});
        m_cursorTheme = gsettingsGet("cursor-theme");
    }
}

void CursorsIcons::restoreDefaults() {
    remember();
    m_config.insert("icons", QJsonObject{{"mode", "omarchy"}, {"pick", iconPick()}});
    m_config.insert("cursor", QJsonObject{{"mode", "fixed"}, {"pick", ""}, {"size", 24}});
    saveConfig();
    applyIcons(resolvedIconTheme());
    restoreCursorDefaults();
    setNotice("Icons follow the Omarchy theme again, and the cursor is Omarchy's own.");
    reload();
    emit appliedChanged();
}

int CursorsIcons::syncNow(const QString &home, const QStringList &systemDirs, bool runCommands) {
    CursorsIcons self(nullptr, home, systemDirs, runCommands);
    // Nothing chosen in OmaCraft: Omarchy's theme switch has the last word.
    self.apply();
    return 0;
}

// ---------------------------------------------------------------- importing

void CursorsIcons::chooseArchive() {
    if (m_picker)
        m_picker->chooseArchive("cursoricons-import", "Import an icon or cursor theme", m_home + "/Downloads");
}

void CursorsIcons::chooseFolder() {
    if (m_picker)
        m_picker->chooseFolder("cursoricons-import", "Import an icon or cursor theme folder", m_home + "/Downloads");
}

QStringList CursorsIcons::themeRoots(const QString &dir) {
    QStringList out;
    QList<QPair<QString, int>> queue{{dir, 0}};
    while (!queue.isEmpty()) {
        const auto [path, depth] = queue.takeFirst();
        const QFileInfo info(path);
        if (info.isSymLink())
            continue;
        const bool hasIndex = !readIndex(path + "/index.theme").isEmpty();
        const bool hasCursors = QFileInfo(path + "/cursors").isDir() || QFileInfo(path + "/hyprcursors").isDir();
        if (hasIndex || hasCursors) {
            out << path;
            continue;
        }
        if (depth >= 4)
            continue;
        for (const QFileInfo &child : QDir(path).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::NoSymLinks, QDir::Name))
            queue << qMakePair(child.absoluteFilePath(), depth + 1);
    }
    return out;
}

bool CursorsIcons::sanitize(const QString &root, QString *why) {
    const QString canonical = QFileInfo(root).canonicalFilePath();
    qint64 total = 0;
    int count = 0;
    QStringList drop;
    QDirIterator it(root, QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QFileInfo entry(it.next());
        if (++count > 250000) {
            if (why)
                *why = "it holds more than 250,000 files";
            return false;
        }
        if (entry.isSymLink()) {
            // A link out of the theme could point an icon at anything on disk.
            const QString target = QFileInfo(entry.absoluteFilePath()).canonicalFilePath();
            if (target.isEmpty() || !(target + "/").startsWith(canonical + "/"))
                drop << entry.absoluteFilePath();
            continue;
        }
        if (entry.isDir()) {
            QFile::setPermissions(entry.absoluteFilePath(), QFile::permissions(entry.absoluteFilePath()) | QFile::ReadOwner
                                                                | QFile::WriteOwner | QFile::ExeOwner);
            continue;
        }
        if (!entry.isFile()) {
            drop << entry.absoluteFilePath();
            continue;
        }
        QFile::setPermissions(entry.absoluteFilePath(),
                              (QFile::permissions(entry.absoluteFilePath()) | QFile::ReadOwner | QFile::WriteOwner)
                                  & ~(QFile::ExeOwner | QFile::ExeGroup | QFile::ExeOther | QFile::ExeUser));
        total += entry.size();
        if (total > qint64(2) * 1024 * 1024 * 1024) {
            if (why)
                *why = "it unpacks to more than 2 GB";
            return false;
        }
    }
    for (const QString &path : drop)
        QFile::remove(path);
    return true;
}

void CursorsIcons::importFrom(const QString &pathOrUrl) {
    QString path = pathOrUrl;
    if (path.startsWith("file:"))
        path = QUrl(path).toLocalFile();
    const QFileInfo info(path);
    if (path.isEmpty() || !info.exists()) {
        setError("Nothing to import at " + pathOrUrl);
        return;
    }
    if (m_busy)
        return;
    const QString staging = m_home + "/.cache/omacraft/import-" + QString::number(QRandomGenerator::global()->generate(), 16);
    QDir().mkpath(staging);
    const QString label = info.fileName();

    if (info.isDir()) {
        // A theme folder or a folder of themes; the copy is what gets checked.
        if (!copyTree(info.absoluteFilePath(), staging + "/" + info.fileName())) {
            QDir(staging).removeRecursively();
            setError("Can't copy " + info.absoluteFilePath());
            return;
        }
        finishImport(staging, label);
        return;
    }
    bool archive = false;
    for (const QString &suffix : kArchiveSuffixes)
        archive = archive || label.endsWith(suffix, Qt::CaseInsensitive);
    if (!archive) {
        QDir(staging).removeRecursively();
        setError(label + " isn't an archive OmaCraft can open: use .tar.gz, .tar.xz, .tar.zst, .zip or a folder.");
        return;
    }
    if (Proc::which("bsdtar").isEmpty()) {
        QDir(staging).removeRecursively();
        setError("Importing archives needs bsdtar (pacman -S libarchive).");
        return;
    }
    if (!m_runCommands) {
        QDir(staging).removeRecursively();
        return;
    }
    setBusy(true);
    setNotice("Unpacking " + label + "…");
    // bsdtar refuses absolute paths and ".." on its own; links out of the
    // folder are dropped afterwards. The archive's own name is the theme's
    // when it has no folder inside.
    const QString into = staging + "/" + archiveStem(label);
    QDir().mkpath(into);
    Proc::run(this, "bsdtar", {"-x", "-f", info.absoluteFilePath(), "-C", into, "--no-same-owner"},
              [this, staging, label](const Proc::Result &result) {
        setBusy(false);
        if (!result.ok()) {
            QDir(staging).removeRecursively();
            setError("Can't unpack " + label + ": " + result.message());
            return;
        }
        finishImport(staging, label);
    }, 180000);
}

void CursorsIcons::finishImport(const QString &staging, const QString &label) {
    QString why;
    if (!sanitize(staging, &why)) {
        QDir(staging).removeRecursively();
        setError("Not importing " + label + ": " + why + ".");
        return;
    }
    const QStringList roots = themeRoots(staging);
    if (roots.isEmpty()) {
        QDir(staging).removeRecursively();
        setError("No icon or cursor theme in " + label + ": a theme is a folder with an index.theme, or a cursors folder.");
        return;
    }
    QStringList added, skipped;
    for (const QString &root : roots) {
        const QString id = QFileInfo(root).fileName();
        if (!safeId(id) || id.startsWith(kTintedPrefix)) {
            skipped << id + " (not a usable name)";
            continue;
        }
        if (!pathOf(id).isEmpty()) {
            skipped << id + " (already installed)";
            continue;
        }
        // A bare cursors folder gets the index.theme it was missing.
        if (!QFileInfo::exists(root + "/index.theme"))
            Proc::writeAtomically(root + "/index.theme", QString("[Icon Theme]\nName=%1\nInherits=Adwaita\n").arg(id).toUtf8());
        const QString target = userDir() + "/" + id;
        if (!moveTree(root, target)) {
            skipped << id + " (couldn't be moved in)";
            continue;
        }
        added << id;
        if (m_runCommands && readTheme(target, true).icons && !Proc::which("gtk-update-icon-cache").isEmpty())
            Proc::detach("gtk-update-icon-cache", {"-q", "-f", "-t", target});
    }
    QDir(staging).removeRecursively();
    reload();
    if (added.isEmpty())
        setError("Nothing imported from " + label + ": " + skipped.join(", ") + ".");
    else
        setNotice("Imported " + added.join(", ") + (skipped.isEmpty() ? QString() : ". Skipped " + skipped.join(", ")) + ".");
}

void CursorsIcons::remove(const QString &id) {
    const QString path = pathOf(id);
    const bool user = path.startsWith(userDir() + "/") || path.startsWith(m_home + "/.icons/");
    if (path.isEmpty() || !user) {
        setError(id + " came with the system; only themes you imported can be removed.");
        return;
    }
    if (id == m_iconTheme || id == m_cursorTheme || id == iconPick() || id == cursorPick()) {
        setError(id + " is in use. Pick another first.");
        return;
    }
    const QString stash = m_home + "/.local/share/omacraft/stash/icons/" + id + "-" + QString::number(QDateTime::currentSecsSinceEpoch());
    if (!moveTree(path, stash)) {
        setError("Can't move " + id + " to " + stash);
        return;
    }
    m_cursorSamples.clear();
    reload();
    setNotice(id + " is put away in " + QDir(m_home).relativeFilePath(stash) + "; move it back to ~/.local/share/icons to restore it.");
}

void CursorsIcons::openFolder() {
    QDir().mkpath(userDir());
    if (m_runCommands)
        Proc::detach("xdg-open", {userDir()});
}

void CursorsIcons::themeSwitched() {
    // The theme-set hook does the work; the page only catches up.
    if (m_runCommands)
        QTimer::singleShot(1500, this, [this] {
            readApplied();
            m_cursorSamples.clear();
            reload();
        });
    emit appliedChanged();
}
