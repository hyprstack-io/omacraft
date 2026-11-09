QT += core gui qml quick quickcontrols2 testlib dbus network webenginecore
CONFIG += c++20 testcase
TARGET = omacraft_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += \
    omacraft_tests.h \
    ../src/agentdock.h ../src/animations.h ../src/introreel.h ../src/asciiview.h ../src/bar.h ../src/bootsplash.h ../src/buildconfig.h ../src/drives.h \
    ../src/filepicker.h ../src/hyprcraft.h ../src/isobuilder.h ../src/launcher.h ../src/locklogon.h ../src/cursoricons.h ../src/marketplace.h ../src/burn.h ../src/omascii.h ../src/plugins.h \
    ../src/proc.h ../src/replica.h ../src/rofioma.h ../src/syntaxhighlighter.h ../src/theme.h ../src/themesync.h ../src/wallpaper.h ../src/wallpicker.h ../src/folders.h \
    ../src/effects.h ../src/layout.h ../src/lights.h ../src/palette.h ../src/scene.h ../src/screensaver.h ../src/store.h ../src/edgetab.h ../src/hyprvyzr.h

SOURCES += \
    main.cpp omacraft_tests.cpp iso_tests.cpp cursoricons_tests.cpp hyprvyzr_tests.cpp ../src/hyprvyzr.cpp \
    ../src/agentdock.cpp ../src/animations.cpp ../src/introreel.cpp ../src/asciiview.cpp ../src/bar.cpp ../src/bootsplash.cpp ../src/buildconfig.cpp ../src/drives.cpp \
    ../src/hyprcraft.cpp ../src/isobuilder.cpp ../src/launcher.cpp ../src/locklogon.cpp ../src/cursoricons.cpp ../src/marketplace.cpp ../src/burn.cpp ../src/omascii.cpp ../src/plugins.cpp ../src/proc.cpp \
    ../src/replica.cpp ../src/rofioma.cpp ../src/syntaxhighlighter.cpp ../src/theme.cpp ../src/themesync.cpp ../src/wallpaper.cpp ../src/wallpicker.cpp ../src/folders.cpp ../src/hardware.cpp \
    ../src/effects.cpp ../src/layout.cpp ../src/lights.cpp ../src/palette.cpp ../src/scene.cpp ../src/screensaver.cpp ../src/store.cpp ../src/edgetab.cpp

LIBS += -lLayerShellQtInterface

RESOURCES += ../src/resources.qrc
