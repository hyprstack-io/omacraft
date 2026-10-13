#include "buildconfig.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QProcess>
#include <QRegularExpression>
#include <QSet>

QJsonObject BuildConfig::toJson() const {
    return {
        {"profile", profile},
        {"isoName", isoName},
        {"hostname", hostname},
        {"packages", packages},
        {"overlays", [this] {
             QJsonArray list;
             for (const Overlay &overlay : overlays)
                 list.append(QJsonObject{{"source", overlay.source}, {"target", overlay.target}});
             return list;
         }()},
        {"omarchySetup", omarchySetup},
        {"outputDir", outputDir},
        {"timezone", timezone},
        {"keymap", keymap},
        {"services", services},
        {"kernelParams", kernelParams},
        {"compression", compression},
        {"files", [this] {
             QJsonArray list;
             for (const EditedFile &file : files)
                 list.append(QJsonObject{{"path", file.path}, {"content", file.content}});
             return list;
         }()},
        {"homeChoices", homeChoices},
        {"replicaSecrets", replicaSecrets},
    };
}

BuildConfig BuildConfig::fromJson(const QJsonObject &json, const BuildConfig &defaults) {
    BuildConfig config = defaults;
    config.profile = json.value("profile").toString(defaults.profile);
    config.isoName = json.value("isoName").toString(defaults.isoName);
    config.hostname = json.value("hostname").toString(defaults.hostname);
    config.packages = json.value("packages").toString(defaults.packages);
    if (json.contains("overlays")) {
        config.overlays.clear();
        for (const QJsonValue &value : json.value("overlays").toArray()) {
            const QJsonObject overlay = value.toObject();
            if (!overlay.value("source").toString().isEmpty())
                config.overlays.append({overlay.value("source").toString(), overlay.value("target").toString("/")});
        }
    } else if (const QString old = json.value("overlayDir").toString(); !old.isEmpty()) {
        // Settings from before there could be several folders.
        config.overlays = {{old, "/"}};
    }
    config.omarchySetup = json.value("omarchySetup").toBool(defaults.omarchySetup);
    config.outputDir = json.value("outputDir").toString(defaults.outputDir);
    config.timezone = json.value("timezone").toString(defaults.timezone);
    config.keymap = json.value("keymap").toString(defaults.keymap);
    config.services = json.value("services").toString(defaults.services);
    config.kernelParams = json.value("kernelParams").toString(defaults.kernelParams);
    config.compression = json.value("compression").toString(defaults.compression);
    if (config.compression != "default" && config.compression != "fast" && config.compression != "small")
        config.compression = defaults.compression;
    if (json.contains("files")) {
        config.files.clear();
        for (const QJsonValue &value : json.value("files").toArray()) {
            const QJsonObject file = value.toObject();
            if (!file.value("path").toString().isEmpty())
                config.files.append({file.value("path").toString(), file.value("content").toString()});
        }
    }
    config.homeChoices = json.value("homeChoices").toObject();
    config.replicaSecrets = json.value("replicaSecrets").toBool(defaults.replicaSecrets);
    if (config.profile != "releng" && config.profile != "baseline" && config.profile != "replica")
        config.profile = defaults.profile;
    return config;
}

namespace Profile {

QStringList parsePackages(const QString &text) {
    QStringList packages;
    QSet<QString> seen;
    for (QString line : text.split('\n')) {
        const int comment = line.indexOf('#');
        if (comment >= 0)
            line.truncate(comment);
        for (const QString &word : line.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts)) {
            if (!seen.contains(word)) {
                seen.insert(word);
                packages.append(word);
            }
        }
    }
    return packages;
}

bool isValidIsoName(const QString &name) {
    static const QRegularExpression pattern("^[a-z0-9][a-z0-9-]{0,31}$");
    return pattern.match(name).hasMatch();
}

bool isValidHostname(const QString &name) {
    static const QRegularExpression pattern("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$");
    return pattern.match(name).hasMatch();
}

