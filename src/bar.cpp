#include "bar.h"

#include <algorithm>
#include <cmath>

#include <QColor>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJSEngine>
#include <QJsonDocument>
#include <QRegularExpression>
#include <QSet>

#include "proc.h"
#include "theme.h"

namespace {

const QStringList kLanes{"left", "center", "right"};
const QString kNotTheBar = "omabar16 isn't your bar right now. Use it as the bar first.";

QJsonObject readJsonObject(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object();
}

bool isHex(const QJsonValue &value) {
    static const QRegularExpression hex("^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$");
    return value.isString() && hex.match(value.toString()).hasMatch();
}

QString slug(const QString &label) {
    QString out = label.toLower();
    out.replace(QRegularExpression("[^a-z0-9]+"), "-");
    out.remove(QRegularExpression("^-+|-+$"));
    return out;
}

// The parts of the bar section OmaCraft edits, out of shell.json's "bar".
QJsonObject configOf(const QJsonObject &bar) {
    QJsonObject layout = bar.value("layout").toObject();
    for (const auto &lane : kLanes)
        if (!layout.value(lane).isArray())
            layout.insert(lane, QJsonArray{});
    return QJsonObject{{"position", bar.value("position").toString("top")},
                       {"transparent", bar.value("transparent").toBool()},
                       {"centerAnchor", bar.contains("centerAnchor") ? bar.value("centerAnchor").toString() : "omarchy.clock"},
                       {"layout", layout},
                       {"style", bar.value("style").toObject()},
                       {"hidden", bar.value("hidden").toArray()}};
}

// A bar theme's id from its name: "Rosé Pine Moon" -> "rose-pine-moon".
QString themeSlug(const QString &label) {
    QString plain = label.normalized(QString::NormalizationForm_D);
    plain.remove(QRegularExpression("[\\x{0300}-\\x{036f}]"));
    return slug(plain);
}

// The themes OmaCraft ships beside the plugin's (:/data/bar-extras.json).
QJsonObject barExtras() {
    QFile file(":/data/bar-extras.json");
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object();
}

// The plugin's base16 themes and OmaCraft's, one of each name, A to Z.
// Each row is [label, background, foreground, red, orange, yellow, green,
// cyan, blue, purple], made a solid chevron theme as omabar16 makes its own.
QVariantList withMoreBase16(QVariantList themes, const QJsonArray &rows) {
    QSet<QString> have;
    for (const auto &theme : themes)
        have.insert(theme.toMap().value("label").toString().toLower());
    for (const auto &value : rows) {
        const QJsonArray d = value.toArray();
        if (d.size() < 10 || have.contains(d.at(0).toString().toLower()))
            continue;
        const QString label = d.at(0).toString();
        have.insert(label.toLower());
        QVariantMap style{{"shape", "arrow"}, {"solid", true}, {"colors", "cycle"}, {"gap", 1}, {"flatEnds", true}, {"depth", 0.42},
                          {"palette", QVariantList{d.at(7).toString(), d.at(8).toString(), d.at(6).toString(),
                                                   d.at(5).toString(), d.at(4).toString(), d.at(3).toString()}},
                          {"bg", d.at(1).toString()}, {"fg", d.at(1).toString()}, {"accent", d.at(7).toString()}};
        themes << QVariantMap{{"id", "base16-" + themeSlug(label)}, {"label", label}, {"desc", "base16 · " + d.at(1).toString()},
                              {"base16", true}, {"style", style}};
    }
    std::sort(themes.begin(), themes.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value("label").toString().compare(b.toMap().value("label").toString(), Qt::CaseInsensitive) < 0;
    });
    return themes;
}

double relativeLuminance(const QColor &c) {
    auto channel = [](double v) { return v <= 0.04045 ? v / 12.92 : std::pow((v + 0.055) / 1.055, 2.4); };
    return 0.2126 * channel(c.redF()) + 0.7152 * channel(c.greenF()) + 0.0722 * channel(c.blueF());
}
double contrastOf(const QColor &a, const QColor &b) {
    const double la = relativeLuminance(a), lb = relativeLuminance(b);
    return (std::max(la, lb) + 0.05) / (std::min(la, lb) + 0.05);
}

// A bar theme for each of Omarchy's own themes: a look chosen for it, in
// the colours its colors.toml has, so the bar matches the theme even while
// another one is in use.
QVariantList omarchyThemes(const QJsonObject &looks, const QString &themesDir) {
    QVariantList out;
    for (auto it = looks.begin(); it != looks.end(); ++it) {
        const auto colors = Theme::readColors(themesDir + "/" + it.key() + "/colors.toml");
        if (colors.isEmpty())
            continue;
        const QJsonObject look = it.value().toObject();
        QVariantMap style = look.value("style").toObject().toVariantMap();
        const QString accent = colors.value("accent", colors.value("blue", "#888888"));
        const QString background = colors.value("background", "#111111");
        QVariantList palette;
        for (const auto &name : style.value("palette").toList())
            palette << colors.value(name.toString(), accent);
        if (palette.isEmpty())
            palette << accent;
        style["palette"] = palette;
        style["bg"] = background;
        style["accent"] = accent;
        if (!style.contains("colors"))
            style["colors"] = "cycle";
        // Ink that reads: the background on filled segments when it can,
        // otherwise near-black or near-white; the theme's text elsewhere.
        const QString shape = style.value("shape").toString();
        const bool fills = shape != "none" && shape != "underline" && style.value("solid", true).toBool();
        const QColor first(palette.first().toString());
        if (fills)
            style["fg"] = contrastOf(QColor(background), first) >= 3 ? background
                        : relativeLuminance(first) > 0.35 ? QString("#111111") : QString("#f5f5f5");
        else
            style["fg"] = colors.value("foreground", "#cccccc");
        out << QVariantMap{{"id", "omarchy-theme-" + it.key()}, {"label", look.value("label").toString(it.key())},
                           {"desc", look.value("desc").toString()}, {"omarchy", it.key()}, {"style", style}};
    }
    return out;
}

