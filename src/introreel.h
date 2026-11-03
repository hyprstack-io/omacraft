#pragma once

#include <QObject>
#include <QSet>
#include <QStringList>
#include <QVariantMap>

class Omascii;

// The Plugin Suite's title: "OMACRAFT" in the TheDraw font balistcx, without
// a shadow, played through every one of the Boot Splash page's intro effects
// in turn, round and round, rendered by omascii.
// It starts on a random effect each launch. Rendering an intro takes a few
// seconds, so each one is kept in ~/.cache/omacraft/intro (keyed by the
// effect, the art's settings and the palette, so a new theme renders
// afresh) and the next one is rendered ahead while the current one plays.
class IntroReel : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY effectsChanged)
    Q_PROPERTY(QStringList effects READ effects NOTIFY effectsChanged)
    Q_PROPERTY(int index READ index NOTIFY effectChanged)
    Q_PROPERTY(QString effect READ effect NOTIFY effectChanged)
    // The intro playing now; empty until the first is ready.
    Q_PROPERTY(QStringList frames READ frames NOTIFY framesChanged)
    Q_PROPERTY(int fps READ fps NOTIFY framesChanged)
    // Frames to hold the finished art for before the intro goes again.
    Q_PROPERTY(int hold READ hold NOTIFY framesChanged)
    // The finished art, shown until the first intro is ready.
    Q_PROPERTY(QString still READ still NOTIFY stillChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    // The font the title is drawn in: one picked to try out, else the usual.
    // Only the title changes; the boot splash keeps its own font.
    Q_PROPERTY(QString font READ font NOTIFY fontChanged)
    Q_PROPERTY(bool customFont READ customFont NOTIFY fontChanged)
    // Every font omascii has, FIGlet then TheDraw: { name, detail, set }.
    Q_PROPERTY(QVariantList fonts READ fonts NOTIFY fontsChanged)
    Q_PROPERTY(bool loadingFonts READ loadingFonts NOTIFY fontsChanged)

public:
    explicit IntroReel(Omascii *omascii, const QString &cacheDir = {}, QObject *parent = nullptr);
    ~IntroReel() override;

    bool available() const { return !m_effects.isEmpty(); }
    QStringList effects() const { return m_effects; }
    int index() const { return m_index; }
    QString effect() const { return m_effects.value(m_index); }
    QStringList frames() const { return m_frames; }
    int fps() const { return m_fps; }
    int hold() const { return m_hold; }
    QString still() const { return m_still; }
    bool loading() const { return m_loading; }
    QString font() const { return m_font.isEmpty() ? titleFont() : m_font; }
    bool customFont() const { return !m_font.isEmpty(); }
    QVariantList fonts() const { return m_fonts; }
    bool loadingFonts() const { return m_loadingFonts; }

    // The settings the title is drawn with: the boot design's colours, the
    // word in its own font, no picture, border or padding.
    static QVariantMap titleConfig(const QVariantMap &boot);
    // "TDF balistcx" once omascii has its TheDraw fonts, else "ANSI Shadow".
    static QString titleFont();
    // Where one intro is kept: its effect and a hash of everything it's drawn from.
    QString cachePath(const QString &effect) const;

    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void show(int index);
    // An empty name goes back to the usual font.
    Q_INVOKABLE void setFont(const QString &name);
    // Asks omascii for its fonts, once.
    Q_INVOKABLE void loadFonts();

signals:
    void effectsChanged();
    void effectChanged();
    void framesChanged();
    void stillChanged();
    void loadingChanged();
    void fontChanged();
    void fontsChanged();

private:
    void sync();
    void load();
    void render(const QString &effect);
    void prefetch();
    bool readCached(const QString &effect);
    void setLoading(bool loading);
    QString configJson() const;

    Omascii *m_omascii;
    QString m_cacheDir;
    QStringList m_effects;
    int m_index = -1;
    QStringList m_frames;
    int m_fps = 50;
    int m_hold = 60;
    QString m_still;
    bool m_loading = false;
    // By cache path, so a render for a font no longer shown can't block or
    // stand in for the one that is.
    QSet<QString> m_rendering;
    QString m_font;
    QVariantList m_fonts;
    bool m_loadingFonts = false;
    bool m_fontsLoaded = false;
    QString m_drawnFrom;
};