// Pacman's own rule for package names.
bool isValidPackageName(const QString &name) {
    static const QRegularExpression pattern("^[a-z0-9@_+][a-z0-9@._+-]*$");
    return pattern.match(name).hasMatch();
}

bool isValidTimezone(const QString &zone, const QString &zoneinfoDir) {
    static const QRegularExpression pattern("^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*$");
    return pattern.match(zone).hasMatch() && QFileInfo(zoneinfoDir + "/" + zone).isFile();
}

bool isValidKeymap(const QString &keymap, const QString &keymapsDir) {
    static const QRegularExpression pattern("^[A-Za-z0-9_][A-Za-z0-9_.-]*$");
    if (!pattern.match(keymap).hasMatch())
        return false;
    QDirIterator it(keymapsDir, {keymap + ".map", keymap + ".map.gz", keymap + ".map.zst"}, QDir::Files,
                    QDirIterator::Subdirectories);
    return it.hasNext();
}

bool isValidUnitName(const QString &unit) {
    static const QRegularExpression pattern("^[A-Za-z0-9][A-Za-z0-9:_.@\\\\-]*$");
    return pattern.match(unit).hasMatch() && unit.size() <= 255;
}

bool isValidKernelParam(const QString &param) {
    static const QRegularExpression pattern("^[A-Za-z0-9_.,:=/+@-]+$");
    return pattern.match(param).hasMatch();
}

bool isValidLivePath(const QString &path) {
    if (!path.startsWith('/') || path.contains('\n') || path.contains(QChar(0)))
        return false;
    if (path == "/")
        return true;
    return QDir::cleanPath(path) == path && !path.split('/').contains("..");
}

bool isValidProfilePath(const QString &path) {
    if (path.isEmpty() || path.startsWith('/') || path.contains('\n') || path.contains(QChar(0)))
        return false;
    if (QDir::cleanPath(path) != path || path.split('/').contains("..") || path == ".")
        return false;
    // The live system's files go in by their own path.
    return path != "airootfs" && !path.startsWith("airootfs/");
}

QStringList parseServices(const QString &text) {
    QStringList units;
    for (QString unit : parsePackages(text)) {
        if (!unit.contains('.'))
            unit += ".service";
        if (!units.contains(unit))
            units.append(unit);
    }
    return units;
}

QString wantedBy(const QString &unit, const QString &unitDir) {
    // An instance (getty@tty2.service) is enabled from its template (getty@.service).
    QString file = unit;
    const int at = unit.indexOf('@');
    const int dot = unit.lastIndexOf('.');
    if (at >= 0 && dot > at)
        file = unit.left(at + 1) + unit.mid(dot);
    QFile source(unitDir + "/" + file);
    if (source.open(QIODevice::ReadOnly)) {
        bool install = false;
        for (const QString &raw : QString::fromUtf8(source.readAll()).split('\n')) {
            const QString line = raw.trimmed();
            if (line.startsWith('['))
                install = line == "[Install]";
            else if (install && line.startsWith("WantedBy=")) {
                const QString target = line.mid(9).split(' ', Qt::SkipEmptyParts).value(0);
                if (isValidUnitName(target))
                    return target;
            }
        }
    }
    return "multi-user.target";
}

QString hostTimezone() {
    const QString target = QFileInfo("/etc/localtime").symLinkTarget();
    const int at = target.indexOf("zoneinfo/");
    return at < 0 ? QString() : target.mid(at + 9);
}

QString hostKeymap() {
    QFile file("/etc/vconsole.conf");
    if (!file.open(QIODevice::ReadOnly))
        return {};
    for (const QString &line : QString::fromUtf8(file.readAll()).split('\n')) {
        if (line.startsWith("KEYMAP="))
            return line.mid(7).trimmed().remove('"');
    }
    return {};
}

QString baseProfile(const BuildConfig &config) {
    return config.profile == "replica" ? "releng" : config.profile;
}

