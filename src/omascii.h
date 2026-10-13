#pragma once

#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QTimer>
#include <QVariantList>
#include <functional>

// The omascii boot screen designer, through omascii's own command line, so
// the shell overlay, the CLI and OMAcraft share one config and one library.
// Every change is kept as it's made, as the overlay does.
class Omascii : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY statusChanged)
    Q_PROPERTY(QVariantMap config READ config NOTIFY configChanged)
    Q_PROPERTY(QVariantMap options READ options NOTIFY statusChanged)
    Q_PROPERTY(QVariantMap palette READ palette NOTIFY statusChanged)
    Q_PROPERTY(QVariantMap boot READ boot NOTIFY statusChanged)
    Q_PROPERTY(QString fontSet READ fontSet WRITE setFontSet NOTIFY fontsChanged)
    Q_PROPERTY(QString fontFilter READ fontFilter WRITE setFontFilter NOTIFY fontsChanged)
    Q_PROPERTY(QVariantList fonts READ fonts NOTIFY fontsChanged)
    Q_PROPERTY(int fontTotal READ fontTotal NOTIFY fontsChanged)
    Q_PROPERTY(bool loadingFonts READ loadingFonts NOTIFY fontsChanged)
    Q_PROPERTY(QString previewHtml READ previewHtml NOTIFY previewChanged)
    Q_PROPERTY(int previewCols READ previewCols NOTIFY previewChanged)
    Q_PROPERTY(int previewRows READ previewRows NOTIFY previewChanged)
    Q_PROPERTY(QString previewForeground READ previewForeground NOTIFY previewChanged)
    Q_PROPERTY(QString previewBackground READ previewBackground NOTIFY previewChanged)
    Q_PROPERTY(bool rendering READ rendering NOTIFY previewChanged)
    Q_PROPERTY(QVariantList saved READ saved NOTIFY savedChanged)
    Q_PROPERTY(QVariantList images READ images NOTIFY imagesChanged)
    Q_PROPERTY(QStringList frames READ frames NOTIFY framesChanged)
    Q_PROPERTY(int fps READ fps NOTIFY framesChanged)
    Q_PROPERTY(bool loadingFrames READ loadingFrames NOTIFY framesChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY configChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY configChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    explicit Omascii(std::function<QString()> pluginDir, QObject *parent = nullptr);

    QString cli() const;
    bool available() const { return !cli().isEmpty(); }
    bool loaded() const { return m_loaded; }
    QVariantMap config() const { return m_config; }
    QVariantMap options() const { return m_options; }
    QVariantMap palette() const { return m_palette; }
    QVariantMap boot() const { return m_boot; }
    QString fontSet() const { return m_fontSet; }
    QString fontFilter() const { return m_fontFilter; }
    QVariantList fonts() const;
    int fontTotal() const { return m_allFonts.size(); }
    bool loadingFonts() const { return m_loadingFonts; }
    QString previewHtml() const { return m_previewHtml; }
    int previewCols() const { return m_previewCols; }
    int previewRows() const { return m_previewRows; }
    QString previewForeground() const { return m_previewForeground; }
    QString previewBackground() const { return m_previewBackground; }
    bool rendering() const { return m_render && m_render->state() != QProcess::NotRunning; }
    QVariantList saved() const { return m_saved; }
    QVariantList images() const { return m_images; }
    QStringList frames() const { return m_frames; }
    int fps() const { return m_fps; }
    bool loadingFrames() const { return m_loadingFrames; }
    bool canUndo() const { return !m_undo.isEmpty(); }
    bool canRedo() const { return !m_redo.isEmpty(); }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }

    void setFontSet(const QString &set);
    void setFontFilter(const QString &filter);

    // Why the design can't go to the boot screen yet, or empty.
    static QString applyProblem(const QVariantMap &config);
    // The font list in `omascii fonts --json` for any set, as {name, detail}.
    static QVariantList parseFonts(const QByteArray &json);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setOption(const QString &key, const QVariant &value);
    Q_INVOKABLE void toggleEffect(const QString &effect);
    Q_INVOKABLE void setEffects(const QStringList &effects);
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    Q_INVOKABLE void loadImages();
    Q_INVOKABLE void saveToLibrary(const QString &name);
    Q_INVOKABLE void useSaved(const QString &id);
    Q_INVOKABLE void renameSaved(const QString &id, const QString &name);
    Q_INVOKABLE void removeSaved(const QString &id);
    Q_INVOKABLE void applyToBoot();
    Q_INVOKABLE void restoreBoot();
    Q_INVOKABLE void exportGif();
    Q_INVOKABLE void fetchTheDraw();
    Q_INVOKABLE void fetchMoreFonts();
    Q_INVOKABLE void loadFrames(const QString &effect);
    Q_INVOKABLE void dismissMessages();

signals:
    void availableChanged();
    void statusChanged();
    void configChanged();
    void fontsChanged();
    void previewChanged();
    void savedChanged();
    void imagesChanged();
    void framesChanged();
    void messageChanged();

private:
    void change(const QVariantMap &next);
    void render();
    void persist();
    void loadFonts();
    void loadSaved();
    QString configJson() const;
    void setError(const QString &message);
    void setNotice(const QString &message);
    void inTerminal(const QStringList &arguments, const QString &after = {});

    std::function<QString()> m_pluginDir;
    bool m_loaded = false;
    QVariantMap m_config;
    QList<QVariantMap> m_undo;
    QList<QVariantMap> m_redo;
    QVariantMap m_options;
    QVariantMap m_palette;
    QVariantMap m_boot;
    QString m_fontSet = "figlet";
    QString m_fontFilter;
    QVariantList m_allFonts;
    bool m_loadingFonts = false;
    QString m_previewHtml;
    int m_previewCols = 0;
    int m_previewRows = 0;
    QString m_previewForeground = "#ffffff";
    QString m_previewBackground = "#000000";
    QPointer<QProcess> m_render;
    bool m_renderAgain = false;
    QVariantList m_saved;
    QVariantList m_images;
    QStringList m_frames;
    int m_fps = 50;
    bool m_loadingFrames = false;
    QString m_error;
    QString m_notice;
    QTimer m_renderDebounce;
    QTimer m_persistDebounce;
};
