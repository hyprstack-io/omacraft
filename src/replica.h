#pragma once

#include <QJsonObject>
#include <QList>
#include <QString>
#include <QStringList>

struct BuildConfig;

// The "This desktop" profile: a live ISO that boots into a copy of the desktop
// it was built on. The packages, the system's changed settings, the user, and
// the chosen parts of their home all come along.
namespace Replica {

// What a top-level piece of the home folder is, which decides whether it
// comes along unless the user says otherwise.
enum class Kind {
    Settings,   // Desktop and app configuration: on.
    Secret,     // Sign-ins, keys, browser profiles, shell history: off.
    Cache,      // Caches, trash, toolchains that reinstall themselves: off.
    Personal,   // Documents, Pictures, projects: off.
};

struct HomeItem {
    QString path;  // Relative to home, e.g. ".config/hypr".
    Kind kind = Kind::Settings;
    bool on() const { return kind == Kind::Settings; }
};

// The machine the ISO replicates.
struct System {
    QString user;
    uint uid = 0;
    uint gid = 0;
    QString home;
    QString shell;
    QStringList groups;
    QString kernel;          // The kernel package, e.g. linux-omarchy.
    QStringList native;      // Explicitly installed, from the sync repos.
    QStringList foreign;     // Not in any repo (AUR), so repackaged at build.
    QString error;           // Why it can't be replicated; empty when it can.
};

// Reads the running system: the user, their kernel, their packages.
System readSystem();

// The pieces of home, one level into .config, .local/share, and .local/state
// so settings and secrets that sit side by side can be told apart.
QList<HomeItem> classifyHome(const QString &home);
Kind classify(const QString &relativePath, bool isDir);

// Whether an item comes along, given the user's overrides.
bool included(const HomeItem &item, const QJsonObject &choices);

// File and folder names left out wherever they appear in home: browsers and
// Electron apps keep hundreds of megabytes of cache inside their settings.
QStringList cacheNames();

// Extended regular expressions for /etc paths that never come along: the
// machine's identity, disks, boot loader, and the users and groups (the live
// system makes its own). With secrets false, Wi-Fi passwords and keys too.
QStringList etcExcludes(bool secrets);

// Packages every replica needs for archiso to boot it.
QStringList essentialPackages(const QString &kernel);

// Writes the replica profile into dest from archiso's releng profile.
// hostPacmanConf is /etc/pacman.conf, so the ISO uses the same repos
// (Omarchy's included). Returns an error sentence, or empty on success.
QString prepare(const QString &relengDir, const QString &dest, const BuildConfig &config,
                const System &system, const QString &hostPacmanConf = "/etc/pacman.conf");

// Boot entries name the kernel's files after its package and get room for a
// whole desktop's worth of changes in the live session.
QString rewriteBootConfig(const QString &text, const QString &kernel);

// Runs in the ISO's chroot after the packages are in: makes the user and
// unpacks what the build collected.
QString customizeScript();

}
