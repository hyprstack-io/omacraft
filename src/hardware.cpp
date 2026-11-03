#include "hardware.h"

#include <QDir>
#include <QFile>

namespace {

QByteArray readTrimmed(const QString &path) {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll().trimmed() : QByteArray();
}

} // namespace

bool Hardware::hasAlienwareKeys(const QString &sysRoot) {
    if (qEnvironmentVariable("OMACRAFT_SHOW_LIGHTS") == "1")
        return true;
    for (const char *field : {"sys_vendor", "board_vendor", "product_name"})
        if (readTrimmed(sysRoot + "/class/dmi/id/" + field).contains("Alienware"))
            return true;
    const QString usb = sysRoot + "/bus/usb/devices";
    const auto devices = QDir(usb).entryList(QDir::AllEntries | QDir::NoDotAndDotDot);
    for (const auto &device : devices)
        if (readTrimmed(usb + "/" + device + "/idVendor") == "187c")
            return true;
    return false;
}
