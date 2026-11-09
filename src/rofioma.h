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
// shutdown, drawn by rofi or, in the Wlogout style, by wlogout itself as
// HyDE's animated style 1), any number of custom
// menus, the emoji and glyph pickers (as hyprdots' pickers: search, Enter
// copies or types it) and a keybinding cheatsheet read from Hyprland.
//
// The control centre is swaync's list of widgets, in notify.widgets. Beyond
// its built-in ones, swaync can hold any number of instances (label#x,
// buttons-grid#x, slider#x, menubar#x), and those are what's installed:
// notify.customWidgets maps each id to its name, glyph and swaync settings.
// They come from the store (data/swaync-widgets.json), from a pack file, or
// from the page's own form, and install into the library; the page drags them
// from there into the panel.
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
    Q_PROPERTY(QVariantList powerEnters READ powerEnters CONSTANT)
    Q_PROPERTY(QVariantList powerHovers READ powerHovers CONSTANT)
    Q_PROPERTY(QVariantList backdrops READ backdrops CONSTANT)
    Q_PROPERTY(QVariantList widgetLibrary READ widgetLibrary NOTIFY changed)
    Q_PROPERTY(QVariantList widgetStore READ widgetStore NOTIFY changed)
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
    // The effects on offer: {id, name, description}.
    static QVariantList powerEnters();
    static QVariantList powerHovers();
    static QVariantList backdrops();
    // Everything that can go in the panel: {id, name, glyph, description,
    // custom}, the built-in widgets, then the installed ones.
    QVariantList widgetLibrary() const;
    // What can be installed: the store's widgets, each marked installed or not.
    QVariantList widgetStore() const;
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
    void refreshPickers();
    // The pieces of render(), for tests.
    static QString colorsRasi(const QVariantMap &palette, const QJsonObject &look);
    static QString powerRasi(const QJsonObject &power, const QJsonObject &look);
    // overlay: try the omacraft.rofioma overlay first, then wlogout or rofi.
    static QString powerScript(const QJsonObject &power, const QString &dir, bool overlay = true);
    // The wlogout style: its layout, its CSS (with @MGN@, @HVR@ and @FONT@
    // left for power.sh to fill in from the monitor) and a button's icon.
    static QString wlogoutLayout(const QJsonObject &power, const QString &dir);
    static QString wlogoutCss(const QJsonObject &power, const QVariantMap &palette, const QJsonObject &look,
                              const QString &dir);
    static QByteArray wlogoutIcon(const QString &glyph, const QString &color);
    static QString buttonId(const QJsonObject &button, int index);
    static QString menuRasi(const QJsonObject &menu, const QJsonObject &look);
    static QString menuScript(const QJsonObject &menu, const QString &dir, bool overlay = true);
    static QString symbolsRasi(const QJsonObject &symbols, const QJsonObject &look);
    static QString symbolsScript(const QJsonObject &symbols, const QString &dir);
    static QString keybindsRasi(const QJsonObject &look);
    // The control centre key's script: swaync's panel, or the shell's history.
    static QString notificationsScript();
    static QString keybindsScript(const QString &dir, bool run, bool overlay = true);
    static QString swayncCss(const QVariantMap &palette, const QJsonObject &notify, const QJsonObject &look);
    static QByteArray swayncConfig(const QJsonObject &notify);
    // The CSS for the notifications' entrance, hover and critical alarm, and
    // the control centre's entrance. Part of swayncCss.
    static QString swayncEffects(const QJsonObject &notify);
    // A widget from a pack or the store, cut down to what swaync reads. Empty
    // (with problem set) when it isn't one.
    static QJsonObject cleanWidget(const QJsonObject &widget, QString *problem = nullptr);
    // Every shell command a widget's settings would run.
    static QStringList widgetCommands(const QJsonObject &config);
    static QString keysLua(const QJsonObject &config, const QString &dir, bool swaync);
    // Everything the omacraft.rofioma overlay draws: the power menu, the
    // menus, the cheatsheet's settings, colours and look, as popups.json.
    static QByteArray popupsJson(const QJsonObject &config, const QVariantMap &palette, const QString &dir);

    // Moved keys. rofioma.json's keymap maps a bind's own keys (as Hyprland
    // first declares them) to the keys it was moved to. omacraft_keymap.lua
    // applies it while Hyprland reads its config, before Omarchy's binds, by
    // declaring each moved bind on its new keys, so it keeps its own action.
    // It also defines the capture submap, which pauses every bind while a
    // new key is pressed.
    static QString canonicalKeys(const QString &keys);
    static QString keymapLua(const QJsonObject &keymap);
    // Hyprland's binds (hyprctl binds -j) as the cheatsheet lists them:
    // keys, description, submap, dispatcher, arg, and the keys a moved bind
    // came from. describedOnly leaves out binds with no description.
    static QVariantList bindsFrom(const QByteArray &json, const QJsonObject &keymap, bool describedOnly);
    QString keymapPath() const { return m_home + "/.config/hypr/omacraft_keymap.lua"; }
    // Moves the bind now on `from` to `to`, or back to its own keys when
    // `to` is empty. Returns what went wrong, or nothing once it's done.
    Q_INVOKABLE QString moveBind(const QString &from, const QString &to);
    // Pauses (or resumes) every Hyprland bind while a new key is pressed, so
    // pressing one that's taken doesn't run it.
    Q_INVOKABLE void captureKeys(bool on);
    // An id made from a name: lower case, letters, digits and dashes.
    static QString slug(const QString &name);
    static QString nerdFontName(const QString &name, const QString &set);

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
    // One colour of your own. From the theme's colours, the other three start
    // as the theme's, so picking one colour changes only that one.
    Q_INVOKABLE void setCustomColor(const QString &name, const QString &hex);

    // The control centre: a widget from the library put in the panel at a
    // place (-1 at the end, above the list if it's last), moved, or taken out.
    Q_INVOKABLE void placeWidget(const QString &id, int at);
    Q_INVOKABLE void moveWidget(int from, int to);
    Q_INVOKABLE void removeWidget(const QString &id);
    // Installs one of the store's widgets into the library.
    Q_INVOKABLE void installWidget(const QString &id);
    // Takes an installed widget out of the panel and the library.
    Q_INVOKABLE void uninstallWidget(const QString &id);
    // What a pack file holds, before installing it: {error} or {name, count,
    // commands}, so the page can show what it would run.
    Q_INVOKABLE QVariantMap readWidgetPack(const QString &path) const;
    Q_INVOKABLE bool installWidgetPack(const QString &path);
    // A widget from the page's form. kind: label, buttons or slider. fields:
    // text; lines of "Label = command"; label, getter, setter. Returns its id.
    Q_INVOKABLE QString createWidget(const QString &kind, const QString &name, const QVariantMap &fields);

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
    // Writes omacraft_keymap.lua and loads it from hyprland.lua, ahead of
    // Omarchy's binds. False (with the error set) if it couldn't.
    bool writeKeymap();
    QByteArray currentBindsJson() const;
    void load();
    void save(bool keysToo = false);
    bool writeKeys();
    QJsonObject customWidgets() const;
    void putNotify(const QString &field, const QJsonValue &value);
    void addCustom(const QJsonObject &widget);
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
