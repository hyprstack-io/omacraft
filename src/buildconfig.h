#pragma once

#include <QJsonObject>
#include <QList>
#include <QString>
#include <QStringList>

// A folder of the user's, copied into the live system at target ("/" merges
// it into the root, so folder/etc/issue becomes /etc/issue).
struct Overlay {
    QString source;
    QString target = "/";
    bool operator==(const Overlay &other) const = default;
};

// A file written from the editor. path is a live-system path ("/etc/motd"),
// or "profile:" and a path inside the archiso profile ("profile:pacman.conf").
struct EditedFile {
    QString path;
    QString content;
    bool operator==(const EditedFile &other) const = default;
};

// Everything the user chooses about the ISO. It's plain data so the backend
// can snapshot it for undo and save it as JSON.
struct BuildConfig {
    QString profile = "releng";
    QString isoName = "hyprbuildz";
    QString hostname = "archiso";
    QString packages;
    QList<Overlay> overlays;
    bool omarchySetup = false;
    QString outputDir;
    // Empty means the profile's own (UTC, us).
    QString timezone;
    QString keymap;
    // systemd units to enable, separated like packages.
    QString services;
    // Extra kernel command line for every boot entry.
    QString kernelParams;
    // "default", "fast" (bigger ISO, quicker build) or "small".
    QString compression = "default";
    QList<EditedFile> files;
    // "This desktop" only: which pieces of home differ from their default
    // (path relative to home → included), and whether passwords come along.
    QJsonObject homeChoices;
    bool replicaSecrets = false;

    QJsonObject toJson() const;
    static BuildConfig fromJson(const QJsonObject &json, const BuildConfig &defaults);

    bool operator==(const BuildConfig &other) const = default;
};

namespace Profile {

// The prefix of an edited file's path that puts it in the profile itself.
inline constexpr QLatin1StringView profilePrefix{"profile:"};

// Package names from the free-form text field: whitespace or newline
// separated, with # starting a comment, duplicates dropped.
QStringList parsePackages(const QString &text);

bool isValidIsoName(const QString &name);
bool isValidHostname(const QString &name);
bool isValidPackageName(const QString &name);
bool isValidTimezone(const QString &zone, const QString &zoneinfoDir = "/usr/share/zoneinfo");
bool isValidKeymap(const QString &keymap, const QString &keymapsDir = "/usr/share/kbd/keymaps");
bool isValidUnitName(const QString &unit);
bool isValidKernelParam(const QString &param);
// An overlay target or an edited file in the live system: absolute, no "..".
bool isValidLivePath(const QString &path);
// A path inside the profile ("pacman.conf", "grub/grub.cfg"), not airootfs.
bool isValidProfilePath(const QString &path);

// Unit names from the services field, with ".service" added where no type is given.
QStringList parseServices(const QString &text);

// The target a unit is enabled for: its WantedBy= on this machine, or
// multi-user.target.
QString wantedBy(const QString &unit, const QString &unitDir = "/usr/lib/systemd/system");

// What's wrong with the config, in a sentence for the window; empty when it
// can be built. configsDir is archiso's /usr/share/archiso/configs, workDir
// where the profile is put together (no folder to include may hold it).
QString validate(const BuildConfig &config, const QString &configsDir, const QString &workDir = {});

// Why a folder to include can never build: it holds workDir, is a system
// folder the ISO's packages install, or goes into /boot. Empty when it's fine.
QString overlayProblem(const Overlay &overlay, const QString &workDir);

// The archiso profile a build starts from: "This desktop" builds on releng.
QString baseProfile(const BuildConfig &config);

// The packages to put on the ISO beyond the stock profile's own.
QStringList extraPackages(const BuildConfig &config);

// Copies the stock profile into dest (which must not exist yet) and applies
// the config to the copy. The stock profile is never touched. Returns an
// error sentence, or empty on success.
QString prepare(const QString &stockProfileDir, const QString &dest, const BuildConfig &config);

// Lines appended to profiledef.sh for compression and boot options, for an
// airootfs image type ("squashfs" or "erofs").
QByteArray profiledefExtras(const BuildConfig &config, const QString &imageType);

// The airootfs_image_type a profiledef.sh sets.
QString imageType(const QString &profiledefPath);

// What an edited file starts as: the stock profile's copy, then for a live
// path this machine's, else empty.
QString stockContent(const QString &stockProfileDir, const QString &path);

// The time zone and console keymap this machine uses, or empty.
QString hostTimezone();
QString hostKeymap();

// The 32-character ISO 9660 volume label for an ISO name, e.g. HYPRBUILDZ_202610.
QString isoLabelPrefix(const QString &isoName);

// The live ISO's omarchy-setup command.
QString omarchySetupScript();

}