// The source of a QML JavaScript library, made plain JavaScript: ".pragma
// library" dropped and each ".import "x.js" as Name" replaced by that file's
// top-level names, gathered into an object called Name.
QString plainScript(const QString &path, int depth = 0) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    QString source = QString::fromUtf8(file.readAll());
    source.replace(QRegularExpression(R"(^\s*\.pragma\s+library\s*$)", QRegularExpression::MultilineOption), "");
    static const QRegularExpression importLine(R"re(^\s*\.import\s+"([^"]+\.js)"\s+as\s+(\w+)\s*$)re",
                                               QRegularExpression::MultilineOption);
    QString prelude;
    auto it = importLine.globalMatch(source);
    while (it.hasNext()) {
        const auto match = it.next();
        const QString inner = QFileInfo(path).absolutePath() + "/" + match.captured(1);
        const QString body = depth < 3 ? plainScript(inner, depth + 1) : QString();
        static const QRegularExpression topName(R"(^(?:var|function)\s+(\w+))", QRegularExpression::MultilineOption);
        QStringList names;
        auto names_it = topName.globalMatch(body);
        while (names_it.hasNext())
            names << names_it.next().captured(1);
        names.removeDuplicates();
        QStringList fields;
        for (const auto &name : names)
            fields << QString("%1: typeof %1 === 'undefined' ? undefined : %1").arg(name);
        prelude += QString("var %1 = (function() {\n%2\nreturn { %3 };\n})();\n")
                       .arg(match.captured(2), body, fields.join(", "));
    }
    source.replace(importLine, "");
    return prelude + source;
}

QString stampOf(const QString &path) {
    return path + "@" + QFileInfo(path).lastModified().toString(Qt::ISODateWithMs);
}

} // namespace

Bar::Bar(std::function<QString()> pluginDir, std::function<QString()> studioDir, const QString &home, bool runCommands,
         QObject *parent)
    : QObject(parent),
      m_pluginDir(std::move(pluginDir)),
      m_studioDir(std::move(studioDir)),
      m_home(home.isEmpty() ? QDir::homePath() : home),
      m_runCommands(runCommands) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(120);
    connect(&m_debounce, &QTimer::timeout, this, &Bar::reload);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    // Long enough to gather a run of edits, short enough to feel live.
    m_writeTimer.setSingleShot(true);
    m_writeTimer.setInterval(140);
    connect(&m_writeTimer, &QTimer::timeout, this, &Bar::write);
    m_burst.setSingleShot(true);
    m_burst.setInterval(600);
    reload();
    if (m_runCommands)
        refreshWidgets();
}

// --- reading ---

bool Bar::loadPresets(const QString &path, QString *problem) {
    const QString source = plainScript(path);
    if (source.isEmpty()) {
        if (problem)
            *problem = "Can't read " + path;
        return false;
    }
    QJSEngine engine;
    const QJSValue result = engine.evaluate(source, path);
    if (result.isError()) {
        if (problem)
            *problem = QString("%1 line %2: %3").arg(path).arg(result.property("lineNumber").toInt()).arg(result.toString());
        return false;
    }
    const QJSValue global = engine.globalObject();

    const auto colors = Theme::readColors(m_home + "/.local/state/omarchy/current/theme/colors.toml");
    const QStringList defaultPalette = global.property("DEFAULT_PALETTE").toVariant().toStringList();
    auto swatches = [&](const QVariantMap &style) {
        QStringList palette = style.value("palette").toStringList();
        if (palette.isEmpty())
            palette = defaultPalette;
        QStringList hexes;
        for (const auto &entry : palette)
            hexes << (entry.startsWith('#') ? entry : colors.value(entry, "#888888"));
        return hexes.mid(0, 6);
    };

    QVariantList themes;
    auto addThemes = [&](const QVariantList &list, const QString &group) {
        for (const auto &value : list) {
            auto theme = value.toMap();
            if (theme.value("id").toString().isEmpty())
                continue;
            theme["group"] = group;
            theme["swatches"] = swatches(theme.value("style").toMap());
            themes << theme;
        }
    };
    addThemes(global.property("THEMES").toVariant().toList(), "Originals");
    addThemes(global.property("JAKOOLIT").toVariant().toList(), "JaKooLit");
    if (global.hasProperty("HANCORE"))
        addThemes(global.property("HANCORE").toVariant().toList(), "HANCORE");
    const QJsonObject extras = barExtras();
    addThemes(omarchyThemes(extras.value("omarchy").toObject(),
                            qEnvironmentVariable("OMACRAFT_OMARCHY_THEMES", "/usr/share/omarchy/themes")), "Omarchy");
    // More base16 beside the plugin's own, when it has a base16 set.
    const QVariantList base16 = global.property("BASE16").toVariant().toList();
    addThemes(base16.isEmpty() ? base16 : withMoreBase16(base16, extras.value("base16").toArray()), "base16");
    QVariantList yours = userThemes().toVariantList();
    for (auto &theme : yours) {
        auto map = theme.toMap();
        map["user"] = true;
        theme = map;
    }
    addThemes(yours, "Yours");

    QVariantList layouts;
    QVariantList source_layouts = global.property(global.hasProperty("ALL_LAYOUTS") ? "ALL_LAYOUTS" : "LAYOUTS")
                                      .toVariant().toList();
    for (const auto &value : source_layouts) {
        auto layout = value.toMap();
        const QString id = layout.value("id").toString();
        QStringList counts;
        const auto lanes = layout.value("layout").toMap();
        for (const auto &lane : kLanes)
            counts << QString::number(lanes.value(lane).toList().size());
        layout["counts"] = counts.join(" · ");
        const QString edge = layout.value("position").toString();
        layout["group"] = id.startsWith("jk-") ? "JaKooLit"
                        : id.startsWith("hc-") ? "HANCORE"
                        : (edge == "left" || edge == "right") ? "Side rails"
                        : "Originals";
        layouts << layout;
    }

    m_themes = themes;
    m_layouts = layouts;
    m_glyphs = global.property("GLYPHS").toVariant().toMap();
    loadIcons(QFileInfo(path).absolutePath() + "/Icons.js");
    emit presetsChanged();
    return true;
}

