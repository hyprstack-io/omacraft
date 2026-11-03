#pragma once

#include <QString>

// What this machine has, for the pages that only make sense on some hardware.
namespace Hardware {

// True on an Alienware machine, which is the only hardware the keyboard lights
// can drive: Alienware's USB vendor id on the bus, or the vendor in the DMI
// tables. OMACRAFT_SHOW_LIGHTS=1 says yes anywhere, for working on the page.
// sysRoot is for the tests.
bool hasAlienwareKeys(const QString &sysRoot = "/sys");

} // namespace Hardware
