// omacraft — one home for the skll Omarchy plugins: installs, enables and
// places them in the shell, and holds every one's settings, alongside the
// HyprCraft configurator and the hyprbuildz ISO builder.

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QTextStream>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickImageProvider>
#include <QQuickStyle>
#include <QProcess>
#include <QQuickWindow>
#include <QThread>
#include <QTimer>
#include <QUrl>
#include <QtQml/qqml.h>
#include <QtWebEngineQuick/qquickwebengineprofile.h>
#include <QtWebEngineQuick/qtwebenginequickglobal.h>

#include "agentdock.h"
#include "animations.h"
#include "asciiview.h"
#include "bar.h"
#include "bootsplash.h"
#include "burn.h"
#include "cursoricons.h"
#include "edgetab.h"
#include "hyprcraft.h"
#include "hyprvyzr.h"
#include "isobuilder.h"
#include "lights.h"
#include "marketplace.h"
#include "launcher.h"
#include "locklogon.h"
#include "omascii.h"
#include "introreel.h"
#include "rofioma.h"
#include "screensaver.h"
#include "plugins.h"
#include "portalfilepicker.h"
#include "syntaxhighlighter.h"
#include "folders.h"
#include "hardware.h"
#include "theme.h"
#include "themesync.h"
#include "wallpaper.h"
#include "wallpicker.h"

// Desktop entries name their icons by theme name, so QML asks for
// image://icon/<name> and gets the icon theme's picture. Qt Quick loads
// these on its own thread, where QIcon and QPixmap aren't safe, so the
// icon is drawn on the GUI thread and handed back as an image.
class IconProvider : public QQuickImageProvider {
public:
    IconProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

    QImage requestImage(const QString &id, QSize *size, const QSize &requested) override {
        const QSize wanted = requested.isValid() ? requested : QSize(48, 48);
        QImage image;
        auto draw = [&] {
            QIcon icon = id.startsWith('/') ? QIcon(id) : QIcon::fromTheme(id);
            if (icon.isNull())
                icon = QIcon::fromTheme("application-x-executable");
            image = icon.pixmap(wanted).toImage();
        };
        if (QThread::currentThread() == qApp->thread())
            draw();
        else
            QMetaObject::invokeMethod(qApp, draw, Qt::BlockingQueuedConnection);
        if (size)
            *size = image.size();
        return image;
    }
};