QString validate(const BuildConfig &config, const QString &configsDir) {
    const QString base = baseProfile(config);
    if (!QFileInfo(configsDir + "/" + base + "/profiledef.sh").isFile())
        return QString("archiso's %1 profile isn't in %2. Install archiso first.").arg(base, configsDir);
    if (!isValidIsoName(config.isoName))
        return "The ISO name needs lowercase letters, digits, and dashes, up to 32 characters.";
    if (!isValidHostname(config.hostname))
        return "The hostname needs letters, digits, and dashes, up to 63 characters, not starting or ending with a dash.";
    for (const QString &package : parsePackages(config.packages)) {
        if (!isValidPackageName(package))
            return QString("“%1” isn't a valid package name.").arg(package);
    }
    for (const Overlay &overlay : config.overlays) {
        if (!QFileInfo(overlay.source).isDir())
            return QString("The folder to include, %1, doesn't exist.").arg(overlay.source);
        if (!isValidLivePath(overlay.target))
            return QString("Where %1 goes, “%2”, needs to be a full path like /etc or /root, without “..”.")
                .arg(QFileInfo(overlay.source).fileName(), overlay.target);
    }
    if (!config.timezone.isEmpty() && !isValidTimezone(config.timezone))
        return QString("“%1” isn't a time zone. Use a name like Europe/London or America/New_York.").arg(config.timezone);
    if (!config.keymap.isEmpty() && !isValidKeymap(config.keymap))
        return QString("“%1” isn't a console keyboard layout. Try us, uk, de, or fr.").arg(config.keymap);
    for (const QString &unit : parseServices(config.services)) {
        if (!isValidUnitName(unit))
            return QString("“%1” isn't a valid systemd unit name.").arg(unit);
    }
    for (const QString &param : parsePackages(config.kernelParams)) {
        if (!isValidKernelParam(param))
            return QString("The boot option “%1” has characters a kernel command line can't take.").arg(param);
    }
    for (const EditedFile &file : config.files) {
        const bool inProfile = file.path.startsWith(profilePrefix);
        if (inProfile ? !isValidProfilePath(file.path.mid(profilePrefix.size())) : !isValidLivePath(file.path) || file.path == "/")
            return QString("“%1” isn't a file path the ISO can hold.").arg(file.path);
    }
    const QFileInfo output(config.outputDir);
    if (config.outputDir.isEmpty() || !output.isDir())
        return "Choose a folder to save the ISO in.";
    if (!output.isWritable())
        return QString("You can't write to %1. Choose another folder for the ISO.").arg(config.outputDir);
    return {};
}

QStringList extraPackages(const BuildConfig &config) {
    QStringList packages = parsePackages(config.packages);
    // The minimal profile has no installer, and omarchy-setup drives archinstall.
    // A copy of this desktop already is Omarchy, so it doesn't get the setup.
    if (config.omarchySetup && config.profile != "replica" && !packages.contains("archinstall"))
        packages.append("archinstall");
    return packages;
}

QString isoLabelPrefix(const QString &isoName) {
    // The label is NAME_YYYYMM and ISO 9660 allows 32 characters, so the
    // name part gets 25. Dashes become underscores, as Arch's ARCH_ does.
    return isoName.toUpper().replace('-', '_').left(25);
}

namespace {

bool writeFile(const QString &path, const QByteArray &contents, QIODevice::OpenMode mode = QIODevice::WriteOnly) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    if (!file.open(mode))
        return false;
    return file.write(contents) == contents.size();
}

QByteArray shellQuote(const QString &value) {
    QString quoted = value;
    quoted.replace('\'', "'\\''");
    return ("'" + quoted + "'").toUtf8();
}

