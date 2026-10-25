#include "hyprsettings.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>

#include "proc.h"

namespace {

const QString kOmasetRequire = QStringLiteral("require(\"hypr.omaset\")");
const QString kRulesRequire = QStringLiteral("pcall(require, \"hypr.omacraft_opacity\")");

QJsonObject readObject(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object();
}

QVariantMap opt(const char *key, const char *group, const char *label, const char *type, double from, double to,
                double step, int decimals, const char *suffix, const char *hint) {
    return {{"key", key}, {"group", group}, {"label", label}, {"type", type}, {"from", from}, {"to", to},
            {"step", step}, {"decimals", decimals}, {"suffix", suffix}, {"hint", hint}};
}

} // namespace

HyprSettings::HyprSettings(const QString &home, bool runCommands, QObject *parent)
    : QObject(parent), m_home(home.isEmpty() ? QDir::homePath() : home), m_runCommands(runCommands) {
    refresh();
}

QVariantList HyprSettings::options() {
    return {
        opt("decoration.active_opacity", "Transparency", "Focused windows", "number", 0.1, 1, 0.01, 2, "",
            "How opaque the window you're working in is. 1 is solid."),
        opt("decoration.inactive_opacity", "Transparency", "Other windows", "number", 0.1, 1, 0.01, 2, "",
            "How opaque every other window is."),
        opt("decoration.fullscreen_opacity", "Transparency", "Fullscreen windows", "number", 0.1, 1, 0.01, 2, "",
            "How opaque a fullscreen window is."),

        opt("decoration.blur.enabled", "Blur", "Blur behind windows", "bool", 0, 0, 0, 0, "",
            "Blurs what shows through transparent windows, the bar and menus."),
        opt("decoration.blur.size", "Blur", "Size", "int", 1, 20, 1, 0, " px", "How far each pass spreads."),
        opt("decoration.blur.passes", "Blur", "Passes", "int", 1, 6, 1, 0, "",
            "More passes, a smoother blur; each costs a little more."),
        opt("decoration.blur.vibrancy", "Blur", "Vibrancy", "number", 0, 1, 0.01, 2, "",
            "Saturates the colours that show through."),
        opt("decoration.blur.noise", "Blur", "Noise", "number", 0, 0.2, 0.005, 3, "", "A fine grain over the blur."),
        opt("decoration.blur.contrast", "Blur", "Contrast", "number", 0, 2, 0.01, 2, "", ""),
        opt("decoration.blur.brightness", "Blur", "Brightness", "number", 0, 2, 0.01, 2, "", ""),
        opt("decoration.blur.xray", "Blur", "X-ray", "bool", 0, 0, 0, 0, "",
            "Floating windows blur only the wallpaper, not the windows under them."),
        opt("decoration.blur.popups", "Blur", "Blur popups", "bool", 0, 0, 0, 0, "", "Menus and tooltips too."),

        opt("decoration.rounding", "Shape and spacing", "Corner rounding", "int", 0, 30, 1, 0, " px", ""),
        opt("decoration.rounding_power", "Shape and spacing", "Corner shape", "number", 1, 10, 0.1, 1, "",
            "2 is a circle's curve; higher is squarer, like a squircle."),
        opt("general.border_size", "Shape and spacing", "Border width", "int", 0, 10, 1, 0, " px", ""),
        opt("general.gaps_in", "Shape and spacing", "Gaps between windows", "int", 0, 40, 1, 0, " px", ""),
        opt("general.gaps_out", "Shape and spacing", "Gaps at the screen edge", "int", 0, 60, 1, 0, " px", ""),

        opt("decoration.shadow.enabled", "Shadows and dimming", "Shadows", "bool", 0, 0, 0, 0, "", ""),
        opt("decoration.shadow.range", "Shadows and dimming", "Shadow size", "int", 0, 60, 1, 0, " px", ""),
        opt("decoration.shadow.render_power", "Shadows and dimming", "Shadow falloff", "int", 1, 4, 1, 0, "",
            "Higher fades faster from the window."),
        opt("decoration.shadow.color", "Shadows and dimming", "Shadow colour", "color", 0, 0, 0, 0, "", ""),
        opt("decoration.dim_inactive", "Shadows and dimming", "Dim other windows", "bool", 0, 0, 0, 0, "",
            "Darkens every window but the focused one."),
        opt("decoration.dim_strength", "Shadows and dimming", "Dim strength", "number", 0, 1, 0.01, 2, "", ""),
    };
}

