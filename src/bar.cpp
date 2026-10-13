#include "bar.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJSEngine>
#include <QJsonArray>
#include <QJsonDocument>
#include <QRegularExpression>

#include "proc.h"

namespace {

QJsonObject readJsonObject(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object();
}

// The current Omarchy theme's named colours, so palettes that name them
// ("accent", "blue") can be shown as swatches.
QHash<QString, QString> themeColors(const QString &home) {
    QHash<QString, QString> colors;
    QFile file(home + "/.local/state/omarchy/current/theme/colors.toml");
    if (!file.open(QIODevice::ReadOnly))
        return colors;
    static const QRegularExpression line(R"re(^\s*([a-z0-9_]+)\s*=\s*["'](#[0-9a-fA-F]{6})["'])re",
                                         QRegularExpression::MultilineOption);
    auto it = line.globalMatch(QString::fromUtf8(file.readAll()));
    while (it.hasNext()) {
        const auto match = it.next();
        colors.insert(match.captured(1), match.captured(2));
    }
    return colors;
}

} // namespace

Bar::Bar(std::function<QString()> pluginDir, const QString &home, bool runCommands, QObject *parent)
    : QObject(parent),
      m_pluginDir(std::move(pluginDir)),
      m_home(home.isEmpty() ? QDir::homePath() : home),
      m_runCommands(runCommands) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(120);
    connect(&m_debounce, &QTimer::timeout, this, &Bar::reload);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    reload();
    if (m_runCommands)
        refreshWidgets();
}

bool Bar::loadPresets(const QString &path, QString *problem) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        if (problem)
            *problem = "Can't read " + path;
        return false;
    }
    // ".pragma library" is a QML directive, not JavaScript.
    QString source = QString::fromUtf8(file.readAll());
    source.replace(QRegularExpression(R"(^\s*\.pragma\s+library\s*$)", QRegularExpression::MultilineOption), "");

    QJSEngine engine;
    const QJSValue result = engine.evaluate(source, path);
    if (result.isError()) {
        if (problem)
            *problem = QString("%1 line %2: %3").arg(path).arg(result.property("lineNumber").toInt()).arg(result.toString());
        return false;
    }
    const QJSValue global = engine.globalObject();

    const auto colors = themeColors(m_home);
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
    auto addGroup = [&](const QVariantList &list, const QString &group) {
        for (const auto &value : list) {
            auto theme = value.toMap();
            theme["group"] = group;
            theme["swatches"] = swatches(theme.value("style").toMap());
            themes << theme;
        }
    };
    addGroup(global.property("THEMES").toVariant().toList(), "Looks");
    addGroup(global.property("JAKOOLIT").toVariant().toList(), "JaKooLit");
    addGroup(global.property("BASE16").toVariant().toList(), "base16");

    QFile userFile(m_home + "/.config/omarchy/omabar16/themes.json");
    if (userFile.open(QIODevice::ReadOnly))
        addGroup(QJsonDocument::fromJson(userFile.readAll()).array().toVariantList(), "Yours");

    QVariantList layouts;
    for (const auto &value : global.property("LAYOUTS").toVariant().toList()) {
        auto layout = value.toMap();
        QStringList ids;
        const auto lanes = layout.value("layout").toMap();
        for (const auto &lane : {"left", "center", "right"})
            ids << QString::number(lanes.value(lane).toList().size());
        layout["counts"] = ids.join(" · ");
        layouts << layout;
    }

    m_themes = themes;
    m_layouts = layouts;
    m_glyphs = global.property("GLYPHS").toVariant().toMap();
    emit presetsChanged();
    return true;
}

void Bar::setShellConfig(const QJsonObject &shell) {
    m_shell = shell;
    emit changed();
}

void Bar::watch() {
    const auto paths = m_watcher.files() + m_watcher.directories();
    if (!paths.isEmpty())
        m_watcher.removePaths(paths);
    const QString shell = m_home + "/.config/omarchy/shell.json";
    for (const auto &path : {shell, QFileInfo(shell).absolutePath(), m_home + "/.config/omarchy/omabar16"})
        if (QFileInfo::exists(path))
            m_watcher.addPath(path);
}

void Bar::reload() {
    setShellConfig(readJsonObject(m_home + "/.config/omarchy/shell.json"));
    const QString dir = m_pluginDir ? m_pluginDir() : QString();
    const QString presets = dir.isEmpty() ? QString() : dir + "/data/Presets.js";
    // shell.json changes on every tweak; only read the presets again when
    // they, or the user's saved themes, have changed.
    const QString userThemes = m_home + "/.config/omarchy/omabar16/themes.json";
    const QString stamp = presets + "|" + QFileInfo(presets).lastModified().toString(Qt::ISODateWithMs) + "|"
                        + QFileInfo(userThemes).lastModified().toString(Qt::ISODateWithMs);
    QString problem;
    if (presets.isEmpty()) {
        m_presetsPath.clear();
        if (!m_themes.isEmpty()) {
            m_themes.clear();
            m_layouts.clear();
            emit presetsChanged();
        }
    } else if (stamp != m_presetsPath) {
        if (loadPresets(presets, &problem))
            m_presetsPath = stamp;
        else
            setError("Couldn't read omabar16's presets: " + problem);
    }
    watch();
}