// cp -a keeps symlinks (the profile's /etc/localtime is one) and modes.
// --remove-destination replaces a symlink in the profile rather than writing
// through it to wherever it points on this machine.
QString copyTree(const QString &from, const QString &to) {
    QProcess cp;
    cp.setProcessChannelMode(QProcess::MergedChannels);
    cp.start("cp", {"-a", "--no-preserve=ownership", "--remove-destination", "--", from + "/.", to});
    if (!cp.waitForFinished(-1) || cp.exitStatus() != QProcess::NormalExit || cp.exitCode() != 0)
        return QString("Couldn't copy %1: %2").arg(from, QString::fromUtf8(cp.readAll()).trimmed());
    return {};
}

// Whether path, once its folders exist, lies inside root. A symlinked folder
// in the profile (they point at the live system's paths) would otherwise
// steer a write onto this machine.
bool insideTree(const QString &root, const QString &path) {
    const QString canonicalRoot = QFileInfo(root).canonicalFilePath();
    const QString parent = QFileInfo(QFileInfo(path).absolutePath()).canonicalFilePath();
    return !canonicalRoot.isEmpty() && (parent == canonicalRoot || parent.startsWith(canonicalRoot + "/"));
}

// Puts a file at path under root, replacing a symlink there instead of
// following it.
bool placeFile(const QString &root, const QString &path, const QByteArray &contents) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    if (!insideTree(root, path))
        return false;
    if (QFileInfo(path).isSymLink())
        QFile::remove(path);
    return writeFile(path, contents);
}

bool placeLink(const QString &root, const QString &path, const QString &target) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    if (!insideTree(root, path))
        return false;
    if (QFileInfo(path).isSymLink() || QFileInfo::exists(path))
        QFile::remove(path);
    return QFile::link(target, path);
}

bool isText(const QByteArray &bytes) {
    return !bytes.contains('\0') && !QString::fromUtf8(bytes).contains(QChar::ReplacementCharacter);
}

}

QString imageType(const QString &profiledefPath) {
    QFile file(profiledefPath);
    if (!file.open(QIODevice::ReadOnly))
        return "squashfs";
    // profiledef.sh is sourced, so the last assignment wins.
    QString type = "squashfs";
    static const QRegularExpression assignment("^\\s*airootfs_image_type=[\"']?([a-z0-9+]+)");
    for (const QString &line : QString::fromUtf8(file.readAll()).split('\n')) {
        if (const auto match = assignment.match(line); match.hasMatch())
            type = match.captured(1);
    }
    return type;
}

QByteArray profiledefExtras(const BuildConfig &config, const QString &imageType) {
    QByteArray lines;
    const bool erofs = imageType == "erofs";
    if (config.compression == "fast") {
        lines += erofs ? "airootfs_image_tool_options=('-zlz4hc,12' -E 'ztailpacking')\n"
                       : "airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')\n";
    } else if (config.compression == "small") {
        lines += erofs ? "airootfs_image_tool_options=('-zlzma,109' -E 'ztailpacking')\n"
                       : "airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')\n";
    }
    const QStringList params = parsePackages(config.kernelParams);
    if (!params.isEmpty())
        lines += "kernel_params_x86_64=" + shellQuote(params.join(' ')) + "\n";
    return lines;
}

QString stockContent(const QString &stockProfileDir, const QString &path) {
    QStringList candidates;
    if (path.startsWith(profilePrefix)) {
        candidates << stockProfileDir + "/" + path.mid(profilePrefix.size());
    } else {
        candidates << stockProfileDir + "/airootfs" + path << path;
    }
    for (const QString &candidate : candidates) {
        const QFileInfo info(candidate);
        if (!info.isFile() || info.size() > 512 * 1024)
            continue;
        QFile file(candidate);
        if (!file.open(QIODevice::ReadOnly))
            continue;
        const QByteArray bytes = file.readAll();
        if (isText(bytes))
            return QString::fromUtf8(bytes);
    }
    return {};
}

