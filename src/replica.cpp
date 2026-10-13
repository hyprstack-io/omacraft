#include "replica.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QRegularExpression>
#include <QSet>
#include <grp.h>
#include <pwd.h>
#include <unistd.h>

#include "buildconfig.h"

namespace Replica {

namespace {

QStringList run(const QString &program, const QStringList &arguments, int *exitCode = nullptr) {
    QProcess process;
    process.start(program, arguments);
    process.waitForFinished(30000);
    if (exitCode)
        *exitCode = process.exitStatus() == QProcess::NormalExit ? process.exitCode() : -1;
    return QString::fromUtf8(process.readAllStandardOutput()).split('\n', Qt::SkipEmptyParts);
}

QByteArray shellQuote(const QString &value) {
    QString quoted = value;
    quoted.replace('\'', "'\\''");
    return ("'" + quoted + "'").toUtf8();
}

bool writeFile(const QString &path, const QByteArray &contents) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    return file.open(QIODevice::WriteOnly) && file.write(contents) == contents.size();
}

// cp -a, because some of what's copied from releng is a symlink.
bool copyPath(const QString &from, const QString &to) {
    QDir().mkpath(QFileInfo(to).absolutePath());
    return QProcess::execute("cp", {"-a", "--no-preserve=ownership", "--", from, to}) == 0;
}

// Each of these, as a whole top-level entry of home.
const QSet<QString> secretTop{
    ".ssh", ".gnupg", ".password-store", ".pki", ".mozilla", ".claude", ".claude.json", ".codex", ".gemini",
    ".copilot", ".aws", ".azure", ".kube", ".docker", ".gh", ".netrc", ".git-credentials", ".npmrc", ".pypirc",
    ".vault-token", ".lesshst", ".wget-hsts", ".Xauthority", ".ICEauthority", ".thunderbird", ".config/Claude",
};
const QSet<QString> cacheTop{
    ".cache", ".cargo", ".rustup", ".npm", ".pnpm-store", ".bun", ".deno", ".dotnet", ".nuget", ".gradle", ".m2",
    ".vscode", ".vscode-shared", ".vscode-oss", ".cursor", ".var", ".local/share/Trash", ".local/share/mise",
    ".local/share/uv", ".local/share/Steam", ".local/share/flatpak", ".local/share/containers",
    ".local/share/docker", ".local/share/virtualenvs", ".local/share/pnpm", ".local/share/go",
    ".local/share/JetBrains", ".local/share/baloo", ".local/share/gvfs-metadata", ".local/share/nvim",
    ".zcompdump",
};
// Browsers, editors with sign-ins, chat apps, password managers, and tokens.
const QSet<QString> secretConfig{
    "chromium", "google-chrome", "google-chrome-beta", "google-chrome-unstable", "BraveSoftware", "mozilla",
    "vivaldi", "opera", "microsoft-edge", "Code", "Code - OSS", "VSCodium", "Cursor", "Claude", "discord",
    "Slack", "Signal", "Element", "teams-for-linux", "1Password", "Bitwarden", "KeePassXC", "gh", "hub",
    "rclone", "op", "Postman", "Mullvad VPN", "obsidian", "spotify", "github-copilot", "zoomus.conf",
};
const QSet<QString> secretShare{"keyrings", "TelegramDesktop", "recently-used.xbel", "password-store", "pki"};

}

