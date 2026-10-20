#pragma once

#include <QFileSystemWatcher>
#include <QObject>

// The HyprStack boot animation as the Plymouth theme: whether it's installed,
// whether it's the boot screen now, and switching to it or back. The theme
// itself ships with the package, in /usr/share/plymouth/themes/hyprstack-boot.
//
// Switching runs in a terminal, since it asks for a password and rebuilds
// the initramfs. The theme it replaces goes in omascii's previous-theme file,
// so turning it off here and omascii's "Undo boot change" put back the same one.
class BootSplash : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool on READ on NOTIFY changed)
    Q_PROPERTY(QString theme READ theme NOTIFY changed)
    Q_PROPERTY(bool switching READ switching NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)

public:
    static inline const QString kTheme = "hyprstack-boot";

    explicit BootSplash(QObject *parent = nullptr);
    BootSplash(const QString &confPath, const QString &themesDir, const QString &previousPath,
               QObject *parent = nullptr);

    bool available() const;
    bool on() const { return m_theme == kTheme; }
    QString theme() const { return m_theme; }
    bool switching() const { return !m_waitingFor.isEmpty(); }
    QString error() const { return m_error; }

    // The Theme= line of a plymouthd.conf, or empty.
    static QString themeIn(const QByteArray &conf);
    // The shell command that makes name the boot theme and rebuilds the
    // initramfs the way Omarchy's own plymouth commands do.
    static QString switchCommand(const QString &name);

    // The theme turning HyprStack off goes back to: the one it replaced, else
    // Omarchy's own.
    Q_INVOKABLE QString previousTheme() const;

    Q_INVOKABLE void setOn(bool on);
    Q_INVOKABLE void reload();

signals:
    void changed();

private:
    void watch();

    QString m_confPath;
    QString m_themesDir;
    QString m_previousPath;
    QString m_theme;
    QString m_waitingFor;
    QString m_error;
    QFileSystemWatcher m_watcher;
};