QString prepare(const QString &stockProfileDir, const QString &dest, const BuildConfig &config) {
    if (QFileInfo::exists(dest))
        return QString("%1 already exists.").arg(dest);
    if (!QDir().mkpath(dest))
        return QString("Couldn't create %1.").arg(dest);
    if (const QString error = copyTree(stockProfileDir, dest); !error.isEmpty())
        return error;

    const QString airootfs = dest + "/airootfs";
    QDir().mkpath(airootfs);
    QByteArray permissions;

    // Profile files from the editor replace the stock ones first, so what
    // hyprbuildz adds below (packages, profiledef lines) still applies.
    for (const EditedFile &file : config.files) {
        if (!file.path.startsWith(profilePrefix))
            continue;
        if (!placeFile(dest, dest + "/" + file.path.mid(profilePrefix.size()), file.content.toUtf8()))
            return QString("Couldn't write %1 into the profile.").arg(file.path.mid(profilePrefix.size()));
    }

    for (const Overlay &overlay : config.overlays) {
        const QString target = overlay.target == "/" ? airootfs : airootfs + overlay.target;
        QDir().mkpath(target);
        if (!insideTree(airootfs, target + "/x"))
            return QString("%1 would land outside the live system.").arg(overlay.target);
        if (const QString error = copyTree(overlay.source, target); !error.isEmpty())
            return error;

        // mkarchiso copies airootfs without its modes, so anything executable
        // in the user's folders has to be listed in file_permissions to stay so.
        QDirIterator it(overlay.source, QDir::Files | QDir::Hidden | QDir::NoSymLinks, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QFileInfo file(it.next());
            if (file.permission(QFileDevice::ExeOwner)) {
                const QString inIso = QDir::cleanPath(overlay.target + "/" + QDir(overlay.source).relativeFilePath(file.filePath()));
                permissions += "file_permissions[" + shellQuote(inIso) + "]=\"0:0:755\"\n";
            }
        }
    }

    // Files from the editor win over the folders; a script stays runnable.
    for (const EditedFile &file : config.files) {
        if (file.path.startsWith(profilePrefix))
            continue;
        if (!placeFile(airootfs, airootfs + file.path, file.content.toUtf8()))
            return QString("Couldn't write %1 into the profile.").arg(file.path);
        if (file.content.startsWith("#!"))
            permissions += "file_permissions[" + shellQuote(file.path) + "]=\"0:0:755\"\n";
    }

    // The settings above the editor win over it, as they're what the window shows.
    if (!placeFile(airootfs, airootfs + "/etc/hostname", config.hostname.toUtf8() + "\n"))
        return "Couldn't write the hostname into the profile.";

    if (!config.timezone.isEmpty() && !placeLink(airootfs, airootfs + "/etc/localtime", "/usr/share/zoneinfo/" + config.timezone))
        return "Couldn't set the time zone in the profile.";

    if (!config.keymap.isEmpty()) {
        QByteArray vconsole;
        QFile existing(airootfs + "/etc/vconsole.conf");
        if (!QFileInfo(existing.fileName()).isSymLink() && existing.open(QIODevice::ReadOnly)) {
            for (const QByteArray &line : existing.readAll().split('\n')) {
                if (!line.isEmpty() && !line.startsWith("KEYMAP="))
                    vconsole += line + "\n";
            }
            existing.close();
        }
        vconsole += "KEYMAP=" + config.keymap.toUtf8() + "\n";
        if (!placeFile(airootfs, airootfs + "/etc/vconsole.conf", vconsole))
            return "Couldn't set the keyboard layout in the profile.";
    }

    // What systemctl enable would do: a link in the target's .wants folder.
    for (const QString &unit : parseServices(config.services)) {
        QString file = unit;
        const int at = unit.indexOf('@');
        const int dot = unit.lastIndexOf('.');
        if (at >= 0 && dot > at)
            file = unit.left(at + 1) + unit.mid(dot);
        const QString link = QString("%1/etc/systemd/system/%2.wants/%3").arg(airootfs, wantedBy(unit), unit);
        if (!placeLink(airootfs, link, "/usr/lib/systemd/system/" + file))
            return QString("Couldn't enable %1 in the profile.").arg(unit);
    }

    if (config.omarchySetup) {
        if (!writeFile(airootfs + "/usr/local/bin/omarchy-setup", omarchySetupScript().toUtf8()))
            return "Couldn't add omarchy-setup to the profile.";
        permissions += "file_permissions[\"/usr/local/bin/omarchy-setup\"]=\"0:0:755\"\n";
        const QByteArray motd = "\nTo install Arch and then Omarchy, run: \x1b[1momarchy-setup\x1b[0m\n\n";
        if (!writeFile(airootfs + "/etc/motd", motd, QIODevice::Append))
            return "Couldn't add the omarchy-setup hint to the profile's motd.";
    }

    const QStringList packages = extraPackages(config);
    if (!packages.isEmpty()) {
        QFile list(dest + "/packages.x86_64");
        if (!list.open(QIODevice::ReadOnly))
            return "The profile has no packages.x86_64.";
        const QSet<QString> existing = [&] {
            const QStringList names = parsePackages(QString::fromUtf8(list.readAll()));
            return QSet<QString>(names.begin(), names.end());
        }();
        list.close();
        QByteArray added = "\n# Added by hyprbuildz.\n";
        for (const QString &package : packages) {
            if (!existing.contains(package))
                added += package.toUtf8() + "\n";
        }
        if (!writeFile(dest + "/packages.x86_64", added, QIODevice::Append))
            return "Couldn't add packages to the profile.";
    }

    // profiledef.sh is sourced by mkarchiso, so later assignments win.
    const QByteArray label = isoLabelPrefix(config.isoName).toUtf8();
    QByteArray profiledef = "\n# Added by hyprbuildz.\n"
                            "iso_name=" + shellQuote(config.isoName) + "\n"
                            "iso_label=\"" + label + "_$(date --date=\"@${SOURCE_DATE_EPOCH:-$(date +%s)}\" +%Y%m)\"\n";
    profiledef += profiledefExtras(config, imageType(dest + "/profiledef.sh"));
    profiledef += permissions;
    if (!writeFile(dest + "/profiledef.sh", profiledef, QIODevice::Append))
        return "Couldn't update the profile's profiledef.sh.";

    return {};
}