System readSystem() {
    System system;
    const passwd *user = getpwuid(getuid());
    if (!user) {
        system.error = "Couldn't read your user account.";
        return system;
    }
    system.user = QString::fromLocal8Bit(user->pw_name);
    system.uid = user->pw_uid;
    system.gid = user->pw_gid;
    system.home = QString::fromLocal8Bit(user->pw_dir);
    system.shell = QString::fromLocal8Bit(user->pw_shell);

    int count = 64;
    QList<gid_t> gids(count);
    if (getgrouplist(user->pw_name, user->pw_gid, gids.data(), &count) < 0) {
        gids.resize(count);
        getgrouplist(user->pw_name, user->pw_gid, gids.data(), &count);
    }
    for (int i = 0; i < count; ++i) {
        if (const group *g = getgrgid(gids[i]))
            system.groups.append(QString::fromLocal8Bit(g->gr_name));
    }

    // The kernel is whichever package owns a vmlinuz; Omarchy ships its own.
    for (const QFileInfo &module : QDir("/usr/lib/modules").entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        if (!QFileInfo::exists(module.filePath() + "/vmlinuz"))
            continue;
        const QStringList owner = run("pacman", {"-Qoq", module.filePath() + "/vmlinuz"});
        if (!owner.isEmpty()) {
            system.kernel = owner.first();
            break;
        }
    }
    if (system.kernel.isEmpty()) {
        system.error = "Couldn't tell which kernel package this system boots.";
        return system;
    }

    int status = 0;
    system.native = run("pacman", {"-Qqen"}, &status);
    if (status != 0) {
        system.error = "pacman couldn't list the installed packages.";
        return system;
    }
    // Debug symbol packages are build leftovers, not part of the desktop.
    for (const QString &package : run("pacman", {"-Qqm"})) {
        if (!package.endsWith("-debug"))
            system.foreign.append(package);
    }
    system.native.removeIf([](const QString &package) { return package.endsWith("-debug"); });
    return system;
}

Kind classify(const QString &path, bool isDir) {
    const QString name = path.section('/', -1);
    if (secretTop.contains(path) || name.contains("history") || name == "lesshst")
        return Kind::Secret;
    if (cacheTop.contains(path))
        return Kind::Cache;
    if (path.startsWith(".config/") && secretConfig.contains(name))
        return Kind::Secret;
    if (path.startsWith(".local/share/") && secretShare.contains(name))
        return Kind::Secret;
    if (!path.startsWith('.'))
        return Kind::Personal;
    Q_UNUSED(isDir);
    return Kind::Settings;
}

QList<HomeItem> classifyHome(const QString &home) {
    QList<HomeItem> items;
    // These are opened up one level; everything else is one item.
    const QStringList expanded{".config", ".local/share", ".local/state"};
    const auto add = [&](const QString &relative, bool isDir) {
        items.append({relative, classify(relative, isDir)});
    };

    const QDir::Filters filters = QDir::AllEntries | QDir::Hidden | QDir::System | QDir::NoDotAndDotDot;
    for (const QFileInfo &entry : QDir(home).entryInfoList(filters, QDir::Name | QDir::IgnoreCase)) {
        const QString name = entry.fileName();
        if (name == ".local") {
            for (const QFileInfo &child : QDir(entry.filePath()).entryInfoList(filters, QDir::Name | QDir::IgnoreCase)) {
                const QString relative = ".local/" + child.fileName();
                if (!expanded.contains(relative)) {
                    add(relative, child.isDir());
                    continue;
                }
                for (const QFileInfo &grandchild : QDir(child.filePath()).entryInfoList(filters, QDir::Name | QDir::IgnoreCase))
                    add(relative + "/" + grandchild.fileName(), grandchild.isDir());
            }
        } else if (name == ".config" && entry.isDir() && !entry.isSymLink()) {
            for (const QFileInfo &child : QDir(entry.filePath()).entryInfoList(filters, QDir::Name | QDir::IgnoreCase))
                add(".config/" + child.fileName(), child.isDir());
        } else {
            add(name, entry.isDir());
        }
    }
    return items;
}

bool included(const HomeItem &item, const QJsonObject &choices) {
    return choices.contains(item.path) ? choices.value(item.path).toBool() : item.on();
}

QStringList cacheNames() {
    return {"Cache", "Code Cache", "GPUCache", "CachedData", "CacheStorage", "ShaderCache", "GrShaderCache",
            "GraphiteDawnCache", "DawnCache", "DawnGraphiteCache", "DawnWebGPUCache", "Service Worker",
            "blob_storage", "Crashpad", "component_crx_cache", "extensions_crx_cache", "__pycache__",
            "node_modules", ".Trash-*", "Singleton*"};
}

