#pragma once

#include <QElapsedTimer>
#include <QFile>
#include <QList>
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QHash>
#include <QVariantList>

#include "buildconfig.h"
#include "drives.h"
#include "replica.h"

class FilePicker;

class IsoBuilder : public QObject {
    Q_OBJECT

    // The ISO the user is putting together.
    Q_PROPERTY(QString profile READ profile WRITE setProfile NOTIFY configChanged)
    Q_PROPERTY(QString isoName READ isoName WRITE setIsoName NOTIFY configChanged)
    Q_PROPERTY(QString hostname READ hostname WRITE setHostname NOTIFY configChanged)
    Q_PROPERTY(QString packages READ packages WRITE setPackages NOTIFY configChanged)
    Q_PROPERTY(QVariantList overlays READ overlays NOTIFY configChanged)
    Q_PROPERTY(bool omarchySetup READ omarchySetup WRITE setOmarchySetup NOTIFY configChanged)
    Q_PROPERTY(QString outputDir READ outputDir WRITE setOutputDir NOTIFY configChanged)
    Q_PROPERTY(int packageCount READ packageCount NOTIFY configChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY configChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY configChanged)
    Q_PROPERTY(bool replicaSecrets READ replicaSecrets WRITE setReplicaSecrets NOTIFY configChanged)
    Q_PROPERTY(QString timezone READ timezone WRITE setTimezone NOTIFY configChanged)
    Q_PROPERTY(QString keymap READ keymap WRITE setKeymap NOTIFY configChanged)
    Q_PROPERTY(QString services READ services WRITE setServices NOTIFY configChanged)
    Q_PROPERTY(QString kernelParams READ kernelParams WRITE setKernelParams NOTIFY configChanged)
    Q_PROPERTY(QString compression READ compression WRITE setCompression NOTIFY configChanged)
    Q_PROPERTY(QVariantList editedFiles READ editedFiles NOTIFY configChanged)
    Q_PROPERTY(QVariantList fileSuggestions READ fileSuggestions NOTIFY configChanged)
    Q_PROPERTY(QStringList timezones READ timezones CONSTANT)
    Q_PROPERTY(QStringList keymaps READ keymaps CONSTANT)

    // "This desktop": what the scan of this machine found.
    Q_PROPERTY(bool desktopScanned READ desktopScanned NOTIFY desktopChanged)
    Q_PROPERTY(bool sizing READ sizing NOTIFY desktopChanged)
    Q_PROPERTY(QString desktopError READ desktopError NOTIFY desktopChanged)
    Q_PROPERTY(QString desktopUser READ desktopUser NOTIFY desktopChanged)
    Q_PROPERTY(QString desktopKernel READ desktopKernel NOTIFY desktopChanged)
    Q_PROPERTY(int nativeCount READ nativeCount NOTIFY desktopChanged)
    Q_PROPERTY(QStringList foreignPackages READ foreignPackages NOTIFY desktopChanged)
    Q_PROPERTY(QVariantList homeItems READ homeItems NOTIFY desktopChanged)
    Q_PROPERTY(QString homeSize READ homeSize NOTIFY desktopChanged)