void Bar::loadIcons(const QString &path) {
    m_iconSets.clear();
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return;
    // RAW = { fa: "name:hex;…", oct: "…" }
    static const QRegularExpression set(R"re(^\s*(\w+)\s*:\s*"([^"]*)")re", QRegularExpression::MultilineOption);
    auto it = set.globalMatch(QString::fromUtf8(file.readAll()));
    while (it.hasNext()) {
        const auto match = it.next();
        if (match.captured(2).contains(':'))
            m_iconSets.insert(match.captured(1), match.captured(2));
    }
}

QVariantList Bar::icons(const QString &set, const QString &query, int limit) const {
    QVariantList out;
    const QStringList words = query.toLower().split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
    for (const auto &pair : m_iconSets.value(set).split(';', Qt::SkipEmptyParts)) {
        const int colon = pair.lastIndexOf(':');
        if (colon <= 0)
            continue;
        QString name = pair.left(colon);
        name.replace('_', ' ');
        bool match = true;
        for (const auto &word : words)
            match = match && name.contains(word);
        if (!match)
            continue;
        bool ok = false;
        const uint code = pair.mid(colon + 1).toUInt(&ok, 16);
        if (!ok)
            continue;
        out << QVariantMap{{"name", name}, {"glyph", QString::fromUcs4(reinterpret_cast<const char32_t *>(&code), 1)}};
        if (out.size() >= limit)
            break;
    }
    return out;
}

void Bar::setShellConfig(const QJsonObject &shell) {
    m_shell = shell;
    const QJsonObject next = configOf(shell.value("bar").toObject());
    if (next != m_cfg)
        m_cfg = next;
    // The bar as OmaCraft first found it, for Revert.
    if (m_snapshot.isEmpty() && !shell.isEmpty())
        m_snapshot = m_cfg;
    emit changed();
}

void Bar::watch() {
    const auto paths = m_watcher.files() + m_watcher.directories();
    if (!paths.isEmpty())
        m_watcher.removePaths(paths);
    const QString shell = shellPath();
    for (const auto &path : {shell, QFileInfo(shell).absolutePath(), m_home + "/.config/omarchy/omabar16"})
        if (QFileInfo::exists(path))
            m_watcher.addPath(path);
}

void Bar::reload() {
    // An edit not yet written is newer than the file.
    if (!m_pendingWrite)
        setShellConfig(readJsonObject(shellPath()));

    QStringList candidates;
    if (m_studioDir && !m_studioDir().isEmpty())
        candidates << m_studioDir() + "/bar/data/Presets.js";
    const QString dir = m_pluginDir ? m_pluginDir() : QString();
    if (!dir.isEmpty())
        candidates << dir + "/data/Presets.js";
    QString presets;
    for (const auto &path : candidates)
        if (QFileInfo::exists(path)) {
            presets = path;
            break;
        }
    // The bar can't draw any of it without omabar16.
    if (dir.isEmpty())
        presets.clear();

    // shell.json changes on every edit; only read the presets again when
    // they, or the user's saved themes, have changed.
    const QString stamp = presets.isEmpty() ? QString()
                        : stampOf(presets) + "|" + stampOf(m_home + "/.config/omarchy/omabar16/themes.json");
    if (presets.isEmpty()) {
        m_presetsStamp.clear();
        if (!m_themes.isEmpty()) {
            m_themes.clear();
            m_layouts.clear();
            emit presetsChanged();
        }
    } else if (stamp != m_presetsStamp) {
        QString problem;
        if (loadPresets(presets, &problem))
            m_presetsStamp = stamp;
        else
            setError("Couldn't read the bar's presets: " + problem);
    }
    watch();
}

QString Bar::barId() const {
    const auto id = m_shell.value("bar").toObject().value("id").toString();
    return id.isEmpty() ? "omarchy.bar" : id;
}

QString Bar::position() const {
    const auto value = m_cfg.value("position").toString();
    return value.isEmpty() ? "top" : value;
}

QVariantMap Bar::themeColors() const {
    QVariantMap out;
    const auto colors = Theme::readColors(m_home + "/.local/state/omarchy/current/theme/colors.toml");
    for (auto it = colors.begin(); it != colors.end(); ++it)
        out.insert(it.key(), it.value());
    return out;
}

QString Bar::currentTheme() const {
    // A theme is current when the bar's style is exactly it.
    QJsonObject current = m_cfg.value("style").toObject();
    // An underlined theme may have had its text made readable.
    const bool underline = current.value("shape").toString() == "underline";
    if (underline)
        current.remove("fg");
    for (const auto &value : m_themes) {
        const auto theme = value.toMap();
        QJsonObject style = QJsonObject::fromVariantMap(theme.value("style").toMap());
        if (underline)
            style.remove("fg");
        if (style == current)
            return theme.value("id").toString();
    }
    return {};
}

QString Bar::currentLayout() const {
    // The same widgets in the same places; their settings don't count.
    auto ids = [](const QJsonObject &layout) {
        QStringList out;
        for (const auto &lane : kLanes) {
            QStringList row;
            for (const auto &entry : layout.value(lane).toArray())
                row << entry.toObject().value("id").toString();
            out << row.join(",");
        }
        return out.join("|");
    };
    const QString mine = ids(m_cfg.value("layout").toObject());
    for (const auto &value : m_layouts) {
        const auto layout = value.toMap();
        if (ids(QJsonObject::fromVariantMap(layout.value("layout").toMap())) == mine)
            return layout.value("id").toString();
    }
    return {};
}

void Bar::refreshWidgets() {
    if (!m_runCommands)
        return;
    Proc::run(this, "omarchy-plugin-catalog", {}, [this](const Proc::Result &result) {
        QVariantList widgets;
        for (const auto &value : QJsonDocument::fromJson(result.out).array()) {
            const auto plugin = value.toObject();
            bool widget = false;
            for (const auto &kind : plugin.value("kinds").toArray())
                widget = widget || kind.toString() == "bar-widget";
            if (!widget)
                continue;
            const auto barWidget = plugin.value("barWidget").toObject();
            const QString name = barWidget.value("displayName").toString();
            const QString category = barWidget.value("category").toString();
            widgets << QVariantMap{{"id", plugin.value("id").toString()},
                                   {"name", name.isEmpty() ? plugin.value("name").toString() : name},
                                   {"description", plugin.value("description").toString()},
                                   {"category", category.isEmpty() ? "Other" : category},
                                   {"multiple", barWidget.value("allowMultiple").toBool()}};
        }
        std::sort(widgets.begin(), widgets.end(), [](const QVariant &a, const QVariant &b) {
            return a.toMap().value("name").toString().compare(b.toMap().value("name").toString(),
                                                               Qt::CaseInsensitive) < 0;
        });
        m_widgets = widgets;
        emit widgetsChanged();
    });
}

QString Bar::glyphFor(const QString &id) const {
    const QString glyph = m_glyphs.value(id).toString();
    return glyph.isEmpty() ? QString::fromUcs4(U"\U000F0B47") : glyph;
}

QString Bar::widgetName(const QString &id) const {
    for (const auto &value : m_widgets) {
        const auto widget = value.toMap();
        if (widget.value("id").toString() == id)
            return widget.value("name").toString();
    }
    QString name = id.section('.', 1);
    if (name.isEmpty())
        name = id;
    name.replace('-', ' ');
    return name.isEmpty() ? name : name.at(0).toUpper() + name.mid(1);
}

// --- writing ---

bool Bar::editable() {
    if (inUse())
        return true;
    setError(kNotTheBar);
    return false;
}

bool Bar::commit(QJsonObject next, bool checkInk) {
    if (!editable())
        return false;
    if (checkInk) {
        QJsonObject bar = next;
        const QString ink = underlineInk(bar, Theme::readColors(m_home + "/.local/state/omarchy/current/theme/colors.toml"));
        if (!ink.isEmpty()) {
            QJsonObject style = next.value("style").toObject();
            style.insert("fg", ink);
            next.insert("style", style);
            setNotice(QString("Underlined text sits on the bar itself, so it's now %1 to read there.").arg(ink));
        }
    }
    if (next == m_cfg)
        return true;
    // A run of quick edits (a slider dragged, a colour wheel turned) is one step.
    if (!m_burst.isActive()) {
        m_undo.append(m_cfg);
        while (m_undo.size() > 80)
            m_undo.removeFirst();
        m_redo.clear();
    }
    m_burst.start();
    m_cfg = next;
    m_pendingWrite = true;
    m_writeTimer.start();
    emit changed();
    return true;
}

void Bar::flush() {
    if (m_writeTimer.isActive()) {
        m_writeTimer.stop();
        write();
    }
}

void Bar::write() {
    m_pendingWrite = false;
    QFile file(shellPath());
    if (!file.open(QIODevice::ReadWrite)) {
        setError("Couldn't open " + shellPath() + ": " + file.errorString());
        return;
    }
    const QByteArray before = file.readAll();
    QJsonParseError parseError;
    QJsonObject shell = QJsonDocument::fromJson(before.trimmed().isEmpty() ? "{}" : before, &parseError).object();
    if (parseError.error != QJsonParseError::NoError) {
        setError("shell.json doesn't read as JSON (" + parseError.errorString() + "), so the bar wasn't saved.");
        return;
    }
    QJsonObject bar = shell.value("bar").toObject();
    for (auto it = m_cfg.begin(); it != m_cfg.end(); ++it)
        bar.insert(it.key(), it.value());
    // omabar16 never reads "hidden"; it's only there while something is.
    if (m_cfg.value("hidden").toArray().isEmpty())
        bar.remove("hidden");
    bar.insert("id", "omabar16");
    shell.insert("bar", bar);
    // In place, not through a rename: the shell's file watcher stays on it.
    const QByteArray bytes = QJsonDocument(shell).toJson(QJsonDocument::Indented);
    if (!file.seek(0) || file.write(bytes) != bytes.size() || !file.resize(bytes.size())) {
        setError("Couldn't save " + shellPath() + ": " + file.errorString());
        return;
    }
    file.close();
    m_shell = shell;
}

QJsonObject Bar::entryAt(const QString &lane, int index) const {
    const QJsonArray entries = m_cfg.value("layout").toObject().value(lane).toArray();
    return index >= 0 && index < entries.size() ? entries.at(index).toObject() : QJsonObject();
}

QJsonObject Bar::newEntry(const QString &id) const {
    if (id == "omarchy.spacer")
        return {{"id", id}, {"size", 12}};
    if (id == "omarchy.clock")
        return {{"id", id}, {"format", "dddd HH:mm"}, {"formatAlt", "d MMMM 'W'ww yyyy"}, {"verticalFormat", "HH\n—\nmm"}};
    return {{"id", id}};
}

void Bar::fixAnchor(QJsonObject &cfg) {
    // The anchor sits dead centre; it has to be in the centre lane. Failing
    // that the clock, failing that nothing (the lane centres as a group).
    const QJsonArray center = cfg.value("layout").toObject().value("center").toArray();
    auto has = [&center](const QString &id) {
        return std::any_of(center.begin(), center.end(), [&id](const QJsonValue &v) { return v.toObject().value("id").toString() == id; });
    };
    const QString anchor = cfg.value("centerAnchor").toString();
    if (!anchor.isEmpty() && has(anchor))
        return;
    cfg.insert("centerAnchor", has("omarchy.clock") ? "omarchy.clock" : "");
}

// --- themes ---

void Bar::applyTheme(const QString &id) {
    for (const auto &value : m_themes) {
        const auto theme = value.toMap();
        if (theme.value("id").toString() != id)
            continue;
        QJsonObject next = m_cfg;
        next.insert("style", QJsonObject::fromVariantMap(theme.value("style").toMap()));
        commit(next, true);
        return;
    }
    if (editable())
        setError("There's no bar theme called " + id + ".");
}

void Bar::setWholeStyle(const QVariantMap &style) {
    QJsonObject next = m_cfg;
    next.insert("style", sanitizeStyle(QJsonObject::fromVariantMap(style)));
    commit(next, true);
}

void Bar::setStyle(const QString &key, const QVariant &value) {
    QJsonObject next = m_cfg;
    QJsonObject style = next.value("style").toObject();
    const QJsonValue json = QJsonValue::fromVariant(value);
    if (!value.isValid() || value.isNull() || (json.isString() && json.toString().isEmpty()))
        style.remove(key);
    else
        style.insert(key, json);
    // Segments with no fill setting are solid, as in omabar16.
    if (key == "shape" && json.toString() != "none" && !style.contains("solid"))
        style.insert("solid", true);
    next.insert("style", style);
    commit(next, key == "shape" || key == "bg" || key == "minContrast" || key == "fg");
}

void Bar::setColor(const QString &part, const QString &hex) {
    if (!isHex(hex)) {
        clearColor(part);
        return;
    }
    QJsonObject next = m_cfg;
    QJsonObject style = next.value("style").toObject();
    if (part == "bg" || part == "fg" || part == "accent" || part == "outlineColor" || part == "hoverColor") {
        style.insert(part, hex);
    } else if (part.startsWith("pal:")) {
        QJsonArray palette = style.value("palette").toArray();
        const int index = part.mid(4).toInt();
        // Theme colour names become what they show now, so one can change.
        const auto colors = Theme::readColors(m_home + "/.local/state/omarchy/current/theme/colors.toml");
        for (int i = 0; i < palette.size(); ++i)
            if (!isHex(palette.at(i)))
                palette.replace(i, colors.value(palette.at(i).toString(), "#888888"));
        while (palette.size() <= index)
            palette.append(hex);
        palette.replace(index, hex);
        style.insert("palette", palette);
    } else if (part.startsWith("region:") || part.startsWith("module:")) {
        const QString group = part.startsWith("region:") ? "regions" : "modules";
        QJsonObject map = style.value(group).toObject();
        map.insert(part.section(':', 1), hex);
        style.insert(group, map);
    } else {
        return;
    }
    if (style.value("shape").toString("none") == "none" && part != "bg" && part != "fg" && part != "hoverColor")
        style.insert("shape", "arrow");
    next.insert("style", style);
    commit(next, part == "bg" || part == "fg");
}

void Bar::clearColor(const QString &part) {
    QJsonObject next = m_cfg;
    QJsonObject style = next.value("style").toObject();
    if (part == "bg" || part == "fg" || part == "accent" || part == "outlineColor" || part == "hoverColor") {
        style.remove(part);
    } else if (part.startsWith("pal:")) {
        style.remove("palette");
    } else if (part.startsWith("region:") || part.startsWith("module:")) {
        const QString group = part.startsWith("region:") ? "regions" : "modules";
        QJsonObject map = style.value(group).toObject();
        map.remove(part.section(':', 1));
        if (map.isEmpty())
            style.remove(group);
        else
            style.insert(group, map);
    }
    next.insert("style", style);
    commit(next, part == "bg" || part == "fg");
}

QJsonArray Bar::userThemes() const {
    QFile file(m_home + "/.config/omarchy/omabar16/themes.json");
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).array();
}

void Bar::saveUserThemes(const QJsonArray &themes) {
    QString problem;
    if (!Proc::writeAtomically(m_home + "/.config/omarchy/omabar16/themes.json",
                               QJsonDocument(themes).toJson(QJsonDocument::Indented), &problem)) {
        setError("Couldn't save your bar themes: " + problem);
        return;
    }
    // Read back at once, rather than when the watcher gets to it.
    m_presetsStamp.clear();
    reload();
}

bool Bar::saveTheme(const QString &name) {
    const QString label = name.trimmed().left(40);
    if (label.isEmpty())
        return false;
    const QString id = "user-" + (slug(label).isEmpty() ? "theme" : slug(label));
    QJsonArray themes;
    for (const auto &value : userThemes())
        if (value.toObject().value("id").toString() != id)
            themes.append(value);
    themes.append(QJsonObject{{"id", id}, {"label", label}, {"desc", "Your theme"}, {"user", true},
                              {"style", m_cfg.value("style").toObject()}});
    saveUserThemes(themes);
    setNotice("Saved the bar's look as “" + label + "”, under Yours.");
    return true;
}

void Bar::deleteTheme(const QString &id) {
    QJsonArray themes;
    for (const auto &value : userThemes())
        if (value.toObject().value("id").toString() != id)
            themes.append(value);
    saveUserThemes(themes);
}

void Bar::exportTheme(const QString &id) {
    QJsonObject theme{{"label", "My bar"}, {"desc", "Exported look"}, {"style", sanitizeStyle(m_cfg.value("style").toObject())}};
    if (!id.isEmpty()) {
        const auto found = std::find_if(m_themes.begin(), m_themes.end(), [&id](const QVariant &v) { return v.toMap().value("id") == id; });
        if (found == m_themes.end())
            return;
        const auto map = found->toMap();
        theme = {{"label", map.value("label").toString()}, {"desc", map.value("desc").toString()},
                 {"style", sanitizeStyle(QJsonObject::fromVariantMap(map.value("style").toMap()))}};
    }
    const QByteArray json = QJsonDocument(QJsonObject{{"omabar16", 1}, {"themes", QJsonArray{theme}}}).toJson(QJsonDocument::Indented);
    const QString path = m_home + "/.config/omarchy/omabar16/exports/" + (slug(theme.value("label").toString()).isEmpty() ? "theme" : slug(theme.value("label").toString())) + ".json";
    QString problem;
    if (!Proc::writeAtomically(path, json, &problem)) {
        setError("Couldn't export: " + problem);
        return;
    }
    QString shown = path;
    shown.replace(m_home, "~");
    setNotice("Exported to " + shown + (m_runCommands && !Proc::which("wl-copy").isEmpty() ? ", and copied." : "."));
    if (m_runCommands && !Proc::which("wl-copy").isEmpty())
        Proc::run(this, "sh", {"-c", "wl-copy < " + Proc::shellQuote(path)});
}

void Bar::importThemes(const QString &textOrPath) {
    QByteArray json = textOrPath.trimmed().toUtf8();
    if (!json.startsWith('{') && !json.startsWith('[')) {
        QString path = Proc::expandHome(QString::fromUtf8(json), m_home);
        if (path.startsWith("file://"))
            path = path.mid(7);
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) {
            setError("Couldn't read " + path + ".");
            return;
        }
        json = file.readAll();
    }
    const QJsonArray found = parseThemes(json);
    if (found.isEmpty()) {
        setError("That has no bar themes in it.");
        return;
    }
    QJsonArray themes = userThemes();
    for (const auto &value : found) {
        const auto theme = value.toObject();
        const QString label = theme.value("label").toString();
        const QString id = "user-" + (slug(label).isEmpty() ? "imported" : slug(label));
        for (int i = themes.size() - 1; i >= 0; --i)
            if (themes.at(i).toObject().value("id").toString() == id)
                themes.removeAt(i);
        themes.append(QJsonObject{{"id", id}, {"label", label}, {"desc", "Imported"}, {"user", true}, {"style", theme.value("style")}});
    }
    saveUserThemes(themes);
    setNotice(QString("Imported %1 %2, under Yours.").arg(found.size()).arg(found.size() == 1 ? "theme" : "themes"));
}

