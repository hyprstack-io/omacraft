#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QProcess>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

#include "isobuilder.h"
#include "buildconfig.h"
#include "drives.h"
#include "filepicker.h"
#include "replica.h"
#include "syntaxhighlighter.h"
#include "theme.h"

// Stands in for the portal so tests can answer the picker themselves.
class FakePicker : public FilePicker {
    Q_OBJECT

public:
    QString lastPurpose;
    void chooseFolder(const QString &purpose, const QString &, const QString &) override { lastPurpose = purpose; }
    void chooseIso(const QString &) override {}
};

namespace {

void write(const QString &path, const QByteArray &contents, QFileDevice::Permissions permissions = {}) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(contents);
    file.close();
    if (permissions)
        file.setPermissions(permissions);
}

QByteArray read(const QString &path) {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}

// A stand-in for /usr/share/archiso/configs with a releng-shaped profile.
void makeConfigs(const QString &configs) {
    const QString releng = configs + "/releng";
    write(releng + "/profiledef.sh",
          "#!/usr/bin/env bash\n"
          "iso_name=\"archlinux\"\n"
          "iso_label=\"ARCH_202610\"\n"
          "file_permissions=(\n  [\"/etc/shadow\"]=\"0:0:400\"\n)\n");
    write(releng + "/packages.x86_64", "base\nlinux\n# a comment\narchinstall\n");
    write(releng + "/airootfs/etc/hostname", "archiso\n");
    write(releng + "/airootfs/etc/motd", "Welcome.\n");
    QFile::link("/usr/share/zoneinfo/UTC", releng + "/airootfs/etc/localtime");
}

// Sources the prepared profiledef.sh the way mkarchiso does and prints what it set.
QString sourceProfiledef(const QString &profile, const QString &expression) {
    QProcess bash;
    bash.start("bash", {"-c", "declare -A file_permissions; source \"$1\"; " + expression, "bash", profile + "/profiledef.sh"});
    bash.waitForFinished();
    return QString::fromUtf8(bash.readAllStandardOutput()).trimmed();
}

}

class IsoTests : public QObject {
    Q_OBJECT

private slots:
    void parsesPackages()
    {
        QCOMPARE(Profile::parsePackages("git  neovim\nbtop # monitor\n# all comment\ngit\n\n"),
                 QStringList({"git", "neovim", "btop"}));
        QVERIFY(Profile::parsePackages("  \n# nothing\n").isEmpty());
    }

    void validatesNames()
    {
        QVERIFY(Profile::isValidIsoName("hyprbuildz"));
        QVERIFY(Profile::isValidIsoName("my-arch-2"));
        QVERIFY(!Profile::isValidIsoName("My ISO"));
        QVERIFY(!Profile::isValidIsoName("-dash"));
        QVERIFY(!Profile::isValidIsoName(QString(33, 'a')));

        QVERIFY(Profile::isValidHostname("archiso"));
        QVERIFY(Profile::isValidHostname("Box-1"));
        QVERIFY(!Profile::isValidHostname("trailing-"));
        QVERIFY(!Profile::isValidHostname("has space"));

        QVERIFY(Profile::isValidPackageName("lib32-mesa"));
        QVERIFY(Profile::isValidPackageName("gtk+3"));
        QVERIFY(!Profile::isValidPackageName("Bad"));
        QVERIFY(!Profile::isValidPackageName("--needed"));
    }

    void validatesConfig()
    {
        QTemporaryDir dir;
        makeConfigs(dir.path() + "/configs");
        QDir().mkpath(dir.path() + "/out");

        BuildConfig config;
        config.outputDir = dir.path() + "/out";
        QCOMPARE(Profile::validate(config, dir.path() + "/configs"), QString());

        BuildConfig badPackage = config;
        badPackage.packages = "git $(rm)";
        QVERIFY(Profile::validate(badPackage, dir.path() + "/configs").contains("$(rm)"));

        BuildConfig noArchiso = config;
        QVERIFY(Profile::validate(noArchiso, dir.path() + "/missing").contains("Install archiso"));

        BuildConfig noOverlay = config;
        noOverlay.overlays = {{dir.path() + "/nope", "/"}};
        QVERIFY(Profile::validate(noOverlay, dir.path() + "/configs").contains("doesn't exist"));

        // A folder holding the work folder would be copied into itself.
        QDir().mkpath(dir.path() + "/home/.cache/hyprbuildz");
        BuildConfig wholeHome = config;
        wholeHome.overlays = {{dir.path() + "/home", "/home/me"}};
        QVERIFY(Profile::validate(wholeHome, dir.path() + "/configs", dir.path() + "/home/.cache/hyprbuildz")
                    .contains("into itself"));
        QCOMPARE(Profile::validate(wholeHome, dir.path() + "/configs", dir.path() + "/elsewhere"), QString());

        BuildConfig systemEtc = config;
        systemEtc.overlays = {{"/etc", "/etc"}};
        QVERIFY(Profile::validate(systemEtc, dir.path() + "/configs").contains("pacman won't install over it"));

        BuildConfig intoBoot = config;
        intoBoot.overlays = {{dir.path() + "/out", "/boot"}};
        QVERIFY(Profile::validate(intoBoot, dir.path() + "/configs").contains("/boot"));

        // This desktop ignores the folders, so they can't stop its build.
        BuildConfig replica = systemEtc;
        replica.profile = "replica";
        QCOMPARE(Profile::validate(replica, dir.path() + "/configs"), QString());

        BuildConfig noOutput = config;
        noOutput.outputDir = dir.path() + "/nope";
        QVERIFY(!Profile::validate(noOutput, dir.path() + "/configs").isEmpty());
    }

