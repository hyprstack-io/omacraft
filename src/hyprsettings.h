#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

// Hyprland's look, edited alongside Omarchy Settings (omaset): window
// transparency, blur, rounding, borders and gaps, shadows and dimming. The
// values are omaset's own: ~/.config/hypr/omaset.json, with omaset.lua
// generated from it exactly as omaset writes it, so both apps always show
// the same settings and either can change them. Each change is applied to
// the running Hyprland at once, as omaset does.
//
// Modarchy writes some of the same options to modarchy.lua, which
// hyprland.lua loads after omaset, so Modarchy's value comes back on the
// next reload; those options are reported so the page can say so.
//
// Per-app opacity, which omaset has no place for, goes in
// ~/.config/hypr/omacraft_opacity.lua (window rules) from
// ~/.config/omacraft/window-opacity.json.
class HyprSettings : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList options READ options CONSTANT)
    Q_PROPERTY(QVariantMap values READ values NOTIFY changed)
    Q_PROPERTY(QStringList omasetKeys READ omasetKeys NOTIFY changed)
    Q_PROPERTY(QVariantMap modarchy READ modarchy NOTIFY changed)
    Q_PROPERTY(QVariantList opacityRules READ opacityRules NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)

public:
    // home: tests pass a temp directory and set runCommands to false so
    // Hyprland is never asked or touched.
    explicit HyprSettings(const QString &home = {}, bool runCommands = true, QObject *parent = nullptr);

    // Every option: {key, group, label, type (number, int, bool, color),
    // from, to, step, decimals, suffix, hint}. Keys are omaset's.
    static QVariantList options();
    static QVariantMap option(const QString &key);

    // What each option is now: omaset's value, else Hyprland's.
    QVariantMap values() const;
    QStringList omasetKeys() const { return m_omaset.keys(); }
    // Options Modarchy sets (and that win after a reload), with its value.
    QVariantMap modarchy() const { return m_modarchy; }
    QVariantList opacityRules() const { return m_rules; }
    QString error() const { return m_error; }

    QString omasetJsonPath() const { return m_home + "/.config/hypr/omaset.json"; }
    QString omasetLuaPath() const { return m_home + "/.config/hypr/omaset.lua"; }
    QString rulesLuaPath() const { return m_home + "/.config/hypr/omacraft_opacity.lua"; }
    QString rulesJsonPath() const { return m_home + "/.config/omacraft/window-opacity.json"; }

    // omaset's generators, kept byte for byte so its file reads the same
    // whichever app wrote it last.
    static QString luaValue(const QVariant &value);
    static QString luaTable(const QVariantMap &flat, int indent = 0);
    static QString omasetLua(const QVariantMap &flat);
    // hyprland.lua with omaset's require added, as omaset adds it.
    static QString withOmasetRequire(const QString &hyprland);
    // `hyprctl getoption -j` to a value: numbers, bools, the first of a gap's
    // four sides, a colour as "rgba(rrggbbaa)".
    static QVariant parseOption(const QByteArray &json);
    static QString rulesLua(const QVariantList &rules);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setValue(const QString &key, const QVariant &value);
    // Hands the option back to Omarchy's default (omaset's "reset").
    Q_INVOKABLE void reset(const QString &key);
    // match: a window class (a regular expression, as Hyprland takes it).
    Q_INVOKABLE void addOpacityRule(const QString &match, double active, double inactive);
    Q_INVOKABLE void removeOpacityRule(int index);
    Q_INVOKABLE void dismissError();

signals:
    void changed();

private:
    void readFiles();
    bool writeOmaset(const QVariantMap &values);
    void writeRules();
    bool ensureRequire(const QString &line, const QString &comment, bool omasetStyle);
    void readLive(const QString &key);
    void setError(const QString &message);

    QString m_home;
    bool m_runCommands;
    QVariantMap m_omaset;
    QVariantMap m_live;
    QVariantMap m_modarchy;
    QVariantList m_rules;
    QString m_error;
};