QString Bar::barId() const {
    const auto id = m_shell.value("bar").toObject().value("id").toString();
    return id.isEmpty() ? "omarchy.bar" : id;
}

QString Bar::position() const {
    const auto value = m_shell.value("bar").toObject().value("position").toString();
    return value.isEmpty() ? "top" : value;
}

bool Bar::transparent() const { return m_shell.value("bar").toObject().value("transparent").toBool(); }
QVariantMap Bar::style() const { return m_shell.value("bar").toObject().value("style").toObject().toVariantMap(); }
QVariantMap Bar::layout() const { return m_shell.value("bar").toObject().value("layout").toObject().toVariantMap(); }

QString Bar::currentTheme() const {
    // The customizer marks a theme current when the bar's style is exactly it.
    const QJsonObject current = m_shell.value("bar").toObject().value("style").toObject();
    for (const auto &value : m_themes) {
        const auto theme = value.toMap();
        if (QJsonObject::fromVariantMap(theme.value("style").toMap()) == current)
            return theme.value("id").toString();
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
            widgets << QVariantMap{{"id", plugin.value("id").toString()},
                                   {"name", name.isEmpty() ? plugin.value("name").toString() : name},
                                   {"category", barWidget.value("category").toString()},
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
    return glyph.isEmpty() ? QString::fromUtf8("●") : glyph;
}

void Bar::ipc(const QStringList &arguments, const QString &doneNotice) {
    if (!inUse()) {
        setError("omabar16 isn't your bar right now. Use it as the bar first.");
        return;
    }
    if (!m_runCommands)
        return;
    Proc::run(this, "omarchy-shell", QStringList{"omabar16"} + arguments, [this, arguments, doneNotice](const Proc::Result &result) {
        const QString answer = QString::fromUtf8(result.out).trimmed();
        if (!result.ok()) {
            setError(QString("omabar16 didn't answer %1: %2").arg(arguments.first(), result.message()));
        } else if (!answer.isEmpty() && answer != "ok" && arguments.first() != "tab") {
            setError(QString("omabar16: %1").arg(answer));
        } else if (!doneNotice.isEmpty()) {
            m_notice = doneNotice;
            m_error.clear();
            emit messageChanged();
        }
        m_debounce.start();
    }, 15000);
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

void Bar::applyTheme(const QString &id) { ipc({"theme", id}); }
void Bar::applyLayout(const QString &id) { ipc({"layout", id}); }
void Bar::setPosition(const QString &position) { ipc({"position", position}); }

void Bar::setTransparent(bool on) {
    if (!m_runCommands)
        return;
    Proc::run(this, "omarchy-bar", {"transparent", on ? "true" : "false"}, [this](const Proc::Result &result) {
        if (!result.ok())
            setError(result.message());
        m_debounce.start();
    });
}

void Bar::setStyle(const QString &key, const QVariant &value) {
    QString text;
    if (value.typeId() == QMetaType::Bool)
        text = value.toBool() ? "true" : "false";
    else if (value.isValid() && !value.isNull())
        text = value.toString();
    ipc({"style", key, text});
}

void Bar::setColor(const QString &part, const QString &hex) { ipc({"color", part, hex}); }

void Bar::addWidget(const QString &id, const QString &lane) {
    const int end = layout().value(lane).toList().size();
    ipc({"add", id, lane, QString::number(end)});
}

void Bar::removeWidget(const QString &lane, int index) { ipc({"remove", lane, QString::number(index)}); }

void Bar::moveWidget(const QString &fromLane, int fromIndex, const QString &toLane, int toIndex) {
    ipc({"move", fromLane, QString::number(fromIndex), toLane, QString::number(toIndex)});
}

void Bar::undo() { ipc({"undo"}); }
void Bar::redo() { ipc({"redo"}); }
void Bar::revert() { ipc({"revert"}, "Reverted the bar to how it was when the customizer last opened."); }

void Bar::exportTheme(const QString &id) {
    ipc({"exportTheme", id}, "Exported. omabar16 saves exports beside your themes in ~/.config/omarchy/omabar16.");
}

void Bar::openCustomizer(const QString &tab) {
    if (!inUse()) {
        setError("omabar16 isn't your bar right now. Use it as the bar first.");
        return;
    }
    const QString payload = tab.isEmpty() ? "{}" : QString(R"({"tab":"%1"})").arg(tab);
    Proc::run(this, "omarchy-shell", {"shell", "summon", "omabar16", payload});
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