QJsonObject Bar::sanitizeStyle(const QJsonObject &style) {
    static const QSet<QString> colours{"bg", "fg", "accent", "outlineColor", "hoverColor"};
    static const QSet<QString> words{"shape", "colors", "fontFamily", "iconFont"};
    static const QSet<QString> flags{"solid", "flatEnds"};
    static const QSet<QString> numbers{"tint", "gap", "inset", "depth", "edge", "float", "pad", "size", "radius",
                                       "minContrast", "outline", "shadow", "backdrop", "barOpacity",
                                       "segmentOpacity", "hoverOpacity"};
    QJsonObject out;
    for (auto it = style.begin(); it != style.end(); ++it) {
        const QString key = it.key();
        const QJsonValue v = it.value();
        if (colours.contains(key) && isHex(v))
            out.insert(key, v);
        else if (words.contains(key) && v.isString() && !v.toString().isEmpty())
            out.insert(key, v.toString().left(80));
        else if (flags.contains(key) && v.isBool())
            out.insert(key, v);
        else if (numbers.contains(key) && v.isDouble())
            out.insert(key, v);
        else if (key == "palette" && v.isArray()) {
            QJsonArray palette;
            for (const auto &entry : v.toArray())
                if (entry.isString())
                    palette.append(entry.toString().left(24));
            if (!palette.isEmpty())
                out.insert(key, palette);
        } else if ((key == "regions" || key == "modules") && v.isObject()) {
            QJsonObject map;
            const auto source = v.toObject();
            for (auto m = source.begin(); m != source.end(); ++m)
                if (isHex(m.value()))
                    map.insert(m.key(), m.value());
            if (!map.isEmpty())
                out.insert(key, map);
        }
    }
    return out;
}