    void omarchyNeedsArchinstall()
    {
        BuildConfig config;
        config.packages = "git";
        QCOMPARE(Profile::extraPackages(config), QStringList({"git"}));
        config.omarchySetup = true;
        QCOMPARE(Profile::extraPackages(config), QStringList({"git", "archinstall"}));
    }

    void labelsFitIso9660()
    {
        QCOMPARE(Profile::isoLabelPrefix("my-arch"), QString("MY_ARCH"));
        // NAME_YYYYMM must fit in 32 characters.
        QVERIFY(Profile::isoLabelPrefix(QString(32, 'a')).size() + 7 <= 32);
    }

    void preparesProfileWithoutTouchingStock()
    {
        QTemporaryDir dir;
        const QString configs = dir.path() + "/configs";
        makeConfigs(configs);
        const QByteArray stockDef = read(configs + "/releng/profiledef.sh");
        const QByteArray stockPackages = read(configs + "/releng/packages.x86_64");

        const QString overlay = dir.path() + "/overlay";
        write(overlay + "/etc/issue", "Hello\n");
        write(overlay + "/usr/local/bin/hello", "#!/bin/sh\necho hi\n",
              QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);

        BuildConfig config;
        config.isoName = "my-arch";
        config.hostname = "forge";
        config.packages = "git archinstall\nneovim";
        config.overlays = {{overlay, "/"}};
        config.omarchySetup = true;

        const QString profile = dir.path() + "/run/profile";
        QCOMPARE(Profile::prepare(configs + "/releng", profile, config), QString());

        // The stock profile is untouched.
        QCOMPARE(read(configs + "/releng/profiledef.sh"), stockDef);
        QCOMPARE(read(configs + "/releng/packages.x86_64"), stockPackages);

        // Symlinks stay symlinks, and the user's files are merged in.
        QCOMPARE(QFileInfo(profile + "/airootfs/etc/localtime").symLinkTarget(), QString("/usr/share/zoneinfo/UTC"));
        QCOMPARE(read(profile + "/airootfs/etc/issue"), QByteArray("Hello\n"));
        QCOMPARE(read(profile + "/airootfs/etc/hostname"), QByteArray("forge\n"));

        // archinstall was already there, so only the new packages are added.
        const QStringList packages = Profile::parsePackages(QString::fromUtf8(read(profile + "/packages.x86_64")));
        QCOMPARE(packages, QStringList({"base", "linux", "archinstall", "git", "neovim"}));

        // Omarchy setup is on the ISO, executable, and announced.
        QVERIFY(read(profile + "/airootfs/usr/local/bin/omarchy-setup").startsWith("#!/usr/bin/env bash"));
        QVERIFY(read(profile + "/airootfs/etc/motd").startsWith("Welcome.\n"));
        QVERIFY(read(profile + "/airootfs/etc/motd").contains("omarchy-setup"));

        // profiledef.sh still sources, with the new name, label, and modes.
        QCOMPARE(sourceProfiledef(profile, "echo $iso_name"), QString("my-arch"));
        QVERIFY(sourceProfiledef(profile, "echo $iso_label").startsWith("MY_ARCH_20"));
        QCOMPARE(sourceProfiledef(profile, "echo ${file_permissions[/etc/shadow]}"), QString("0:0:400"));
        QCOMPARE(sourceProfiledef(profile, "echo ${file_permissions[/usr/local/bin/hello]}"), QString("0:0:755"));
        QCOMPARE(sourceProfiledef(profile, "echo ${file_permissions[/usr/local/bin/omarchy-setup]}"), QString("0:0:755"));
        QCOMPARE(sourceProfiledef(profile, "echo ${#file_permissions[@]}"), QString("3"));

        // Preparing over an existing directory is refused.
        QVERIFY(!Profile::prepare(configs + "/releng", profile, config).isEmpty());
    }

    void omarchySetupScriptParses()
    {
        QProcess bash;
        bash.start("bash", {"-n"});
        bash.write(Profile::omarchySetupScript().toUtf8());
        bash.closeWriteChannel();
        bash.waitForFinished();
        QCOMPARE(bash.exitCode(), 0);
    }

    void rootScriptsParse()
    {
        for (const QString &script : {QFINDTESTDATA("../src/build.sh"), QFINDTESTDATA("../src/flash.sh")}) {
            QVERIFY(!script.isEmpty());
            QProcess sh;
            sh.start("sh", {"-n", script});
            sh.waitForFinished();
            QVERIFY2(sh.exitCode() == 0, qPrintable(script + ": " + sh.readAllStandardError()));
        }
    }

