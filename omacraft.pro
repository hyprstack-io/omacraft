QT += core gui qml quick quickcontrols2 dbus network webenginequick webenginecore

CONFIG += c++20 release
TARGET = omacraft
TEMPLATE = app

HEADERS += \
    src/agentdock.h \
    src/animations.h \
    src/introreel.h \
    src/asciiview.h \
    src/bar.h \
    src/bootsplash.h \
    src/buildconfig.h \
    src/drives.h \
    src/edgetab.h \
    src/folders.h \
    src/filepicker.h \
    src/hyprcraft.h \
    src/isobuilder.h \
    src/launcher.h \
    src/burn.h \
    src/omascii.h \
    src/plugins.h \
    src/portalfilepicker.h \
    src/proc.h \
    src/replica.h \
    src/rofioma.h \
    src/syntaxhighlighter.h \
    src/theme.h \
    src/themesync.h \
    src/wallpaper.h \
    src/wallpicker.h \
    src/effects.h \
    src/layout.h \
    src/lights.h \
    src/palette.h \
    src/scene.h \
    src/screensaver.h \
    src/store.h

SOURCES += \
    src/main.cpp \
    src/agentdock.cpp \
    src/edgetab.cpp \
    src/animations.cpp \
    src/introreel.cpp \
    src/asciiview.cpp \
    src/bar.cpp \
    src/bootsplash.cpp \
    src/buildconfig.cpp \
    src/drives.cpp \
    src/folders.cpp \
    src/hyprcraft.cpp \
    src/isobuilder.cpp \
    src/launcher.cpp \
    src/burn.cpp \
    src/omascii.cpp \
    src/plugins.cpp \
    src/portalfilepicker.cpp \
    src/proc.cpp \
    src/replica.cpp \
    src/rofioma.cpp \
    src/syntaxhighlighter.cpp \
    src/theme.cpp \
    src/themesync.cpp \
    src/wallpaper.cpp \
    src/wallpicker.cpp \
    src/effects.cpp \
    src/layout.cpp \
    src/lights.cpp \
    src/palette.cpp \
    src/scene.cpp \
    src/screensaver.cpp \
    src/store.cpp

# The tab OmaCraft folds into sits on the screen edge as a layer surface.
LIBS += -lLayerShellQtInterface

RESOURCES += src/resources.qrc