QString omarchySetupScript() {
    return R"(#!/usr/bin/env bash
# Added by hyprbuildz. Installs Arch with archinstall, then arranges for the
# Omarchy installer to run the first time the new user logs in, because
# Omarchy installs as a regular user on a booted system, not from the live ISO.
set -euo pipefail

target=/mnt

if [[ ${1:-} != --after-install ]]; then
  archinstall
fi

if ! mountpoint -q "$target"; then
  echo "The new system isn't mounted at $target."
  echo "Mount its root partition there, then run: omarchy-setup --after-install"
  exit 1
fi

user=$(awk -F: '$3 >= 1000 && $3 < 60000 { print $1; exit }' "$target/etc/passwd")
if [[ -z $user ]]; then
  echo "The new system has no regular user, and Omarchy installs as one (with sudo)."
  echo "Create one, then run: omarchy-setup --after-install"
  exit 1
fi

arch-chroot "$target" /bin/bash -s -- "$user" <<'CHROOT'
set -euo pipefail
user=$1
home=$(getent passwd "$user" | cut -d: -f6)
touch "$home/.omarchy-first-login"
cat >> "$home/.bash_profile" <<'PROFILE'

# Added by hyprbuildz: runs the Omarchy installer once, on the first login.
if [[ -f ~/.omarchy-first-login ]]; then
  rm -f ~/.omarchy-first-login
  curl -fsSL https://omarchy.org/install | bash
fi
PROFILE
chown "$user:" "$home/.omarchy-first-login" "$home/.bash_profile"
CHROOT

echo
echo "Done. Reboot, log in as $user on the console with a network connection,"
echo "and the Omarchy installer starts."
)";
}

}