QStringList etcExcludes(bool secrets) {
    QStringList excludes{
        // Users and groups: the live system makes its own, so the package-made
        // system accounts keep the ids their files were installed with.
        "^/etc/(passwd|shadow|group|gshadow|subuid|subgid)-?$",
        "^/etc/\\.pwd\\.lock$",
        // The machine's identity and disks.
        "^/etc/(fstab|crypttab|machine-id|hostname|adjtime|resolv\\.conf|mtab|\\.updated)$",
        // archiso builds its own initramfs; the host's hooks wouldn't boot it.
        "^/etc/mkinitcpio",
        // The boot loader and snapshots belong to the installed disk.
        "(limine|snapper|snap-pac|grub\\.d|default/grub|/etc/kernel/)",
        "cryptsetup",
        // Generated from packages, so the ISO regenerates its own.
        "^/etc/pacman\\.d/gnupg/",
        "^/etc/ld\\.so\\.cache$",
        "^/etc/ca-certificates/extracted/",
        "^/etc/ssl/certs/",
        "^/etc/udev/hwdb\\.bin$",
        "^/etc/xml/catalog$",
        // Backups and editor leftovers, which can hold the very files above
        // (an fstab with the disk's UUIDs, a half-written gshadow).
        "\\.(pacnew|pacsave|bak|back|old|orig|swp)$",
        "~$",
        "/\\.#",
        "^/etc/fstab",
        "shadow",
    };
    if (!secrets) {
        excludes += {
            "^/etc/NetworkManager/system-connections/",
            "^/etc/iwd/",
            "^/etc/wpa_supplicant/",
            "^/etc/ssh/ssh_host_",
            "^/etc/wireguard/",
            "^/etc/docker/key\\.json$",
            "^/etc/ssl/private/",
            "\\.key$",
        };
    }
    return excludes;
}

QStringList essentialPackages(const QString &kernel) {
    return {"base", kernel, "mkinitcpio", "mkinitcpio-archiso", "syslinux", "sudo"};
}

QString rewriteBootConfig(const QString &text, const QString &kernel) {
    QString result = text;
    static const QRegularExpression vmlinuz("vmlinuz-linux(?![\\w-])");
    static const QRegularExpression initramfs("initramfs-linux(?=\\.img)");
    result.replace(vmlinuz, "vmlinuz-" + kernel);
    result.replace(initramfs, "initramfs-" + kernel);
    // A live session writes to RAM; archiso's default 256 MB fills up as soon
    // as a desktop's apps start caching, so allow half of memory.
    if (!result.contains("cow_spacesize="))
        result.replace("archisobasedir=%INSTALL_DIR%", "archisobasedir=%INSTALL_DIR% cow_spacesize=50%");
    return result;
}