    // What's happening: idle, measuring (home, before a "This desktop" build),
    // checking, building, flashing, installing.
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY stateChanged)
    Q_PROPERTY(bool cancelling READ cancelling NOTIFY stateChanged)
    Q_PROPERTY(QString stage READ stage NOTIFY progressChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString elapsed READ elapsed NOTIFY progressChanged)
    Q_PROPERTY(QString remaining READ remaining NOTIFY progressChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

    // What the machine is missing to build at all.
    Q_PROPERTY(QString missing READ missing NOTIFY toolsChanged)
    Q_PROPERTY(bool archisoMissing READ archisoMissing NOTIFY toolsChanged)

    // Flashing.
    Q_PROPERTY(QString builtIso READ builtIso NOTIFY builtIsoChanged)
    Q_PROPERTY(QString flashIso READ flashIso NOTIFY flashChanged)
    Q_PROPERTY(QString flashIsoSize READ flashIsoSize NOTIFY flashChanged)
    Q_PROPERTY(QVariantList drives READ drives NOTIFY flashChanged)

public:
    // configPath is where settings are saved, configsDir archiso's profiles.
    // Both default to the real locations; tests pass temp directories.
    explicit IsoBuilder(FilePicker *picker, const QString &configPath = {},
                     const QString &configsDir = "/usr/share/archiso/configs", QObject *parent = nullptr);
    ~IsoBuilder() override;

    QString profile() const { return m_config.profile; }
    QString isoName() const { return m_config.isoName; }
    QString hostname() const { return m_config.hostname; }
    QString packages() const { return m_config.packages; }
    QVariantList overlays() const;
    bool omarchySetup() const { return m_config.omarchySetup; }
    QString outputDir() const { return m_config.outputDir; }
    int packageCount() const;
    bool canUndo() const { return !m_undo.isEmpty(); }
    bool canRedo() const { return !m_redo.isEmpty(); }

    void setProfile(const QString &value);
    void setIsoName(const QString &value);
    void setHostname(const QString &value);
    void setPackages(const QString &value);
    QString timezone() const { return m_config.timezone; }
    QString keymap() const { return m_config.keymap; }
    QString services() const { return m_config.services; }
    QString kernelParams() const { return m_config.kernelParams; }
    QString compression() const { return m_config.compression; }
    void setTimezone(const QString &value);
    void setKeymap(const QString &value);
    void setServices(const QString &value);
    void setKernelParams(const QString &value);
    void setCompression(const QString &value);
    QVariantList editedFiles() const;
    QVariantList fileSuggestions() const;
    QStringList timezones() const;
    QStringList keymaps() const;
    void setOmarchySetup(bool value);
    void setOutputDir(const QString &value);
    bool replicaSecrets() const { return m_config.replicaSecrets; }
    void setReplicaSecrets(bool value);

    bool desktopScanned() const { return m_desktopScanned; }
    bool sizing() const { return m_du.state() != QProcess::NotRunning; }
    QString desktopError() const { return m_system.error; }
    QString desktopUser() const { return m_system.user; }
    QString desktopKernel() const { return m_system.kernel; }
    int nativeCount() const { return m_system.native.size(); }
    QStringList foreignPackages() const { return m_system.foreign; }
    QVariantList homeItems() const;
    QString homeSize() const;
    qint64 includedHomeBytes() const;
    // The biggest home folders the build includes, as "Downloads (5.9 GB), …".
    QString biggestHomeItems(int count) const;

    QString state() const { return m_state; }
    bool busy() const { return m_state != "idle"; }
    bool cancelling() const { return m_cancelling; }
    QString stage() const { return m_stage; }
    double progress() const { return m_progress; }
    QString elapsed() const;
    QString remaining() const;
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }
    QString missing() const { return m_missing; }
    bool archisoMissing() const { return m_archisoMissing; }
    QString builtIso() const { return m_builtIso; }
    QString flashIso() const { return m_flashIso; }
    QString flashIsoSize() const;
    QVariantList drives() const;

    const BuildConfig &config() const { return m_config; }

    // The build stage a line of mkarchiso output starts, and how far along the
    // build that is (0–1); returns false for lines that don't start one.
    static bool stageForLine(const QString &line, QString *stage, double *progress);

    // Progress within a stage: packages downloaded and installed, and
    // mksquashfs's percentage. quiet is set for lines that only redraw a
    // progress bar and don't belong in the log.
    struct BuildProgress {
        int packages = 0;
        int downloaded = 0;
    };
    static bool refineProgress(const QString &line, BuildProgress *state, QString *stage, double *progress, bool *quiet);

    // The syntax colouring an edited file gets: shell, ini, json, lua, css,
    // packages, or plain.
    static QString languageFor(const QString &path, const QString &content = {});

    // The ISO's file name in dir that doesn't clobber anything there yet.
    static QString uniqueIsoPath(const QString &dir, const QString &isoName, const QString &date);

    // Reads this machine for "This desktop": user, kernel, packages, home.
    Q_INVOKABLE void scanDesktop();
    Q_INVOKABLE void setHomeItem(const QString &path, bool on);
    // Sets every item of a kind ("settings", "secret", "cache", "personal").
    Q_INVOKABLE void setHomeKind(const QString &kind, bool on);

    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();

    Q_INVOKABLE void build();
    Q_INVOKABLE void cancel();
    // Cancels whatever runs and quits once it has stopped.
    Q_INVOKABLE void cancelAndQuit();

    // Folders to include: the picker adds one; each has a target in the ISO.
    Q_INVOKABLE void chooseOverlay();
    Q_INVOKABLE void addOverlay(const QString &source, const QString &target = "/");
    Q_INVOKABLE void removeOverlay(int index);
    Q_INVOKABLE void setOverlayTarget(int index, const QString &target);
    Q_INVOKABLE void clearOverlays();

    Q_INVOKABLE void useHostTimezone();
    Q_INVOKABLE void useHostKeymap();

    // Files edited in the window. A path is a live-system path, or
    // "profile:" and a path in the archiso profile.
    Q_INVOKABLE QString fileContent(const QString &path) const;
    Q_INVOKABLE bool isFileEdited(const QString &path) const;
    // What the file is before any edit: the stock profile's, or this machine's.
    Q_INVOKABLE QString stockFileContent(const QString &path) const;
    // Why a path can't be edited, or empty; normalizes "~" and missing slashes.
    Q_INVOKABLE QString normalizeFilePath(const QString &path) const;
    Q_INVOKABLE QString filePathProblem(const QString &path) const;
    Q_INVOKABLE void saveFile(const QString &path, const QString &content);
    Q_INVOKABLE void removeFile(const QString &path);
    Q_INVOKABLE QString fileLanguage(const QString &path, const QString &content) const { return languageFor(path, content); }
    Q_INVOKABLE void chooseOutput();
    Q_INVOKABLE void chooseFlashIso();
    Q_INVOKABLE void installArchiso();
    Q_INVOKABLE void checkTools();

    Q_INVOKABLE void openFlash();
    Q_INVOKABLE void refreshDrives();
    // confirmation must be the drive's name (sdb): typing it is the user's
    // proof they looked at which drive is about to be erased.
    Q_INVOKABLE void flash(const QString &devicePath, const QString &confirmation);

    Q_INVOKABLE void dismissMessages();