QJsonArray Bar::parseThemes(const QByteArray &json) {
    const QJsonDocument doc = QJsonDocument::fromJson(json);
    QJsonArray list;
    if (doc.isArray())
        list = doc.array();
    else if (doc.object().value("themes").isArray())
        list = doc.object().value("themes").toArray();
    else if (doc.isObject())
        list.append(doc.object());
    QJsonArray out;
    for (const auto &value : list) {
        const auto theme = value.toObject();
        if (!theme.value("style").isObject())
            continue;
        QString label = theme.value("label").toString(theme.value("name").toString()).trimmed().left(32);
        out.append(QJsonObject{{"label", label.isEmpty() ? "Imported" : label},
                               {"style", sanitizeStyle(theme.value("style").toObject())}});
    }
    return out;
}

QString Bar::underlineInk(const QJsonObject &bar, const QHash<QString, QString> &themeColors) {
    const QJsonObject style = bar.value("style").toObject();
    // A transparent bar's text is omabar16's to fit to the wallpaper.
    if (style.value("shape").toString() != "underline" || bar.value("transparent").toBool())
        return {};
    static const QRegularExpression hex("^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$");
    auto color = [](const QString &value) { return hex.match(value).hasMatch() ? QColor(value.left(7)) : QColor(); };
    QColor background = color(style.value("bg").toString());
    if (!background.isValid())
        background = color(themeColors.value("background"));
    const QColor themeText = color(themeColors.value("foreground"));
    QColor text = color(style.value("fg").toString());
    if (!text.isValid())
        text = themeText;
    if (!background.isValid() || !text.isValid())
        return {};
    // The bar's own minimum, held between "just legible" and AAA.
    const double minimum = std::clamp(style.value("minContrast").toDouble(4.5), 3.0, 7.0);
    if (Theme::contrastRatio(text, background) >= minimum)
        return {};
    // The theme's text colour, moved toward black or white only as far as it
    // has to go.
    return Theme::readable(themeText.isValid() ? themeText : text, background, minimum).name();
}