QVariantMap HyprSettings::option(const QString &key) {
    for (const auto &entry : options())
        if (entry.toMap().value("key").toString() == key)
            return entry.toMap();
    return {};
}

QVariantMap HyprSettings::values() const {
    QVariantMap out = m_live;
    for (auto it = m_omaset.cbegin(); it != m_omaset.cend(); ++it)
        out.insert(it.key(), it.value());
    return out;
}

// ---------------------------------------------------------------- omaset's format

QString HyprSettings::luaValue(const QVariant &value) {
    switch (value.typeId()) {
    case QMetaType::Bool:
        return value.toBool() ? "true" : "false";
    case QMetaType::Int:
    case QMetaType::LongLong:
    case QMetaType::UInt:
        return QString::number(value.toLongLong());
    case QMetaType::Double:
    case QMetaType::Float: {
        const double number = value.toDouble();
        if (number == qRound64(number))
            return QString::number(qRound64(number));
        return QString::number(number, 'f', 3).remove(QRegularExpression("0+$"));
    }
    default: {
        auto text = value.toString();
        text.replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n");
        return '"' + text + '"';
    }
    }
}

QString HyprSettings::luaTable(const QVariantMap &flat, int indent) {
    QMap<QString, QVariantMap> groups;
    QMap<QString, QVariant> leaves;
    for (auto it = flat.cbegin(); it != flat.cend(); ++it) {
        const auto dot = it.key().indexOf('.');
        if (dot < 0)
            leaves.insert(it.key(), it.value());
        else
            groups[it.key().left(dot)].insert(it.key().mid(dot + 1), it.value());
    }
    static const QRegularExpression identifier("^[A-Za-z_][A-Za-z0-9_]*$");
    auto luaKey = [](const QString &key) {
        return identifier.match(key).hasMatch() ? key : QStringLiteral("[\"%1\"]").arg(key);
    };
    const QString pad(indent + 2, ' ');
    QString out = "{\n";
    for (auto it = groups.cbegin(); it != groups.cend(); ++it)
        out += pad + luaKey(it.key()) + " = " + luaTable(it.value(), indent + 2) + ",\n";
    for (auto it = leaves.cbegin(); it != leaves.cend(); ++it)
        out += pad + luaKey(it.key()) + " = " + luaValue(it.value()) + ",\n";
    out += QString(indent, ' ') + "}";
    return out;
}

QString HyprSettings::omasetLua(const QVariantMap &flat) {
    QString out = QStringLiteral(
        "-- Written by Omarchy Settings (omaset) and rewritten whenever a setting\n"
        "-- changes there. Reset a setting in the app to hand it back to Omarchy.\n");
    if (!flat.isEmpty())
        out += "\nhl.config(" + luaTable(flat) + ")\n";
    return out;
}

QString HyprSettings::withOmasetRequire(const QString &hyprland) {
    if (hyprland.contains(kOmasetRequire))
        return hyprland;
    const QString block = QStringLiteral("-- Settings changed in Omarchy Settings (omaset).\n%1\n\n").arg(kOmasetRequire);
    // Before Omarchy's toggles, so a toggle like "no gaps" still overrides.
    static const QRegularExpression toggles(R"re((^--[^\n]*\n)?^require\("default\.hypr\.toggles"\))re",
                                            QRegularExpression::MultilineOption);
    const auto match = toggles.match(hyprland);
    if (match.hasMatch()) {
        auto text = hyprland;
        text.insert(match.capturedStart(), block);
        return text;
    }
    auto text = hyprland;
    if (!text.endsWith('\n'))
        text += '\n';
    return text + '\n' + block.trimmed() + '\n';
}