QString prepare(const QString &relengDir, const QString &dest, const BuildConfig &config,
                const System &system, const QString &hostPacmanConf) {
    if (!system.error.isEmpty())
        return system.error;
    if (QFileInfo::exists(dest))
        return QString("%1 already exists.").arg(dest);
    QDir().mkpath(dest);

    // releng's boot loaders and profiledef; its live-installer extras
    // (networkd, iwd, mirror picking, the speech and memtest entries) don't
    // belong in a copy of a desktop.
    for (const QString &part : {"profiledef.sh", "syslinux", "efiboot", "grub", "bootstrap_packages"}) {
        if (QFileInfo::exists(relengDir + "/" + part) && !copyPath(relengDir + "/" + part, dest + "/" + part))
            return QString("Couldn't copy %1 from archiso's profile.").arg(part);
    }
    for (const QFileInfo &entry : QDir(dest + "/efiboot/loader/entries").entryInfoList(QDir::Files)) {
        if (entry.fileName().contains("speech") || entry.fileName().contains("memtest"))
            QFile::remove(entry.filePath());
    }

    const QString airootfs = dest + "/airootfs";
    for (const QString &keep : {"etc/mkinitcpio.conf.d/archiso.conf", "etc/systemd/journald.conf.d/volatile-storage.conf",
                                "etc/systemd/system/pacman-init.service", "etc/systemd/system/etc-pacman.d-gnupg.mount",
                                "etc/systemd/system/multi-user.target.wants/pacman-init.service"}) {
        const QString from = relengDir + "/airootfs/" + keep;
        if (QFileInfo(from).exists() || QFileInfo(from).isSymLink())
            copyPath(from, airootfs + "/" + keep);
    }
    if (!writeFile(airootfs + "/etc/hostname", config.hostname.toUtf8() + "\n"))
        return "Couldn't write the hostname into the profile.";
    if (!writeFile(airootfs + "/root/customize_airootfs.sh", customizeScript().toUtf8()))
        return "Couldn't write the replica's setup script.";

    // Boot entries point at this system's kernel.
    for (const QString &folder : {"efiboot", "syslinux", "grub"}) {
        QDirIterator it(dest + "/" + folder, {"*.conf", "*.cfg"}, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString path = it.next();
            QFile file(path);
            if (!file.open(QIODevice::ReadOnly))
                continue;
            const QString text = QString::fromUtf8(file.readAll());
            file.close();
            if (!writeFile(path, rewriteBootConfig(text, system.kernel).toUtf8()))
                return QString("Couldn't update %1.").arg(path);
        }
    }

    // Packages: archiso's essentials, everything installed on purpose, the
    // repackaged foreign ones, and anything extra the user listed.
    QStringList packages = essentialPackages(system.kernel) + system.native + system.foreign + Profile::parsePackages(config.packages);
    packages.removeDuplicates();
    if (!writeFile(dest + "/packages.x86_64", "# Written by hyprbuildz from " + system.user.toUtf8() + "'s system.\n"
                                              + packages.join('\n').toUtf8() + "\n"))
        return "Couldn't write the package list.";

    // The host's repositories, so Omarchy's own packages resolve, plus a local
    // one the build fills with the repackaged foreign packages.
    QFile hostConf(hostPacmanConf);
    if (!hostConf.open(QIODevice::ReadOnly))
        return QString("Couldn't read %1.").arg(hostPacmanConf);
    QByteArray pacmanConf = hostConf.readAll();
    if (!system.foreign.isEmpty())
        pacmanConf += "\n# Added by hyprbuildz: this system's AUR packages, repackaged.\n"
                      "[hyprbuildz-local]\nSigLevel = Optional TrustAll\nServer = file://@LOCALREPO@\n";
    if (!writeFile(dest + "/pacman.conf", pacmanConf))
        return "Couldn't write the profile's pacman.conf.";

    // What build.sh collects as root before mkarchiso runs.
    const QString data = dest + "/hyprbuildz";
    QByteArray homePaths;
    const QString homeRelative = system.home.mid(1);
    for (const HomeItem &item : classifyHome(system.home)) {
        if (included(item, config.homeChoices))
            homePaths += (homeRelative + "/" + item.path).toUtf8() + "\n";
    }
    QByteArray env = "user=" + shellQuote(system.user) + "\n"
                     "uid=" + QByteArray::number(system.uid) + "\n"
                     "gid=" + QByteArray::number(system.gid) + "\n"
                     "user_shell=" + shellQuote(system.shell) + "\n"
                     "user_groups=" + shellQuote(system.groups.join(' ')) + "\n";
    if (!writeFile(data + "/home-paths", homePaths)
        || !writeFile(data + "/home-excludes", cacheNames().join('\n').toUtf8() + "\n")
        || !writeFile(data + "/etc-excludes", etcExcludes(config.replicaSecrets).join('\n').toUtf8() + "\n")
        || !writeFile(data + "/foreign", system.foreign.join('\n').toUtf8() + (system.foreign.isEmpty() ? "" : "\n"))
        || !writeFile(data + "/secrets", config.replicaSecrets ? "1\n" : "0\n")
        || !writeFile(data + "/user.env", env))
        return "Couldn't write the replica's lists.";

    const QByteArray label = Profile::isoLabelPrefix(config.isoName).toUtf8();
    QByteArray profiledef = "\n# Added by hyprbuildz.\n"
                            "iso_name=" + shellQuote(config.isoName) + "\n"
                            "iso_label=\"" + label + "_$(date --date=\"@${SOURCE_DATE_EPOCH:-$(date +%s)}\" +%Y%m)\"\n"
                            "iso_application=" + shellQuote(system.user + "'s desktop, live") + "\n"
                            // zstd: a desktop is several gigabytes, and xz takes an hour on it.
                            "airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')\n"
                            "file_permissions=(\n  [\"/root\"]=\"0:0:750\"\n  [\"/root/customize_airootfs.sh\"]=\"0:0:755\"\n)\n";
    // Compression and boot options from the window; set after the zstd above, so they win.
    profiledef += Profile::profiledefExtras(config, "squashfs");
    QFile def(dest + "/profiledef.sh");
    if (!def.open(QIODevice::Append) || def.write(profiledef) != profiledef.size())
        return "Couldn't update the profile's profiledef.sh.";
    return {};
}