// --- layout ---

void Bar::applyLayout(const QString &id) {
    const auto found = std::find_if(m_layouts.begin(), m_layouts.end(), [&id](const QVariant &v) { return v.toMap().value("id") == id; });
    if (found == m_layouts.end())
        return;
    const auto preset = found->toMap();
    QSet<QString> known;
    for (const auto &widget : m_widgets)
        known.insert(widget.toMap().value("id").toString());

    const QJsonObject current = m_cfg.value("layout").toObject();
    auto mine = [&current](const QString &widget) -> QJsonObject {
        for (const auto &lane : kLanes)
            for (const auto &entry : current.value(lane).toArray())
                if (entry.toObject().value("id").toString() == widget)
                    return entry.toObject();
        return {};
    };
    // A hidden widget stays hidden, wherever the preset would put it.
    QSet<QString> hidden;
    for (const auto &value : m_cfg.value("hidden").toArray())
        hidden.insert(value.toObject().value("entry").toObject().value("id").toString());
    QJsonObject next_layout;
    QSet<QString> present;
    const auto lanes = preset.value("layout").toMap();
    for (const auto &lane : kLanes) {
        QJsonArray entries;
        for (const auto &value : lanes.value(lane).toList()) {
            const QJsonObject entry = QJsonObject::fromVariantMap(value.toMap());
            const QString widget = entry.value("id").toString();
            if ((!known.isEmpty() && !known.contains(widget)) || hidden.contains(widget))
                continue;
            // A widget already on the bar keeps its own settings (clock
            // format, custom icon…); the preset only decides where it goes.
            const QJsonObject own = mine(widget);
            entries.append(own.isEmpty() ? entry : own);
            present.insert(widget);
        }
        next_layout.insert(lane, entries);
    }
    // Widgets from other plugins (folder trays, the dock…) follow you into
    // every layout, on the right.
    QJsonArray right = next_layout.value("right").toArray();
    for (const auto &lane : kLanes)
        for (const auto &entry : current.value(lane).toArray()) {
            const QString widget = entry.toObject().value("id").toString();
            if (!widget.startsWith("omarchy.") && !present.contains(widget))
                right.append(entry);
        }
    next_layout.insert("right", right);

    QJsonObject next = m_cfg;
    next.insert("layout", next_layout);
    next.insert("centerAnchor", preset.value("anchor").toString());
    const QString edge = preset.value("position").toString();
    if (!edge.isEmpty())
        next.insert("position", edge);
    fixAnchor(next);
    commit(next);
}

