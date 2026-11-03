#pragma once

#include <QColor>
#include <QFileSystemWatcher>
#include <QHash>
#include <QImage>
#include <QJsonObject>
#include <QObject>
#include <QQuickImageProvider>
#include <QVariantList>
#include <QVariantMap>

class FilePicker;

// XCursor files, read and recoloured in place. The format is a table of
// chunks; an image chunk holds premultiplied ARGB, little-endian, which is
// QImage's ARGB32_Premultiplied as it is.
namespace XCursor {

struct Frame {
    int nominal = 0;   // the size the theme says it is
    int width = 0;
    int height = 0;
    int delay = 0;     // ms, for animated cursors
    qsizetype offset = 0; // where its pixels start in the file
};

// Every image chunk, in the file's order; empty when it isn't an XCursor.
QList<Frame> frames(const QByteArray &file);
// The frames of the nominal size nearest to wanted.
QList<Frame> framesNear(const QList<Frame> &all, int wanted);
QImage image(const QByteArray &file, const Frame &frame);
// Whether a cursor's body is dark (black arrow, white outline) or light.
bool darkBody(const QByteArray &file);
// One premultiplied ARGB pixel recoloured: the body takes fill, the outline
// keeps its own colour, coloured details turn to fill's hue.
quint32 tintPixel(quint32 argb, const QColor &fill, bool darkBody);
// The whole file recoloured; anything that isn't an image chunk is kept.
QByteArray tinted(const QByteArray &file, const QColor &fill, bool darkBody);

} // namespace XCursor

// The Cursors & Icons page. Icon and cursor themes are folders in the icon
// search path with an index.theme; this class finds them, imports new ones
// from archives or folders into ~/.local/share/icons, and sets the ones in use
// through gsettings (GTK, and Hyprland, which follows it) and hyprctl.
//
// The choice is kept in ~/.config/omacraft/appearance.json. Omarchy puts its
// theme's own icons back on every theme switch, so OmaCraft's theme-set hook
// (`omacraft --sync-colors`) applies the choice again afterwards, retinting a
// theme-following cursor and picking a theme-following icon colour on the way.
class CursorsIcons : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList iconThemes READ iconThemes NOTIFY themesChanged)
    Q_PROPERTY(QVariantList cursorThemes READ cursorThemes NOTIFY themesChanged)
    Q_PROPERTY(QString iconTheme READ iconTheme NOTIFY appliedChanged)
    Q_PROPERTY(QString cursorTheme READ cursorTheme NOTIFY appliedChanged)
    Q_PROPERTY(int cursorSize READ cursorSize NOTIFY appliedChanged)
    // "omarchy" leaves icons to the Omarchy theme, "fixed" keeps a pick,
    // "follow" keeps a family and changes its colour with the theme.
    Q_PROPERTY(QString iconMode READ iconMode NOTIFY appliedChanged)
    Q_PROPERTY(QString iconPick READ iconPick NOTIFY appliedChanged)
    // "fixed" keeps a pick, "follow" wears a tinted copy of it.
    Q_PROPERTY(QString cursorMode READ cursorMode NOTIFY appliedChanged)
    Q_PROPERTY(QString cursorPick READ cursorPick NOTIFY appliedChanged)
    Q_PROPERTY(QString tintKey READ tintKey NOTIFY appliedChanged)
    Q_PROPERTY(QVariantMap themeColors READ themeColors NOTIFY appliedChanged)
    Q_PROPERTY(QString tintColor READ tintColor NOTIFY appliedChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY appliedChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    static inline const QString kTintedPrefix = "omacraft-tinted-";
    static inline const QString kRequire = "hypr.omacraft_cursor";

    // Tests pass a temp home, their own search path and runCommands false, so
    // nothing reaches gsettings, hyprctl or the live theme.
    explicit CursorsIcons(FilePicker *picker, const QString &home = {}, const QStringList &systemDirs = {"/usr/share/icons"},
                          bool runCommands = true, QObject *parent = nullptr);

    QVariantList iconThemes() const { return m_iconThemes; }
    QVariantList cursorThemes() const { return m_cursorThemes; }
    QString iconTheme() const { return m_iconTheme; }
    QString cursorTheme() const { return m_cursorTheme; }
    int cursorSize() const { return m_cursorSize; }
    QString iconMode() const;
    QString iconPick() const;
    QString cursorMode() const;
    QString cursorPick() const;
    QString tintKey() const;
    QVariantMap themeColors() const;
    QString tintColor() const;
    bool canUndo() const { return !m_undo.isEmpty(); }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }

    // The page's tiles.
    Q_INVOKABLE QVariantList iconSamples(const QString &id);
    // { role, source, frames: [ms…], animated } for each cursor a tile shows.
    Q_INVOKABLE QVariantList cursorSamples(const QString &id, int size = 48);

    Q_INVOKABLE void useIcons(const QString &id);
    Q_INVOKABLE void setIconMode(const QString &mode);
    Q_INVOKABLE void useCursor(const QString &id);
    Q_INVOKABLE void setCursorMode(const QString &mode);
    Q_INVOKABLE void setCursorSize(int size);
    Q_INVOKABLE void setTintKey(const QString &key);
    Q_INVOKABLE void undo();
    // Icons back to the Omarchy theme's, the cursor back to Omarchy's default.
    Q_INVOKABLE void restoreDefaults();

    Q_INVOKABLE void chooseArchive();
    Q_INVOKABLE void chooseFolder();
    // A file or folder: a dropped URL or a path.
    Q_INVOKABLE void importFrom(const QString &pathOrUrl);
    // Moves an imported theme into OmaCraft's stash; system themes stay.
    Q_INVOKABLE void remove(const QString &id);
    Q_INVOKABLE void openFolder();
    Q_INVOKABLE void reload();
    Q_INVOKABLE void dismissMessages();
    // The Omarchy theme changed: the hook has re-applied, so read it back.
    void themeSwitched();

    // The theme-set hook's work, without a window.
    static int syncNow(const QString &home = {}, const QStringList &systemDirs = {"/usr/share/icons"}, bool runCommands = true);

    // --- the parts the tests reach ---
    struct Theme {
        QString id;          // the folder's name, which is what gsettings takes
        QString name;        // index.theme's Name
        QString path;
        QStringList inherits;
        QStringList directories;
        bool user = false;
        bool icons = false;
        bool xcursor = false;
        bool hyprcursor = false;
        bool generated = false;
    };
    static QHash<QString, QString> readIndex(const QString &file, const QString &group = "Icon Theme");
    static Theme readTheme(const QString &path, bool user);
    QList<Theme> scan() const;
    // The colour a variant name says it is ("Yaru-blue-dark" → blue), the
    // family it belongs to and its suffix; an empty colour if it says none.
    struct Variant { QString family; QString color; QString suffix; };
    static Variant variantOf(const QString &id);
    static QColor variantColor(const QString &color);
    // The installed theme of id's family nearest in hue to accent.
    static QString nearestVariant(const QString &id, const QStringList &installed, const QColor &accent);
    // Writes a tinted copy of base's XCursors and returns its id, or empty.
    QString writeTinted(const QString &baseId, const QColor &color, QString *why = nullptr) const;
    // Every theme folder found under an extracted import, outermost first.
    static QStringList themeRoots(const QString &dir);
    // Drops links that lead outside root; false if the tree is too big to take.
    static bool sanitize(const QString &root, QString *why);
    QString cursorLua() const;
    QJsonObject config() const { return m_config; }