QVariant HyprSettings::parseOption(const QByteArray &json) {
    const auto object = QJsonDocument::fromJson(json).object();
    if (object.contains("int"))
        return object.value("int").toInt();
    if (object.contains("float"))
        return object.value("float").toDouble();
    if (object.contains("css")) {
        const auto parts = object.value("css").toString().split(' ', Qt::SkipEmptyParts);
        return parts.isEmpty() ? QVariant() : QVariant(parts.first().toInt());
    }
    if (object.contains("bool"))
        return object.value("bool").toBool();
    // Colours come back as AARRGGBB (a gradient of one, with its angle).
    if (object.contains("gradient") || object.contains("color")) {
        const QString text = object.contains("gradient") ? object.value("gradient").toString()
                                                         : object.value("color").toString();
        static const QRegularExpression argb("^(?:0x)?([0-9a-fA-F]{2})([0-9a-fA-F]{6})$");
        const auto match = argb.match(text.split(' ', Qt::SkipEmptyParts).value(0));
        if (match.hasMatch())
            return QStringLiteral("rgba(%1%2)").arg(match.captured(2), match.captured(1)).toLower();
        return {};
    }
    if (object.contains("str")) {
        const auto text = object.value("str").toString();
        return text == "[[EMPTY]]" ? QString() : text;
    }
    return {};
}

QString HyprSettings::rulesLua(const QVariantList &rules) {
    QString out = QStringLiteral(
        "-- Generated by OmaCraft (Window Transitions › Windows). Edit the rules there.\n"
        "-- Per-app opacity: focused, then other windows, for each window class.\n");
    for (const auto &entry : rules) {
        const auto rule = entry.toMap();
        out += QStringLiteral("o.window(%1, { opacity = \"%2 %3\" })\n")
                   .arg(luaValue(rule.value("match").toString()), luaValue(rule.value("active").toDouble()),
                        luaValue(rule.value("inactive").toDouble()));
    }
    return out;
}

// ---------------------------------------------------------------- reading

void HyprSettings::readFiles() {
    m_omaset = readObject(omasetJsonPath()).toVariantMap();
    m_modarchy.clear();
    const QVariantMap saved = readObject(m_home + "/.config/modarchy/hyprland.json").value("saved").toObject().toVariantMap();
    // Modarchy only wins while hyprland.lua still loads its file.
    QFile main(m_home + "/.config/hypr/hyprland.lua");
    const bool loaded = main.open(QIODevice::ReadOnly) && main.readAll().contains("hypr.modarchy");
    if (loaded)
        for (const auto &entry : options()) {
            const QString key = entry.toMap().value("key").toString();
            if (saved.contains(key))
                m_modarchy.insert(key, saved.value(key));
        }
    m_rules = readObject(rulesJsonPath()).value("rules").toArray().toVariantList();
}

void HyprSettings::refresh() {
    readFiles();
    emit changed();
    if (!m_runCommands)
        return;
    for (const auto &entry : options())
        readLive(entry.toMap().value("key").toString());
}

void HyprSettings::readLive(const QString &key) {
    Proc::run(this, "hyprctl", {"getoption", QString(key).replace('.', ':'), "-j"}, [this, key](const Proc::Result &result) {
        if (!result.ok())
            return;
        const QVariant value = parseOption(result.out);
        if (value.isValid() && m_live.value(key) != value) {
            m_live.insert(key, value);
            emit changed();
        }
    }, 3000);
}

// ---------------------------------------------------------------- writing

void HyprSettings::setValue(const QString &key, const QVariant &value) {
    const QVariantMap info = option(key);
    if (info.isEmpty())
        return;
    const QString type = info.value("type").toString();
    QVariant typed;
    if (type == "bool")
        typed = value.toBool();
    else if (type == "int")
        typed = int(qRound(qBound(info.value("from").toDouble(), value.toDouble(), info.value("to").toDouble())));
    else if (type == "number")
        typed = qBound(info.value("from").toDouble(), value.toDouble(), info.value("to").toDouble());
    else {
        static const QRegularExpression colour("^rgba\\([0-9a-fA-F]{8}\\)$");
        if (!colour.match(value.toString()).hasMatch())
            return setError("Colours are written rgba(rrggbbaa).");
        typed = value.toString().toLower();
    }

    // omaset's file as it is now, in case omaset changed it since.
    QVariantMap values = readObject(omasetJsonPath()).toVariantMap();
    values.insert(key, typed);
    if (!writeOmaset(values))
        return;
    m_live.insert(key, typed);

    if (m_runCommands) {
        const QString statement = QStringLiteral("hl.config(%1)").arg(luaTable({{key, typed}}).simplified());
        Proc::run(this, "hyprctl", {"eval", statement}, [this, key](const Proc::Result &result) {
            const QString out = QString::fromUtf8(result.out).trimmed();
            if (!result.ok() || (!out.isEmpty() && out != "ok"))
                setError(QStringLiteral("Hyprland refused %1: %2").arg(key, out.isEmpty() ? result.message() : out));
        });
    }
    emit changed();
}