void Bar::setPosition(const QString &position) {
    static const QStringList edges{"top", "bottom", "left", "right"};
    if (!edges.contains(position))
        return;
    QJsonObject next = m_cfg;
    next.insert("position", position);
    commit(next);
}

void Bar::setTransparent(bool on) {
    QJsonObject next = m_cfg;
    next.insert("transparent", on);
    commit(next, true);
}

void Bar::setCenterAnchor(const QString &id) {
    QJsonObject next = m_cfg;
    next.insert("centerAnchor", id);
    fixAnchor(next);
    commit(next);
}

void Bar::addWidget(const QString &id, const QString &lane, int index) {
    if (id.isEmpty() || !kLanes.contains(lane))
        return;
    QJsonObject next = m_cfg;
    QJsonObject layout = next.value("layout").toObject();
    QJsonArray entries = layout.value(lane).toArray();
    const int at = index < 0 ? entries.size() : std::min<int>(index, entries.size());
    entries.insert(at, newEntry(id));
    layout.insert(lane, entries);
    next.insert("layout", layout);
    fixAnchor(next);
    commit(next);
}

void Bar::removeWidget(const QString &lane, int index) {
    QJsonObject next = m_cfg;
    QJsonObject layout = next.value("layout").toObject();
    QJsonArray entries = layout.value(lane).toArray();
    if (index < 0 || index >= entries.size())
        return;
    entries.removeAt(index);
    layout.insert(lane, entries);
    next.insert("layout", layout);
    fixAnchor(next);
    commit(next);
}