signals:
    void configChanged();
    void desktopChanged();
    void stateChanged();
    void progressChanged();
    void messageChanged();
    void toolsChanged();
    void builtIsoChanged();
    void flashChanged();
    void logCleared();
    void logAppended(const QString &line);
    void flashFinished(bool ok);

private:
    void change(const BuildConfig &next);
    void save() const;
    void load();
    void setState(const QString &state);
    void setStage(const QString &stage, double progress);
    void setError(const QString &message);
    void setNotice(const QString &message);
    void appendOutput(const QByteArray &bytes);
    void clearLog();
    static QString logPath();
    void startPrivileged(const QString &state, const QString &scriptResource, const QStringList &arguments);
    void checkPackagesThenBuild();
    void runBuild();
    void finishBuild(int exitCode);
    void finishFlash(int exitCode);
    void finishInstall(int exitCode);
    QString runDirectory() const;
    void removeRun();
    static QString pkexecError(int exitCode);

    FilePicker *m_picker;
    QString m_configPath;
    QString m_configsDir;
    BuildConfig m_config;
    QList<BuildConfig> m_undo;
    QList<BuildConfig> m_redo;

    QString m_state = "idle";
    bool m_cancelling = false;
    bool m_quitWhenIdle = false;
    QString m_stage;
    double m_progress = 0;
    BuildProgress m_buildProgress;
    QString m_error;
    QString m_notice;
    QString m_missing;
    bool m_archisoMissing = false;

    QProcess m_process;
    QByteArray m_pendingOutput;
    QFile m_log;
    QString m_run;
    QString m_finalIso;
    QElapsedTimer m_clock;
    QTimer m_tick;

    QString m_builtIso;
    QString m_flashIso;
    qint64 m_flashIsoBytes = 0;
    QList<Drive> m_drives;
    QString m_flashDevice;

    Replica::System m_system;
    QList<Replica::HomeItem> m_homeItems;
    QHash<QString, qint64> m_homeBytes;
    bool m_desktopScanned = false;
    QProcess m_du;
};