void HyprSettings::reset(const QString &key) {
    QVariantMap values = readObject(omasetJsonPath()).toVariantMap();
    if (!values.remove(key))
        return;
    if (!writeOmaset(values))
        return;
    m_live.remove(key);
    if (m_runCommands) {
        // Back to whatever the other files say: Hyprland reads them again.
        Proc::run(this, "hyprctl", {"reload"}, [this, key](const Proc::Result &) { readLive(key); });
    }
    emit changed();
}

bool HyprSettings::writeOmaset(const QVariantMap &values) {
    QString message;
    const QByteArray json = QJsonDocument(QJsonObject::fromVariantMap(values)).toJson(QJsonDocument::Indented);
    // The Lua goes first, as omaset writes it: hyprland.lua must never
    // require a module that isn't there.
    if (!Proc::writeAtomically(omasetJsonPath(), json, &message)
        || !Proc::writeAtomically(omasetLuaPath(), omasetLua(values).toUtf8(), &message)) {
        setError("Couldn't write " + omasetLuaPath() + ": " + message);
        return false;
    }
    m_omaset = values;
    m_error.clear();
    return ensureRequire(kOmasetRequire, {}, true);
}

bool HyprSettings::ensureRequire(const QString &line, const QString &comment, bool omasetStyle) {
    const QString path = m_home + "/.config/hypr/hyprland.lua";
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        setError("Couldn't read " + path + ", so these settings won't survive a restart.");
        return false;
    }
    const QString original = QString::fromUtf8(file.readAll());
    file.close();
    if (original.contains(line))
        return true;
    QString updated = omasetStyle ? withOmasetRequire(original)
                                  : original + (original.endsWith('\n') ? "" : "\n") + "\n" + comment + "\n" + line + "\n";
    QFile::copy(path, QStringLiteral("%1.bak.%2").arg(path).arg(QDateTime::currentSecsSinceEpoch()));
    QString message;
    if (!Proc::writeAtomically(path, updated.toUtf8(), &message)) {
        setError("Couldn't update " + path + ": " + message);
        return false;
    }
    return true;
}

void HyprSettings::addOpacityRule(const QString &match, double active, double inactive) {
    const QString cls = match.trimmed();
    if (cls.isEmpty())
        return setError("Name the app by its window class (hyprctl clients shows it).");
    QVariantList rules;
    for (const auto &entry : m_rules)
        if (entry.toMap().value("match").toString() != cls)
            rules << entry;
    rules << QVariantMap{{"match", cls}, {"active", qBound(0.1, active, 1.0)}, {"inactive", qBound(0.1, inactive, 1.0)}};
    m_rules = rules;
    writeRules();
}

void HyprSettings::removeOpacityRule(int index) {
    if (index < 0 || index >= m_rules.size())
        return;
    m_rules.removeAt(index);
    writeRules();
}

void HyprSettings::writeRules() {
    QString message;
    const QByteArray json = QJsonDocument(QJsonObject{{"rules", QJsonArray::fromVariantList(m_rules)}}).toJson(QJsonDocument::Indented);
    if (!Proc::writeAtomically(rulesLuaPath(), rulesLua(m_rules).toUtf8(), &message)
        || !Proc::writeAtomically(rulesJsonPath(), json, &message)) {
        setError("Couldn't write " + rulesLuaPath() + ": " + message);
        return;
    }
    m_error.clear();
    if (ensureRequire(kRulesRequire, "-- Per-app opacity, set in OmaCraft.", false) && m_runCommands)
        Proc::detach("hyprctl", {"reload"});
    emit changed();
}

void HyprSettings::setError(const QString &message) {
    m_error = message;
    emit changed();
}

void HyprSettings::dismissError() {
    m_error.clear();
    emit changed();
}
