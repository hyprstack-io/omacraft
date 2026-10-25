#pragma once

#include <QColor>
#include <QFileSystemWatcher>
#include <QHash>
#include <QList>
#include <QObject>
#include <QTimer>

// The current Omarchy theme's colours, as the keyboard uses them, and the
// colours of the active wallpaper itself. hyprskin and the theme switcher
// both rewrite colors.toml and swap the background, so following them is what
// makes the lights follow the wallpaper.
struct ThemePalette {
    QColor accent{"#FFD60A"};
    QColor background{"#0e0e10"};
    QColor foreground{"#ffffff"};
    // Every named colour in colors.toml (red, bright_blue, color4…).
    QHash<QString, QColor> named;
    // The hues the active wallpaper is made of, the most present first. A
    // theme fills in colours a wallpaper doesn't have (a bright yellow for a
    // teal photo), so when there is a wallpaper the keys light only these.
    QList<QColor> wallpaper;

    // The theme's colours, and the wallpaper's when `wallpaperImage` is one.
    static ThemePalette read(const QString &colorsToml, const QString &wallpaperImage = {});
    // Up to six distinct hues found in an image, the most present first; a
    // single grey when it has none. Empty when it can't be read.
    static QList<QColor> wallpaperColors(const QString &image);

    // The four colour slots a design or animation paints with: the
    // wallpaper's main hue (else the theme's accent), the two hues furthest
    // from it and from each other, and a dim glow of it for the keys in
    // between. With a wallpaper, every slot is one of its colours or a shade
    // of one.
    QList<QColor> slotColors() const;
    // The vivid colours ordered round the colour wheel, for the animations
    // that sweep through many colours: the wallpaper's when there is one.
    QList<QColor> cycle() const;

    bool operator==(const ThemePalette &other) const;
    bool operator!=(const ThemePalette &other) const { return !(*this == other); }
};

// Follows ~/.local/state/omarchy/current/theme/colors.toml and the background
// beside it. A theme switch replaces files and symlinks, so the watch is
// re-armed after every change.
class PaletteWatcher : public QObject {
    Q_OBJECT

public:
    explicit PaletteWatcher(const QString &currentDirectory = {}, QObject *parent = nullptr);

    const ThemePalette &palette() const { return m_palette; }
    QString colorsPath() const { return m_directory + "/theme/colors.toml"; }
    QString backgroundPath() const { return m_directory + "/background"; }

signals:
    void changed();

private:
    void reload();

    QString m_directory;
    ThemePalette m_palette;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};
