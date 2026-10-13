QT += core gui qml quick quickcontrols2 dbus webenginequick webenginecore

CONFIG += c++20 release
TARGET = omacraft
TEMPLATE = app

HEADERS += \
    src/agentdock.h \
    src/animations.h \
    src/bar.h \
    src/buildconfig.h \
    src/drives.h \
    src/filepicker.h \
    src/hyprcraft.h \
    src/isobuilder.h \
    src/omascii.h \
    src/plugins.h \
    src/portalfilepicker.h \
    src/proc.h \
    src/replica.h \
    src/syntaxhighlighter.h \
    src/theme.h

SOURCES += \
    src/main.cpp \
    src/agentdock.cpp \
    src/animations.cpp \
    src/bar.cpp \
    src/buildconfig.cpp \
    src/drives.cpp \
    src/hyprcraft.cpp \
    src/isobuilder.cpp \
    src/omascii.cpp \
    src/plugins.cpp \
    src/portalfilepicker.cpp \
    src/proc.cpp \
    src/replica.cpp \
    src/syntaxhighlighter.cpp \
    src/theme.cpp

RESOURCES += src/resources.qrc
