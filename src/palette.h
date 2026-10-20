#pragma once

#include <QColor>
#include <QFileSystemWatcher>
#include <QHash>
#include <QList>
#include <QObject>
#include <QTimer>

// The current Omarchy theme's colours, as the keyboard uses them. hyprskin
// and the theme switcher both rewrite colors.toml, so following this file is
// what makes the lights follow the wallpaper.
struct ThemePalette {
    QColor accent{"#FFD60A"};
    QColor background{"#0e0e10"};
    QColor foreground{"#ffffff"};
    // Every named colour in colors.toml (red, bright_blue, color4…).
    QHash<QString, QColor> named;

    static ThemePalette read(const QString &colorsToml);

    // The four colour slots a design or animation paints with, picked from
    // the theme: the accent, the two theme hues furthest from it and from
    // each other, and a dim glow of the accent for the keys in between.
    QList<QColor> slotColors() const;
    // The theme's vivid colours ordered round the colour wheel, for the
    // animations that sweep through many colours. Starts at the accent.
    QList<QColor> cycle() const;

    bool operator==(const ThemePalette &other) const;
    bool operator!=(const ThemePalette &other) const { return !(*this == other); }
};

// Follows ~/.local/state/omarchy/current/theme/colors.toml. A theme switch
// replaces files and symlinks, so the watch is re-armed after every change.
class PaletteWatcher : public QObject {
    Q_OBJECT

public:
    explicit PaletteWatcher(const QString &currentDirectory = {}, QObject *parent = nullptr);

    const ThemePalette &palette() const { return m_palette; }
    QString colorsPath() const { return m_directory + "/theme/colors.toml"; }

signals:
    void changed();

private:
    void reload();

    QString m_directory;
    ThemePalette m_palette;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};