    void listsOnlyRemovableDrives()
    {
        const QByteArray json = R"({"blockdevices": [
          {"name": "/dev/nvme0n1", "size": 512110190592, "model": "Samsung SSD", "tran": "nvme", "rm": false,
           "hotplug": false, "type": "disk", "ro": false, "mountpoints": [null],
           "children": [{"name": "/dev/nvme0n1p2", "type": "part", "mountpoints": ["/"]}]},
          {"name": "/dev/sdb", "size": 32010928128, "model": "SanDisk Ultra ", "tran": "usb", "rm": true,
           "hotplug": true, "type": "disk", "ro": false, "mountpoints": [null],
           "children": [{"name": "/dev/sdb1", "type": "part", "mountpoints": ["/run/media/me/STICK"]}]},
          {"name": "/dev/sdc", "size": 2000365289472, "model": "WD Passport", "tran": "usb", "rm": false,
           "hotplug": true, "type": "disk", "ro": false, "mountpoints": [],
           "children": [{"name": "/dev/sdc1", "type": "part", "mountpoints": ["/home"]}]},
          {"name": "/dev/sdd", "size": 0, "model": "Card Reader", "tran": "usb", "rm": true,
           "hotplug": true, "type": "disk", "ro": false, "mountpoints": [null]},
          {"name": "/dev/sde", "size": 1000000000, "model": "Tiny", "tran": "usb", "rm": "1",
           "hotplug": "1", "type": "disk", "ro": "0", "mountpoints": [null]},
          {"name": "/dev/sr0", "size": 1073741312, "model": "DVD", "tran": "sata", "rm": true,
           "hotplug": true, "type": "rom", "ro": false, "mountpoints": [null]}
        ]})";

        const QList<Drive> drives = Drives::parse(json, "/home/me/Downloads/arch.iso", 1200000000);
        QCOMPARE(drives.size(), 4);

        QCOMPARE(drives[0].path, QString("/dev/sdb"));
        QCOMPARE(drives[0].name, QString("sdb"));
        QCOMPARE(drives[0].model, QString("SanDisk Ultra"));
        QCOMPARE(drives[0].mountpoints, QStringList({"/run/media/me/STICK"}));
        QCOMPARE(drives[0].blocker, QString());

        QVERIFY(drives[1].blocker.contains("/home"));
        QVERIFY(drives[2].blocker.contains("No media"));
        QVERIFY(drives[3].blocker.contains("Too small"));
    }

    void blocksTheDriveHoldingTheIso()
    {
        const QByteArray json = R"({"blockdevices": [
          {"name": "/dev/sdb", "size": 32010928128, "model": "Stick", "tran": "usb", "rm": true,
           "hotplug": true, "type": "disk", "ro": false, "mountpoints": [null],
           "children": [{"name": "/dev/sdb1", "type": "part", "mountpoints": ["/run/media/me/STICK"]}]}
        ]})";
        QVERIFY(Drives::parse(json, "/run/media/me/STICK/arch.iso", 1).first().blocker.contains("ISO is on"));
        QVERIFY(Drives::parse(json, "/run/media/me/STICKY/arch.iso", 1).first().blocker.isEmpty());
    }

    void readsDdProgress()
    {
        QCOMPARE(Drives::parseDdProgress("1203765248 bytes (1.2 GB, 1.1 GiB) copied, 42 s, 28.7 MB/s"), 1203765248LL);
        QCOMPARE(Drives::parseDdProgress("300+0 records in"), -1LL);
        QCOMPARE(Drives::formatSize(32010928128), QString("32.0 GB"));
    }

    void followsMkarchisoStages()
    {
        QString stage;
        double progress = 0;
        QVERIFY(IsoBuilder::stageForLine("[mkarchiso] INFO: Creating SquashFS image, this may take some time...", &stage, &progress));
        QVERIFY(stage.contains("Compressing"));
        QCOMPARE(progress, .60);
        QVERIFY(!IsoBuilder::stageForLine("downloading linux-6.17.tar.zst", &stage, &progress));
    }

    void neverClobbersAnIso()
    {
        QTemporaryDir dir;
        QCOMPARE(IsoBuilder::uniqueIsoPath(dir.path(), "arch", "2026.10.11"), dir.path() + "/arch-2026.10.11-x86_64.iso");
        write(dir.path() + "/arch-2026.10.11-x86_64.iso", "x");
        write(dir.path() + "/arch-2026.10.11-x86_64-2.iso.part", "x");
        QCOMPARE(IsoBuilder::uniqueIsoPath(dir.path(), "arch", "2026.10.11"), dir.path() + "/arch-2026.10.11-x86_64-3.iso");
    }

    void undoesAndRedoesAndSaves()
    {
        QTemporaryDir dir;
        FakePicker picker;
        const QString configPath = dir.path() + "/config/config.json";
        {
            IsoBuilder backend(&picker, configPath, dir.path() + "/configs");
            QVERIFY(!backend.canUndo());
            backend.setHostname("one");
            backend.setHostname("two");
            backend.setOmarchySetup(true);
            QVERIFY(backend.canUndo());

            backend.undo();
            QCOMPARE(backend.omarchySetup(), false);
            backend.undo();
            QCOMPARE(backend.hostname(), QString("one"));
            QVERIFY(backend.canRedo());
            backend.redo();
            QCOMPARE(backend.hostname(), QString("two"));

            // A new change drops the redo history.
            backend.setProfile("baseline");
            QVERIFY(!backend.canRedo());

            // Setting the same value isn't a change.
            QSignalSpy spy(&backend, &IsoBuilder::configChanged);
            backend.setProfile("baseline");
            backend.setProfile("nonsense");
            QCOMPARE(spy.count(), 0);
        }

        // Saved atomically, and read back by the next run.
        QVERIFY(!QFileInfo::exists(configPath + ".tmp"));
        IsoBuilder again(&picker, configPath, dir.path() + "/configs");
        QCOMPARE(again.hostname(), QString("two"));
        QCOMPARE(again.profile(), QString("baseline"));
        QVERIFY(!again.canUndo());
    }

    void picksFoldersThroughThePicker()
    {
        QTemporaryDir dir;
        FakePicker picker;
        IsoBuilder backend(&picker, dir.path() + "/config.json", dir.path() + "/configs");
        backend.chooseOutput();
        QCOMPARE(picker.lastPurpose, QString("output"));
        emit picker.folderSelected("output", QUrl::fromLocalFile(dir.path()));
        QCOMPARE(backend.outputDir(), dir.path());
        emit picker.folderSelected("overlay", QUrl::fromLocalFile("/tmp"));
        emit picker.folderSelected("overlay", QUrl::fromLocalFile("/srv"));
        emit picker.folderSelected("overlay", QUrl::fromLocalFile("/tmp"));
        QCOMPARE(backend.config().overlays.size(), 2);
        QCOMPARE(backend.overlays().at(1).toMap().value("source").toString(), QString("/srv"));
        backend.setOverlayTarget(1, "usr/share/stuff/");
        QCOMPARE(backend.config().overlays.at(1).target, QString("/usr/share/stuff"));
        backend.removeOverlay(0);
        QCOMPARE(backend.config().overlays.first().source, QString("/srv"));
    }

    void reportsMissingArchiso()
    {
        QTemporaryDir dir;
        FakePicker picker;
        IsoBuilder backend(&picker, dir.path() + "/config.json", dir.path() + "/no-configs");
        QVERIFY(backend.archisoMissing());
        QVERIFY(backend.missing().contains("archiso"));
        backend.build();
        QVERIFY(backend.error().contains("archiso"));
        QVERIFY(!backend.busy());
    }

    void classifiesHome()
    {
        using Replica::Kind;
        QCOMPARE(Replica::classify(".config/hypr", true), Kind::Settings);
        QCOMPARE(Replica::classify(".zshrc", false), Kind::Settings);
        QCOMPARE(Replica::classify(".ssh", true), Kind::Secret);
        QCOMPARE(Replica::classify(".zsh_history", false), Kind::Secret);
        QCOMPARE(Replica::classify(".local/state/lesshst", false), Kind::Secret);
        QCOMPARE(Replica::classify(".config/chromium", true), Kind::Secret);
        QCOMPARE(Replica::classify(".local/share/keyrings", true), Kind::Secret);
        QCOMPARE(Replica::classify(".cache", true), Kind::Cache);
        QCOMPARE(Replica::classify(".local/share/Trash", true), Kind::Cache);
        QCOMPARE(Replica::classify("Documents", true), Kind::Personal);

        QTemporaryDir home;
        write(home.path() + "/.config/hypr/hyprland.conf", "x");
        write(home.path() + "/.config/chromium/Default/Cookies", "x");
        write(home.path() + "/.local/share/omarchy/x", "x");
        write(home.path() + "/.local/bin/tool", "x");
        write(home.path() + "/.zshrc", "x");
        write(home.path() + "/Pictures/a.png", "x");
        QStringList paths;
        for (const auto &item : Replica::classifyHome(home.path()))
            paths << item.path;
        QCOMPARE(paths, QStringList({".config/chromium", ".config/hypr", ".local/bin", ".local/share/omarchy", ".zshrc", "Pictures"}));

        const Replica::HomeItem pictures{"Pictures", Kind::Personal};
        QVERIFY(!Replica::included(pictures, {}));
        QVERIFY(Replica::included(pictures, {{"Pictures", true}}));
    }

    void keepsMachineFilesOutOfEtc()
    {
        const auto excluded = [](const QString &path, bool secrets) {
            for (const QString &pattern : Replica::etcExcludes(secrets))
                if (QRegularExpression(pattern).match(path).hasMatch())
                    return true;
            return false;
        };
        for (const QString &path : {"/etc/shadow", "/etc/passwd", "/etc/fstab", "/etc/fstab.20260918.back",
                                    "/etc/.#gshadow123", "/etc/machine-id", "/etc/mkinitcpio.conf",
                                    "/etc/mkinitcpio.conf.d/omarchy.conf", "/etc/default/limine",
                                    "/etc/systemd/system/multi-user.target.wants/limine-snapper-sync.service",
                                    "/etc/pacman.conf.bak", "/etc/ufw/after.rules~", "/etc/pacman.d/gnupg/pubring.gpg"})
            QVERIFY2(excluded(path, true), qPrintable(path));
        for (const QString &path : {"/etc/sddm.conf.d/autologin.conf", "/etc/pacman.conf", "/etc/sudoers.d/omarchy",
                                    "/etc/systemd/system/display-manager.service", "/etc/vconsole.conf"})
            QVERIFY2(!excluded(path, false), qPrintable(path));
        QVERIFY(excluded("/etc/NetworkManager/system-connections/Home.nmconnection", false));
        QVERIFY(!excluded("/etc/NetworkManager/system-connections/Home.nmconnection", true));
        QVERIFY(excluded("/etc/ssh/ssh_host_ed25519_key", false));
    }

    void pointsBootAtTheKernel()
    {
        const QString entry = "linux /arch/boot/x86_64/vmlinuz-linux\ninitrd /arch/boot/x86_64/initramfs-linux.img\n"
                              "options archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID%\n";
        const QString result = Replica::rewriteBootConfig(entry, "linux-omarchy");
        QVERIFY(result.contains("vmlinuz-linux-omarchy\n"));
        QVERIFY(result.contains("initramfs-linux-omarchy.img"));
        QVERIFY(result.contains("archisobasedir=%INSTALL_DIR% cow_spacesize=50%"));
        // Rewriting twice changes nothing more.
        QCOMPARE(Replica::rewriteBootConfig(result, "linux-omarchy"), result);
    }

    void preparesReplicaProfile()
    {
        QTemporaryDir dir;
        const QString releng = dir.path() + "/releng";
        write(releng + "/profiledef.sh", "iso_name=\"archlinux\"\nfile_permissions=(\n  [\"/root/.automated_script.sh\"]=\"0:0:755\"\n)\n");
        write(releng + "/packages.x86_64", "base\nlinux\niwd\n");
        write(releng + "/efiboot/loader/entries/01-archiso-linux.conf", "linux /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux\noptions archisobasedir=%INSTALL_DIR%\n");
        write(releng + "/efiboot/loader/entries/02-archiso-speech-linux.conf", "x");
        write(releng + "/efiboot/loader/entries/03-archiso-memtest86+x64.conf", "x");
        write(releng + "/syslinux/archiso_sys-linux.cfg", "LINUX /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux\nINITRD /%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img\n");
        write(releng + "/airootfs/etc/mkinitcpio.conf.d/archiso.conf", "HOOKS=(base archiso)\n");
        write(releng + "/airootfs/etc/systemd/system/pacman-init.service", "[Unit]\n");
        QDir().mkpath(releng + "/airootfs/etc/systemd/system/multi-user.target.wants");
        QFile::link("../pacman-init.service", releng + "/airootfs/etc/systemd/system/multi-user.target.wants/pacman-init.service");
        write(releng + "/airootfs/etc/systemd/system/multi-user.target.wants/iwd.service", "x");
        write(releng + "/airootfs/root/.automated_script.sh", "x");
        write(dir.path() + "/pacman.conf", "[options]\n[core]\nInclude = /etc/pacman.d/mirrorlist\n[omarchy]\nServer = https://pkgs.omarchy.org/$arch\n");

        const QString home = dir.path() + "/home/me";
        write(home + "/.config/hypr/hyprland.conf", "x");
        write(home + "/.ssh/id_ed25519", "x");
        write(home + "/Wallpapers/a.png", "x");

        Replica::System system;
        system.user = "me";
        system.uid = 1000;
        system.gid = 1000;
        system.home = home;
        system.shell = "/bin/zsh";
        system.groups = {"me", "wheel", "docker"};
        system.kernel = "linux-omarchy";
        system.native = {"hyprland", "omarchy", "linux-omarchy"};
        system.foreign = {"paru"};

        BuildConfig config;
        config.profile = "replica";
        config.isoName = "my-desktop";
        config.hostname = "forge";
        config.packages = "htop";
        config.homeChoices = {{"Wallpapers", true}};

        const QString profile = dir.path() + "/run/profile";
        QCOMPARE(Replica::prepare(releng, profile, config, system, dir.path() + "/pacman.conf"), QString());

        // Packages: essentials first, then the system's, then the extras, once each.
        QCOMPARE(Profile::parsePackages(QString::fromUtf8(read(profile + "/packages.x86_64"))),
                 QStringList({"base", "linux-omarchy", "mkinitcpio", "mkinitcpio-archiso", "syslinux", "sudo",
                              "hyprland", "omarchy", "paru", "htop"}));

        // The host's repos, plus the local one for the repackaged AUR packages.
        const QByteArray pacmanConf = read(profile + "/pacman.conf");
        QVERIFY(pacmanConf.contains("[omarchy]"));
        QVERIFY(pacmanConf.contains("[hyprbuildz-local]\nSigLevel = Optional TrustAll\nServer = file://@LOCALREPO@"));

        // Boot entries use the kernel; the speech and memtest entries are gone.
        QVERIFY(read(profile + "/efiboot/loader/entries/01-archiso-linux.conf").contains("vmlinuz-linux-omarchy"));
        QVERIFY(!QFileInfo::exists(profile + "/efiboot/loader/entries/02-archiso-speech-linux.conf"));
        QVERIFY(!QFileInfo::exists(profile + "/efiboot/loader/entries/03-archiso-memtest86+x64.conf"));
        QVERIFY(read(profile + "/syslinux/archiso_sys-linux.cfg").contains("initramfs-linux-omarchy.img"));

        // Only what the live system needs from releng's airootfs.
        QVERIFY(QFileInfo::exists(profile + "/airootfs/etc/mkinitcpio.conf.d/archiso.conf"));
        QVERIFY(QFileInfo(profile + "/airootfs/etc/systemd/system/multi-user.target.wants/pacman-init.service").isSymLink());
        QVERIFY(!QFileInfo::exists(profile + "/airootfs/etc/systemd/system/multi-user.target.wants/iwd.service"));
        QVERIFY(!QFileInfo::exists(profile + "/airootfs/root/.automated_script.sh"));
        QCOMPARE(read(profile + "/airootfs/etc/hostname"), QByteArray("forge\n"));
        QVERIFY(read(profile + "/airootfs/root/customize_airootfs.sh").startsWith("#!/usr/bin/env bash"));

        // What the root script collects: settings and the chosen folder, not keys.
        const QString homeRelative = home.mid(1);
        QCOMPARE(QString::fromUtf8(read(profile + "/hyprbuildz/home-paths")).split('\n', Qt::SkipEmptyParts),
                 QStringList({homeRelative + "/.config/hypr", homeRelative + "/Wallpapers"}));
        QCOMPARE(read(profile + "/hyprbuildz/foreign"), QByteArray("paru\n"));
        QCOMPARE(read(profile + "/hyprbuildz/secrets"), QByteArray("0\n"));
        QVERIFY(read(profile + "/hyprbuildz/etc-excludes").contains("system-connections"));

        // user.env and profiledef.sh source cleanly.
        QProcess bash;
        bash.start("bash", {"-c", "source \"$1\"; echo \"$user $uid $gid $user_shell $user_groups\"", "bash",
                            profile + "/hyprbuildz/user.env"});
        bash.waitForFinished();
        QCOMPARE(QString::fromUtf8(bash.readAllStandardOutput()).trimmed(), QString("me 1000 1000 /bin/zsh me wheel docker"));
        QCOMPARE(sourceProfiledef(profile, "echo $iso_name"), QString("my-desktop"));
        QCOMPARE(sourceProfiledef(profile, "echo ${airootfs_image_tool_options[1]}"), QString("zstd"));
        QCOMPARE(sourceProfiledef(profile, "echo ${#file_permissions[@]}"), QString("2"));
    }

    void replicaWithoutForeignPackagesHasNoLocalRepo()
    {
        QTemporaryDir dir;
        write(dir.path() + "/releng/profiledef.sh", "iso_name=x\n");
        write(dir.path() + "/pacman.conf", "[core]\n");
        QDir().mkpath(dir.path() + "/home");
        Replica::System system;
        system.user = "me";
        system.home = dir.path() + "/home";
        system.kernel = "linux";
        BuildConfig config;
        config.profile = "replica";
        QCOMPARE(Replica::prepare(dir.path() + "/releng", dir.path() + "/profile", config, system, dir.path() + "/pacman.conf"), QString());
        QVERIFY(!read(dir.path() + "/profile/pacman.conf").contains("hyprbuildz-local"));

        system.error = "No kernel.";
        QCOMPARE(Replica::prepare(dir.path() + "/releng", dir.path() + "/profile2", config, system), QString("No kernel."));
    }

    void customizeScriptParses()
    {
        QProcess bash;
        bash.start("bash", {"-n"});
        bash.write(Replica::customizeScript().toUtf8());
        bash.closeWriteChannel();
        bash.waitForFinished();
        QCOMPARE(bash.exitCode(), 0);
    }

    void appliesNewOptions()
    {
        QTemporaryDir dir;
        const QString configs = dir.path() + "/configs";
        makeConfigs(configs);
        // A stock symlink a careless write would follow out of the profile.
        const QString outside = dir.path() + "/outside.conf";
        write(outside, "untouched\n");
        QFile::link(outside, configs + "/releng/airootfs/etc/resolv.conf");

        const QString wallpapers = dir.path() + "/wallpapers";
        write(wallpapers + "/sunset.png", "png");
        write(wallpapers + "/bin/rotate", "#!/bin/sh\n", QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
        const QString dotfiles = dir.path() + "/dotfiles";
        write(dotfiles + "/.zshrc", "from the folder\n");

        BuildConfig config;
        config.isoName = "options";
        config.overlays = {{wallpapers, "/usr/share/backgrounds/mine"}, {dotfiles, "/root"}};
        config.timezone = "Europe/London";
        config.keymap = "uk";
        config.services = "sshd getty@tty2 systemd-networkd.socket";
        config.kernelParams = "copytoram  nomodeset";
        config.compression = "fast";
        config.files = {{"/root/.zshrc", "from the editor\n"},
                        {"/etc/resolv.conf", "nameserver 1.1.1.1\n"},
                        {"/usr/local/bin/welcome", "#!/bin/bash\necho hi\n"},
                        {"profile:pacman.conf", "[options]\nParallelDownloads = 9\n"}};
        QCOMPARE(Profile::validate(config, configs), QString("Choose a folder to save the ISO in."));

        const QString profile = dir.path() + "/run/profile";
        QCOMPARE(Profile::prepare(configs + "/releng", profile, config), QString());
        const QString root = profile + "/airootfs";

        // Folders land at their targets.
        QCOMPARE(read(root + "/usr/share/backgrounds/mine/sunset.png"), QByteArray("png"));
        QCOMPARE(sourceProfiledef(profile, "echo ${file_permissions[/usr/share/backgrounds/mine/bin/rotate]}"), QString("0:0:755"));
        // The editor wins over a folder, and replaces a symlink instead of writing through it.
        QCOMPARE(read(root + "/root/.zshrc"), QByteArray("from the editor\n"));
        QVERIFY(!QFileInfo(root + "/etc/resolv.conf").isSymLink());
        QCOMPARE(read(root + "/etc/resolv.conf"), QByteArray("nameserver 1.1.1.1\n"));
        QCOMPARE(read(outside), QByteArray("untouched\n"));
        QCOMPARE(sourceProfiledef(profile, "echo ${file_permissions[/usr/local/bin/welcome]}"), QString("0:0:755"));
        QCOMPARE(read(profile + "/pacman.conf"), QByteArray("[options]\nParallelDownloads = 9\n"));
        // The stock profile keeps its link.
        QVERIFY(QFileInfo(configs + "/releng/airootfs/etc/resolv.conf").isSymLink());

        QCOMPARE(QFileInfo(root + "/etc/localtime").symLinkTarget(), QString("/usr/share/zoneinfo/Europe/London"));
        QVERIFY(read(root + "/etc/vconsole.conf").contains("KEYMAP=uk\n"));
        QCOMPARE(QFileInfo(root + "/etc/systemd/system/multi-user.target.wants/sshd.service").symLinkTarget(),
                 QString("/usr/lib/systemd/system/sshd.service"));
        QVERIFY(QFileInfo(root + "/etc/systemd/system/getty.target.wants/getty@tty2.service").isSymLink()
                || QFileInfo(root + "/etc/systemd/system/multi-user.target.wants/getty@tty2.service").isSymLink());
        QCOMPARE(QFileInfo(root + "/etc/systemd/system/sockets.target.wants/systemd-networkd.socket").symLinkTarget(),
                 QString("/usr/lib/systemd/system/systemd-networkd.socket"));

        QCOMPARE(sourceProfiledef(profile, "echo $kernel_params_x86_64"), QString("copytoram nomodeset"));
        QCOMPARE(sourceProfiledef(profile, "echo ${airootfs_image_tool_options[1]}"), QString("lz4"));
    }

    void validatesNewOptions()
    {
        QVERIFY(Profile::isValidTimezone("America/New_York"));
        QVERIFY(!Profile::isValidTimezone("Mars/Olympus"));
        QVERIFY(!Profile::isValidTimezone("../etc/passwd"));
        QVERIFY(Profile::isValidKeymap("us"));
        QVERIFY(!Profile::isValidKeymap("no-such-layout"));
        QVERIFY(Profile::isValidUnitName("getty@tty2.service"));
        QVERIFY(!Profile::isValidUnitName("-rf"));
        QVERIFY(Profile::isValidKernelParam("video=1920x1080"));
        QVERIFY(!Profile::isValidKernelParam("a;reboot"));
        QVERIFY(Profile::isValidLivePath("/etc/motd"));
        QVERIFY(!Profile::isValidLivePath("/etc/../root"));
        QVERIFY(!Profile::isValidLivePath("etc/motd"));
        QVERIFY(Profile::isValidProfilePath("grub/grub.cfg"));
        QVERIFY(!Profile::isValidProfilePath("../escape"));
        QVERIFY(!Profile::isValidProfilePath("airootfs/etc/motd"));
        QCOMPARE(Profile::parseServices("sshd sshd.service fstrim.timer"), QStringList({"sshd.service", "fstrim.timer"}));
        QCOMPARE(Profile::wantedBy("nothing-like-this.service"), QString("multi-user.target"));

        QCOMPARE(Profile::profiledefExtras(BuildConfig(), "squashfs"), QByteArray());
        BuildConfig small;
        small.compression = "small";
        QVERIFY(Profile::profiledefExtras(small, "erofs").contains("-zlzma"));
        QVERIFY(Profile::profiledefExtras(small, "squashfs").contains("'xz'"));
    }

    void migratesTheOldFolder()
    {
        const BuildConfig config = BuildConfig::fromJson(QJsonObject{{"overlayDir", "/srv/files"}}, BuildConfig());
        QCOMPARE(config.overlays.size(), 1);
        QCOMPARE(config.overlays.first().source, QString("/srv/files"));
        QCOMPARE(config.overlays.first().target, QString("/"));

        BuildConfig full;
        full.overlays = {{"/a", "/"}, {"/b", "/root"}};
        full.files = {{"/etc/motd", "hi\n"}};
        full.timezone = "UTC";
        full.compression = "small";
        full.kernelParams = "copytoram";
        QVERIFY(BuildConfig::fromJson(full.toJson(), BuildConfig()) == full);
    }

    void followsProgressWithinStages()
    {
        IsoBuilder::BuildProgress state;
        QString stage;
        double progress = 0;
        bool quiet = false;
        QVERIFY(!IsoBuilder::refineProgress("Packages (4) a b c d", &state, &stage, &progress, &quiet));
        QCOMPARE(state.packages, 4);
        QVERIFY(IsoBuilder::refineProgress(" linux-6.17-1-x86_64 downloading...", &state, &stage, &progress, &quiet));
        QCOMPARE(stage, QString("Downloading packages (1 of 4)"));
        QVERIFY(qFuzzyCompare(progress, .05 + .15 / 4));
        QVERIFY(IsoBuilder::refineProgress("(2/4) installing glibc", &state, &stage, &progress, &quiet));
        QCOMPARE(progress, .35);
        QVERIFY(!quiet);
        QVERIFY(IsoBuilder::refineProgress("[=========/          ] 5000/10000  50%", &state, &stage, &progress, &quiet));
        QVERIFY(quiet);
        QCOMPARE(progress, .75);
        QVERIFY(!IsoBuilder::refineProgress("==> Some other line", &state, &stage, &progress, &quiet));

        // With VerbosePkgLists, pacman heads a table with "Package (N)" instead.
        state = {};
        QVERIFY(!IsoBuilder::refineProgress("Package (218)   New Version  Net Change  Download Size", &state, &stage, &progress, &quiet));
        QCOMPARE(state.packages, 218);
    }

    void coloursSyntax()
    {
        using Span = SyntaxHighlighter::Span;
        QCOMPARE(SyntaxHighlighter::spans("shell", "echo \"$HOME\" # hi"),
                 QList<Span>({{5, 1, "string"}, {6, 5, "variable"}, {11, 1, "string"}, {13, 4, "comment"}}));
        QCOMPARE(SyntaxHighlighter::spans("shell", "if [ -n \'$x\' ]; then"),
                 QList<Span>({{0, 2, "keyword"}, {8, 4, "string"}, {16, 4, "keyword"}}));
        QCOMPARE(SyntaxHighlighter::spans("ini", "[options]"), QList<Span>({{0, 9, "section"}}));
        QCOMPARE(SyntaxHighlighter::spans("ini", "ParallelDownloads = 5"),
                 QList<Span>({{0, 17, "key"}, {20, 1, "number"}}));
        QCOMPARE(SyntaxHighlighter::spans("ini", "# Don't"), QList<Span>({{0, 7, "comment"}}));
        QCOMPARE(SyntaxHighlighter::spans("packages", "git Bad # x"), QList<Span>({{4, 3, "error"}, {8, 3, "comment"}}));
        QCOMPARE(SyntaxHighlighter::spans("json", "{\"a\": true}"),
                 QList<Span>({{1, 3, "key"}, {6, 4, "constant"}}));
        int state = 0;
        SyntaxHighlighter::spans("css", "a { /* start", 0, &state);
        QCOMPARE(state, 1);
        QCOMPARE(SyntaxHighlighter::spans("css", "end */ b", 1, &state), QList<Span>({{0, 6, "comment"}}));
        QCOMPARE(state, 0);

        QCOMPARE(IsoBuilder::languageFor("profile:pacman.conf"), QString("ini"));
        QCOMPARE(IsoBuilder::languageFor("/usr/local/bin/welcome", "#!/bin/bash\n"), QString("shell"));
        QCOMPARE(IsoBuilder::languageFor("profile:packages.x86_64"), QString("packages"));
        QCOMPARE(IsoBuilder::languageFor("/root/.zshrc"), QString("shell"));
        QCOMPARE(IsoBuilder::languageFor("/etc/motd"), QString("plain"));
    }

    void savesReplicaChoices()
    {
        BuildConfig config;
        config.profile = "replica";
        config.homeChoices = {{"Wallpapers", true}, {".config/hypr", false}};
        config.replicaSecrets = true;
        const BuildConfig back = BuildConfig::fromJson(config.toJson(), BuildConfig());
        QVERIFY(back == config);
    }

    void themeFallsBack()
    {
        QTemporaryDir dir;
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#FFD60A"));
        QCOMPARE(theme.accentForeground(), QString("black"));
    }

    void themeReadsAccent()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("theme");
        QFile colors(dir.path() + "/theme/colors.toml");
        QVERIFY(colors.open(QIODevice::WriteOnly));
        colors.write("accent = \"#112233\"\n");
        colors.close();

        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#112233"));
        QCOMPARE(theme.accentForeground(), QString("white"));
    }
};

int runIsoTests(int argc, char **argv)
{
    IsoTests tests;
    return QTest::qExec(&tests, argc, argv);
}

#include "iso_tests.moc"