int main(int argc, char *argv[]) {
    if (argc > 1 && (QString(argv[1]) == "--version" || QString(argv[1]) == "-V")) {
        QTextStream(stdout) << "omacraft " << OMACRAFT_VERSION << Qt::endl;
        return 0;
    }

    // `omacraft --sync-colors` is the theme-set hook's: no window, just bring
    // OmaCraft's parts up to the new theme.
    if (argc > 1 && QString(argv[1]) == "--sync-colors") {
        QCoreApplication app(argc, argv);
        const int synced = ThemeSync::syncNow();
        // Omarchy has just put its theme's icons back: the Cursors & Icons
        // choice goes on again, a theme-following one in the new colours.
        CursorsIcons::syncNow();
        return synced;
    }

    // `omacraft pick [tab]` opens the wallpaper picker over the desktop and
    // leaves OmaCraft's window where it is, closed or folded.
    if (argc > 1 && QString(argv[1]) == "pick") {
        QCoreApplication app(argc, argv);
        return QProcess::execute("omarchy-shell", WallPicker::summonArguments(argc > 2 ? argv[2] : "")) == 0 ? 0 : 1;
    }

    // `omacraft kasm-view <spec>` is one HyprVYZR session's window: its own
    // process (so each session closes on its own), never handed to the
    // running OmaCraft, with nothing but the theme and the web view.
    if (argc > 2 && QString(argv[1]) == "kasm-view") {
        QtWebEngineQuick::initialize();
        QGuiApplication app(argc, argv);
        app.setApplicationName("omacraft-hyprvyzr");
        app.setApplicationDisplayName("HyprVYZR");
        // Its own window class, so Hyprland rules and the bar can tell
        // sessions apart from OmaCraft.
        app.setDesktopFileName("hyprvyzr");
        app.setWindowIcon(QIcon::fromTheme("omacraft"));
        QQuickStyle::setStyle("Material");
        Theme theme;
        KasmView view(QString::fromLocal8Bit(argv[2]));
        // One profile for every session, kept with HyprVYZR's data: a Kasm
        // dashboard sign-in survives, the everyday browser never sees it.
        QQuickWebEngineProfile profile("hyprvyzr");
        profile.setOffTheRecord(false);
        const QString data = QDir::homePath() + "/.local/share/hyprvyzr/web";
        profile.setPersistentStoragePath(data + "/storage");
        profile.setCachePath(QDir::homePath() + "/.cache/hyprvyzr/web");
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("theme", &theme);
        engine.rootContext()->setContextProperty("session", &view);
        engine.rootContext()->setContextProperty("kasmProfile", &profile);
        engine.load(QUrl("qrc:/KasmView.qml"));
        if (engine.rootObjects().isEmpty())
            return 1;
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

    // The web view needs both of these before the application exists.
    HyprCraft::registerScheme();
    QtWebEngineQuick::initialize();

    QGuiApplication app(argc, argv);
    app.setApplicationName("omacraft");
    app.setApplicationDisplayName("OmaCraft");
    app.setApplicationVersion(OMACRAFT_VERSION);

    // Matches the window to omacraft.desktop, so the compositor (Wayland
    // app_id) and the launcher pick up the installed icon.
    app.setDesktopFileName("omacraft");
    app.setWindowIcon(QIcon::fromTheme("omacraft"));

    // omacraft keys move FROM [TO] | keys capture on|off: the cheatsheet
    // overlay edits binds through these, so OmaCraft stays the one writer of
    // the moved keys. TO left out puts the bind back on its own keys.
    const QStringList args = app.arguments();
    if (args.size() >= 3 && args.at(1) == "keys") {
        Rofioma rofioma;
        QTextStream out(stdout), err(stderr);
        if (args.at(2) == "move" && args.size() >= 4) {
            const QString problem = rofioma.moveBind(args.at(3), args.size() >= 5 ? args.at(4) : QString());
            if (!problem.isEmpty()) {
                err << problem << Qt::endl;
                return 1;
            }
            out << "ok" << Qt::endl;
            return 0;
        }
        if (args.at(2) == "capture" && args.size() >= 4) {
            rofioma.captureKeys(args.at(3) == "on");
            // Let a first capture's reload land before the submap is entered.
            QTimer::singleShot(900, &app, &QCoreApplication::quit);
            return app.exec();
        }
        // keys bind POPUP KEY: one of ROFIoma's own keys (power, emoji,
        // glyphs, keybinds, notifications, menu-<id>); an empty KEY clears it.
        if (args.at(2) == "bind" && args.size() >= 4) {
            if (!rofioma.bindKey(args.at(3), args.size() >= 5 ? args.at(4) : QString())) {
                err << rofioma.error() << Qt::endl;
                return 1;
            }
            out << "ok" << Qt::endl;
            return 0;
        }
        err << "usage: omacraft keys move FROM [TO] | omacraft keys capture on|off | omacraft keys bind POPUP [KEY]" << Qt::endl;
        return 2;
    }

    // One OmaCraft at a time: launched again (from the launcher, a key or
    // the bar), it hands its page to the one running, folded or not.
    const bool screenshotting = !qEnvironmentVariable("OMACRAFT_SCREENSHOT").isEmpty();
    if (!screenshotting && EdgeTab::passToRunning(app.arguments().mid(1)))
        return 0;
    EdgeTab edgeTab(QDir::homePath());
    if (!screenshotting)
        edgeTab.listen();
    // Closing folds the window into its edge tab, so the last window going
    // isn't the end; quitting is explicit.
    if (edgeTab.supported())
        app.setQuitOnLastWindowClosed(false);

    QQuickStyle::setStyle("Material");

    Theme theme;
    Plugins plugins;
    Animations animations([&plugins] { return plugins.pluginDir("omacraft.animations"); });
    AgentDock dock([&plugins] { return plugins.pluginDir("omacraft.agentdock"); },
                   [&plugins] { return plugins.isEnabled("omacraft.agentdock"); });
    Bar bar([&plugins] { return plugins.pluginDir("omabar16"); }, [&plugins] { return plugins.pluginDir("omacraft.studio"); });
    Launcher launcher([&plugins] { return plugins.pluginDir("omacraft.studio"); });
    Burn burn([&plugins] { return plugins.pluginDir("omacraft.burn"); });
    Omascii omascii([&plugins] { return plugins.pluginDir("omacraft.omascii"); });
    // The Plugin Suite title, played through the Boot Splash intros.
    IntroReel introReel(&omascii);
    BootSplash bootSplash;
    // Screensaver designs the screensaver with omascii's renderer, through the
    // path of its command only: it never reaches the boot screen's design.
    Screensaver saver([&omascii] { return omascii.cli(); });
    HyprCraft hyprcraft([&plugins] {
        QStringList dirs;
        const QString dir = plugins.pluginDir("omacraft.hyprcraft");
        if (!dir.isEmpty())
            dirs << dir + "/app";
        // The project's build, else the package's copy of the plugin.
        dirs << plugins.sourcePath("omacraft.hyprcraft") + "/app";
        return dirs;
    });
    PortalFilePicker picker;
    IsoBuilder iso(&picker);
    Folders folders;
    Wallpaper wallpaper([&plugins] { return plugins.pluginDir("omacraft.studio"); }, &picker);
    // The picker key: the shell overlay that browses the same wallpapers.
    WallPicker wallPicker({}, true, [&plugins] { return plugins.pluginDir(WallPicker::kPluginId); });
    // HyprVYZR: Kasm workspaces, through the plugin's hyprvyzr command.
    Hyprvyzr hyprvyzr([&plugins] {
        const QString dir = plugins.pluginDir(Hyprvyzr::kPluginId);
        return dir.isEmpty() ? plugins.sourcePath(Hyprvyzr::kPluginId) : dir;
    }, &dock);
    QObject::connect(&plugins, &Plugins::changed, &hyprvyzr, &Hyprvyzr::changed);
    // Alienflare edits AlienFlare's scene; the alienflare service lights the keys.
    Lights lights;
    // ROFIoma: rofi popups and swaync's notifications.
    Rofioma rofioma;
    // The marketplaces browse omarchy's catalogues; Omarchy's own tools install.
    Marketplace market;
    QObject::connect(&market, &Marketplace::installedChanged, &plugins, &Plugins::refresh);
    // Lock & Logon: the lock's look, the idle times and the login screen.
    LockLogon lockLogon(&plugins, &picker);
    QObject::connect(&lockLogon, &LockLogon::idleChanged, &saver, &Screensaver::refreshSystem);
    // Cursors & Icons: icon and cursor themes, imported and chosen.
    CursorsIcons cursorIcons(&picker);
    QObject::connect(&theme, &Theme::changed, &cursorIcons, &CursorsIcons::themeSwitched);
    ThemeSync themeSync(&dock, &animations, &burn, &launcher, &omascii, &wallpaper);
    // Without the keyboard there's nothing for the wallpaper's colours to light.
    const bool alienwareKeys = Hardware::hasAlienwareKeys();
    if (alienwareKeys)
        themeSync.setLights(&lights);

    // Each page follows the plugins as they're installed, removed and moved.
    QObject::connect(&plugins, &Plugins::changed, &animations, &Animations::refresh);
    QObject::connect(&plugins, &Plugins::changed, &dock, &AgentDock::reload);
    QObject::connect(&plugins, &Plugins::changed, &bar, &Bar::reload);
    QObject::connect(&plugins, &Plugins::changed, &launcher, &Launcher::reload);
    QObject::connect(&plugins, &Plugins::changed, &burn, &Burn::reload);
    QObject::connect(&plugins, &Plugins::changed, &hyprcraft, &HyprCraft::refresh);
    QObject::connect(&plugins, &Plugins::changed, &wallpaper, &Wallpaper::refresh);
    QObject::connect(&plugins, &Plugins::changed, &omascii, [&omascii] {
        if (omascii.available() != omascii.loaded())
            omascii.refresh();
    });
    animations.refresh();
    omascii.refresh();
    dock.refreshMonitors();

    // HyprCraft gets its own profile, so its saved work and cache live with
    // OmaCraft's data rather than in a shared browser profile.
    QQuickWebEngineProfile webProfile("omacraft-hyprcraft");
    webProfile.setOffTheRecord(false);
    webProfile.setPersistentStoragePath(hyprcraft.storagePath() + "/storage");
    webProfile.setCachePath(hyprcraft.storagePath() + "/cache");
    webProfile.setDownloadPath(hyprcraft.downloadDir());
    webProfile.installUrlSchemeHandler("hyprcraft", &hyprcraft);

    qmlRegisterType<SyntaxHighlighter>("Omacraft", 1, 0, "SyntaxHighlighter");
    qmlRegisterType<AsciiView>("Omacraft", 1, 0, "AsciiView");

    QQmlApplicationEngine engine;
    engine.setNetworkAccessManagerFactory(&market.imageCache());
    engine.addImageProvider("icon", new IconProvider);
    engine.addImageProvider("cursor", new CursorImageProvider);
    auto *context = engine.rootContext();
    context->setContextProperty("theme", &theme);
    context->setContextProperty("plugins", &plugins);
    context->setContextProperty("animations", &animations);
    context->setContextProperty("dock", &dock);
    context->setContextProperty("bar", &bar);
    context->setContextProperty("launcher", &launcher);
    context->setContextProperty("burn", &burn);
    context->setContextProperty("omascii", &omascii);
    context->setContextProperty("introReel", &introReel);
    context->setContextProperty("bootSplash", &bootSplash);
    context->setContextProperty("saver", &saver);
    context->setContextProperty("hyprcraft", &hyprcraft);
    context->setContextProperty("hyprcraftProfile", &webProfile);
    context->setContextProperty("iso", &iso);
    context->setContextProperty("wallpaper", &wallpaper);
    context->setContextProperty("wallPicker", &wallPicker);
    context->setContextProperty("hyprvyzr", &hyprvyzr);
    context->setContextProperty("folders", &folders);
    context->setContextProperty("themeSync", &themeSync);
    context->setContextProperty("lights", &lights);
    context->setContextProperty("alienwareKeys", alienwareKeys);
    context->setContextProperty("rofioma", &rofioma);
    context->setContextProperty("market", &market);
    context->setContextProperty("lockLogon", &lockLogon);
    context->setContextProperty("cursorIcons", &cursorIcons);
    context->setContextProperty("edgeTab", &edgeTab);
    // About Us shows the licence and notices as they're shipped.
    const auto builtIn = [](const QString &path) {
        QFile file(path);
        return file.open(QIODevice::ReadOnly) ? QString::fromUtf8(file.readAll()) : QString();
    };
    context->setContextProperty("aboutLicense", builtIn(":/about/LICENSE"));
    context->setContextProperty("aboutNotices", builtIn(":/about/THIRD-PARTY-NOTICES.md"));

    // `omacraft <page>` opens on that page, for keybindings and the bar.
    // Main.qml finds the page by its id, and falls back to the first.
    context->setContextProperty("startPage", app.arguments().value(1));
    // `omacraft wallpaper colors` also opens a page's own tab.
    context->setContextProperty("startTab", app.arguments().value(2));

    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;

    // OMACRAFT_SCREENSHOT=out.png saves the window once it has settled, then
    // quits, so the look can be checked without a display (with
    // QT_QPA_PLATFORM=offscreen) or while the screen is locked.
    const QString screenshot = qEnvironmentVariable("OMACRAFT_SCREENSHOT");
    if (!screenshot.isEmpty()) {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        // OMACRAFT_SCREENSHOT_SIZE=WxH shoots a bigger window, to see a whole page.
        const QStringList size = qEnvironmentVariable("OMACRAFT_SCREENSHOT_SIZE").split('x');
        if (size.size() == 2 && size.at(0).toInt() > 0 && size.at(1).toInt() > 0)
            window->resize(size.at(0).toInt(), size.at(1).toInt());
        QTimer::singleShot(qEnvironmentVariableIntValue("OMACRAFT_SCREENSHOT_DELAY") > 0
                               ? qEnvironmentVariableIntValue("OMACRAFT_SCREENSHOT_DELAY") : 3000,
                           &app, [window, screenshot] {
            window->grabWindow().save(screenshot);
            QCoreApplication::quit();
        });
    }

    return app.exec();
}
