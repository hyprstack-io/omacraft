#pragma once

#include <QFileSystemWatcher>
#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <functional>

// omabar16, the bar, edited entirely from OMAcraft. The bar draws whatever
// shell.json's "bar" section says and follows that file live, so OMAcraft
// keeps its own copy of the section, changes it, and writes it back in place
// (as the folder trays do), with an undo history of its own. Nothing goes
// through a customizer overlay.
//
// The preset themes and layouts are read from Studio's bar data when it is
// there (it adds the HANCORE set), otherwise from omabar16's own
// data/Presets.js, so OMAcraft lists exactly what the plugins ship.
class Bar : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY presetsChanged)
    Q_PROPERTY(bool inUse READ inUse NOTIFY changed)
    Q_PROPERTY(QString barId READ barId NOTIFY changed)
    Q_PROPERTY(QString position READ position NOTIFY changed)
    Q_PROPERTY(bool transparent READ transparent NOTIFY changed)
    Q_PROPERTY(QString centerAnchor READ centerAnchor NOTIFY changed)
    Q_PROPERTY(QVariantMap style READ style NOTIFY changed)
    Q_PROPERTY(QVariantMap layout READ layout NOTIFY changed)
    // position, transparent, centerAnchor, layout and style together, for previews.
    Q_PROPERTY(QVariantMap config READ config NOTIFY changed)
    Q_PROPERTY(QString currentTheme READ currentTheme NOTIFY changed)
    Q_PROPERTY(QString currentLayout READ currentLayout NOTIFY changed)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY changed)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY changed)
    Q_PROPERTY(bool edited READ edited NOTIFY changed)
    Q_PROPERTY(QVariantList themes READ themes NOTIFY presetsChanged)
    Q_PROPERTY(QVariantList layouts READ layouts NOTIFY presetsChanged)
    Q_PROPERTY(QVariantMap glyphs READ glyphs NOTIFY presetsChanged)
    Q_PROPERTY(QVariantMap themeColors READ themeColors NOTIFY presetsChanged)
    Q_PROPERTY(bool hasIcons READ hasIcons NOTIFY presetsChanged)
    Q_PROPERTY(QVariantList widgets READ widgets NOTIFY widgetsChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    // pluginDir: omabar16's folder (empty when it isn't installed).
    // studioDir: omacraft.studio's folder, whose bar/data has more presets.
    explicit Bar(std::function<QString()> pluginDir, std::function<QString()> studioDir = {},
                 const QString &home = {}, bool runCommands = true, QObject *parent = nullptr);

    bool available() const { return !m_themes.isEmpty(); }
    bool inUse() const { return barId() == "omabar16"; }
    QString barId() const;
    QString position() const;
    bool transparent() const { return m_cfg.value("transparent").toBool(); }
    QString centerAnchor() const { return m_cfg.value("centerAnchor").toString(); }
    QVariantMap style() const { return m_cfg.value("style").toObject().toVariantMap(); }
    QVariantMap layout() const { return m_cfg.value("layout").toObject().toVariantMap(); }
    QVariantMap config() const { return m_cfg.toVariantMap(); }
    QString currentTheme() const;
    QString currentLayout() const;
    bool canUndo() const { return !m_undo.isEmpty(); }
    bool canRedo() const { return !m_redo.isEmpty(); }
    bool edited() const { return !m_snapshot.isEmpty() && m_snapshot != m_cfg; }
    QVariantList themes() const { return m_themes; }
    QVariantList layouts() const { return m_layouts; }
    QVariantMap glyphs() const { return m_glyphs; }
    QVariantMap themeColors() const;
    bool hasIcons() const { return !m_iconSets.isEmpty(); }
    QVariantList widgets() const { return m_widgets; }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }
    QString shellPath() const { return m_home + "/.config/omarchy/shell.json"; }

    // An underlined bar leaves its text on the bar itself, but omabar16 draws
    // it in "fg", which most themes set to the dark ink of filled segments. The
    // colour that reads on the bar instead, or "" when the text already reads.
    static QString underlineInk(const QJsonObject &bar, const QHash<QString, QString> &themeColors);
    // Only the style keys omabar16 knows, each of the right kind, so an
    // imported file can't carry anything else into shell.json.
    static QJsonObject sanitizeStyle(const QJsonObject &style);
    // Themes in an export file, a bare theme or a list of them: [{label, style}].
    static QJsonArray parseThemes(const QByteArray &json);

    // Reads themes and layouts from a Presets.js file; false if it won't run.
    bool loadPresets(const QString &path, QString *problem = nullptr);
    void setShellConfig(const QJsonObject &shell);
    // Writes a pending change now rather than after the short pause.
    void flush();

    Q_INVOKABLE void reload();
    Q_INVOKABLE void useAsBar();
    Q_INVOKABLE void refreshWidgets();
    Q_INVOKABLE QString glyphFor(const QString &id) const;
    Q_INVOKABLE QString widgetName(const QString &id) const;
    // Icons for a custom glyph: set "fa" or "oct", words to match, at most limit.
    Q_INVOKABLE QVariantList icons(const QString &set, const QString &query, int limit = 400) const;
    Q_INVOKABLE void dismissMessages();

    // --- themes ---
    Q_INVOKABLE void applyTheme(const QString &id);
    // The whole style at once (a look from one theme, colours from another).
    Q_INVOKABLE void setWholeStyle(const QVariantMap &style);
    // value "" (or nothing) removes the key, so the bar falls back to its default.
    Q_INVOKABLE void setStyle(const QString &key, const QVariant &value);
    // Parts: bg, fg, accent, outlineColor, hoverColor, region:<lane>, pal:<n>, module:<id>.
    Q_INVOKABLE void setColor(const QString &part, const QString &hex);
    Q_INVOKABLE void clearColor(const QString &part);
    Q_INVOKABLE bool saveTheme(const QString &name);
    Q_INVOKABLE void deleteTheme(const QString &id);
    // id "" exports the bar's look as it is now.
    Q_INVOKABLE void exportTheme(const QString &id);
    // Pasted JSON, or the path of an exported file.
    Q_INVOKABLE void importThemes(const QString &textOrPath);

    // --- layout ---
    Q_INVOKABLE void applyLayout(const QString &id);
    Q_INVOKABLE void setPosition(const QString &position);
    Q_INVOKABLE void setTransparent(bool on);
    Q_INVOKABLE void setCenterAnchor(const QString &id);
    // index -1 adds at the lane's end.
    Q_INVOKABLE void addWidget(const QString &id, const QString &lane, int index = -1);
    Q_INVOKABLE void removeWidget(const QString &lane, int index);
    Q_INVOKABLE void moveWidget(const QString &fromLane, int fromIndex, const QString &toLane, int toIndex);
    // A setting on one layout entry (icon, color, format…); "" removes it.
    Q_INVOKABLE void setEntry(const QString &lane, int index, const QString &key, const QVariant &value);

    // --- history ---
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    // Back to the bar as it was when OMAcraft opened.
    Q_INVOKABLE void revert();