void Bar::moveWidget(const QString &fromLane, int fromIndex, const QString &toLane, int toIndex) {
    if (!kLanes.contains(fromLane) || !kLanes.contains(toLane))
        return;
    QJsonObject next = m_cfg;
    QJsonObject layout = next.value("layout").toObject();
    QJsonArray from = layout.value(fromLane).toArray();
    if (fromIndex < 0 || fromIndex >= from.size())
        return;
    const QJsonValue entry = from.at(fromIndex);
    from.removeAt(fromIndex);
    if (fromLane == toLane && toIndex > fromIndex)
        --toIndex;
    layout.insert(fromLane, from);
    QJsonArray to = layout.value(toLane).toArray();
    to.insert(std::clamp<int>(toIndex, 0, to.size()), entry);
    layout.insert(toLane, to);
    next.insert("layout", layout);
    fixAnchor(next);
    commit(next);
}

void Bar::hideWidget(const QString &lane, int index) {
    const QJsonObject entry = entryAt(lane, index);
    if (entry.isEmpty())
        return;
    QJsonObject next = m_cfg;
    QJsonObject layout = next.value("layout").toObject();
    QJsonArray entries = layout.value(lane).toArray();
    entries.removeAt(index);
    layout.insert(lane, entries);
    next.insert("layout", layout);
    // Where it was, so showing it puts it back there, anchor and all.
    QJsonObject record{{"lane", lane}, {"index", index}, {"entry", entry}};
    if (lane == "center" && next.value("centerAnchor").toString() == entry.value("id").toString())
        record.insert("anchor", true);
    QJsonArray hidden = next.value("hidden").toArray();
    hidden.append(record);
    next.insert("hidden", hidden);
    fixAnchor(next);
    commit(next);
}

void Bar::showWidget(int hiddenIndex, const QString &lane, int index) {
    QJsonArray hidden = m_cfg.value("hidden").toArray();
    if (hiddenIndex < 0 || hiddenIndex >= hidden.size())
        return;
    const QJsonObject record = hidden.at(hiddenIndex).toObject();
    const QString to = kLanes.contains(lane) ? lane : kLanes.contains(record.value("lane").toString()) ? record.value("lane").toString() : "right";
    QJsonObject next = m_cfg;
    QJsonObject layout = next.value("layout").toObject();
    QJsonArray entries = layout.value(to).toArray();
    const int wanted = index >= 0 ? index : kLanes.contains(lane) ? entries.size() : record.value("index").toInt(entries.size());
    entries.insert(std::clamp<int>(wanted, 0, entries.size()), record.value("entry").toObject());
    layout.insert(to, entries);
    next.insert("layout", layout);
    hidden.removeAt(hiddenIndex);
    next.insert("hidden", hidden);
    if (to == "center" && record.value("anchor").toBool())
        next.insert("centerAnchor", record.value("entry").toObject().value("id").toString());
    fixAnchor(next);
    commit(next);
}

void Bar::setEntry(const QString &lane, int index, const QString &key, const QVariant &value) {
    if (key == "id")
        return;
    QJsonObject entry = entryAt(lane, index);
    if (entry.isEmpty())
        return;
    const QJsonValue json = QJsonValue::fromVariant(value);
    if (!value.isValid() || value.isNull() || (json.isString() && json.toString().isEmpty()))
        entry.remove(key);
    else
        entry.insert(key, json);
    QJsonObject next = m_cfg;
    QJsonObject layout = next.value("layout").toObject();
    QJsonArray entries = layout.value(lane).toArray();
    entries.replace(index, entry);
    layout.insert(lane, entries);
    next.insert("layout", layout);
    commit(next);
}

// --- history ---

void Bar::undo() {
    if (m_undo.isEmpty() || !editable())
        return;
    m_burst.stop();
    m_redo.append(m_cfg);
    m_cfg = m_undo.takeLast();
    m_pendingWrite = true;
    m_writeTimer.start();
    emit changed();
}

void Bar::redo() {
    if (m_redo.isEmpty() || !editable())
        return;
    m_burst.stop();
    m_undo.append(m_cfg);
    m_cfg = m_redo.takeLast();
    m_pendingWrite = true;
    m_writeTimer.start();
    emit changed();
}

void Bar::revert() {
    if (m_snapshot.isEmpty() || m_snapshot == m_cfg)
        return;
    m_burst.stop();
    if (commit(m_snapshot))
        setNotice("The bar is back to how it was when OmaCraft opened. Undo brings your changes back.");
}

void Bar::useAsBar() {
    if (!m_runCommands)
        return;
    Proc::run(this, "omarchy-bar", {"use", "omabar16"}, [this](const Proc::Result &result) {
        if (!result.ok())
            setError(result.message());
        m_debounce.start();
    });
}

void Bar::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}

void Bar::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}

void Bar::setNotice(const QString &message) {
    m_notice = message;
    m_error.clear();
    emit messageChanged();
}
