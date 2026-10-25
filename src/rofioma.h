#pragma once

#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

// ROFIoma, a studio for rofi-styled popups and swaync's notifications. One
// file holds every design, ~/.config/omacraft/rofioma.json, and each change
// regenerates what rofi and swaync read:
//
//   ~/.config/omacraft/rofioma/   colors.rasi, a .rasi and a .sh per popup
//                                 (power, symbols, keybinds, menu-<id>), and
//                                 the emoji and Nerd Font glyph lists
//   ~/.config/swaync/             style.css and config.json (the first write
//                                 keeps a copy of what was there)
//   ~/.config/hypr/omacraft_rofioma.lua
//                                 the popups' keys, and swaync's autostart
//                                 once notifications are handed to it
//
// The popups are: the power menu (lock, logout, suspend, hibernate, reboot,
// shutdown, in the manner of hyprdots' wlogout style 1), any number of custom
// menus, the emoji and glyph pickers (as hyprdots' pickers: search, Enter
// copies or types it) and a keybinding cheatsheet read from Hyprland.
//
// The Omarchy shell owns org.freedesktop.Notifications, so swaync only gets
// it when handed over: the shell's omarchy.notifications plugin goes into
// shell.json's disabledPlugins and swaync starts; taking it back undoes both.
class Rofioma : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap config READ config NOTIFY changed)
    Q_PROPERTY(QVariantMap palette READ palette NOTIFY changed)
    Q_PROPERTY(QVariantList powerActions READ powerActions CONSTANT)
    Q_PROPERTY(QVariantList powerStyles READ powerStyles CONSTANT)
    Q_PROPERTY(QVariantList menuLayouts READ menuLayouts CONSTANT)
    Q_PROPERTY(QVariantList notifyWidgets READ notifyWidgets CONSTANT)
    Q_PROPERTY(QVariantList missing READ missing NOTIFY toolsChanged)
    Q_PROPERTY(bool swayncOwns READ swayncOwns NOTIFY changed)
    Q_PROPERTY(QVariantList binds READ binds NOTIFY bindsChanged)
    Q_PROPERTY(QString configPath READ configPath CONSTANT)
    Q_PROPERTY(QString outputDir READ outputDir CONSTANT)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    // home: tests pass a temp directory and set runCommands to false so
    // rofi, swaync, the shell and Hyprland are never touched.
    explicit Rofioma(const QString &home = {}, bool runCommands = true, QObject *parent = nullptr);

    QVariantMap config() const { return m_config.toVariantMap(); }
    // The colours the popups are drawn in now: bg, alt, fg, muted, accent,
    // accentFg, urgent, as #rrggbb.
    QVariantMap palette() const;
    static QVariantList powerActions();
    static QVariantList powerStyles();
    static QVariantList menuLayouts();
    static QVariantList notifyWidgets();
    // Programs the popups need that aren't on PATH.
    QVariantList missing() const { return m_missing; }
    bool swayncOwns() const;
    // Hyprland's described binds, {keys, description}, as the cheatsheet lists them.
    QVariantList binds() const { return m_binds; }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }

    QString configPath() const { return m_home + "/.config/omacraft/rofioma.json"; }
    QString outputDir() const { return m_home + "/.config/omacraft/rofioma"; }
    QString keysPath() const { return m_home + "/.config/hypr/omacraft_rofioma.lua"; }
    QString swayncDir() const { return m_home + "/.config/swaync"; }
    QString shellPath() const { return m_home + "/.config/omarchy/shell.json"; }

    static QJsonObject defaults();
    // Every file the design generates, by path relative to home.
    QHash<QString, QByteArray> render() const;
    // The pieces of render(), for tests.
    static QString colorsRasi(const QVariantMap &palette, const QJsonObject &look);
    static QString powerRasi(const QJsonObject &power, const QJsonObject &look);
    static QString powerScript(const QJsonObject &power, const QString &dir);
    static QString menuRasi(const QJsonObject &menu, const QJsonObject &look);
    static QString menuScript(const QJsonObject &menu, const QString &dir);
    static QString symbolsRasi(const QJsonObject &symbols, const QJsonObject &look);
    static QString symbolsScript(const QJsonObject &symbols, const QString &dir);
    static QString keybindsRasi(const QJsonObject &look);
    static QString keybindsScript(const QString &dir, bool run);
    static QString swayncCss(const QVariantMap &palette, const QJsonObject &notify, const QJsonObject &look);
    static QByteArray swayncConfig(const QJsonObject &notify);
    static QString keysLua(const QJsonObject &config, const QString &dir, bool swaync);
    // An id made from a name: lower case, letters, digits and dashes.
    static QString slug(const QString &name);

    Q_INVOKABLE void reload();
    // Emoji or Nerd Font glyphs ({symbol, name, set, code}) whose name, set or
    // codepoint has every word of the query, at most limit of them; set ""
    // is every set.
    Q_INVOKABLE QVariantList searchSymbols(const QString &kind, const QString &query, const QString &set = {},
                                           int limit = 240) const;
    Q_INVOKABLE QStringList symbolSets(const QString &kind) const;
    Q_INVOKABLE void copy(const QString &text);
    Q_INVOKABLE void refreshBinds();
    // Sets one value by a dotted path ("power.style", "look.radius",
    // "notify.position"), then regenerates.
    Q_INVOKABLE void set(const QString &path, const QVariant &value);
    Q_INVOKABLE void setPowerButton(int index, const QString &field, const QVariant &value);
    Q_INVOKABLE void movePowerButton(int from, int to);
    Q_INVOKABLE void resetPower();

    Q_INVOKABLE QString addMenu(const QString &name);
    Q_INVOKABLE void removeMenu(const QString &id);
    Q_INVOKABLE void setMenu(const QString &id, const QString &field, const QVariant &value);
    Q_INVOKABLE void addMenuItem(const QString &id);
    Q_INVOKABLE void setMenuItem(const QString &id, int index, const QString &field, const QVariant &value);
    Q_INVOKABLE void removeMenuItem(const QString &id, int index);
    Q_INVOKABLE void moveMenuItem(const QString &id, int from, int to);

    // Opens a popup as it now is: power, emoji, glyphs, keybinds or menu-<id>.
    Q_INVOKABLE void open(const QString &popup);
    // Binds a popup's key ("" takes it off); keys are written as WallPicker
    // normalises them.
    Q_INVOKABLE bool bindKey(const QString &popup, const QString &key);
    // A test notification in each urgency, to see the style.
    Q_INVOKABLE void testNotification();
    Q_INVOKABLE void handNotificationsToSwaync(bool on);
    // Installs whatever is missing, in a terminal (pacman asks for a password).
    Q_INVOKABLE void installMissing();
    Q_INVOKABLE void dismissMessages();

signals:
    void changed();
    void toolsChanged();
    void bindsChanged();
    void messageChanged();

private:
    void load();
    void save(bool keysToo = false);
    bool writeKeys();
    QJsonObject menu(const QString &id, int *index = nullptr) const;
    void putMenu(int index, const QJsonObject &menu);
    void findTools();
    // emoji.tsv or glyphs.tsv as rows of symbol, name, set; read once.
    const QList<QStringList> &symbolRows(const QString &kind) const;
    bool editShell(bool swaync, QString *problem);
    void setError(const QString &message);
    void setNotice(const QString &message);

    QString m_home;
    bool m_runCommands;
    QJsonObject m_config;
    QVariantList m_missing;
    QVariantList m_binds;
    mutable QHash<QString, QList<QStringList>> m_symbols;
    QString m_error;
    QString m_notice;
};