signals:
    void changed();
    void presetsChanged();
    void widgetsChanged();
    void messageChanged();

private:
    // Makes next the bar's config: one undo step (quick runs of edits, such
    // as dragging a slider, share one), then written after a short pause.
    // checkInk: the change can leave an underlined bar's text unreadable.
    bool commit(QJsonObject next, bool checkInk = false);
    bool editable();
    void write();
    QJsonObject entryAt(const QString &lane, int index) const;
    QJsonObject newEntry(const QString &id) const;
    static void fixAnchor(QJsonObject &cfg);
    void loadIcons(const QString &path);
    void saveUserThemes(const QJsonArray &themes);
    QJsonArray userThemes() const;
    void setError(const QString &message);
    void setNotice(const QString &message);
    void watch();

    std::function<QString()> m_pluginDir;
    std::function<QString()> m_studioDir;
    QString m_home;
    bool m_runCommands;
    QString m_presetsStamp;
    QJsonObject m_shell;
    // The bar section OMAcraft edits: position, transparent, centerAnchor, layout, style.
    QJsonObject m_cfg;
    QJsonObject m_snapshot;
    QList<QJsonObject> m_undo;
    QList<QJsonObject> m_redo;
    QVariantList m_themes;
    QVariantList m_layouts;
    QVariantMap m_glyphs;
    QHash<QString, QString> m_iconSets;
    QVariantList m_widgets;
    QString m_error;
    QString m_notice;
    bool m_pendingWrite = false;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
    QTimer m_writeTimer;
    QTimer m_burst;
};
