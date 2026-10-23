#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

// The wallpaper picker's key. omacraft.wallpicker is a shell overlay, Omarchy's
// background switcher with OmaCraft's wallpapers in it, so it opens over the
// desktop from a key without OmaCraft's window. The key lives in
// ~/.config/hypr/omacraft_wallpicker.lua, which OmaCraft writes whole and
// hyprland.lua loads (OmaCraft adds that line once, keeping a copy of the
// file as it was).
class WallPicker : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString key READ key NOTIFY changed)
    Q_PROPERTY(bool bound READ bound NOTIFY changed)
    Q_PROPERTY(QString defaultKey READ defaultKey CONSTANT)
    Q_PROPERTY(QString error READ error NOTIFY changed)

public:
    // home: tests pass a temp directory and set runCommands to false so
    // Hyprland and the shell are never touched.
    explicit WallPicker(const QString &home = {}, bool runCommands = true, QObject *parent = nullptr);

    static constexpr const char *kPluginId = "omacraft.wallpicker";

    QString key() const { return m_key; }
    bool bound() const { return !m_key.isEmpty(); }
    QString defaultKey() const { return "SUPER + ALT + W"; }
    QString error() const { return m_error; }
    QString keysPath() const { return m_home + "/.config/hypr/omacraft_wallpicker.lua"; }

    // "super alt w", "SUPER+ALT+W" or "Super + Alt + W" to "SUPER + ALT + W";
    // empty when it isn't a key Hyprland can bind (no key, or only modifiers).
    static QString normalizeKey(const QString &key);
    // The generated file for a key, and the key a file binds.
    static QString keysFile(const QString &key);
    static QString keyIn(const QString &file);
    // `omarchy-shell` arguments that open the picker on a tab.
    static QStringList summonArguments(const QString &tab);

    Q_INVOKABLE void reload();
    Q_INVOKABLE bool bind(const QString &key);
    Q_INVOKABLE void unbind();
    // Opens the picker over the desktop: tab is theme, wallhaven, library or favorites.
    Q_INVOKABLE void open(const QString &tab = {});

signals:
    void changed();

private:
    bool write(const QString &contents);
    void setError(const QString &message);

    QString m_home;
    bool m_runCommands;
    QString m_key;
    QString m_error;
};