signals:
    void themesChanged();
    void appliedChanged();
    void busyChanged();
    void messageChanged();

private:
    QString userDir() const { return m_home + "/.local/share/icons"; }
    QString configPath() const { return m_home + "/.config/omacraft/appearance.json"; }
    QString colorsPath() const { return m_home + "/.local/state/omarchy/current/theme/colors.toml"; }
    QString omarchyIconsPath() const { return m_home + "/.local/state/omarchy/current/theme/icons.theme"; }
    QString luaPath() const { return m_home + "/.config/hypr/omacraft_cursor.lua"; }
    QStringList searchDirs() const;
    QString pathOf(const QString &id) const;
    QString cursorPathOf(const QString &id) const;
    void readApplied();
    void saveConfig();
    void remember();
    void setError(const QString &message);
    void setNotice(const QString &message);
    void setBusy(bool busy);
    // Puts the config onto the desktop: icons, cursor, size, the Lua file.
    void apply(bool cursorToo = true);
    void applyIcons(const QString &id);
    void applyCursor(const QString &id, int size);
    void restoreCursorDefaults();
    void finishImport(const QString &staging, const QString &label);
    QString resolvedIconTheme() const;
    QString resolvedCursorTheme(bool write);

    FilePicker *m_picker;
    QString m_home;
    QStringList m_systemDirs;
    bool m_runCommands;
    QJsonObject m_config;
    QList<QJsonObject> m_undo;
    QVariantList m_iconThemes;
    QVariantList m_cursorThemes;
    QHash<QString, QVariantList> m_iconSamples;
    QHash<QString, QVariantList> m_cursorSamples;
    QString m_iconTheme;
    QString m_cursorTheme;
    int m_cursorSize = 24;
    bool m_busy = false;
    QString m_error;
    QString m_notice;
    QFileSystemWatcher m_watcher;
};

// image://cursor/<frame>/<hex of the file's path>: one frame of an XCursor,
// at the nominal size nearest to what's asked (48 when nothing is).
class CursorImageProvider : public QQuickImageProvider {
public:
    CursorImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}
    QImage requestImage(const QString &id, QSize *size, const QSize &requested) override;
};
