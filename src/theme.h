#pragma once

#include <QColor>
#include <QFileSystemWatcher>
#include <QHash>
#include <QObject>
#include <QTimer>

// The Omarchy theme, as OmaCraft paints itself with it. Reads the current
// theme's colors.toml (and follows it when the theme changes) and derives
// every surface, border and text colour the window uses from its background,
// foreground and accent, so a light theme gives a light window and a dark
// one a dark window. QML reads these by role (theme.card, theme.textMuted…)
// and never names a colour itself, apart from content such as previews.
class Theme : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString accent READ accent NOTIFY changed)
    Q_PROPERTY(QString accentForeground READ accentForeground NOTIFY changed)
    Q_PROPERTY(bool dark READ dark NOTIFY changed)

    // Surfaces, from the window back to front.
    Q_PROPERTY(QColor window READ window NOTIFY changed)
    Q_PROPERTY(QColor sidebar READ sidebar NOTIFY changed)
    Q_PROPERTY(QColor sunken READ sunken NOTIFY changed)
    Q_PROPERTY(QColor inset READ inset NOTIFY changed)
    Q_PROPERTY(QColor card READ card NOTIFY changed)
    Q_PROPERTY(QColor hover READ hover NOTIFY changed)
    Q_PROPERTY(QColor raised READ raised NOTIFY changed)
    Q_PROPERTY(QColor border READ border NOTIFY changed)
    Q_PROPERTY(QColor borderStrong READ borderStrong NOTIFY changed)

    // Text, strongest first.
    Q_PROPERTY(QColor text READ text NOTIFY changed)
    Q_PROPERTY(QColor textSoft READ textSoft NOTIFY changed)
    Q_PROPERTY(QColor textMuted READ textMuted NOTIFY changed)
    Q_PROPERTY(QColor textDim READ textDim NOTIFY changed)
    Q_PROPERTY(QColor textFaint READ textFaint NOTIFY changed)

    // States.
    Q_PROPERTY(QColor danger READ danger NOTIFY changed)
    Q_PROPERTY(QColor dangerFill READ dangerFill NOTIFY changed)
    Q_PROPERTY(QColor dangerBorder READ dangerBorder NOTIFY changed)
    Q_PROPERTY(QColor dangerText READ dangerText NOTIFY changed)
    Q_PROPERTY(QColor warning READ warning NOTIFY changed)
    Q_PROPERTY(QColor warningFill READ warningFill NOTIFY changed)
    Q_PROPERTY(QColor warningBorder READ warningBorder NOTIFY changed)
    Q_PROPERTY(QColor warningText READ warningText NOTIFY changed)
    Q_PROPERTY(QColor success READ success NOTIFY changed)

public:
    explicit Theme(const QString &currentDirectory = {}, QObject *parent = nullptr);

    QString accent() const { return m_accent; }
    QString accentForeground() const;
    bool dark() const { return m_dark; }

    QColor window() const { return m_background; }
    QColor sidebar() const { return m_dark ? mix(m_background, Qt::black, 0.28) : mix(m_background, m_foreground, 0.035); }
    QColor sunken() const { return m_dark ? mix(m_background, Qt::black, 0.4) : mix(m_background, m_foreground, 0.05); }
    QColor inset() const { return mix(m_background, m_foreground, 0.02); }
    QColor card() const { return mix(m_background, m_foreground, 0.045); }
    QColor hover() const { return mix(m_background, m_foreground, 0.085); }
    QColor raised() const { return mix(m_background, m_foreground, 0.07); }
    QColor border() const { return mix(m_background, m_foreground, 0.13); }
    QColor borderStrong() const { return mix(m_background, m_foreground, 0.2); }

    QColor text() const { return m_foreground; }
    QColor textSoft() const { return mix(m_foreground, m_background, 0.12); }
    QColor textMuted() const { return mix(m_foreground, m_background, 0.38); }
    QColor textDim() const { return mix(m_foreground, m_background, 0.5); }
    QColor textFaint() const { return mix(m_foreground, m_background, 0.62); }

    QColor danger() const { return m_red; }
    QColor dangerFill() const { return mix(m_background, m_red, 0.13); }
    QColor dangerBorder() const { return mix(m_background, m_red, 0.45); }
    QColor dangerText() const { return mix(m_red, m_foreground, 0.35); }
    QColor warning() const { return m_yellow; }
    QColor warningFill() const { return mix(m_background, m_yellow, 0.1); }
    QColor warningBorder() const { return mix(m_background, m_yellow, 0.4); }
    QColor warningText() const { return mix(m_yellow, m_foreground, 0.45); }
    QColor success() const { return m_green; }

    // The theme's colours by name (accent, background, red, …) from a
    // colors.toml, and whether it is dark ("mode", else the background).
    static QHash<QString, QString> readColors(const QString &path);
    static QString readAccent(const QString &path);
    static bool isDark(const QHash<QString, QString> &colors);
    // a moved t of the way to b (0 = a, 1 = b).
    static QColor mix(const QColor &a, const QColor &b, double t);
    // color itself, or moved away from against until text in it reads.
    static QColor readable(const QColor &color, const QColor &against, double minimum);
    // WCAG contrast ratio between two colours (1 to 21).
    static double contrastRatio(const QColor &a, const QColor &b);

signals:
    void changed();

private:
    void reload();

    QString m_directory;
    QString m_accent = "#FFD60A";
    bool m_dark = true;
    QColor m_background{"#0e0e10"};
    QColor m_foreground{"#ffffff"};
    QColor m_red{"#ff8a8a"};
    QColor m_yellow{"#c9a227"};
    QColor m_green{"#9ece6a"};
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};
