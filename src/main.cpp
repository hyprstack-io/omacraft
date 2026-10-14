// omacraft — one home for the skll Omarchy plugins: installs, enables and
// places them in the shell, and holds every one's settings, alongside the
// HyprCraft configurator and the hyprbuildz ISO builder.

#include <QDir>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickImageProvider>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>
#include <QUrl>
#include <QtQml/qqml.h>
#include <QtWebEngineQuick/qquickwebengineprofile.h>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>

#include "agentdock.h"
#include "animations.h"
#include "bar.h"
#include "burn.h"
#include "hyprcraft.h"
#include "isobuilder.h"
#include "launcher.h"
#include "omascii.h"
#include "plugins.h"
#include "portalfilepicker.h"
#include "syntaxhighlighter.h"
#include "theme.h"

// Desktop entries name their icons by theme name, so QML asks for
// image://icon/<name> and gets the icon theme's picture.
class IconProvider : public QQuickImageProvider {
public:
    IconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requested) override {
        const QSize wanted = requested.isValid() ? requested : QSize(48, 48);
        QIcon icon = id.startsWith('/') ? QIcon(id) : QIcon::fromTheme(id);
        if (icon.isNull())
            icon = QIcon::fromTheme("application-x-executable");
        const QPixmap pixmap = icon.pixmap(wanted);
        if (size)
            *size = pixmap.size();
        return pixmap;
    }
};

int main(int argc, char *argv[]) {
    // The web view needs both of these before the application exists.
    HyprCraft::registerScheme();
    QtWebEngineQuick::initialize();

    QGuiApplication app(argc, argv);
    app.setApplicationName("omacraft");
    app.setApplicationDisplayName("OMAcraft");
    app.setApplicationVersion("0.1.0");

    // Matches the window to omacraft.desktop, so the compositor (Wayland
    // app_id) and the launcher pick up the installed icon.
    app.setDesktopFileName("omacraft");
    app.setWindowIcon(QIcon::fromTheme("omacraft"));

    QQuickStyle::setStyle("Material");

    Theme theme;
    Plugins plugins;
    Animations animations([&plugins] { return plugins.pluginDir("omacraft.animations"); });
    AgentDock dock([&plugins] { return plugins.pluginDir("omacraft.agentdock"); },
                   [&plugins] { return plugins.isEnabled("omacraft.agentdock"); });
    Bar bar([&plugins] { return plugins.pluginDir("omabar16"); });
    Launcher launcher([&plugins] { return plugins.pluginDir("omacraft.studio"); });
    Burn burn([&plugins] { return plugins.pluginDir("omacraft.burn"); });
    Omascii omascii([&plugins] { return plugins.pluginDir("omacraft.omascii"); });
    HyprCraft hyprcraft([&plugins] {
        QStringList dirs;
        const QString dir = plugins.pluginDir("omacraft.hyprcraft");
        if (!dir.isEmpty())
            dirs << dir + "/app";
        dirs << plugins.sourcePath("omacraft.hyprcraft") + "/app";
        // The package carries a copy of the build for machines without the
        // project checked out.
        dirs << "/usr/share/omacraft/hyprcraft";
        return dirs;
    });
    PortalFilePicker picker;
    IsoBuilder iso(&picker);

    // Each page follows the plugins as they're installed, removed and moved.
    QObject::connect(&plugins, &Plugins::changed, &animations, &Animations::refresh);
    QObject::connect(&plugins, &Plugins::changed, &dock, &AgentDock::reload);
    QObject::connect(&plugins, &Plugins::changed, &bar, &Bar::reload);
    QObject::connect(&plugins, &Plugins::changed, &launcher, &Launcher::reload);
    QObject::connect(&plugins, &Plugins::changed, &burn, &Burn::reload);
    QObject::connect(&plugins, &Plugins::changed, &hyprcraft, &HyprCraft::refresh);
    QObject::connect(&plugins, &Plugins::changed, &omascii, [&omascii] {
        if (omascii.available() != omascii.loaded())
            omascii.refresh();
    });
    animations.refresh();
    omascii.refresh();
    dock.refreshMonitors();

    // HyprCraft gets its own profile, so its saved work and cache live with
    // OMAcraft's data rather than in a shared browser profile.
    QQuickWebEngineProfile webProfile("omacraft-hyprcraft");
    webProfile.setOffTheRecord(false);
    webProfile.setPersistentStoragePath(hyprcraft.storagePath() + "/storage");
    webProfile.setCachePath(hyprcraft.storagePath() + "/cache");
    webProfile.setDownloadPath(hyprcraft.downloadDir());
    webProfile.installUrlSchemeHandler("hyprcraft", &hyprcraft);

    qmlRegisterType<SyntaxHighlighter>("Omacraft", 1, 0, "SyntaxHighlighter");

    QQmlApplicationEngine engine;
    engine.addImageProvider("icon", new IconProvider);
    auto *context = engine.rootContext();
    context->setContextProperty("theme", &theme);
    context->setContextProperty("plugins", &plugins);
    context->setContextProperty("animations", &animations);
    context->setContextProperty("dock", &dock);
    context->setContextProperty("bar", &bar);
    context->setContextProperty("launcher", &launcher);
    context->setContextProperty("burn", &burn);
    context->setContextProperty("omascii", &omascii);
    context->setContextProperty("hyprcraft", &hyprcraft);
    context->setContextProperty("hyprcraftProfile", &webProfile);
    context->setContextProperty("iso", &iso);

    // `omacraft <page>` opens on that page, for keybindings and the bar.
    const QStringList pages{"plugins", "animations", "effects", "dock", "bar", "launcher", "ascii", "hyprcraft", "iso"};
    const QString start = app.arguments().value(1);
    context->setContextProperty("startPage", qMax(0, pages.indexOf(start)));

    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;

    // OMACRAFT_SCREENSHOT=out.png saves the window once it has settled, then
    // quits, so the look can be checked without a display (with
    // QT_QPA_PLATFORM=offscreen) or while the screen is locked.
    const QString screenshot = qEnvironmentVariable("OMACRAFT_SCREENSHOT");
    if (!screenshot.isEmpty()) {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QTimer::singleShot(qEnvironmentVariableIntValue("OMACRAFT_SCREENSHOT_DELAY") > 0
                               ? qEnvironmentVariableIntValue("OMACRAFT_SCREENSHOT_DELAY") : 3000,
                           &app, [window, screenshot] {
            window->grabWindow().save(screenshot);
            QCoreApplication::quit();
        });
    }

    return app.exec();
}