QString customizeScript() {
    return R"SCRIPT(#!/usr/bin/env bash
# Added by hyprbuildz. Runs inside the ISO's root once its packages are in:
# unpacks the system's settings, makes the user, and unpacks their home.
set -euo pipefail

stage=/root/hyprbuildz
source "$stage/user.env"

echo "hyprbuildz: Unpacking the system settings"
tar -xpf "$stage/etc.tar" -C /
[[ -f $stage/usrlocal.tar ]] && tar -xpf "$stage/usrlocal.tar" -C /

echo "hyprbuildz: Creating $user"
getent group "$gid" >/dev/null || groupadd -g "$gid" "$user"
extra=()
for group in $user_groups; do
  [[ $group == "$(getent group "$gid" | cut -d: -f1)" ]] && continue
  if getent group "$group" >/dev/null; then
    extra+=("$group")
  else
    echo "hyprbuildz: There's no $group group on the ISO, so $user isn't in it."
  fi
done
if [[ ! -x $user_shell ]]; then
  echo "hyprbuildz: $user_shell isn't on the ISO; $user gets bash."
  user_shell=/bin/bash
fi
if (( ${#extra[@]} )); then
  useradd -u "$uid" -g "$gid" -G "$(IFS=,; echo "${extra[*]}")" -s "$user_shell" -d "/home/$user" -M "$user"
else
  useradd -u "$uid" -g "$gid" -s "$user_shell" -d "/home/$user" -M "$user"
fi
install -d -o "$uid" -g "$gid" -m 0700 "/home/$user"

echo "hyprbuildz: Unpacking $user's home"
tar -xpf "$stage/home.tar" -C /
# Folders tar made on the way to a chosen one (.config, .local/share) are
# root's; everything in the home belongs to the user.
chown -hR "$uid:$gid" "/home/$user"

if [[ -n ${password_hash:-} ]]; then
  usermod -p "$password_hash" "$user"
else
  # No password came along, so sudo can't ask for one. Like any live ISO's
  # user, this one is trusted.
  passwd -d "$user" >/dev/null
  echo "$user ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-hyprbuildz-live
  chmod 0440 /etc/sudoers.d/99-hyprbuildz-live
fi

# Boot straight into the desktop, as the host does.
if pacman -Q sddm >/dev/null 2>&1; then
  session=$(grep -rhs '^Session=' /etc/sddm.conf.d /etc/sddm.conf | tail -n 1 | cut -d= -f2-)
  if [[ -z $session ]]; then
    for candidate in omarchy.desktop hyprland-uwsm.desktop hyprland.desktop; do
      if [[ -f /usr/local/share/wayland-sessions/$candidate || -f /usr/share/wayland-sessions/$candidate ]]; then
        session=$candidate
        break
      fi
    done
  fi
  mkdir -p /etc/sddm.conf.d
  printf '[Autologin]\nUser=%s\nSession=%s\n' "$user" "$session" > /etc/sddm.conf.d/zz-hyprbuildz-live.conf
  [[ -e /etc/systemd/system/display-manager.service ]] || systemctl enable sddm.service
fi
systemctl set-default graphical.target

if [[ -e /etc/systemd/system/multi-user.target.wants/systemd-resolved.service ]]; then
  ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
fi
[[ -f /etc/locale.gen ]] && locale-gen

rm -rf "$stage"
echo "hyprbuildz: $user's desktop is in place"
)SCRIPT";
}

}
