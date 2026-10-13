#pragma once

#include <QByteArray>
#include <QList>
#include <QString>
#include <QStringList>

// A removable drive the ISO could be written to. Drives that must not be
// written are still listed, with the reason, so the user isn't left
// wondering where their stick went.
struct Drive {
    QString path;   // /dev/sdb
    QString name;   // sdb, what the user types to confirm
    QString model;
    QString transport;
    qint64 size = 0;
    QStringList mountpoints;
    QString blocker;  // Why it can't be written; empty when it can.
};

namespace Drives {

// The arguments for lsblk whose JSON parse() reads.
QStringList lsblkArguments();

// Removable or hot-plugged whole disks from lsblk's JSON. isoPath and isoSize
// are the image to write, so a drive holding it or too small is blocked.
QList<Drive> parse(const QByteArray &lsblkJson, const QString &isoPath, qint64 isoSize);

// "31.9 GB", in the decimal units drives are sold in.
QString formatSize(qint64 bytes);

// Bytes written so far, from a line of `dd status=progress`; -1 if it isn't one.
qint64 parseDdProgress(const QString &line);

}
