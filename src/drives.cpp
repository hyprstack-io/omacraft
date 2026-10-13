#include "drives.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>

namespace Drives {

namespace {

// A drive with any of these mounted is part of the running system.
bool isSystemMount(const QString &mountpoint) {
    static const QStringList system{"/", "/boot", "/boot/efi", "/efi", "/home", "/usr", "/var", "/opt", "/srv", "[SWAP]"};
    return system.contains(mountpoint);
}

void collectMountpoints(const QJsonObject &device, QStringList &into) {
    for (const QJsonValue &mount : device.value("mountpoints").toArray()) {
        if (mount.isString() && !mount.toString().isEmpty())
            into.append(mount.toString());
    }
    for (const QJsonValue &child : device.value("children").toArray())
        collectMountpoints(child.toObject(), into);
}

bool flag(const QJsonValue &value) {
    // Older lsblk prints booleans as "0"/"1" strings.
    return value.isBool() ? value.toBool() : value.toVariant().toString() == "1";
}

qint64 number(const QJsonValue &value) {
    return value.isDouble() ? static_cast<qint64>(value.toDouble()) : value.toVariant().toString().toLongLong();
}

}

QStringList lsblkArguments() {
    return {"--json", "--bytes", "--paths", "--output", "NAME,SIZE,MODEL,TRAN,RM,HOTPLUG,TYPE,RO,MOUNTPOINTS"};
}

QList<Drive> parse(const QByteArray &lsblkJson, const QString &isoPath, qint64 isoSize) {
    QList<Drive> drives;
    const QJsonArray devices = QJsonDocument::fromJson(lsblkJson).object().value("blockdevices").toArray();
    for (const QJsonValue &value : devices) {
        const QJsonObject device = value.toObject();
        const QString transport = device.value("tran").toString();
        if (device.value("type").toString() != "disk")
            continue;
        if (!flag(device.value("rm")) && !flag(device.value("hotplug")) && transport != "usb")
            continue;

        Drive drive;
        drive.path = device.value("name").toString();
        drive.name = drive.path.section('/', -1);
        drive.model = device.value("model").toString().trimmed();
        drive.transport = transport;
        drive.size = number(device.value("size"));
        collectMountpoints(device, drive.mountpoints);

        if (drive.size <= 0) {
            drive.blocker = "No media in the drive.";
        } else if (flag(device.value("ro"))) {
            drive.blocker = "The drive is read-only.";
        } else {
            for (const QString &mount : drive.mountpoints) {
                if (isSystemMount(mount)) {
                    drive.blocker = QString("This drive holds %1 of the running system.").arg(mount);
                    break;
                }
                if (!isoPath.isEmpty() && (isoPath == mount || isoPath.startsWith(mount.endsWith('/') ? mount : mount + "/"))) {
                    drive.blocker = "The ISO is on this drive.";
                    break;
                }
            }
        }
        if (drive.blocker.isEmpty() && isoSize > drive.size)
            drive.blocker = QString("Too small for the ISO (%1).").arg(formatSize(isoSize));

        drives.append(drive);
    }
    return drives;
}

QString formatSize(qint64 bytes) {
    const double size = static_cast<double>(bytes);
    if (size >= 1e12)
        return QString::number(size / 1e12, 'f', 1) + " TB";
    if (size >= 1e9)
        return QString::number(size / 1e9, 'f', 1) + " GB";
    if (size >= 1e6)
        return QString::number(size / 1e6, 'f', 0) + " MB";
    return QString::number(bytes) + " B";
}

qint64 parseDdProgress(const QString &line) {
    static const QRegularExpression pattern("^\\s*(\\d+) bytes .* copied");
    const auto match = pattern.match(line);
    return match.hasMatch() ? match.captured(1).toLongLong() : -1;
}

}
