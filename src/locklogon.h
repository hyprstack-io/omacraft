#pragma once

#include <QFileSystemWatcher>
#include <QHash>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class FilePicker;
class Plugins;

// The Lock & Logon page. The lock's look is a JSON file the omacraft.lock plugin
// follows as it's saved; the login's look is a draft here until it's applied,
// since only the root helper can reach SDDM's files. Idle times are shell.json's
// own `idle` keys, edited in place like every other shell.json change.
//
// Nothing here checks a setting's range: LockDefaults.js does, on every read, in
// the plugin, the login theme and the page alike, and the helper checks all it's
// handed again. This class only moves settings around.
class LockLogon : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap lockLook READ lockLook NOTIFY lookChanged)
    Q_PROPERTY(QVariantMap loginLook READ loginLook NOTIFY lookChanged)
    Q_PROPERTY(bool canUndoLock READ canUndoLock NOTIFY lookChanged)
    Q_PROPERTY(bool canUndoLogin READ canUndoLogin NOTIFY lookChanged)
    Q_PROPERTY(QVariantMap themeColors READ themeColors NOTIFY systemChanged)
    Q_PROPERTY(QString wallpaper READ wallpaper NOTIFY systemChanged)
    Q_PROPERTY(QVariantList folderImages READ folderImages NOTIFY lookChanged)

    Q_PROPERTY(QString lockInUse READ lockInUse NOTIFY systemChanged)
    Q_PROPERTY(QString lockInUseName READ lockInUseName NOTIFY systemChanged)

    Q_PROPERTY(int screensaverSeconds READ screensaverSeconds NOTIFY systemChanged)
    Q_PROPERTY(int lockSeconds READ lockSeconds NOTIFY systemChanged)
    Q_PROPERTY(bool stayAwake READ stayAwake NOTIFY systemChanged)

    Q_PROPERTY(bool loginThemeInstalled READ loginThemeInstalled NOTIFY systemChanged)
    Q_PROPERTY(bool helperInstalled READ helperInstalled NOTIFY systemChanged)
    Q_PROPERTY(QString loginTheme READ loginTheme NOTIFY systemChanged)
    Q_PROPERTY(QString autologinUser READ autologinUser NOTIFY systemChanged)
    Q_PROPERTY(bool autologinOverridden READ autologinOverridden NOTIFY systemChanged)
    Q_PROPERTY(bool loginApplied READ loginApplied NOTIFY lookChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY systemChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    static inline const QString kHelper = "/usr/lib/omacraft/omacraft-login";
    static inline const QString kThemeOverride = "zz-omacraft-theme.conf";
    static inline const QString kAutologinOverride = "zz-omacraft-autologin.conf";

    // Tests pass a temp home and etc, and runCommands false so nothing reaches
    // the shell or pkexec.
    LockLogon(Plugins *plugins, FilePicker *picker, const QString &home = {}, const QString &etc = "/etc",
              const QString &themesDir = "/usr/share/sddm/themes", bool runCommands = true, QObject *parent = nullptr);

    QVariantMap lockLook() const { return m_look.value("lock"); }
    QVariantMap loginLook() const { return m_look.value("login"); }
    bool canUndoLock() const { return !m_undo.value("lock").isEmpty(); }
    bool canUndoLogin() const { return !m_undo.value("login").isEmpty(); }
    QVariantMap themeColors() const;
    QString wallpaper() const;
    QVariantList folderImages() const;
    QString lockInUse() const { return m_lockInUse; }
    QString lockInUseName() const;
    int screensaverSeconds() const { return m_screensaverSeconds; }
    int lockSeconds() const { return m_lockSeconds; }
    bool stayAwake() const;
    bool loginThemeInstalled() const;
    bool helperInstalled() const;
    QString loginTheme() const { return m_loginTheme; }
    QString autologinUser() const { return m_autologinUser; }
    bool autologinOverridden() const;
    bool loginApplied() const;
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }

    // What SDDM ends up with from a folder of .conf files, later files winning,
    // as SDDM itself reads them: { theme, autologinUser }.
    static QVariantMap readSddmConfig(const QString &confDir);
    // The look as the helper's KEY=VALUE arguments, with the theme's colours
    // fixed in, since the greeter runs before any theme exists. Paths stay out.
    QStringList loginArguments() const;
    // The file a login background comes from, or empty with a reason in *why.
    QString loginBackgroundFile(QString *why = nullptr) const;

    Q_INVOKABLE void set(const QString &target, const QString &key, const QVariant &value);
    Q_INVOKABLE void setMany(const QString &target, const QVariantMap &values);
    // Replaces the whole look: a preset, or back to the defaults with {}.
    Q_INVOKABLE void replace(const QString &target, const QVariantMap &values);
    Q_INVOKABLE void undo(const QString &target);
    Q_INVOKABLE void copyLockToLogin();
    Q_INVOKABLE void choosePicture(const QString &target, const QString &key);
    Q_INVOKABLE void chooseFolder(const QString &target, const QString &key);

    // Swaps OmaCraft's lock in or out, installing the plugin first if need be.
    Q_INVOKABLE void useOurLock(bool on);
    Q_INVOKABLE void previewLock();
    Q_INVOKABLE void lockNow();

    Q_INVOKABLE void setIdle(const QString &key, int seconds);
    Q_INVOKABLE void setStayAwake(bool on);

    Q_INVOKABLE void applyLogin();
    Q_INVOKABLE void useLoginTheme(bool on);
    Q_INVOKABLE void setAutologin(bool on);
    Q_INVOKABLE void tryGreeter();

    Q_INVOKABLE void reload();
    Q_INVOKABLE void dismissMessages();

signals:
    void lookChanged();
    void systemChanged();
    void messageChanged();
    // The saver page shows the same idle times.
    void idleChanged();

private:
    QString lockPath() const { return m_home + "/.config/omarchy/omacraft-lock.json"; }
    QString loginPath() const { return m_home + "/.config/omacraft/login.json"; }
    QString appliedPath() const { return m_home + "/.config/omacraft/login-applied.json"; }
    QString shellPath() const { return m_home + "/.config/omarchy/shell.json"; }
    QString stayAwakePath() const { return m_home + "/.local/state/omarchy/indicators/stay-awake"; }
    QByteArray lookBytes(const QVariantMap &look) const;
    void remember(const QString &target);
    void store(const QString &target, const QVariantMap &look);
    void privileged(const QStringList &arguments, const QString &done, const std::function<void()> &after = {});
    void setError(const QString &message);
    void setNotice(const QString &message);
    void readShell();

    Plugins *m_plugins;
    FilePicker *m_picker;
    QString m_home;
    QString m_etc;
    QString m_themesDir;
    bool m_runCommands;
    QHash<QString, QVariantMap> m_look;
    QHash<QString, QList<QVariantMap>> m_undo;
    QByteArray m_applied;
    QString m_lockInUse;
    int m_screensaverSeconds = 150;
    int m_lockSeconds = 300;
    QString m_loginTheme;
    QString m_autologinUser;
    bool m_busy = false;
    QString m_error;
    QString m_notice;
    QFileSystemWatcher m_watcher;
};
