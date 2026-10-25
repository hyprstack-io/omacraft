#pragma once

#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QTemporaryDir>
#include <QTimer>
#include <QVariantList>
#include <functional>

// Screensaver: the Omarchy screensaver's art and effects. The art is designed
// with omascii's renderer and written to ~/.config/omarchy/branding/
// screensaver.txt; the effects are Omarchy's own random ttfx ones, or a set
// picked here, which Screensaver's runner plays through a hook in /usr/local/bin.
//
// It shares nothing with the boot screen. It keeps its own settings in
// ~/.config/omacraft/omasavr.json and only runs omascii's read-only commands
// (status, fonts, images, render) and build.py's --preview-json, never
// set, apply, saved or anything else that changes the boot design or the
// Plymouth theme. It doesn't even hold the Omascii object, only the path of
// its command.
class Screensaver : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY statusChanged)
    Q_PROPERTY(QVariantMap design READ design NOTIFY configChanged)
    Q_PROPERTY(QString artSource READ artSource NOTIFY configChanged)
    Q_PROPERTY(QString mode READ mode NOTIFY configChanged)
    Q_PROPERTY(QStringList effects READ effects NOTIFY configChanged)
    Q_PROPERTY(QString order READ order NOTIFY configChanged)
    Q_PROPERTY(int frameRate READ frameRate NOTIFY configChanged)
    Q_PROPERTY(int pause READ pause NOTIFY configChanged)
    Q_PROPERTY(bool dirty READ dirty NOTIFY configChanged)
    Q_PROPERTY(QVariantMap applied READ applied NOTIFY configChanged)
    Q_PROPERTY(QVariantMap options READ options NOTIFY statusChanged)
    Q_PROPERTY(QString fontSet READ fontSet WRITE setFontSet NOTIFY fontsChanged)
    Q_PROPERTY(QString fontFilter READ fontFilter WRITE setFontFilter NOTIFY fontsChanged)
    Q_PROPERTY(QVariantList fonts READ fonts NOTIFY fontsChanged)
    Q_PROPERTY(int fontTotal READ fontTotal NOTIFY fontsChanged)
    Q_PROPERTY(bool loadingFonts READ loadingFonts NOTIFY fontsChanged)
    Q_PROPERTY(QVariantList images READ images NOTIFY imagesChanged)
    // The art as the screensaver plays it, as text and as AsciiView's HTML.
    Q_PROPERTY(QString art READ art NOTIFY previewChanged)
    Q_PROPERTY(QString artHtml READ artHtml NOTIFY previewChanged)
    Q_PROPERTY(int artCols READ artCols NOTIFY previewChanged)
    Q_PROPERTY(int artRows READ artRows NOTIFY previewChanged)
    Q_PROPERTY(bool rendering READ rendering NOTIFY previewChanged)
    Q_PROPERTY(QStringList frames READ frames NOTIFY framesChanged)
    Q_PROPERTY(int fps READ fps NOTIFY framesChanged)
    Q_PROPERTY(bool loadingFrames READ loadingFrames NOTIFY framesChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY configChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY configChanged)
    // The screensaver itself: on or off, after how long, and the hook.
    Q_PROPERTY(bool enabled READ enabled NOTIFY systemChanged)
    Q_PROPERTY(int idleSeconds READ idleSeconds NOTIFY systemChanged)
    Q_PROPERTY(int lockSeconds READ lockSeconds NOTIFY systemChanged)
    Q_PROPERTY(QString hook READ hook NOTIFY systemChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY systemChanged)
    Q_PROPERTY(bool hasBackup READ hasBackup NOTIFY systemChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    // home and the bin folders are for tests; the defaults are the real ones.
    explicit Screensaver(std::function<QString()> omasciiCli, const QString &home = {},
                         const QString &hookPath = "/usr/local/bin/omarchy-screensaver",
                         const QString &omarchyPath = {}, QObject *parent = nullptr);

    bool available() const { return !m_cli().isEmpty(); }
    bool loaded() const { return m_loaded; }
    QVariantMap design() const { return m_draft.value("design").toMap(); }
    QString artSource() const { return m_draft.value("art").toString(); }
    QString mode() const { return m_draft.value("mode").toString(); }
    QStringList effects() const { return m_draft.value("effects").toStringList(); }
    QString order() const { return m_draft.value("order").toString(); }
    int frameRate() const { return m_draft.value("frameRate").toInt(); }
    int pause() const { return m_draft.value("pause").toInt(); }
    bool dirty() const;
    QVariantMap applied() const { return m_applied; }
    QVariantMap options() const { return m_options; }
    QString fontSet() const { return m_fontSet; }
    QString fontFilter() const { return m_fontFilter; }
    QVariantList fonts() const;
    int fontTotal() const { return m_allFonts.size(); }
    bool loadingFonts() const { return m_loadingFonts; }
    QVariantList images() const { return m_images; }
    QString art() const { return m_art; }
    QString artHtml() const { return toHtml(m_art); }
    int artCols() const;
    int artRows() const;
    bool rendering() const { return m_render && m_render->state() != QProcess::NotRunning; }
    QStringList frames() const { return m_frames; }
    int fps() const { return m_fps; }
    bool loadingFrames() const { return m_loadingFrames; }
    bool canUndo() const { return !m_undo.isEmpty(); }
    bool canRedo() const { return !m_redo.isEmpty(); }
    bool enabled() const { return m_enabled; }
    int idleSeconds() const { return m_idleSeconds; }
    int lockSeconds() const { return m_lockSeconds; }
    // "none", "ours" (current), "outdated" (ours, older) or "foreign".
    QString hook() const { return m_hook; }
    bool busy() const { return m_busy; }
    bool hasBackup() const;
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }

    void setFontSet(const QString &set);
    void setFontFilter(const QString &filter);

    // A design as omascii renders it: every key, so nothing comes from the
    // boot design omascii has saved.
    static QVariantMap defaultDesign();
    static QVariantMap defaultSettings();
    // The settings file's draft over the defaults, for any missing key.
    static QVariantMap withDefaults(const QVariantMap &settings);
    static QStringList nativeEffects();
    // omascii's lib folder (build.py, effects.py) beside its command.
    static QString omasciiLib(const QString &cli);
    // Why the draft can't be applied yet, or empty.
    static QString applyProblem(const QVariantMap &draft);

    QString settingsPath() const { return m_home + "/.config/omacraft/omasavr.json"; }
    QString artPath() const { return m_home + "/.config/omarchy/branding/screensaver.txt"; }
    QString backupPath() const { return m_home + "/.config/omacraft/omasavr/screensaver.before.txt"; }
    QString runnerDir() const { return m_home + "/.local/share/omacraft/omasavr"; }
    QString shellPath() const { return m_home + "/.config/omarchy/shell.json"; }
    QString logoPath() const { return m_omarchyPath + "/logo.txt"; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void refreshSystem();
    // Design keys (text, font, image, border, ...).
    Q_INVOKABLE void setOption(const QString &key, const QVariant &value);
    // "design", "omarchy" (Omarchy's logo) or "current" (screensaver.txt as it is).
    Q_INVOKABLE void setArtSource(const QString &source);
    // "omarchy" (Omarchy's random effects) or "custom" (the ones picked here).
    Q_INVOKABLE void setMode(const QString &mode);
    Q_INVOKABLE void toggleEffect(const QString &effect);
    Q_INVOKABLE void setEffects(const QStringList &effects);
    Q_INVOKABLE void setOrder(const QString &order);
    Q_INVOKABLE void setFrameRate(int fps);
    Q_INVOKABLE void setPause(int seconds);
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    Q_INVOKABLE void loadImages();
    Q_INVOKABLE void loadFrames(const QString &effect);

    // Writes the art and the effects for the screensaver (and offers the
    // hook when picked effects need it). Never the boot screen.
    Q_INVOKABLE void apply();
    // Applies, then starts the screensaver now to see it.
    Q_INVOKABLE void tryIt();
    Q_INVOKABLE void launch();
    Q_INVOKABLE void restoreBackup();
    Q_INVOKABLE void setEnabled(bool on);
    Q_INVOKABLE void setIdleSeconds(int seconds);
    Q_INVOKABLE void installHook();
    Q_INVOKABLE void removeHook();
    Q_INVOKABLE void dismissMessages();

    // The hook script as it would be installed.
    static QByteArray hookScript();
    // Plain text as AsciiView's HTML: escaped, spaces kept, lines broken.
    static QString toHtml(const QString &text);

signals:
    void availableChanged();
    void statusChanged();
    void configChanged();
    void fontsChanged();
    void imagesChanged();
    void previewChanged();
    void framesChanged();
    void systemChanged();
    void messageChanged();

private:
    void change(const QVariantMap &next);
    void changeDesign(const QString &key, const QVariant &value);
    void render();
    void persist();
    void loadSettings();
    void loadFonts();
    void writeRunner();
    void finishApply(const QString &text, bool launchAfter);
    void apply(bool launchAfter);
    void privileged(const QString &script, const QStringList &arguments, std::function<void(bool)> done);
    QString designJson() const;
    void setError(const QString &message);
    void setNotice(const QString &message);

    std::function<QString()> m_cli;
    QString m_home;
    QString m_hookPath;
    QString m_omarchyPath;
    bool m_loaded = false;
    // {art, design, mode, effects, order, frameRate, pause}: what the page
    // edits. m_applied is what the screensaver plays.
    QVariantMap m_draft;
    QVariantMap m_applied;
    QList<QVariantMap> m_undo;
    QList<QVariantMap> m_redo;
    QVariantMap m_options;
    QString m_fontSet = "figlet";
    QString m_fontFilter;
    QVariantList m_allFonts;
    bool m_loadingFonts = false;
    QVariantList m_images;
    QString m_art;
    QPointer<QProcess> m_render;
    bool m_renderAgain = false;
    QStringList m_frames;
    int m_fps = 50;
    bool m_loadingFrames = false;
    QTemporaryDir m_scratch;
    bool m_enabled = true;
    int m_idleSeconds = 150;
    int m_lockSeconds = 300;
    QString m_hook = "none";
    bool m_busy = false;
    QString m_error;
    QString m_notice;
    QTimer m_renderDebounce;
    QTimer m_persistDebounce;
};
