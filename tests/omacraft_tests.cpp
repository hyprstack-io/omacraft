#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPainter>
#include <QTemporaryDir>
#include <QtTest>
#include <QRegularExpression>
#include <sys/stat.h>
#include <unistd.h>

#include "agentdock.h"
#include "animations.h"
#include "asciiview.h"
#include <QStandardPaths>
#include <QScopeGuard>
#include "bar.h"
#include "edgetab.h"
#include "hardware.h"
#include "introreel.h"
#include "omascii.h"
#include "bootsplash.h"
#include "burn.h"
#include "hyprcraft.h"
#include "launcher.h"
#include "locklogon.h"
#include "omascii.h"
#include "plugins.h"
#include "proc.h"
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickWindow>
#include <memory>
#include "marketplace.h"
#include "theme.h"
#include "rofioma.h"
#include <QProcess>
#include <QImage>
#include "screensaver.h"
#include "theme.h"
#include "themesync.h"
#include "wallpaper.h"
#include "wallpicker.h"
#include "folders.h"
#include "omacraft_tests.h"

namespace {

void writeFile(const QString &path, const QByteArray &bytes) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(bytes);
}

QJsonObject readJson(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object();
}

// Built as JSON rather than a raw string: qmake's scan for Q_OBJECT trips
// over raw string literals that come before the class.
void writeManifest(const QString &dir, const QString &id) {
    const QJsonObject manifest{{"id", id}, {"version", "1.2.3"}, {"kinds", QJsonArray{"bar-widget"}},
                               {"barWidget", QJsonObject{{"defaultSection", "right"}}}};
    writeFile(dir + "/manifest.json", QJsonDocument(manifest).toJson());
}

} // namespace

// --- theme ---

void OmacraftTests::initTestCase()
{
    // The bar's Omarchy themes come from the system's; the tests have none
    // unless they make some.
    qputenv("OMACRAFT_OMARCHY_THEMES", "/nonexistent");
    // Nor do they see the plugins an installed package carries.
    qputenv("OMACRAFT_PLUGINS_DIR", "/nonexistent");
}

void OmacraftTests::findsAlienwareKeys()
{
    qunsetenv("OMACRAFT_SHOW_LIGHTS");
    const auto write = [](const QString &path, const QByteArray &text) {
        QVERIFY(QDir().mkpath(QFileInfo(path).absolutePath()));
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(text);
    };

    QTemporaryDir other;
    write(other.path() + "/class/dmi/id/sys_vendor", "LENOVO\n");
    write(other.path() + "/bus/usb/devices/1-1/idVendor", "046d\n");
    QVERIFY(!Hardware::hasAlienwareKeys(other.path()));

    QTemporaryDir dmi;
    write(dmi.path() + "/class/dmi/id/sys_vendor", "Alienware\n");
    QVERIFY(Hardware::hasAlienwareKeys(dmi.path()));

    QTemporaryDir usb;
    write(usb.path() + "/bus/usb/devices/1-4/idVendor", "187c\n");
    QVERIFY(Hardware::hasAlienwareKeys(usb.path()));

    QTemporaryDir nothing;
    QVERIFY(!Hardware::hasAlienwareKeys(nothing.path()));
}

void OmacraftTests::themeFallsBack()
{
    QTemporaryDir dir;
    Theme theme(dir.path());
    QCOMPARE(theme.accent(), QString("#FFD60A"));
    QCOMPARE(theme.accentForeground(), QString("black"));
}

void OmacraftTests::themeReadsAccent()
{
    QTemporaryDir dir;
    writeFile(dir.path() + "/theme/colors.toml", "accent = \"#112233\"\n");
    Theme theme(dir.path());
    QCOMPARE(theme.accent(), QString("#112233"));
    QCOMPARE(theme.accentForeground(), QString("white"));
}

// --- helpers ---

void OmacraftTests::savesAtomically()
{
    QTemporaryDir dir;
    const QString path = dir.path() + "/deep/er/file.json";
    QVERIFY(Proc::writeAtomically(path, "one"));
    QVERIFY(Proc::writeAtomically(path, "two"));
    QFile file(path);
    QVERIFY(file.open(QIODevice::ReadOnly));
    QCOMPARE(file.readAll(), QByteArray("two"));
}

void OmacraftTests::expandsHomeAndQuotes()
{
    QCOMPARE(Proc::expandHome("~/Work", "/home/me"), QString("/home/me/Work"));
    QCOMPARE(Proc::expandHome("~", "/home/me"), QString("/home/me"));
    QCOMPARE(Proc::expandHome("/etc/~x", "/home/me"), QString("/etc/~x"));
    QCOMPARE(Proc::shellQuote("it's"), QString("'it'\\''s'"));
}

// --- plugins ---

void OmacraftTests::readsBarSections()
{
    const auto shell = QJsonDocument::fromJson(R"({"bar":{"id":"omabar16","layout":{
        "left":[{"id":"omacraft.studio","role":"launcher"},{"id":"omacraft.folders","name":"Apps"}],
        "right":[{"id":"omacraft.agentdock"},{"id":"omacraft.studio","role":"studio"}]}},
        "plugins":[{"id":"omacraft.burn"},{"id":"omacraft.omascii"}],"disabledPlugins":["omacraft.omascii"]})").object();
    QCOMPARE(Plugins::barIn(shell), QString("omabar16"));
    QCOMPARE(Plugins::barIn(QJsonObject()), QString("omarchy.bar"));
    QVERIFY(Plugins::isOnIn(shell, "omacraft.burn"));
    QVERIFY(Plugins::isOnIn(shell, "omacraft.agentdock"));
    QVERIFY(!Plugins::isOnIn(shell, "omacraft.omascii"));
    QVERIFY(!Plugins::isOnIn(shell, "omacraft.animations"));
    // Folder trays and Studio's launcher button belong on the bar; the rest
    // are icons OmaCraft takes over.
    QCOMPARE(Plugins::barIconsIn(shell, "omacraft.agentdock"), 1);
    QCOMPARE(Plugins::barIconsIn(shell, "omacraft.studio"), 1);
    QCOMPARE(Plugins::barIconsIn(shell, "omacraft.folders"), 0);
}

void OmacraftTests::switchesPluginsWithoutBarIcons()
{
    auto shell = QJsonDocument::fromJson(R"({"bar":{"id":"omabar16","layout":{
        "left":[{"id":"omacraft.studio","role":"launcher"},{"id":"omacraft.folders","name":"Apps"}],
        "right":[{"id":"omarchy.clock"},{"id":"omacraft.agentdock"},{"id":"omacraft.studio","role":"studio"}]}},
        "plugins":[{"id":"other.thing"}],"theme":"kept"})").object();

    // On: listed in plugins[], its icon gone, everything else left alone.
    Plugins::switchIn(shell, "omacraft.agentdock", true);
    QVERIFY(Plugins::isOnIn(shell, "omacraft.agentdock"));
    QCOMPARE(Plugins::barIconsIn(shell, "omacraft.agentdock"), 0);
    QCOMPARE(shell.value("plugins").toArray().size(), 2);
    QCOMPARE(shell.value("bar").toObject().value("layout").toObject().value("right").toArray().size(), 2);
    QCOMPARE(shell.value("theme").toString(), QString("kept"));
    Plugins::switchIn(shell, "omacraft.agentdock", true);
    QCOMPARE(shell.value("plugins").toArray().size(), 2);

    // Off: out of plugins[], and nothing is said in disabledPlugins[] when
    // nothing of it is left to load it.
    Plugins::switchIn(shell, "omacraft.agentdock", false);
    QVERIFY(!Plugins::isOnIn(shell, "omacraft.agentdock"));
    QVERIFY(!shell.contains("disabledPlugins"));

    // Studio keeps its launcher button, so off is said, and on unsays it.
    Plugins::switchIn(shell, "omacraft.studio", false);
    QVERIFY(!Plugins::isOnIn(shell, "omacraft.studio"));
    QCOMPARE(shell.value("disabledPlugins").toArray(), QJsonArray{"omacraft.studio"});
    QCOMPARE(shell.value("bar").toObject().value("layout").toObject().value("left").toArray().size(), 2);
    Plugins::switchIn(shell, "omacraft.studio", true);
    QVERIFY(Plugins::isOnIn(shell, "omacraft.studio"));
    QVERIFY(!shell.contains("disabledPlugins"));
    QCOMPARE(Plugins::barIconsIn(shell, "omacraft.studio"), 0);
}

void OmacraftTests::switchingAPluginEditsShellJsonInPlace()
{
    QTemporaryDir home;
    writeManifest(home.path() + "/.config/omarchy/plugins/omacraft.animations", "omacraft.animations");
    const QString shellPath = home.path() + "/.config/omarchy/shell.json";
    writeFile(shellPath, R"({"bar":{"layout":{"right":[{"id":"omacraft.animations"},{"id":"omarchy.clock"}]}}})");

    Plugins plugins(home.path(), false);
    auto item = plugins.plugin("omacraft.animations");
    QVERIFY(item.value("enabled").toBool());
    QCOMPARE(item.value("barIcons").toInt(), 1);
    QCOMPARE(item.value("state").toString(), QString("On, with an icon on the bar"));

    const auto born = QFileInfo(shellPath).fileTime(QFileDevice::FileBirthTime);
    plugins.takeIconsOffBar();
    QCOMPARE(plugins.error(), QString());
    item = plugins.plugin("omacraft.animations");
    QVERIFY(item.value("enabled").toBool());
    QCOMPARE(item.value("barIcons").toInt(), 0);
    QCOMPARE(item.value("state").toString(), QString("On"));
    QCOMPARE(QFileInfo(shellPath).fileTime(QFileDevice::FileBirthTime), born);

    plugins.setEnabled("omacraft.animations", false);
    QVERIFY(!plugins.isEnabled("omacraft.animations"));
    const auto shell = readJson(shellPath);
    QCOMPARE(shell.value("plugins").toArray().size(), 0);
    QCOMPARE(shell.value("bar").toObject().value("layout").toObject().value("right").toArray().size(), 1);
}

void OmacraftTests::installsByLinkingTheSource()
{
    QTemporaryDir home;
    const QString source = home.path() + "/Work/skll-agentdock/plugin";
    writeManifest(source, "omacraft.agentdock");

    Plugins plugins(home.path(), false);
    QVERIFY(!plugins.isInstalled("omacraft.agentdock"));
    QVERIFY(plugins.plugin("omacraft.agentdock").value("canInstall").toBool());

    plugins.install("omacraft.agentdock");
    const QFileInfo installed(home.path() + "/.config/omarchy/plugins/omacraft.agentdock");
    QVERIFY(installed.isSymLink());
    QCOMPARE(installed.symLinkTarget(), source);
    QVERIFY(plugins.isInstalled("omacraft.agentdock"));
    QCOMPARE(plugins.plugin("omacraft.agentdock").value("version").toString(), QString("1.2.3"));
    QCOMPARE(plugins.error(), QString());
}

void OmacraftTests::flagsAFolderThatReusesAPluginId()
{
    QTemporaryDir home;
    const QString source = home.path() + "/Projects/omascii";
    writeManifest(source, "omacraft.omascii");
    const QString dir = home.path() + "/.config/omarchy/plugins";
    QDir().mkpath(dir);
    QVERIFY(QFile::link(source, dir + "/omacraft.omascii"));
    QVERIFY(QFile::link(source, dir + "/skll.omascii"));
    writeManifest(dir + "/.skll.omascii.bak", "omacraft.omascii");

    QCOMPARE(Plugins::duplicatesIn(dir).value("omacraft.omascii"), QStringList{"skll.omascii"});
    Plugins plugins(home.path(), false);
    const auto item = plugins.plugin("omacraft.omascii");
    QCOMPARE(item.value("duplicates").toStringList(), QStringList{"skll.omascii"});
    QCOMPARE(item.value("state").toString(), QString("Also installed as skll.omascii"));
    QVERIFY(plugins.plugin("omacraft.burn").value("duplicates").toStringList().isEmpty());
}

void OmacraftTests::installsFromThePackageWithoutTheProjects()
{
    QTemporaryDir home, packaged;
    writeManifest(packaged.path() + "/omacraft.burn", "omacraft.burn");
    writeManifest(packaged.path() + "/omacraft.omascii", "omacraft.omascii");
    // omascii's project is checked out here; Burn's isn't.
    writeManifest(home.path() + "/Projects/omascii", "omacraft.omascii");
    qputenv("OMACRAFT_PLUGINS_DIR", packaged.path().toUtf8());
    Plugins plugins(home.path(), false);
    QCOMPARE(plugins.sourcePath("omacraft.burn"), packaged.path() + "/omacraft.burn");
    QCOMPARE(plugins.sourcePath("omacraft.omascii"), home.path() + "/Projects/omascii");
    QVERIFY(plugins.plugin("omacraft.burn").value("canInstall").toBool());
    // A plugin the package doesn't carry still points at its project.
    QCOMPARE(plugins.sourcePath("omacraft.studio"), home.path() + "/Work/skll-studio/plugin");
    qputenv("OMACRAFT_PLUGINS_DIR", "/nonexistent");
}

void OmacraftTests::removingALinkKeepsTheCode()
{
    QTemporaryDir home;
    const QString source = home.path() + "/Projects/omascii";
    writeManifest(source, "omacraft.omascii");
    QDir().mkpath(home.path() + "/.config/omarchy/plugins");
    QVERIFY(QFile::link(source, home.path() + "/.config/omarchy/plugins/omacraft.omascii"));

    Plugins plugins(home.path(), false);
    QVERIFY(plugins.isInstalled("omacraft.omascii"));
    plugins.remove("omacraft.omascii");
    QVERIFY(!QFileInfo(home.path() + "/.config/omarchy/plugins/omacraft.omascii").isSymLink());
    QVERIFY(QFileInfo::exists(source + "/manifest.json"));
    QVERIFY(!plugins.isInstalled("omacraft.omascii"));
}

void OmacraftTests::removingAFolderSetsItAsideAndInstallBringsItBack()
{
    QTemporaryDir home;
    const QString installed = home.path() + "/.config/omarchy/plugins/omacraft.animations";
    writeManifest(installed, "omacraft.animations");
    writeFile(installed + "/presets.json", "{}");

    Plugins plugins(home.path(), false);
    plugins.remove("omacraft.animations");
    QVERIFY(!QFileInfo::exists(installed));
    const QString stash = home.path() + "/.local/share/omacraft/stash/omacraft.animations";
    QVERIFY(QFileInfo::exists(stash + "/presets.json"));
    QVERIFY(plugins.plugin("omacraft.animations").value("stashed").toBool());
    QCOMPARE(plugins.pluginDir("omacraft.animations"), QFileInfo(stash).canonicalFilePath());

    plugins.install("omacraft.animations");
    QVERIFY(QFileInfo::exists(installed + "/presets.json"));
    QVERIFY(!QFileInfo(installed).isSymLink());
    QVERIFY(!QFileInfo::exists(stash));
}

void OmacraftTests::installReplacesABrokenLinkButNotAFolder()
{
    QTemporaryDir home;
    const QString source = home.path() + "/Work/skll-agentdock/plugin";
    writeManifest(source, "omacraft.agentdock");
    const QString target = home.path() + "/.config/omarchy/plugins/omacraft.agentdock";
    QDir().mkpath(QFileInfo(target).absolutePath());
    QVERIFY(QFile::link(home.path() + "/gone", target));

    Plugins plugins(home.path(), false);
    QCOMPARE(plugins.plugin("omacraft.agentdock").value("state").toString(), QString("Broken link"));
    plugins.install("omacraft.agentdock");
    QCOMPARE(QFileInfo(target).symLinkTarget(), source);

    // Something of the user's that isn't a plugin stays put.
    QTemporaryDir home2;
    writeManifest(home2.path() + "/Work/skll-agentdock/plugin", "omacraft.agentdock");
    QDir().mkpath(home2.path() + "/.config/omarchy/plugins/omacraft.agentdock");
    writeFile(home2.path() + "/.config/omarchy/plugins/omacraft.agentdock/notes.txt", "mine");
    Plugins other(home2.path(), false);
    other.install("omacraft.agentdock");
    QVERIFY(other.error().contains("in the way"));
    QVERIFY(QFileInfo::exists(home2.path() + "/.config/omarchy/plugins/omacraft.agentdock/notes.txt"));
}

void OmacraftTests::sourcesCanBeMoved()
{
    QTemporaryDir home;
    const QString elsewhere = home.path() + "/code/dock";
    writeManifest(elsewhere, "omacraft.agentdock");
    Plugins plugins(home.path(), false);
    QVERIFY(!plugins.plugin("omacraft.agentdock").value("sourceExists").toBool());
    plugins.setSource("omacraft.agentdock", "~/code/dock");
    QCOMPARE(plugins.sourcePath("omacraft.agentdock"), elsewhere);
    QVERIFY(plugins.plugin("omacraft.agentdock").value("canInstall").toBool());
}

// --- animations ---

void OmacraftTests::readsAnimationStatus()
{
    Animations animations({});
    QVERIFY(!animations.available());
    QVERIFY(animations.readStatus(R"({"preset":"dreamy","speed":0.73,"last":"dreamy","file":"/x.lua",
        "presets":[{"id":"omarchy","name":"Omarchy","description":"Stock","custom":false},
                   {"id":"mine","name":"Mine","description":"","custom":true}]})"));
    QCOMPARE(animations.preset(), QString("dreamy"));
    QCOMPARE(animations.speed(), 0.73);
    QCOMPARE(animations.presets().size(), 2);
    QVERIFY(animations.presets().at(1).toMap().value("custom").toBool());
    QVERIFY(!animations.readStatus("not json"));
}

void OmacraftTests::animationPresetsCarryTheirMotion()
{
    QTemporaryDir home;
    const QString plugin = home.path() + "/plugin";
    writeFile(plugin + "/presets.json", R"({"curves":{"snap":{"type":"bezier","points":[[0.05,0.9],[0.1,1.05]]}},
        "presets":[{"id":"pop","animations":{"windowsIn":[3,"snap","popin 80%"]}},{"id":"mine","animations":{"windowsIn":[9,"snap","slide"]}}]})");
    // Yours win over a built-in with the same id.
    writeFile(home.path() + "/.config/omarchy/animation-presets.json",
              R"({"curves":{"soft":{"type":"spring","mass":1}},"presets":[{"id":"mine","animations":{"windowsIn":[4,"soft","gnomed"]}}]})");
    Animations animations([plugin] { return plugin; }, home.path());
    QVERIFY(animations.readStatus(R"({"preset":"pop","speed":1,"last":"pop","file":"/x.lua",
        "presets":[{"id":"pop","name":"Pop"},{"id":"mine","name":"Mine","custom":true},{"id":"off","name":"Off"}]})"));
    const auto presets = animations.presets();
    QCOMPARE(presets.at(0).toMap().value("animations").toMap().value("windowsIn").toList().at(2).toString(), QString("popin 80%"));
    QCOMPARE(presets.at(1).toMap().value("animations").toMap().value("windowsIn").toList().at(2).toString(), QString("gnomed"));
    QVERIFY(!presets.at(2).toMap().contains("animations"));
    QCOMPARE(animations.curves().value("snap").toMap().value("type").toString(), QString("bezier"));
    QVERIFY(animations.curves().contains("soft"));
}

void OmacraftTests::readsAnimationLookOverrides()
{
    Animations animations({});
    // An older script has no overrides: the page falls back to the preset's own.
    QVERIFY(animations.readStatus(R"({"preset":"omarchy","speed":1,"last":"omarchy","file":"/x.lua","presets":[]})"));
    QCOMPARE(animations.windowStyle(), QString("preset"));
    QCOMPARE(animations.border(), QString("theme"));
    QVERIFY(animations.windowStyles().isEmpty());

    QVERIFY(animations.readStatus(R"({"preset":"pop","speed":1,"last":"pop","file":"/x.lua","presets":[],
        "windowStyle":"slide top","workspaceStyle":"fade","border":"synthwave","borderLoop":true,"borderSpeed":4,
        "borders":[{"id":"synthwave","name":"Synthwave","colors":["ff2a6d","d300c5","05d9e8"],"angle":45}],
        "windowStyles":["preset","slide top"],"workspaceStyles":["preset","fade"]})"));
    QCOMPARE(animations.windowStyle(), QString("slide top"));
    QCOMPARE(animations.workspaceStyle(), QString("fade"));
    QCOMPARE(animations.border(), QString("synthwave"));
    QVERIFY(animations.borderLoop());
    QCOMPARE(animations.borderSpeed(), 4);
    QCOMPARE(animations.borders().first().toMap().value("colors").toList().size(), 3);
    QCOMPARE(animations.windowStyles(), QStringList({"preset", "slide top"}));
}

// --- agent dock ---

void OmacraftTests::dockStartsFromItsDefaults()
{
    QTemporaryDir home;
    AgentDock dock({}, [] { return false; }, home.path());
    QCOMPARE(dock.settings().value("position").toString(), QString("right"));
    QCOMPARE(dock.settings().value("iconSize").toInt(), 28);
    QCOMPARE(dock.agents().size(), 2);
    QVERIFY(!dock.customAgents());
}

void OmacraftTests::dockSavesSettingsWhileStopped()
{
    QTemporaryDir home;
    AgentDock dock({}, [] { return false; }, home.path());
    dock.set("gap", 6);
    dock.set("position", "left");
    dock.set("activeTab", "sneaky"); // not a setting the dock takes from OmaCraft
    const auto saved = readJson(dock.statePath());
    QCOMPARE(saved.value("gap").toInt(), 6);
    QCOMPARE(saved.value("position").toString(), QString("left"));
    QCOMPARE(saved.value("activeTab").toString(), QString(""));
}

void OmacraftTests::dockTakesBottomEdgeAndAutoHide()
{
    QTemporaryDir home;
    AgentDock dock({}, [] { return false; }, home.path());
    QVERIFY(AgentDock::settingKeys().contains("autoHide"));
    QCOMPARE(dock.settings().value("autoHide").toBool(), false);
    dock.set("position", "bottom");
    dock.set("autoHide", true);
    AgentDock again({}, [] { return false; }, home.path());
    QCOMPARE(again.settings().value("position").toString(), QString("bottom"));
    QCOMPARE(again.settings().value("autoHide").toBool(), true);
}

void OmacraftTests::dockItemsMoveAndKeepOnlyTheirFields()
{
    QTemporaryDir home;
    writeFile(home.path() + "/.local/state/skll-agentdock/state.json",
              R"({"dock":[{"type":"cmd","name":"T","glyph":"x","command":"t"},{"type":"spacer"}],"gap":4})");
    AgentDock dock({}, [] { return false; }, home.path());
    QCOMPARE(dock.dock().size(), 2);
    QCOMPARE(dock.dock().at(0).toMap().value("label").toString(), QString("T"));

    dock.moveItem(0, 1);
    dock.addDivider();
    const auto items = readJson(dock.statePath()).value("dock").toArray();
    QCOMPARE(items.size(), 3);
    QCOMPARE(items.at(0).toObject().value("type").toString(), QString("spacer"));
    QCOMPARE(items.at(1).toObject().value("command").toString(), QString("t"));
    QVERIFY(!items.at(1).toObject().contains("label"));
    QCOMPARE(items.at(2).toObject().value("type").toString(), QString("divider"));
    // Settings beside the dock list survive.
    QCOMPARE(readJson(dock.statePath()).value("gap").toInt(), 4);
}

void OmacraftTests::dockAgentsGoToTheConfigFile()
{
    QTemporaryDir home;
    AgentDock dock({}, [] { return false; }, home.path());
    dock.saveAgent(-1, {{"id", "codex"}, {"command", "codex"}, {"icon", ""}});
    QVERIFY(dock.customAgents());
    const auto agents = readJson(dock.configPath()).value("agents").toArray();
    QCOMPARE(agents.size(), 3);
    QCOMPARE(agents.at(2).toObject().value("name").toString(), QString("codex"));
    QVERIFY(!agents.at(2).toObject().contains("icon"));

    dock.removeAgent(0);
    dock.removeAgent(0);
    dock.removeAgent(0);
    QCOMPARE(dock.agents().size(), 1);
    QVERIFY(dock.error().contains("at least one"));

    dock.setMonitor("DP-1");
    QCOMPARE(readJson(dock.configPath()).value("monitor").toString(), QString("DP-1"));
    dock.resetAgents();
    QVERIFY(!dock.customAgents());
    QCOMPARE(readJson(dock.configPath()).value("monitor").toString(), QString("DP-1"));
}

void OmacraftTests::dockHidesAgentTabs()
{
    QTemporaryDir home;
    AgentDock dock({}, [] { return false; }, home.path());
    dock.setAgentShown("gemini", false);
    QCOMPARE(readJson(dock.statePath()).value("hiddenAgents").toArray().size(), 1);
    QVERIFY(!dock.agents().at(1).toMap().value("shown").toBool());
    dock.setAgentShown("gemini", true);
    QVERIFY(dock.agents().at(1).toMap().value("shown").toBool());
}

void OmacraftTests::dockLookHasDefaults()
{
    QTemporaryDir home;
    AgentDock dock({}, [] { return false; }, home.path());
    // The look keys go through the dock's `set` like the rest, with the
    // plugin's own defaults until they're changed.
    for (const auto &key : {"magnify", "magnifyScale", "magnifyRange", "dockShape", "iconShape", "iconPlate",
                            "dockColor", "accentColor", "dockBorder"})
        QVERIFY2(AgentDock::settingKeys().contains(key), key);
    QCOMPARE(dock.settings().value("magnify").toBool(), false);
    QCOMPARE(dock.settings().value("dockShape").toString(), QString("rounded"));
    dock.set("magnify", true);
    dock.set("dockColor", "ocean");
    AgentDock again({}, [] { return false; }, home.path());
    QVERIFY(again.settings().value("magnify").toBool());
    QCOMPARE(again.settings().value("dockColor").toString(), QString("ocean"));
}

// --- bar ---

void OmacraftTests::barReadsPresetsJs()
{
    QTemporaryDir home;
    const QString plugin = home.path() + "/plugin";
    writeFile(plugin + "/data/Presets.js", R"(.pragma library
var DEFAULT_PALETTE = ["accent", "blue"]
var THEMES = [{ id: "pills", label: "Pills", desc: "Round", style: { shape: "round", gap: 6 } }]
var JAKOOLIT = [{ id: "jk", label: "JK", style: { shape: "block", palette: ["#112233"] } }]
var BASE16 = [].map(function(d) { return d })
var LAYOUTS = [{ id: "min", label: "Minimal", layout: { left: [{ id: "a" }], center: [], right: [{ id: "b" }, { id: "c" }] } },
               { id: "jk-x", label: "JK", layout: { left: [], center: [], right: [] } },
               { id: "rail", label: "Rail", position: "left", layout: { left: [], center: [], right: [] } }]
var GLYPHS = { "omarchy.clock": "\u{F0954}" }
)");
    writeFile(home.path() + "/.config/omarchy/omabar16/themes.json", R"([{"id":"user-x","label":"Mine","style":{"shape":"arrow"}}])");
    writeFile(home.path() + "/.local/state/omarchy/current/theme/colors.toml", "accent = \"#abcdef\"\nblue = \"#0000ff\"\n");
    writeFile(home.path() + "/.config/omarchy/shell.json", R"({"bar":{"id":"omabar16","style":{"shape":"round","gap":6}}})");

    Bar bar([plugin] { return plugin; }, {}, home.path(), false);
    QVERIFY2(bar.available(), qPrintable(bar.error()));
    QCOMPARE(bar.themes().size(), 3);
    const auto pills = bar.themes().at(0).toMap();
    QCOMPARE(pills.value("group").toString(), QString("Originals"));
    QCOMPARE(pills.value("swatches").toStringList(), QStringList({"#abcdef", "#0000ff"}));
    QCOMPARE(bar.themes().at(1).toMap().value("swatches").toStringList(), QStringList({"#112233"}));
    QCOMPARE(bar.themes().at(2).toMap().value("group").toString(), QString("Yours"));
    QVERIFY(bar.themes().at(2).toMap().value("user").toBool());
    QCOMPARE(bar.layouts().at(0).toMap().value("counts").toString(), QString("1 · 0 · 2"));
    QCOMPARE(bar.layouts().at(1).toMap().value("group").toString(), QString("JaKooLit"));
    QCOMPARE(bar.layouts().at(2).toMap().value("group").toString(), QString("Side rails"));
    QCOMPARE(bar.glyphFor("omarchy.clock"), QString::fromUcs4(U"\U000F0954"));
    QVERIFY(bar.inUse());
    QCOMPARE(bar.currentTheme(), QString("pills"));
}

void OmacraftTests::barSaysWhenItIsNotTheBar()
{
    QTemporaryDir home;
    Bar bar({}, {}, home.path(), false);
    QVERIFY(!bar.available());
    QVERIFY(!bar.inUse());
    QCOMPARE(bar.barId(), QString("omarchy.bar"));
    bar.applyTheme("pills");
    QVERIFY(bar.error().contains("isn't your bar"));
}

void OmacraftTests::barReadsStudioPresetsWithImports()
{
    QTemporaryDir home;
    const QString plugin = home.path() + "/omabar16", studio = home.path() + "/studio";
    writeFile(plugin + "/data/Presets.js", "var THEMES = [{ id: \"own\", label: \"Own\", style: {} }]\nvar LAYOUTS = []\n");
    // Studio's copy pulls the HANCORE set in with a QML import.
    writeFile(studio + "/bar/data/Hancore.js", R"(.pragma library
var THEMES = [{ id: "hc-v1", label: "HANCORE V1", style: { shape: "block" } }]
var LAYOUTS = [{ id: "hc-v1", label: "HANCORE V1", layout: { left: [], center: [], right: [] } }]
)");
    writeFile(studio + "/bar/data/Presets.js", R"(.pragma library
.import "Hancore.js" as Hancore
var THEMES = [{ id: "a", label: "A", style: { shape: "arrow" } }]
var JAKOOLIT = []
var BASE16 = []
var HANCORE = Hancore.THEMES
var LAYOUTS = [{ id: "default", label: "Default", layout: { left: [], center: [], right: [] } }]
var ALL_LAYOUTS = LAYOUTS.concat(Hancore.LAYOUTS)
)");
    writeFile(studio + "/bar/data/Icons.js", "var RAW = {\n  fa: \"bell:f0f3;bell_o:f0a2;star:f005\",\n  oct: \"alert:f421\"\n}\n");
    Bar bar([plugin] { return plugin; }, [studio] { return studio; }, home.path(), false);
    QVERIFY2(bar.available(), qPrintable(bar.error()));
    QCOMPARE(bar.themes().size(), 2);
    QCOMPARE(bar.themes().at(1).toMap().value("group").toString(), QString("HANCORE"));
    QCOMPARE(bar.layouts().size(), 2);
    QCOMPARE(bar.layouts().at(1).toMap().value("group").toString(), QString("HANCORE"));
    QVERIFY(bar.hasIcons());
    const auto bells = bar.icons("fa", "bell");
    QCOMPARE(bells.size(), 2);
    QCOMPARE(bells.at(1).toMap().value("name").toString(), QString("bell o"));
    QCOMPARE(bells.at(0).toMap().value("glyph").toString(), QString::fromUcs4(U"\U0000F0F3"));
}

void OmacraftTests::barEditsShellJsonInPlaceWithUndo()
{
    QTemporaryDir home;
    const QString plugin = home.path() + "/plugin";
    writeFile(plugin + "/data/Presets.js", "var THEMES = [{ id: \"pills\", label: \"Pills\", style: { shape: \"round\", gap: 6 } }]\nvar LAYOUTS = []\n");
    const QString shell = home.path() + "/.config/omarchy/shell.json";
    writeFile(shell, R"({"version":1,"other":{"keep":true},"bar":{"id":"omabar16","position":"top",
        "layout":{"left":[{"id":"omarchy.menu"}],"center":[{"id":"omarchy.clock"}],"right":[]},"style":{"shape":"arrow"}}})");
    Bar bar([plugin] { return plugin; }, {}, home.path(), false);

    bar.applyTheme("pills");
    bar.flush();
    QJsonObject saved = readJson(shell);
    QVERIFY(saved.value("other").toObject().value("keep").toBool());
    QCOMPARE(saved.value("bar").toObject().value("style").toObject().value("gap").toInt(), 6);
    QCOMPARE(saved.value("bar").toObject().value("id").toString(), QString("omabar16"));
    QCOMPARE(bar.currentTheme(), QString("pills"));
    QVERIFY(bar.canUndo());
    QVERIFY(bar.edited());

    bar.undo();
    bar.flush();
    QCOMPARE(readJson(shell).value("bar").toObject().value("style").toObject().value("shape").toString(), QString("arrow"));
    QVERIFY(bar.canRedo());
    bar.redo();
    bar.flush();
    QCOMPARE(readJson(shell).value("bar").toObject().value("style").toObject().value("shape").toString(), QString("round"));

    // Widgets move between lanes; the anchor leaves with the clock.
    bar.moveWidget("center", 0, "right", 0);
    QCOMPARE(bar.centerAnchor(), QString());
    bar.addWidget("omarchy.spacer", "left");
    bar.setEntry("left", 1, "size", 30);
    bar.setEntry("right", 0, "format", "HH:mm");
    bar.flush();
    const QJsonObject layout = readJson(shell).value("bar").toObject().value("layout").toObject();
    QCOMPARE(layout.value("left").toArray().at(1).toObject().value("size").toInt(), 30);
    QCOMPARE(layout.value("right").toArray().at(0).toObject().value("format").toString(), QString("HH:mm"));
    bar.setEntry("right", 0, "format", "");
    QVERIFY(!bar.layout().value("right").toList().at(0).toMap().contains("format"));

    // Colours: a palette entry turns the named ones into what they show.
    bar.setColor("pal:1", "#123456");
    QCOMPARE(bar.style().value("palette").toList().at(1).toString(), QString("#123456"));
    bar.setColor("module:omarchy.menu", "#ff0000");
    QCOMPARE(bar.style().value("modules").toMap().value("omarchy.menu").toString(), QString("#ff0000"));
    bar.clearColor("module:omarchy.menu");
    QVERIFY(!bar.style().contains("modules"));

    bar.revert();
    bar.flush();
    QCOMPARE(readJson(shell).value("bar").toObject().value("style").toObject(), QJsonObject({{"shape", "arrow"}}));
    QVERIFY(!bar.edited());
}

void OmacraftTests::barLayoutsKeepWidgetSettings()
{
    QTemporaryDir home;
    const QString plugin = home.path() + "/plugin";
    writeFile(plugin + "/data/Presets.js", R"(var THEMES = [{ id: "a", label: "A", style: {} }]
var LAYOUTS = [{ id: "rail", label: "Rail", anchor: "omarchy.clock", position: "left",
  layout: { left: [{ id: "omarchy.menu" }], center: [{ id: "omarchy.clock", format: "HH:mm" }], right: [] } }]
)");
    const QString shell = home.path() + "/.config/omarchy/shell.json";
    writeFile(shell, R"({"bar":{"id":"omabar16","layout":{"left":[],"center":[],
        "right":[{"id":"omarchy.clock","format":"dddd"},{"id":"omacraft.folders","name":"Apps"}]}}})");
    Bar bar([plugin] { return plugin; }, {}, home.path(), false);
    bar.applyLayout("rail");
    const auto layout = bar.layout();
    QCOMPARE(bar.position(), QString("left"));
    QCOMPARE(bar.centerAnchor(), QString("omarchy.clock"));
    QCOMPARE(layout.value("center").toList().at(0).toMap().value("format").toString(), QString("dddd"));
    // Another plugin's widget comes along, on the right.
    QCOMPARE(layout.value("right").toList().at(0).toMap().value("id").toString(), QString("omacraft.folders"));
    QCOMPARE(bar.currentLayout(), QString());
}

void OmacraftTests::barHidesWidgetsAndBringsThemBack()
{
    QTemporaryDir home;
    const QString plugin = home.path() + "/plugin";
    writeFile(plugin + "/data/Presets.js", R"(var THEMES = [{ id: "a", label: "A", style: {} }]
var LAYOUTS = [{ id: "all", label: "All", anchor: "omarchy.clock",
  layout: { left: [{ id: "omarchy.menu" }], center: [{ id: "omarchy.clock" }], right: [{ id: "omarchy.audio" }] } }]
)");
    const QString shell = home.path() + "/.config/omarchy/shell.json";
    writeFile(shell, R"({"bar":{"id":"omabar16","centerAnchor":"omarchy.clock","layout":{"left":[{"id":"omarchy.menu","icon":"X"}],
        "center":[{"id":"omarchy.clock","format":"HH:mm"}],"right":[{"id":"omarchy.audio"},{"id":"omarchy.network"}]}}})");
    Bar bar([plugin] { return plugin; }, {}, home.path(), false);

    // Hidden: off the bar omabar16 draws, settings kept beside it.
    bar.hideWidget("left", 0);
    bar.hideWidget("center", 0);
    QCOMPARE(bar.layout().value("left").toList().size(), 0);
    QCOMPARE(bar.centerAnchor(), QString());
    QCOMPARE(bar.hidden().size(), 2);
    bar.flush();
    QJsonObject saved = readJson(shell).value("bar").toObject();
    QCOMPARE(saved.value("hidden").toArray().at(0).toObject().value("entry").toObject().value("icon").toString(), QString("X"));

    // A preset leaves hidden widgets hidden.
    bar.applyLayout("all");
    QCOMPARE(bar.layout().value("left").toList().size(), 0);
    QCOMPARE(bar.layout().value("center").toList().size(), 0);

    // Shown again: back in place, the clock the anchor again.
    bar.showWidget(1);
    QCOMPARE(bar.layout().value("center").toList().at(0).toMap().value("format").toString(), QString("HH:mm"));
    QCOMPARE(bar.centerAnchor(), QString("omarchy.clock"));
    // Or dropped somewhere else.
    bar.showWidget(0, "right", 1);
    QCOMPARE(bar.layout().value("right").toList().at(1).toMap().value("id").toString(), QString("omarchy.menu"));
    QVERIFY(bar.hidden().isEmpty());
    bar.flush();
    QVERIFY(!readJson(shell).value("bar").toObject().contains("hidden"));
}

void OmacraftTests::barAddsOmarchyAndBase16Themes()
{
    QTemporaryDir home;
    const QString plugin = home.path() + "/plugin";
    writeFile(plugin + "/data/Presets.js", R"(var THEMES = [{ id: "a", label: "A", style: {} }]
var BASE16 = [{ id: "base16-nord", label: "Nord", style: { shape: "arrow" } }, { id: "base16-ocean", label: "Ocean", style: {} }]
var LAYOUTS = []
)");
    const QString themes = home.path() + "/omarchy-themes";
    writeFile(themes + "/tokyo-night/colors.toml", "accent = \"#7aa2f7\"\nbackground = \"#1a1b26\"\nforeground = \"#a9b1d6\"\n"
                                                    "magenta = \"#ad8ee6\"\ncyan = \"#449dab\"\n");
    writeFile(themes + "/white/colors.toml", "accent = \"#6e6e6e\"\nbackground = \"#ffffff\"\nforeground = \"#111111\"\n");
    qputenv("OMACRAFT_OMARCHY_THEMES", themes.toUtf8());
    Bar bar([plugin] { return plugin; }, {}, home.path(), false);
    qputenv("OMACRAFT_OMARCHY_THEMES", "/nonexistent");

    QVariantMap tokyo, white;
    QStringList base16;
    for (const auto &value : bar.themes()) {
        const auto theme = value.toMap();
        if (theme.value("id") == "omarchy-theme-tokyo-night") tokyo = theme;
        if (theme.value("id") == "omarchy-theme-white") white = theme;
        if (theme.value("group") == "base16") base16 << theme.value("label").toString();
    }
    // Only the Omarchy themes that are installed, in their own colours.
    QCOMPARE(tokyo.value("group").toString(), QString("Omarchy"));
    const auto style = tokyo.value("style").toMap();
    QCOMPARE(style.value("bg").toString(), QString("#1a1b26"));
    QCOMPARE(style.value("palette").toList().at(1).toString(), QString("#ad8ee6"));
    // Its own background as ink, where that reads: dark on blue chevrons,
    // white on grey pills.
    QCOMPARE(style.value("fg").toString(), QString("#1a1b26"));
    QCOMPARE(white.value("style").toMap().value("fg").toString(), QString("#ffffff"));
    QVERIFY(!bar.themes().isEmpty());

    // More base16, one of each name, A to Z: the plugin's Ocean stays.
    QVERIFY(base16.contains("Tokyo Night Storm"));
    QCOMPARE(base16.count("Ocean"), 1);
    QStringList sorted = base16;
    std::sort(sorted.begin(), sorted.end(), [](const QString &a, const QString &b) { return a.compare(b, Qt::CaseInsensitive) < 0; });
    QCOMPARE(base16, sorted);
    QVERIFY(base16.size() > 20);
}

void OmacraftTests::edgeTabFollowsThePointerRoundTheEdge()
{
    const QSizeF screen(1000, 800);
    // Upright on the sides, lying down along the top and bottom.
    QCOMPARE(EdgeTab::placement("right", 0.5, screen, QSizeF(40, 120)), QRectF(960, 340, 40, 120));
    QCOMPARE(EdgeTab::placement("bottom", 0, screen, QSizeF(120, 40)), QRectF(0, 760, 120, 40));
    QCOMPARE(EdgeTab::placement("left", 2, screen, QSizeF(40, 120)), QRectF(0, 680, 40, 120));

    // The nearest edge takes it, the grab point staying under the pointer.
    auto [edge, offset] = EdgeTab::nearest(QPointF(990, 400), QPointF(20, 60), screen, QSizeF(40, 120));
    QCOMPARE(edge, QString("right"));
    QCOMPARE(EdgeTab::placement(edge, offset, screen, QSizeF(40, 120)).y(), 340.0);
    std::tie(edge, offset) = EdgeTab::nearest(QPointF(500, 795), QPointF(20, 60), screen, QSizeF(40, 120));
    QCOMPARE(edge, QString("bottom"));
    QCOMPARE(EdgeTab::placement(edge, offset, screen, QSizeF(120, 40)).x(), 480.0);
    std::tie(edge, offset) = EdgeTab::nearest(QPointF(5, -50), QPointF(20, 0), screen, QSizeF(40, 120));
    QCOMPARE(edge, QString("top"));
    QCOMPARE(offset, 0.0);

    // Where it's left is where it comes back.
    QTemporaryDir home;
    writeFile(home.path() + "/.config/omacraft/edge-tab.json", R"({"edge":"bottom","offset":0.25})");
    EdgeTab tab(home.path());
    QCOMPARE(tab.edge(), QString("bottom"));
    QCOMPARE(tab.offset(), 0.25);
    writeFile(home.path() + "/.config/omacraft/edge-tab.json", R"({"edge":"sideways","offset":9})");
    EdgeTab bad(home.path());
    QCOMPARE(bad.edge(), QString("bottom"));
    QCOMPARE(bad.offset(), 1.0);

    // Its look is set by name, kept in range, and comes back too.
    bad.setOption("edge", "left");
    bad.setOption("length", 9999);
    bad.setOption("thickness", 2);
    bad.setOption("opacity", 0.5);
    bad.setOption("showIcon", false);
    bad.setOption("title", "  Craft  ");
    bad.setOption("nonsense", 1);
    EdgeTab again(home.path());
    QCOMPARE(again.edge(), QString("left"));
    QCOMPARE(again.length(), 400);
    QCOMPARE(again.thickness(), 24);
    QCOMPARE(again.opacity(), 0.5);
    QCOMPARE(again.showIcon(), false);
    QCOMPARE(again.showTitle(), true);
    QCOMPARE(again.title(), QString("Craft"));
    again.reset();
    QCOMPARE(EdgeTab(home.path()).length(), 150);
}

void OmacraftTests::introReelDrawsTheTitleItsOwnWay()
{
    // The boot design's colours, but the word, its font and no picture or frame.
    const QVariantMap config = IntroReel::titleConfig(QVariantMap{
        {"source", "image"}, {"image", "/tmp/x.png"}, {"text", "Hello"}, {"font", "TDF x"},
        {"border", "rounded"}, {"color", "accent"}, {"colorMode", "split"}, {"shadow", "drop"}});
    QCOMPARE(config.value("source").toString(), QString("text"));
    QCOMPARE(config.value("text").toString(), QString("OMACRAFT"));
    QCOMPARE(config.value("shadow").toString(), QString("none"));
    // balistcx once the TheDraw fonts are there, a FIGlet font until then.
    QTemporaryDir fonts;
    qputenv("OMASCII_TDF_DIR", fonts.path().toUtf8());
    QCOMPARE(IntroReel::titleFont(), QString("ANSI Shadow"));
    QFile font(fonts.path() + "/balistcx.tdf");
    QVERIFY(font.open(QIODevice::WriteOnly));
    font.close();
    QCOMPARE(IntroReel::titleFont(), QString("TDF balistcx"));
    qunsetenv("OMASCII_TDF_DIR");
    QCOMPARE(config.value("border").toString(), QString("none"));
    QCOMPARE(config.value("color").toString(), QString("accent"));
    QCOMPARE(config.value("inkBg").toString(), QString("none"));

    // Each effect is cached on its own, in the cache folder it was given.
    QTemporaryDir cache;
    Omascii omascii([] { return QString(); });
    IntroReel reel(&omascii, cache.path());
    QVERIFY(reel.cachePath("decrypt").startsWith(cache.path() + "/decrypt-"));
    QVERIFY(reel.cachePath("decrypt") != reel.cachePath("matrix"));
    QCOMPARE(reel.cachePath("decrypt"), reel.cachePath("decrypt"));
    QVERIFY(!reel.available());
}

void OmacraftTests::barThemesSaveImportAndSanitize()
{
    const QJsonObject clean = Bar::sanitizeStyle(QJsonObject{
        {"shape", "round"}, {"gap", 4}, {"bg", "#112233"}, {"fg", "red"}, {"solid", "yes"},
        {"palette", QJsonArray{"accent", "#abcdef", 3}}, {"modules", QJsonObject{{"a", "#000000"}, {"b", "x"}}},
        {"exec", "rm -rf ~"}});
    QCOMPARE(clean, QJsonObject({{"shape", "round"}, {"gap", 4}, {"bg", "#112233"},
                                 {"palette", QJsonArray{"accent", "#abcdef"}}, {"modules", QJsonObject{{"a", "#000000"}}}}));
    QCOMPARE(Bar::parseThemes(R"({"omabar16":1,"themes":[{"label":"X","style":{"shape":"hex"}},{"label":"no style"}]})").size(), 1);
    QCOMPARE(Bar::parseThemes(R"({"name":"Bare","style":{"gap":2}})").at(0).toObject().value("label").toString(), QString("Bare"));

    QTemporaryDir home;
    const QString plugin = home.path() + "/plugin";
    writeFile(plugin + "/data/Presets.js", "var THEMES = [{ id: \"a\", label: \"A\", style: {} }]\nvar LAYOUTS = []\n");
    writeFile(home.path() + "/.config/omarchy/shell.json", R"({"bar":{"id":"omabar16","style":{"shape":"hex","gap":3}}})");
    Bar bar([plugin] { return plugin; }, {}, home.path(), false);
    QVERIFY(bar.saveTheme("My Hex"));
    QCOMPARE(bar.themes().last().toMap().value("id").toString(), QString("user-my-hex"));
    QCOMPARE(bar.currentTheme(), QString("user-my-hex"));
    bar.importThemes(R"([{"label":"Pasted","style":{"shape":"leaf"}}])");
    QCOMPARE(bar.themes().size(), 3);
    bar.exportTheme("");
    QVERIFY(QFileInfo::exists(home.path() + "/.config/omarchy/omabar16/exports/my-bar.json"));
    bar.deleteTheme("user-my-hex");
    QCOMPARE(bar.themes().size(), 2);
}

// --- omascii ---

void OmacraftTests::omasciiChecksBeforeApplying()
{
    QVERIFY(Omascii::applyProblem({{"style", "animated"}, {"effects", QVariantList()}, {"text", "x"}}).contains("intro effect"));
    QVERIFY(Omascii::applyProblem({{"style", "static"}, {"source", "image"}, {"image", ""}}).contains("image"));
    QVERIFY(Omascii::applyProblem({{"style", "static"}, {"source", "text"}, {"text", "  "}}).contains("text"));
    QCOMPARE(Omascii::applyProblem({{"style", "animated"}, {"effects", QVariantList{"burn"}}, {"text", "Hi"}}), QString());
}

void OmacraftTests::omasciiReadsEveryFontList()
{
    const auto figlet = Omascii::parseFonts(R"([{"name":"Big","height":8,"extra":false}])");
    QCOMPARE(figlet.at(0).toMap().value("detail").toString(), QString("8 rows"));
    const auto tdf = Omascii::parseFonts(R"([{"name":"TDF a #1","type":"color","title":"Blue"}])");
    QCOMPARE(tdf.at(0).toMap().value("detail").toString(), QString("Blue · colour"));
    const auto ttf = Omascii::parseFonts(R"([{"name":"TTF Mono Bold","file":"/x.ttf","source":"system"}])");
    QCOMPARE(ttf.at(0).toMap().value("name").toString(), QString("TTF Mono Bold"));
    QCOMPARE(ttf.at(0).toMap().value("detail").toString(), QString("system"));
}

// --- hyprcraft ---

void OmacraftTests::hyprcraftServesOnlyTheApp()
{
    QTemporaryDir root;
    writeFile(root.path() + "/app/index.html", "<html>");
    writeFile(root.path() + "/app/assets/index.js", "1");
    writeFile(root.path() + "/secret.txt", "no");
    const QString app = root.path() + "/app";
    const QString canonical = QFileInfo(app).canonicalFilePath();

    QCOMPARE(HyprCraft::resolve(app, "/"), canonical + "/index.html");
    QCOMPARE(HyprCraft::resolve(app, "/assets/index.js"), canonical + "/assets/index.js");
    QCOMPARE(HyprCraft::resolve(app, "/../secret.txt"), QString());
    QCOMPARE(HyprCraft::resolve(app, "/assets/../../secret.txt"), QString());
    QCOMPARE(HyprCraft::resolve(app, "/missing.js"), QString());
    QCOMPARE(HyprCraft::resolve(QString(), "/index.html"), QString());

    QCOMPARE(HyprCraft::mimeType("a.js"), QByteArray("text/javascript"));
    QCOMPARE(HyprCraft::mimeType("b.CSS"), QByteArray("text/css"));
    QCOMPARE(HyprCraft::mimeType("c.unknown"), QByteArray("application/octet-stream"));
}

void OmacraftTests::hyprcraftFindsTheFirstBuild()
{
    QTemporaryDir root;
    writeFile(root.path() + "/second/index.html", "<html>");
    HyprCraft hyprcraft([&root] { return QStringList{root.path() + "/first", root.path() + "/second"}; });
    QVERIFY(hyprcraft.available());
    QCOMPARE(hyprcraft.appDir(), QFileInfo(root.path() + "/second").canonicalFilePath());
}

int runOmacraftTests(int argc, char **argv)
{
    OmacraftTests tests;
    return QTest::qExec(&tests, argc, argv);
}


// --- launcher (Launcher) ---

namespace {

ino_t inodeOf(const QString &path) {
    struct stat info {};
    return ::stat(QFile::encodeName(path).constData(), &info) == 0 ? info.st_ino : 0;
}

void writeLauncherStyles(const QString &pluginDir) {
    writeFile(pluginDir + "/LauncherStyles.js", R"(.pragma library
var layouts = [ { id: "classic", name: "Classic", kind: "classic" }, { id: "dock", name: "Dock", kind: "strip" } ]
var schemes = [ { id: "omarchy", name: "Omarchy theme" }, { id: "nord", name: "Nord", bg: "#2e3440" } ]
var transitions = [ { id: "auto", name: "Layout's own" }, { id: "pop", name: "Pop", ms: 320, scale: 0.55 } ]
function layout(id) { return layouts[0] }
)");
}

} // namespace

void OmacraftTests::launcherReadsItsStyles()
{
    QTemporaryDir home;
    const QString plugin = home.path() + "/studio";
    writeLauncherStyles(plugin);
    Launcher launcher([plugin] { return plugin; }, home.path(), false);
    QVERIFY(launcher.available());
    QCOMPARE(launcher.layouts().size(), 2);
    QCOMPARE(launcher.schemes().at(1).toMap().value("bg").toString(), QString("#2e3440"));
    QCOMPARE(launcher.transitions().at(1).toMap().value("ms").toInt(), 320);
    // Nothing saved yet: the launcher's own defaults.
    QCOMPARE(launcher.layout(), QString("classic"));
    QCOMPARE(launcher.transition(), QString("auto"));
    QCOMPARE(launcher.speed(), 1.0);
    QVERIFY(launcher.animateLayouts());

    Launcher missing([] { return QString(); }, home.path(), false);
    QVERIFY(!missing.available());
}

void OmacraftTests::launcherWritesInPlaceAndKeepsOtherKeys()
{
    QTemporaryDir home;
    const QString plugin = home.path() + "/studio";
    writeLauncherStyles(plugin);
    const QString style = home.path() + "/.config/omarchy/launcher-style.json";
    writeFile(style, R"({"layout": "classic", "scheme": "omarchy", "someoneElses": 7})");
    const auto inode = inodeOf(style);

    Launcher launcher([plugin] { return plugin; }, home.path(), false);
    launcher.setLayout("dock");
    launcher.setTransition("pop");
    launcher.setSpeed(9);
    launcher.setAnimateColors(false);
    launcher.setScheme("no-such-scheme");
    QVERIFY(!launcher.error().isEmpty());

    QFile file(style);
    QVERIFY(file.open(QIODevice::ReadOnly));
    const auto saved = QJsonDocument::fromJson(file.readAll()).object();
    QCOMPARE(saved.value("layout").toString(), QString("dock"));
    QCOMPARE(saved.value("scheme").toString(), QString("omarchy"));
    QCOMPARE(saved.value("transition").toString(), QString("pop"));
    QCOMPARE(saved.value("speed").toDouble(), 3.0);
    QCOMPARE(saved.value("animateColors").toBool(true), false);
    QCOMPARE(saved.value("someoneElses").toInt(), 7);
    // The same file, rewritten, so the shell's watcher stays on it.
    QCOMPARE(inodeOf(style), inode);
}

static void writeBurnEffects(const QString &plugin)
{
    writeFile(plugin + "/effects.json", R"({"effects": [
        {"id": "fire", "name": "Fire", "pad": 0.12, "duration": 1500, "color": "#ff7a1a"},
        {"id": "doom", "name": "Doom", "pad": 0, "duration": 1300},
        {"id": "glide", "name": "Glide", "pad": 0, "duration": 450}
    ]})");
}

void OmacraftTests::wallPickerNormalizesKeys()
{
    QCOMPARE(WallPicker::normalizeKey("super alt w"), QString("SUPER + ALT + W"));
    QCOMPARE(WallPicker::normalizeKey("ALT+SUPER+w"), QString("SUPER + ALT + W"));
    QCOMPARE(WallPicker::normalizeKey("Win + Control + comma"), QString("SUPER + CTRL + comma"));
    QCOMPARE(WallPicker::normalizeKey("SUPER + code:201"), QString("SUPER + code:201"));
    QCOMPARE(WallPicker::normalizeKey("SUPER + ALT"), QString());
    QCOMPARE(WallPicker::normalizeKey("SUPER + W + Q"), QString());
    QCOMPARE(WallPicker::normalizeKey("SUPER + \"\")"), QString());
    QCOMPARE(WallPicker::normalizeKey(""), QString());
}

void OmacraftTests::wallPickerBindsThroughHyprlandLua()
{
    QTemporaryDir home;
    const QString main = home.path() + "/.config/hypr/hyprland.lua";
    writeFile(main, "require(\"hypr.bindings\")\n");

    WallPicker picker(home.path(), false);
    QVERIFY(!picker.bound());
    QVERIFY(!picker.bind("SUPER + ALT"));
    QVERIFY(!picker.error().isEmpty());

    QVERIFY(picker.bind("super alt w"));
    QCOMPARE(picker.key(), QString("SUPER + ALT + W"));
    QVERIFY(picker.error().isEmpty());
    QFile keys(picker.keysPath());
    QVERIFY(keys.open(QIODevice::ReadOnly));
    const QString file = QString::fromUtf8(keys.readAll());
    QVERIFY(file.contains("hl.unbind(\"SUPER + ALT + W\")"));
    QVERIFY(file.contains(R"(o.bind("SUPER + ALT + W", "Wallpaper picker", "omarchy-shell shell toggle omacraft.wallpicker '{\"tab\":\"library\"}'"))"));
    QCOMPARE(WallPicker::keyIn(file), QString("SUPER + ALT + W"));

    // hyprland.lua gains the require once, with a copy kept of how it was.
    QVERIFY(picker.bind("SUPER + CTRL + ALT + P"));
    QFile hypr(main);
    QVERIFY(hypr.open(QIODevice::ReadOnly));
    QCOMPARE(QString::fromUtf8(hypr.readAll()).count("hypr.omacraft_wallpicker"), 1);
    QCOMPARE(QDir(home.path() + "/.config/hypr").entryList({"hyprland.lua.before-wallpicker-*"}).size(), 1);

    // A fresh look at the file finds the key again; removing it leaves none.
    WallPicker again(home.path(), false);
    QCOMPARE(again.key(), QString("SUPER + CTRL + ALT + P"));
    again.unbind();
    QVERIFY(!again.bound());
    WallPicker after(home.path(), false);
    QVERIFY(!after.bound());

    QCOMPARE(WallPicker::summonArguments("library").value(3), QString(R"({"tab":"library"})"));
}

void OmacraftTests::burnReadsItsEffects()
{
    QTemporaryDir home;
    const QString plugin = home.path() + "/burn";
    writeBurnEffects(plugin);
    Burn burn([plugin] { return plugin; }, home.path(), false);
    QVERIFY(burn.available());
    QCOMPARE(burn.effects().size(), 3);
    QCOMPARE(burn.shaderDir(), plugin + "/shaders");
    // Nothing saved yet: the plugin's own defaults.
    QVERIFY(burn.enabled());
    QCOMPARE(burn.closeEffects(), QStringList{"fire"});
    QCOMPARE(burn.openEffects(), QStringList{"glide"});
    QCOMPARE(burn.exclude(), QStringList{"org.omarchy.screensaver"});
    QVERIFY(burn.skipFullscreen());
    QVERIFY(!burn.keysInstalled());

    Burn missing([] { return QString(); }, home.path(), false);
    QVERIFY(!missing.available());
}

void OmacraftTests::burnWritesInPlaceAndKeepsOtherKeys()
{
    QTemporaryDir home;
    const QString plugin = home.path() + "/burn";
    writeBurnEffects(plugin);
    const QString path = home.path() + "/.config/omarchy/burn-my-windows.json";
    writeFile(path, R"({"close": {"effects": ["fire"], "speed": 1, "theirs": 1}, "someoneElses": 7})");
    const auto inode = inodeOf(path);

    Burn burn([plugin] { return plugin; }, home.path(), false);
    burn.toggleEffect("close", "doom");
    QCOMPARE(burn.closeEffects(), (QStringList{"fire", "doom"}));
    burn.toggleEffect("close", "fire");
    burn.toggleEffect("close", "doom"); // the last one stays
    QCOMPARE(burn.closeEffects(), QStringList{"doom"});
    burn.toggleEffect("open", "random");
    QCOMPARE(burn.openEffects(), QStringList{"random"});
    burn.toggleEffect("open", "fire"); // picking one ends "any"
    QCOMPARE(burn.openEffects(), QStringList{"fire"});
    burn.setSpeed("close", 9);
    QCOMPARE(burn.closeSpeed(), 3.0);
    burn.setIntensity(0.01);
    QCOMPARE(burn.intensity(), 0.25);
    burn.setColor("#38ff6a");
    burn.addExclude("  org.gnome.Calculator ");
    burn.addExclude("org.gnome.Calculator");
    burn.removeExclude("org.omarchy.screensaver");
    QCOMPARE(burn.exclude(), QStringList{"org.gnome.Calculator"});
    burn.setSideEnabled("open", false);
    QVERIFY(!burn.openEnabled());

    QVERIFY(burn.error().isEmpty());
    burn.setColor("pink");
    QVERIFY(!burn.error().isEmpty());
    burn.setEffects("close", {"no-such-effect"});
    QCOMPARE(burn.closeEffects(), QStringList{"doom"});

    QFile file(path);
    QVERIFY(file.open(QIODevice::ReadOnly));
    const auto saved = QJsonDocument::fromJson(file.readAll()).object();
    QCOMPARE(saved.value("someoneElses").toInt(), 7);
    QCOMPARE(saved.value("close").toObject().value("theirs").toInt(), 1);
    QCOMPARE(saved.value("color").toString(), QString("#38ff6a"));
    // The shell watches this file, so it is rewritten, not replaced.
    QCOMPARE(inodeOf(path), inode);
}

void OmacraftTests::wallpaperKnowsAFavoriteByAnyName()
{
    // A Wallhaven wallpaper's id, page and downloaded file share one key.
    QCOMPARE(Wallpaper::favoriteKey("0jk5vq"), QString("0jk5vq"));
    QCOMPARE(Wallpaper::favoriteKey("https://wallhaven.cc/w/0jk5vq"), QString("0jk5vq"));
    QCOMPARE(Wallpaper::favoriteKey("/home/me/Pictures/Wallhaven/wallhaven-0jk5vq.jpg"), QString("0jk5vq"));
    QCOMPARE(Wallpaper::favoriteKey("https://w.wallhaven.cc/full/0j/wallhaven-0jk5vq.png"), QString("0jk5vq"));
    // Anything else by its full path.
    QTemporaryDir dir;
    writeFile(dir.path() + "/sunset.png", "x");
    QCOMPARE(Wallpaper::favoriteKey(dir.path() + "/sunset.png"), QFileInfo(dir.path() + "/sunset.png").canonicalFilePath());
}

void OmacraftTests::wallpaperMergesPagesWithoutRepeats()
{
    auto page = [](const QStringList &ids) {
        QVariantList out;
        for (const auto &id : ids)
            out.append(QVariantMap{{"id", id}});
        return out;
    };
    const QVariantList first = Wallpaper::mergeResults({}, page({"a", "b", "c"}), true);
    QCOMPARE(first.size(), 3);
    // A toplist shifts between pages: "c" comes round again and is dropped.
    const QVariantList second = Wallpaper::mergeResults(first, page({"c", "d"}), false);
    QCOMPARE(second.size(), 4);
    QCOMPARE(second.last().toMap().value("id").toString(), QString("d"));
    // A new search starts over.
    QCOMPARE(Wallpaper::mergeResults(second, page({"z"}), true).size(), 1);
}

void OmacraftTests::wallpaperWritesInOrderAndFlipsAtOnce()
{
    // A stand-in hyprskin that logs every call.
    QTemporaryDir dir;
    const QString plugin = dir.path() + "/studio";
    const QString log = dir.path() + "/calls.log";
    writeFile(plugin + "/bin/hyprskin",
              QString("import json, sys\n"
                      "open(%1, 'a').write(json.dumps(sys.argv[1:]) + '\\n')\n"
                      "print('[]' if sys.argv[1:2] in (['library'], ['favorites']) else '{}')\n")
                  .arg("'" + log + "'").toUtf8());
    Wallpaper wallpaper([plugin] { return plugin; });
    QVERIFY(wallpaper.available());

    wallpaper.toggleFavorite("0jk5vq", QVariantMap{{"url", "https://wallhaven.cc/w/0jk5vq"}, {"views", 9}});
    // The heart answers before hyprskin does.
    QVERIFY(wallpaper.isFavorite("https://wallhaven.cc/w/0jk5vq"));
    QVERIFY(wallpaper.favoriteKeys().contains("0jk5vq"));
    wallpaper.deleteFromLibrary("/lib/wallhaven-0jk5vq.jpg");
    wallpaper.setOption("palette.scheme", "matugen");
    wallpaper.setOption("rotation.interval", 15);
    wallpaper.setOption("targets.terminals", false);

    QStringList writes;
    QTRY_VERIFY_WITH_TIMEOUT(([&] {
        writes.clear();
        QFile file(log);
        if (file.open(QIODevice::ReadOnly))
            for (const auto &line : QString::fromUtf8(file.readAll()).split('\n', Qt::SkipEmptyParts)) {
                const QStringList call = QJsonDocument::fromJson(line.toUtf8()).toVariant().toStringList();
                if (QStringList{"favorite", "delete", "set"}.contains(call.value(0)))
                    writes << call.mid(0, 3).join(' ');
            }
        return writes.size() == 5;
    }()), 15000);
    QCOMPARE(writes, (QStringList{
        "favorite add 0jk5vq",
        "delete /lib/wallhaven-0jk5vq.jpg",
        "set palette.scheme \"matugen\"",
        "set rotation.interval 15",
        "set targets.terminals false",
    }));
    // Only what a favourite needs is kept from the search result.
    QFile file(log);
    QVERIFY(file.open(QIODevice::ReadOnly));
    QVERIFY(file.readAll().contains(R"(\"url\":\"https://wallhaven.cc/w/0jk5vq\")"));
}

void OmacraftTests::hyprcraftKnowsAnOmarchyBundle()
{
    QVERIFY(HyprCraft::isOmarchyBundle("/home/me/Downloads/HyprCraft/hyprcraft-nord-omarchy.zip"));
    QVERIFY(!HyprCraft::isOmarchyBundle("/home/me/Downloads/HyprCraft/hyprcraft-dotfiles.zip"));
    QVERIFY(!HyprCraft::isOmarchyBundle("/home/me/Downloads/HyprCraft/hyprland.lua"));
}

namespace {
// A bar with the tray, one folder and the clock, as shell.json has it.
QByteArray shellWithAFolder() {
    QJsonObject folder{{"id", "omacraft.folders"}, {"name", "Games"}, {"apps", QJsonArray{"steam"}}};
    QJsonObject layout{{"left", QJsonArray{QJsonObject{{"id", "omarchy.menu"}}}},
                       {"center", QJsonArray{QJsonObject{{"id", "omarchy.clock"}, {"format", "HH:mm"}}}},
                       {"right", QJsonArray{QJsonObject{{"id", "omarchy.tray"}}, folder}}};
    return QJsonDocument(QJsonObject{{"version", 1}, {"bar", QJsonObject{{"position", "top"}, {"layout", layout}}}})
        .toJson();
}
}

void OmacraftTests::foldersReadTheirBarEntries()
{
    const QVariantList found = Folders::foldersIn(QJsonDocument::fromJson(shellWithAFolder()).object());
    QCOMPARE(found.size(), 1);
    const QVariantMap folder = found.first().toMap();
    QCOMPARE(folder.value("section").toString(), QString("right"));
    QCOMPARE(folder.value("index").toInt(), 1);
    QCOMPARE(folder.value("apps").toStringList(), QStringList{"steam"});
}

void OmacraftTests::foldersScanInstalledApps()
{
    QTemporaryDir dir;
    const QString user = dir.path() + "/user/applications";
    const QString system = dir.path() + "/system/applications";
    writeFile(system + "/steam.desktop", "[Desktop Entry]\nType=Application\nName=Steam\nIcon=steam\nComment=Games\n");
    writeFile(system + "/hidden.desktop", "[Desktop Entry]\nType=Application\nName=Hidden\nNoDisplay=true\n");
    writeFile(system + "/link.desktop", "[Desktop Entry]\nType=Link\nName=A link\n");
    // A user copy hides the system one with the same id.
    writeFile(user + "/steam.desktop", "[Desktop Entry]\nType=Application\nName=Steam (mine)\nIcon=steam\n");
    // Subfolders join with a dash, as the desktop-entry spec has it.
    writeFile(system + "/kde/org.kde.dolphin.desktop", "[Desktop Entry]\nType=Application\nName=Dolphin\n[Desktop Action new]\nName=New window\n");
    const QVariantList apps = Folders::scanApplications({user, system});
    QStringList ids, names;
    for (const auto &app : apps) {
        ids << app.toMap().value("id").toString();
        names << app.toMap().value("name").toString();
    }
    QCOMPARE(ids, (QStringList{"kde-org.kde.dolphin", "steam"}));
    QCOMPARE(names, (QStringList{"Dolphin", "Steam (mine)"}));
}

void OmacraftTests::foldersEditShellJsonInPlace()
{
    QTemporaryDir home;
    const QString shell = home.path() + "/.config/omarchy/shell.json";
    writeFile(shell, shellWithAFolder());
    const auto inode = inodeOf(shell);
    Folders folders(home.path(), {home.path() + "/apps"});
    QCOMPARE(folders.folders().size(), 1);

    const int added = folders.add("Dev", "left");
    QCOMPARE(added, 1);
    folders.addApp("left", 1, "code.desktop");
    folders.addApp("left", 1, "code");          // already there
    folders.addApp("left", 1, "org.gnome.Nautilus");
    folders.addCommand("left", 1, "Top", "", "alacritty -e btop");
    folders.moveApp("left", 1, 2, -1);           // the command before Nautilus
    folders.update("left", 1, {{"open", "hover"}, {"showLabel", true}, {"id", "evil.widget"}});
    folders.removeApp("right", 1, 0);            // Games loses steam
    folders.moveTo("right", 1, "center");        // Games after the clock

    QCOMPARE(inodeOf(shell), inode);             // rewritten, not replaced
    const QJsonObject saved = readJson(shell);
    const QJsonObject layout = saved.value("bar").toObject().value("layout").toObject();
    const QJsonObject dev = layout.value("left").toArray().at(1).toObject();
    QCOMPARE(dev.value("id").toString(), QString("omacraft.folders"));   // id isn't editable
    QCOMPARE(dev.value("name").toString(), QString("Dev"));
    QCOMPARE(dev.value("open").toString(), QString("hover"));
    QVERIFY(dev.value("showLabel").toBool());
    const QJsonArray apps = dev.value("apps").toArray();
    QCOMPARE(apps.size(), 3);
    QCOMPARE(apps.at(0).toString(), QString("code"));
    QCOMPARE(apps.at(1).toObject().value("command").toString(), QString("alacritty -e btop"));
    QCOMPARE(apps.at(1).toObject().value("icon").toString(), QString("utilities-terminal"));
    QCOMPARE(apps.at(2).toString(), QString("org.gnome.Nautilus"));
    const QJsonArray center = layout.value("center").toArray();
    QCOMPARE(center.size(), 2);
    QCOMPARE(center.at(0).toObject().value("format").toString(), QString("HH:mm"));  // others untouched
    QCOMPARE(center.at(1).toObject().value("name").toString(), QString("Games"));
    QVERIFY(center.at(1).toObject().value("apps").toArray().isEmpty());
    QCOMPARE(layout.value("right").toArray().size(), 1);
    QCOMPARE(saved.value("version").toInt(), 1);

    // Whatever is at a place that isn't a folder is refused, not overwritten.
    folders.remove("right", 0);
    QVERIFY(!folders.error().isEmpty());
    QCOMPARE(readJson(shell).value("bar").toObject().value("layout").toObject().value("right").toArray().size(), 1);

    folders.remove("center", 1);
    QCOMPARE(folders.folders().size(), 1);
}

void OmacraftTests::themeFollowsLightAndDark()
{
    QTemporaryDir dir;
    const QString colors = dir.path() + "/theme/colors.toml";
    writeFile(colors, "mode = \"light\"\nbackground = \"#fffcf0\"\nforeground = \"#100f0f\"\naccent = \"#205ea6\"\nred = \"#af3029\"\n");
    Theme light(dir.path());
    QVERIFY(!light.dark());
    QCOMPARE(light.window(), QColor("#fffcf0"));
    QCOMPARE(light.text(), QColor("#100f0f"));
    QCOMPARE(light.accent(), QString("#205ea6"));
    // Surfaces step from the background towards the text, so on a light
    // theme every layer is darker than the window, and text stays readable.
    QVERIFY(light.card().lightnessF() < light.window().lightnessF());
    QVERIFY(light.border().lightnessF() < light.card().lightnessF());
    QVERIFY(light.textMuted().lightnessF() > light.text().lightnessF());

    // No mode: told by the background.
    writeFile(colors, "background = \"#1a1b26\"\nforeground = \"#c0caf5\"\naccent = \"#7aa2f7\"\n");
    Theme dark(dir.path());
    QVERIFY(dark.dark());
    QVERIFY(dark.card().lightnessF() > dark.window().lightnessF());
    // A missing red falls back, still readable on the background.
    QVERIFY(dark.danger().isValid());

    // A foreground too close to the background is pushed until it reads.
    writeFile(colors, "mode = \"dark\"\nbackground = \"#202020\"\nforeground = \"#303030\"\n");
    Theme murky(dir.path());
    QVERIFY(murky.text().lightnessF() > 0.6);
}

// --- theme sync ---

void OmacraftTests::barUnderlineTextReadsOnTheBar()
{
    const QHash<QString, QString> theme{{"background", "#1a1b26"}, {"foreground", "#c0caf5"}};
    auto bar = [](const QJsonObject &style, bool transparent = false) {
        return QJsonObject{{"id", "omabar16"}, {"style", style}, {"transparent", transparent}};
    };
    // A theme's dark segment ink on its own dark bar: moved to read there.
    const QJsonObject dark{{"shape", "underline"}, {"bg", "#16161e"}, {"fg", "#16161e"}};
    const QString ink = Bar::underlineInk(bar(dark), theme);
    QVERIFY(!ink.isEmpty());
    QVERIFY(Theme::contrastRatio(QColor(ink), QColor("#16161e")) >= 4.5);
    // Already readable, or not underlined, or on the wallpaper: left alone.
    QCOMPARE(Bar::underlineInk(bar({{"shape", "underline"}, {"bg", "#000000"}, {"fg", "#e8e8e8"}}), theme), QString());
    QCOMPARE(Bar::underlineInk(bar({{"shape", "arrow"}, {"bg", "#16161e"}, {"fg", "#16161e"}}), theme), QString());
    QCOMPARE(Bar::underlineInk(bar(dark, true), theme), QString());
    // A light bar gets dark text, and a stricter minimum is kept.
    const QString onLight = Bar::underlineInk(bar({{"shape", "underline"}, {"bg", "#dce2ea"}, {"fg", "#eeeeee"},
                                                   {"minContrast", 7}}), theme);
    QVERIFY(Theme::contrastRatio(QColor(onLight), QColor("#dce2ea")) >= 7);
}

void OmacraftTests::themeSyncBuildsABorderGradient()
{
    const QHash<QString, QString> colors{{"background", "#1a1b26"}, {"accent", "#7aa2f7"}, {"blue", "#7aa2f7"},
                                         {"magenta", "#bb9af7"}, {"cyan", "#1a1c27"}, {"green", "#9ece6a"},
                                         {"yellow", "#e0af68"}};
    // The accent first, the blue that repeats it and the cyan lost in the
    // background left out, four at most.
    QCOMPARE(ThemeSync::borderColors(colors), (QStringList{"7aa2f7", "bb9af7", "9ece6a", "e0af68"}));
    // One colour still makes a gradient.
    QCOMPARE(ThemeSync::borderColors({{"background", "#000000"}, {"accent", "#ff0000"}}).size(), 2);

    QTemporaryDir home;
    const QString path = home.path() + "/.config/omarchy/animation-presets.json";
    writeFile(path, R"({"curves": {"mine": {"type": "spring"}}, "presets": [{"id": "x"}], "borders": {"own": {"colors": ["ffffff"]}}})");
    QVERIFY(ThemeSync::writeBorderRun(home.path(), colors));
    QVERIFY(!ThemeSync::writeBorderRun(home.path(), colors)); // unchanged
    QFile file(path);
    QVERIFY(file.open(QIODevice::ReadOnly));
    const auto saved = QJsonDocument::fromJson(file.readAll()).object();
    QCOMPARE(saved.value("curves").toObject().value("mine").toObject().value("type").toString(), QString("spring"));
    QCOMPARE(saved.value("presets").toArray().size(), 1);
    QVERIFY(saved.value("borders").toObject().contains("own"));
    QCOMPARE(saved.value("borders").toObject().value("wallpaper").toObject().value("colors").toArray().size(), 4);
}

void OmacraftTests::themeSyncFollowsAndPutsBack()
{
    QTemporaryDir home;
    const QString burnPlugin = home.path() + "/burn";
    writeBurnEffects(burnPlugin);
    writeFile(home.path() + "/.config/omarchy/burn-my-windows.json", R"({"color": "#38ff6a"})");
    Burn burn([burnPlugin] { return burnPlugin; }, home.path(), false);
    const QString studio = home.path() + "/studio";
    writeLauncherStyles(studio);
    writeFile(home.path() + "/.config/omarchy/launcher-style.json", R"({"scheme": "nord"})");
    Launcher launcher([studio] { return studio; }, home.path(), false);

    ThemeSync sync(nullptr, nullptr, &burn, &launcher, nullptr, nullptr, home.path(), false);
    QVERIFY(!sync.allFollow());
    sync.followAll();
    QCOMPARE(burn.color(), QString("theme"));
    QCOMPARE(launcher.scheme(), QString("omarchy"));
    QVERIFY(sync.allFollow());

    // What each had is kept, and comes back when it stops following.
    ThemeSync later(nullptr, nullptr, &burn, &launcher, nullptr, nullptr, home.path(), false);
    later.setFollow("effects", false);
    later.setFollow("launcher", false);
    QCOMPARE(burn.color(), QString("#38ff6a"));
    QCOMPARE(launcher.scheme(), QString("nord"));

    // Following with nothing to go back to can't be turned off.
    launcher.setScheme("omarchy");
    for (const auto &part : later.parts())
        if (part.toMap().value("id") == "launcher")
            QVERIFY(part.toMap().value("fixed").toBool());
}

// TheDraw art: background-coloured spans, which crash a RichText Text on
// Qt 6.12, painted by AsciiView instead, sized by the art and its zoom.
void OmacraftTests::asciiViewPaintsBackgroundSpans() {
    AsciiView view;
    QCOMPARE(view.naturalWidth(), 0.0);
    QString row;
    for (int i = 0; i < 40; i++)
        row += QString("<span style=\"color:#ff0000;background-color:#%1;\">\u2588\u2593</span>").arg(i % 2 ? "00aaaa" : "aa00aa");
    view.setHtml("<pre>" + row + "<br>" + row + "</pre>");
    QVERIFY(view.naturalWidth() > 0);
    QVERIFY(view.naturalHeight() > 0);
    QCOMPARE(view.implicitWidth(), view.naturalWidth());

    view.setZoom(0.5);
    QCOMPARE(view.implicitWidth(), view.naturalWidth() * 0.5);
    view.setZoom(-3);
    QVERIFY(view.zoom() > 0);
    view.setZoom(1);

    QImage image(view.naturalWidth(), view.naturalHeight(), QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    QPainter painter(&image);
    view.paint(&painter);
    painter.end();
    QCOMPARE(image.pixelColor(1, 1).alpha(), 255);
}

// A preset sets its whole look, and its font when asked, as one undo step.
void OmacraftTests::omasciiPresetIsOneUndoStep() {
    Omascii omascii([] { return QString(); });
    omascii.setOption("font", "Graffiti");
    omascii.setOption("colorMode", "solid");
    omascii.applyPreset({{"colorMode", "palette"}, {"colorPalette", "acid"}, {"inkBg", "shade"}}, "TDF acidx");
    QCOMPARE(omascii.config().value("colorPalette").toString(), QString("acid"));
    QCOMPARE(omascii.config().value("inkBg").toString(), QString("shade"));
    QCOMPARE(omascii.config().value("font").toString(), QString("TDF acidx"));
    QCOMPARE(omascii.config().value("source").toString(), QString("text"));
    omascii.undo();
    QCOMPARE(omascii.config().value("colorMode").toString(), QString("solid"));
    QCOMPARE(omascii.config().value("font").toString(), QString("Graffiti"));

    // Without a font it keeps the one in use.
    omascii.applyPreset({{"shadow", "glow"}});
    QCOMPARE(omascii.config().value("font").toString(), QString("Graffiti"));
}

void OmacraftTests::bootSplashReadsTheThemeAndWhereToGoBack() {
    QCOMPARE(BootSplash::themeIn("[Daemon]\nTheme=omascii\n"), QString("omascii"));
    QCOMPARE(BootSplash::themeIn("[Daemon]\n# Theme=old\n  Theme = hyprstack-boot  \nShowDelay=0\n"), QString("hyprstack-boot"));
    QCOMPARE(BootSplash::themeIn("[Daemon]\nShowDelay=0\n"), QString());

    QTemporaryDir root;
    const QString conf = root.path() + "/etc/plymouthd.conf";
    const QString themes = root.path() + "/themes";
    const QString previous = root.path() + "/state/previous-theme";
    QVERIFY(Proc::writeAtomically(conf, "[Daemon]\nTheme=omascii\n"));
    QVERIFY(QDir().mkpath(themes + "/omascii"));

    BootSplash splash(conf, themes, previous);
    QCOMPARE(splash.theme(), QString("omascii"));
    QVERIFY(!splash.on());
    QVERIFY(!splash.available());

    QVERIFY(Proc::writeAtomically(themes + "/hyprstack-boot/hyprstack-boot.plymouth", "[Plymouth Theme]\n"));
    QVERIFY(splash.available());

    // Nothing recorded, or a theme that's gone, falls back to Omarchy's own.
    QCOMPARE(splash.previousTheme(), QString("omarchy"));
    QVERIFY(Proc::writeAtomically(previous, "solar\n"));
    QCOMPARE(splash.previousTheme(), QString("omarchy"));
    QVERIFY(Proc::writeAtomically(previous, "omascii\n"));
    QCOMPARE(splash.previousTheme(), QString("omascii"));

    QVERIFY(Proc::writeAtomically(conf, "[Daemon]\nTheme=hyprstack-boot\n"));
    splash.reload();
    QVERIFY(splash.on());

    const QString command = BootSplash::switchCommand("hyprstack-boot");
    QVERIFY(command.startsWith("sudo plymouth-set-default-theme 'hyprstack-boot' && "));
    QVERIFY(command.contains("limine-mkinitcpio"));
    QVERIFY(command.contains("mkinitcpio -P"));
}


// --- Screensaver ---

namespace {

QByteArray readBytes(const QString &path) {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}

// An omascii that logs each command it's asked to run and answers the
// read-only ones; anything else fails.
QString fakeOmascii(const QString &dir) {
    const QString path = dir + "/bin/omascii";
    writeFile(path, QString(R"(#!/bin/sh
echo "$*" >> '%1/omascii.log'
case "$1" in
status) echo '{"layouts":["default","fitted"],"borders":["none","single"]}' ;;
fonts) echo '[{"name":"Standard"},{"name":"TDF dark","title":"Dark"}]' ;;
images) echo '[]' ;;
render) echo '{"text":"  ART\n  ART","cols":5,"rows":2}' ;;
*) exit 3 ;;
esac
)").arg(dir).toUtf8());
    QFile::setPermissions(path, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
    return path;
}

} // namespace

void OmacraftTests::screensaverNeverTouchesTheBootScreen() {
    QTemporaryDir home;
    const QString cli = fakeOmascii(home.path());
    const QString bootConfig = home.path() + "/.config/omascii/config.json";
    writeFile(bootConfig, R"({"text":"Boot","font":"TDF dark","border":"corners"})");
    writeFile(home.path() + "/.config/omarchy/branding/screensaver.txt", "old art\n");
    writeFile(home.path() + "/omarchy/logo.txt", "LOGO\n");

    Screensaver saver([cli] { return cli; }, home.path(), home.path() + "/usr/local/bin/omarchy-screensaver",
                      home.path() + "/omarchy");
    saver.refresh();
    QTRY_VERIFY(saver.loaded());
    // Until something is picked, the screensaver keeps the art it has.
    QCOMPARE(saver.artSource(), QString("current"));
    QTRY_COMPARE(saver.art(), QString("old art"));

    saver.setOption("text", "hello");
    QCOMPARE(saver.artSource(), QString("design"));
    QTRY_COMPARE(saver.art(), QString("  ART\n  ART"));
    QVERIFY(saver.dirty());
    saver.apply();
    QTRY_COMPARE(readBytes(saver.artPath()), QByteArray("  ART\n  ART\n"));
    QCOMPARE(readBytes(saver.backupPath()), QByteArray("old art\n"));
    QVERIFY(!saver.dirty());

    const auto settings = readJson(saver.settingsPath());
    QCOMPARE(settings.value("applied").toObject().value("mode").toString(), QString("omarchy"));
    QCOMPARE(settings.value("applied").toObject().value("design").toObject().value("text").toString(), QString("hello"));
    QVERIFY(QFileInfo(saver.runnerDir() + "/omasavr-screensaver").isExecutable());
    QVERIFY(QFileInfo::exists(saver.runnerDir() + "/omasavr-native.py"));

    // The Omarchy logo is copied as it is, and the old text comes back.
    saver.setArtSource("omarchy");
    saver.apply();
    QTRY_COMPARE(readBytes(saver.artPath()), QByteArray("LOGO\n"));
    saver.restoreBackup();
    QCOMPARE(readBytes(saver.artPath()), QByteArray("old art\n"));

    // omascii was only ever asked to read: no set, apply, saved or restore,
    // and every render carried the whole design, so nothing came from the boot one.
    const QStringList calls = QString::fromUtf8(readBytes(home.path() + "/omascii.log")).split('\n', Qt::SkipEmptyParts);
    QVERIFY(!calls.isEmpty());
    for (const auto &call : calls) {
        const QString command = call.section(' ', 0, 0);
        QVERIFY2(QStringList({"status", "fonts", "images", "render"}).contains(command), qPrintable(call));
        if (command == "render")
            QVERIFY2(call.contains("\"border\":\"none\""), qPrintable(call));
    }
    QCOMPARE(readBytes(bootConfig), QByteArray(R"({"text":"Boot","font":"TDF dark","border":"corners"})"));
    QVERIFY(!QFileInfo::exists(home.path() + "/usr/local/bin/omarchy-screensaver"));
}

void OmacraftTests::screensaverKeepsItsArtPlain() {
    const auto settings = Screensaver::withDefaults({
        {"art", "nonsense"}, {"mode", "loud"}, {"frameRate", 9000},
        {"design", QVariantMap{{"text", "hi"}, {"color", "red"}, {"colorMode", "rainbow"}, {"unknown", 1}}}});
    const auto design = settings.value("design").toMap();
    QCOMPARE(design.value("text").toString(), QString("hi"));
    // ttfx colours the screensaver; the art is shapes only.
    QCOMPARE(design.value("color").toString(), QString("foreground"));
    QCOMPARE(design.value("colorMode").toString(), QString("solid"));
    QVERIFY(!design.contains("unknown"));
    QCOMPARE(settings.value("art").toString(), QString("current"));
    QCOMPARE(settings.value("mode").toString(), QString("omarchy"));
    QCOMPARE(settings.value("frameRate").toInt(), 240);
    // Every key omascii renders with is there.
    for (const auto &key : {"border", "shadow", "padding", "width", "hlayout", "fill", "flip"})
        QVERIFY2(design.contains(key), key);

    QVariantMap custom = Screensaver::defaultSettings();
    custom["mode"] = "custom";
    custom["effects"] = QStringList();
    QVERIFY(!Screensaver::applyProblem(custom).isEmpty());
    custom["effects"] = QStringList{"matrix"};
    QVERIFY(Screensaver::applyProblem(custom).isEmpty());

    Screensaver saver([] { return QString(); });
    saver.setOption("color", "red");
    QCOMPARE(saver.design().value("color").toString(), QString("foreground"));
    QCOMPARE(Screensaver::toHtml("a <b>\n c"), QString("a&nbsp;&lt;b&gt;<br>&nbsp;c"));
}

void OmacraftTests::screensaverKnowsWhoseHookItIs() {
    QTemporaryDir dir;
    const QString hook = dir.path() + "/omarchy-screensaver";
    Screensaver saver([] { return QString(); }, dir.path(), hook, dir.path());
    saver.refreshSystem();
    QCOMPARE(saver.hook(), QString("none"));
    writeFile(hook, "#!/bin/sh\nexec something-else\n");
    saver.refreshSystem();
    QCOMPARE(saver.hook(), QString("foreign"));
    // Someone else's file is never replaced.
    saver.installHook();
    QVERIFY(!saver.busy());
    QCOMPARE(readBytes(hook), QByteArray("#!/bin/sh\nexec something-else\n"));
    QVERIFY(!saver.error().isEmpty());

    QVERIFY(Screensaver::hookScript().contains("omacraft-omasavr-hook"));
    QVERIFY(Screensaver::hookScript().contains("exec /usr/bin/omarchy-screensaver"));
    QFile::remove(hook);
    writeFile(hook, Screensaver::hookScript());
    saver.refreshSystem();
    QCOMPARE(saver.hook(), QString("ours"));
    QFile::remove(hook);
    writeFile(hook, Screensaver::hookScript() + "# older\n");
    saver.refreshSystem();
    QCOMPARE(saver.hook(), QString("outdated"));
}

void OmacraftTests::screensaverSetsTheIdleTimeInPlace() {
    QTemporaryDir home;
    const QString shell = home.path() + "/.config/omarchy/shell.json";
    writeFile(shell, R"({"idle":{"screensaver":150,"lock":300},"bar":{"position":"top"}})");
    const auto inode = inodeOf(shell);
    Screensaver saver([] { return QString(); }, home.path());
    saver.refreshSystem();
    QCOMPARE(saver.idleSeconds(), 150);
    QCOMPARE(saver.lockSeconds(), 300);
    saver.setIdleSeconds(600);
    const auto saved = readJson(shell);
    QCOMPARE(saved.value("idle").toObject().value("screensaver").toInt(), 600);
    QCOMPARE(saved.value("idle").toObject().value("lock").toInt(), 300);
    QCOMPARE(saved.value("bar").toObject().value("position").toString(), QString("top"));
    QCOMPARE(inodeOf(shell), inode);
    saver.setIdleSeconds(1);
    QCOMPARE(saver.idleSeconds(), 10);
}

void OmacraftTests::screensaverScriptsParse() {
    QTemporaryDir dir;
    const QList<QPair<QString, QStringList>> checks{
        {":/omasavr-screensaver.sh", {"bash", "-n"}},
        {":/omasavr-hook.sh", {"bash", "-n"}},
        {":/omasavr-native.py", {"python3", "-m", "py_compile"}},
    };
    for (const auto &[resource, command] : checks) {
        const QString path = dir.path() + "/" + QFileInfo(resource).fileName();
        writeFile(path, readBytes(resource));
        QProcess process;
        process.start(command.first(), command.mid(1) + QStringList{path});
        QVERIFY(process.waitForFinished());
        QVERIFY2(process.exitCode() == 0, qPrintable(resource + ": " + process.readAllStandardError()));
    }
}

// --- ROFIoma ---

void OmacraftTests::rofiomaWritesEveryPopup() {
    QTemporaryDir home;
    Rofioma rofioma(home.path(), false);
    rofioma.set("power.style", "grid");
    const QString dir = rofioma.outputDir();
    for (const char *name : {"colors.rasi", "power.rasi", "confirm.rasi", "power.sh", "symbols.rasi", "symbols.sh",
                             "keybinds.rasi", "keybinds.sh", "emoji.tsv", "glyphs.tsv"})
        QVERIFY2(QFileInfo::exists(dir + "/" + name), name);
    QVERIFY(QFileInfo(dir + "/power.sh").permissions() & QFile::ExeOwner);
    QCOMPARE(readJson(rofioma.configPath()).value("power").toObject().value("style").toString(), QString("grid"));

    const QString power = QString::fromUtf8(readBytes(dir + "/power.sh"));
    QVERIFY(power.contains("-kb-select-1 l"));
    QVERIFY(power.contains("    2) systemctl suspend ;;"));
    // Logout asks first; lock doesn't.
    QVERIFY(power.contains("    1) ask 'Logout' || exit 0 ;;"));
    QVERIFY(!power.contains("ask 'Lock'"));
    QVERIFY(QString::fromUtf8(readBytes(dir + "/power.rasi")).contains("columns: 3;"));

    // A button switched off drops out, and the rest renumber.
    rofioma.setPowerButton(0, "enabled", false);
    QVERIFY(QString::fromUtf8(readBytes(dir + "/power.sh")).contains("    1) systemctl suspend ;;"));

    // swaync's files are only written once asked for, keeping what was there.
    QVERIFY(!QFileInfo::exists(rofioma.swayncDir() + "/style.css"));
    writeFile(rofioma.swayncDir() + "/style.css", "/* mine */");
    rofioma.set("notify.position", "bottom-left");
    rofioma.set("notify.manage", true);
    QVERIFY(QString::fromUtf8(readBytes(rofioma.swayncDir() + "/style.css")).contains("@define-color rf-accent"));
    const QJsonObject config = readJson(rofioma.swayncDir() + "/config.json");
    QCOMPARE(config.value("positionX").toString(), QString("left"));
    QCOMPARE(config.value("positionY").toString(), QString("bottom"));
    const QStringList kept = QDir(rofioma.swayncDir()).entryList({"style.css.before-omacraft-*"});
    QCOMPARE(kept.size(), 1);
    QCOMPARE(readBytes(rofioma.swayncDir() + "/" + kept.first()), QByteArray("/* mine */"));
    rofioma.set("notify.width", 420);
    QCOMPARE(QDir(rofioma.swayncDir()).entryList({"style.css.before-omacraft-*"}).size(), 1);

    // Custom colours reach rofi and swaync.
    rofioma.set("look.colors", "custom");
    rofioma.set("look.custom.accent", "#123456");
    QVERIFY(QString::fromUtf8(readBytes(dir + "/colors.rasi")).contains("rf-accent: #123456;"));
    QVERIFY(QString::fromUtf8(readBytes(rofioma.swayncDir() + "/style.css")).contains("@define-color rf-accent #123456;"));
}

void OmacraftTests::rofiomaScriptsParse() {
    QTemporaryDir home;
    Rofioma rofioma(home.path(), false);
    rofioma.addMenu("Apps");
    rofioma.set("symbols.action", "both");
    for (const QString &name : QDir(rofioma.outputDir()).entryList({"*.sh"}, QDir::Files)) {
        QProcess process;
        process.start("sh", {"-n", rofioma.outputDir() + "/" + name});
        QVERIFY(process.waitForFinished());
        QVERIFY2(process.exitCode() == 0, qPrintable(name + ": " + process.readAllStandardError()));
    }
}

void OmacraftTests::rofiomaWritesWlogout() {
    QTemporaryDir home;
    Rofioma rofioma(home.path(), false);
    rofioma.set("power.style", "wlogout");
    rofioma.setPowerButton(3, "enabled", false); // hibernate
    const QString dir = rofioma.outputDir() + "/wlogout";

    // One layout entry per enabled button, each calling back into power.sh.
    const QString layout = QString::fromUtf8(readBytes(dir + "/layout"));
    QCOMPARE(layout.count("\"label\""), 5);
    QVERIFY(layout.contains("power.sh' run 4"));
    QVERIFY(!layout.contains("hibernate"));

    // HyDE's hover: the overshooting curve, with the bar's ends rounded.
    const QString css = QString::fromUtf8(readBytes(dir + "/style.css"));
    QVERIFY(css.contains("cubic-bezier(.55, 0.0, .28, 1.682)"));
    QVERIFY(css.contains("#lock {"));
    QVERIFY(css.contains("margin: @MGN@px 0px @MGN@px @MGN@px;"));
    QVERIFY(css.contains("margin: @HVR@px @MGN@px @HVR@px 0px;"));

    for (const char *icon : {"lock.png", "lock-hover.png", "shutdown.png"}) {
        QImage image(dir + "/" + icon);
        QVERIFY2(!image.isNull(), icon);
        QCOMPARE(image.width(), 256);
    }
    const QString script = QString::fromUtf8(readBytes(rofioma.outputDir() + "/power.sh"));
    QVERIFY(script.contains("exec wlogout -b 5"));
    QVERIFY(script.contains("command -v wlogout"));
}

void OmacraftTests::rofiomaHandsPopupsToTheOverlay() {
    QTemporaryDir home;
    Rofioma rofioma(home.path(), false);
    const QString id = rofioma.addMenu("Apps");
    rofioma.setPowerButton(3, "enabled", false);
    const QString dir = rofioma.outputDir();

    // What's drawn goes to the overlay; the commands stay in the scripts.
    const QJsonObject popups = readJson(dir + "/popups.json");
    QCOMPARE(popups.value("power").toObject().value("buttons").toArray().size(), 5);
    QVERIFY(!popups.value("power").toObject().value("buttons").toArray().first().toObject().contains("command"));
    QCOMPARE(popups.value("menus").toArray().first().toObject().value("id").toString(), id);
    QVERIFY(!QString::fromUtf8(readBytes(dir + "/popups.json")).contains("omarchy-system"));

    // Each script asks the shell first, and the overlay runs `exec <n>`.
    const QString power = QString::fromUtf8(readBytes(dir + "/power.sh"));
    QVERIFY(power.contains(R"(omarchy-shell shell summon omacraft.rofioma '{"popup":"power","toggle":true}')"));
    QVERIFY(power.contains("elif [ \"${1:-}\" = exec ]; then"));
    QVERIFY(QString::fromUtf8(readBytes(dir + "/menu-" + id + ".sh")).contains("\"popup\":\"menu-" + id + "\""));
    QVERIFY(QString::fromUtf8(readBytes(dir + "/keybinds.sh")).contains("\"popup\":\"keybinds\""));

    // rofi only, when the look says so.
    rofioma.set("look.engine", "rofi");
    QVERIFY(!QString::fromUtf8(readBytes(dir + "/power.sh")).contains("omacraft.rofioma"));
    for (const QString &name : QDir(dir).entryList({"*.sh"}, QDir::Files)) {
        QProcess process;
        process.start("sh", {"-n", dir + "/" + name});
        QVERIFY(process.waitForFinished());
        QCOMPARE(process.exitCode(), 0);
    }
}

void OmacraftTests::rofiomaMovesBinds() {
    QTemporaryDir home;
    writeFile(home.path() + "/.config/hypr/hyprland.lua",
              "-- mine\nrequire(\"default.hypr.omarchy\")\nrequire(\"hypr.bindings\")\n");
    Rofioma rofioma(home.path(), false);

    QVERIFY(!rofioma.moveBind("SUPER + RETURN", "SUPER + SHIFT + nonsense key").isEmpty());
    QCOMPARE(rofioma.moveBind("super + return", "alt+super+t"), QString());
    QCOMPARE(readJson(rofioma.configPath()).value("keymap").toObject().value("SUPER + RETURN").toString(),
             QString("SUPER + ALT + T"));

    // Its line goes above Omarchy's binds, once, with the file kept first.
    const QString main = QString::fromUtf8(readBytes(home.path() + "/.config/hypr/hyprland.lua"));
    QVERIFY(main.indexOf("hypr.omacraft_keymap") < main.indexOf("require(\"default.hypr.omarchy\")"));
    QVERIFY(main.startsWith("-- mine\n"));
    QCOMPARE(QDir(home.path() + "/.config/hypr").entryList({"hyprland.lua.before-keymap-*"}).size(), 1);
    const QString lua = QString::fromUtf8(readBytes(rofioma.keymapPath()));
    QVERIFY(lua.contains(R"(["SUPER + RETURN"] = "SUPER + ALT + T",)"));
    QVERIFY(lua.contains("hl.define_submap(\"omacraft_capture\""));

    // Moving it again goes from where it is now; the map keeps its own keys.
    QCOMPARE(rofioma.moveBind("SUPER + ALT + T", "SUPER + F9"), QString());
    QJsonObject keymap = readJson(rofioma.configPath()).value("keymap").toObject();
    QCOMPARE(keymap.size(), 1);
    QCOMPARE(keymap.value("SUPER + RETURN").toString(), QString("SUPER + F9"));

    // No keys puts it back where it started.
    QCOMPARE(rofioma.moveBind("SUPER + F9", ""), QString());
    QVERIFY(readJson(rofioma.configPath()).value("keymap").toObject().isEmpty());
    QCOMPARE(QString::fromUtf8(readBytes(home.path() + "/.config/hypr/hyprland.lua")).count("hypr.omacraft_keymap"), 1);
}

void OmacraftTests::rofiomaReadsBinds() {
    const QByteArray json = R"([
        {"modmask":65,"key":"q","keycode":0,"description":"Close","has_description":true,"submap":"","dispatcher":"__lua","arg":"3","mouse":false},
        {"modmask":64,"key":"F9","keycode":0,"description":"Terminal","has_description":true,"submap":"","dispatcher":"__lua","arg":"5","mouse":false},
        {"modmask":0,"key":"XF86AudioMute","keycode":0,"description":"","has_description":false,"submap":"","dispatcher":"exec","arg":"x","mouse":false},
        {"modmask":64,"key":"mouse:272","keycode":0,"description":"Move","has_description":true,"submap":"","dispatcher":"movewindow","arg":"","mouse":true}
    ])";
    const QVariantList binds = Rofioma::bindsFrom(json, QJsonObject{{"SUPER + RETURN", "SUPER + F9"}}, true);
    QCOMPARE(binds.size(), 2);
    QCOMPARE(binds.at(0).toMap().value("keys").toString(), QString("SUPER + SHIFT + Q"));
    QCOMPARE(binds.at(1).toMap().value("movedFrom").toString(), QString("SUPER + RETURN"));
    QCOMPARE(Rofioma::bindsFrom(json, {}, false).size(), 3);
    QCOMPARE(Rofioma::canonicalKeys("shift+win  q"), QString("SUPER + SHIFT + Q"));
}

void OmacraftTests::rofiomaKeepsMenusTidy() {
    QTemporaryDir home;
    Rofioma rofioma(home.path(), false);
    const QString id = rofioma.addMenu("Screen Shots!");
    QCOMPARE(id, QString("screen-shots"));
    QCOMPARE(rofioma.addMenu("Screen shots"), QString("screen-shots-2"));
    rofioma.addMenuItem(id);
    rofioma.setMenuItem(id, 3, "command", "grim -g \"$(slurp)\"\nnotify-send done");
    const QString script = QString::fromUtf8(readBytes(rofioma.outputDir() + "/menu-" + id + ".sh"));
    QVERIFY(script.contains("    3) grim -g \"$(slurp)\"; notify-send done ;;"));
    rofioma.moveMenuItem(id, 3, 0);
    QVERIFY(QString::fromUtf8(readBytes(rofioma.outputDir() + "/menu-" + id + ".sh")).contains("    0) grim"));

    QVERIFY(rofioma.bindKey("menu-" + id, "super alt m"));
    rofioma.removeMenu(id);
    QVERIFY(!QFileInfo::exists(rofioma.outputDir() + "/menu-" + id + ".sh"));
    QVERIFY(!QFileInfo::exists(rofioma.outputDir() + "/menu-" + id + ".rasi"));
    QVERIFY(QFileInfo::exists(rofioma.outputDir() + "/menu-screen-shots-2.sh"));
    QVERIFY(!readJson(rofioma.configPath()).value("keys").toObject().contains("menu-" + id));
    QVERIFY(!QString::fromUtf8(readBytes(rofioma.keysPath())).contains("SUPER + ALT + M"));
}

void OmacraftTests::rofiomaBindsKeysThroughHyprlandLua() {
    QTemporaryDir home;
    const QString main = home.path() + "/.config/hypr/hyprland.lua";
    writeFile(main, "require(\"hypr.bindings\")\n");
    Rofioma rofioma(home.path(), false);

    QVERIFY(!rofioma.bindKey("power", "SUPER + CTRL"));
    QVERIFY(!rofioma.error().isEmpty());
    QVERIFY(rofioma.bindKey("power", "super ctrl ESCAPE"));
    QVERIFY(rofioma.bindKey("emoji", "SUPER + ALT + PERIOD"));
    // One key opens one popup.
    QVERIFY(!rofioma.bindKey("glyphs", "super alt period"));

    const QString keys = QString::fromUtf8(readBytes(rofioma.keysPath()));
    QVERIFY(keys.contains("hl.unbind(\"SUPER + CTRL + ESCAPE\")"));
    QVERIFY(keys.contains("o.bind(\"SUPER + CTRL + ESCAPE\", \"Power menu\", \"sh '" + rofioma.outputDir() + "/power.sh'\")"));
    QVERIFY(keys.contains("o.bind(\"SUPER + ALT + PERIOD\", \"Emoji picker\", \"sh '" + rofioma.outputDir() + "/symbols.sh' emoji\")"));
    QVERIFY(!keys.contains("swaync"));
    QCOMPARE(QString::fromUtf8(readBytes(main)).count("hypr.omacraft_rofioma"), 1);
    QCOMPARE(QDir(home.path() + "/.config/hypr").entryList({"hyprland.lua.before-rofioma-*"}).size(), 1);

    QVERIFY(rofioma.bindKey("power", ""));
    QVERIFY(!QString::fromUtf8(readBytes(rofioma.keysPath())).contains("Power menu"));

    // A popup ROFIoma doesn't have is refused rather than saved and never bound.
    QVERIFY(!rofioma.bindKey("notifcations", "SUPER + ALT + N"));
    QVERIFY(rofioma.error().contains("notifcations"));
    QVERIFY(!rofioma.config().value("keys").toMap().contains("notifcations"));

    // The control centre key: swaync's panel when swaync runs, else the shell's history.
    QVERIFY(rofioma.bindKey("notifications", "super alt n"));
    QVERIFY(QString::fromUtf8(readBytes(rofioma.keysPath()))
                .contains("o.bind(\"SUPER + ALT + N\", \"Notification control centre\", \"sh '" + rofioma.outputDir() + "/notifications.sh'\")"));
    QTemporaryDir bin;
    const QString log = bin.filePath("ran");
    for (const QString &tool : {"swaync-client", "omarchy-shell"})
        writeFile(bin.filePath(tool), QString("#!/bin/sh\necho \"%1 $*\" >> '%2'\n").arg(tool, log).toUtf8());
    for (bool running : {true, false}) {
        writeFile(bin.filePath("pgrep"), running ? "#!/bin/sh\nexit 0\n" : "#!/bin/sh\nexit 1\n");
        for (const QString &tool : {"swaync-client", "omarchy-shell", "pgrep"})
            QFile::setPermissions(bin.filePath(tool), QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
        QFile::remove(log);
        QProcess script;
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        env.insert("PATH", bin.path() + ":/usr/bin:/bin");
        script.setProcessEnvironment(env);
        script.start("sh", {rofioma.outputDir() + "/notifications.sh"});
        QVERIFY(script.waitForFinished());
        QCOMPARE(QString::fromUtf8(readBytes(log)).trimmed(),
                 running ? QString("swaync-client --skip-wait --toggle-panel") : QString("omarchy-shell notifications showHistory"));
    }
}

void OmacraftTests::rofiomaHandsNotificationsToSwaync() {
    QTemporaryDir home;
    writeFile(home.path() + "/.config/omarchy/shell.json",
              R"({"plugins":[{"id":"omacraft.burn"}],"disabledPlugins":["omarchy.dock"]})");
    Rofioma rofioma(home.path(), false);
    QVERIFY(!rofioma.swayncOwns());

    rofioma.handNotificationsToSwaync(true);
    QVERIFY(rofioma.swayncOwns());
    QJsonObject shell = readJson(rofioma.shellPath());
    QCOMPARE(shell.value("disabledPlugins").toArray(), (QJsonArray{"omarchy.dock", "omarchy.notifications"}));
    QCOMPARE(shell.value("plugins").toArray().size(), 1);
    QVERIFY(rofioma.config().value("notify").toMap().value("manage").toBool());
    QVERIFY(QString::fromUtf8(readBytes(rofioma.keysPath())).contains("o.launch_on_start(\"swaync\")"));
    // Twice is still once.
    rofioma.handNotificationsToSwaync(true);
    QCOMPARE(readJson(rofioma.shellPath()).value("disabledPlugins").toArray().size(), 2);

    rofioma.handNotificationsToSwaync(false);
    QVERIFY(!rofioma.swayncOwns());
    QCOMPARE(readJson(rofioma.shellPath()).value("disabledPlugins").toArray(), (QJsonArray{"omarchy.dock"}));
    QVERIFY(!QString::fromUtf8(readBytes(rofioma.keysPath())).contains("swaync"));
}

void OmacraftTests::rofiomaFindsSymbols() {
    QTemporaryDir home;
    Rofioma rofioma(home.path(), false);
    const auto power = rofioma.searchSymbols("glyphs", "power settings", "Material Design");
    QVERIFY(!power.isEmpty());
    QCOMPARE(power.first().toMap().value("code").toString(), QString("F0426"));
    QCOMPARE(rofioma.searchSymbols("glyphs", "f0425").first().toMap().value("name").toString(), QString("power"));
    QCOMPARE(rofioma.searchSymbols("emoji", "grinning face", {}, 1).size(), 1);
    QVERIFY(rofioma.symbolSets("emoji").contains("Smileys & Emotion"));
    QCOMPARE(Rofioma::slug("  Hello, World  "), QString("hello-world"));
}

// ---------------------------------------------------------------- control centre

void OmacraftTests::rofiomaBuildsTheControlCentre() {
    QTemporaryDir home;
    Rofioma rofioma(home.path(), false);
    const auto widgets = [&] { return rofioma.config().value("notify").toMap().value("widgets").toStringList(); };
    QCOMPARE(widgets(), QStringList({"title", "dnd", "mpris", "notifications"}));

    // Dropped at the end, a widget stays above the list.
    rofioma.placeWidget("volume", -1);
    QCOMPARE(widgets(), QStringList({"title", "dnd", "mpris", "volume", "notifications"}));
    rofioma.placeWidget("backlight", 1);
    QCOMPARE(widgets().indexOf("backlight"), 1);
    // Already there, or unknown: nothing happens.
    rofioma.placeWidget("backlight", 0);
    rofioma.placeWidget("nonsense", 0);
    QCOMPARE(widgets().size(), 6);

    rofioma.moveWidget(0, 2);
    QCOMPARE(widgets().indexOf("title"), 2);
    rofioma.moveWidget(0, 99);
    QCOMPARE(widgets().size(), 6);
    rofioma.removeWidget("mpris");
    QVERIFY(!widgets().contains("mpris"));
}

void OmacraftTests::rofiomaInstallsWidgets() {
    QTemporaryDir home;
    Rofioma rofioma(home.path(), false);
    const QVariantList store = rofioma.widgetStore();
    QVERIFY(store.size() >= 6);

    const QString id = "buttons-grid#session";
    rofioma.installWidget(id);
    const auto stored = [&] { return rofioma.widgetStore(); };
    QVERIFY(std::any_of(stored().cbegin(), stored().cend(), [&](const QVariant &w) {
        return w.toMap().value("id") == id && w.toMap().value("installed").toBool();
    }));
    const QVariantList library = rofioma.widgetLibrary();
    QVERIFY(std::any_of(library.cbegin(), library.cend(), [&](const QVariant &w) { return w.toMap().value("id") == id; }));

    // Every widget in the store survives its own cleaning.
    for (const auto &value : store)
        QVERIFY(!Rofioma::cleanWidget(QJsonObject::fromVariantMap(value.toMap())).isEmpty());

    // Only placed widgets reach swaync's config.
    rofioma.set("notify.manage", true);
    QJsonObject config = readJson(rofioma.swayncDir() + "/config.json");
    QVERIFY(!config.value("widget-config").toObject().contains(id));
    rofioma.placeWidget(id, 1);
    config = readJson(rofioma.swayncDir() + "/config.json");
    QVERIFY(config.value("widgets").toArray().contains(id));
    QCOMPARE(config.value("widget-config").toObject().value(id).toObject().value("actions").toArray().size(), 4);

    rofioma.uninstallWidget(id);
    config = readJson(rofioma.swayncDir() + "/config.json");
    QVERIFY(!config.value("widgets").toArray().contains(id));

    const QString made = rofioma.createWidget("buttons", "My Tools", {{"text", "Files = nautilus\nnot a button\nTerm = foot"}});
    QCOMPARE(made, QString("buttons-grid#my-tools"));
    QCOMPARE(rofioma.config().value("notify").toMap().value("customWidgets").toMap().value(made).toMap()
                 .value("config").toMap().value("actions").toList().size(), 2);
    // The same name twice makes a second widget, not a replacement.
    QCOMPARE(rofioma.createWidget("buttons", "My Tools", {{"text", "A = b"}}), QString("buttons-grid#my-tools-2"));
    QVERIFY(rofioma.createWidget("buttons", "Empty", {{"text", "no equals here"}}).isEmpty());

    // A pack says what it would run before it's installed.
    const QString pack = home.filePath("pack.json");
    writeFile(pack, R"({"widgets":[{"id":"label#a","name":"A","config":{"text":"hi"}},
                                   {"id":"slider#b","name":"B","config":{"cmd_getter":"get","cmd_setter":"set $value"}}]})");
    const QVariantMap read = rofioma.readWidgetPack(pack);
    QVERIFY(!read.contains("error"));
    QCOMPARE(read.value("commands").toStringList(), QStringList({"get", "set $value"}));
    QVERIFY(rofioma.installWidgetPack(pack));
    QVERIFY(rofioma.config().value("notify").toMap().value("customWidgets").toMap().contains("slider#b"));
}

void OmacraftTests::rofiomaRejectsBadWidgets() {
    QString problem;
    QVERIFY(Rofioma::cleanWidget({{"id", "dnd"}, {"name", "x"}, {"config", QJsonObject{{"text", "x"}}}}, &problem).isEmpty());
    QVERIFY(!problem.isEmpty());
    QVERIFY(Rofioma::cleanWidget({{"id", "label#../../x"}, {"name", "x"}, {"config", QJsonObject{{"text", "x"}}}}).isEmpty());
    QVERIFY(Rofioma::cleanWidget({{"id", "label#ok"}, {"name", ""}, {"config", QJsonObject{{"text", "x"}}}}).isEmpty());
    QVERIFY(Rofioma::cleanWidget({{"id", "label#ok"}, {"name", "x"}, {"config", QJsonObject{{"nope", 1}}}}).isEmpty());

    // Anything swaync doesn't read is left behind.
    const QJsonObject kept = Rofioma::cleanWidget({{"id", "buttons-grid#ok"}, {"name", "x"},
        {"config", QJsonObject{{"extra", 1}, {"actions", QJsonArray{QJsonObject{{"label", "a"}, {"command", "b"}, {"evil", 1}},
                                                                   QJsonObject{{"label", "no command"}}}}}}});
    const QJsonObject config = kept.value("config").toObject();
    QVERIFY(!config.contains("extra"));
    QCOMPARE(config.value("actions").toArray().size(), 1);
    QVERIFY(!config.value("actions").toArray().first().toObject().contains("evil"));

    QTemporaryDir home;
    Rofioma rofioma(home.path(), false);
    QVERIFY(rofioma.readWidgetPack(home.filePath("missing.json")).contains("error"));
    writeFile(home.filePath("bad.json"), "not json");
    QVERIFY(rofioma.readWidgetPack(home.filePath("bad.json")).contains("error"));
    QVERIFY(!rofioma.installWidgetPack(home.filePath("bad.json")));
}

void OmacraftTests::rofiomaWritesNotificationEffects() {
    QJsonObject notify = Rofioma::defaults().value("notify").toObject();
    notify.insert("enter", "pop");
    notify.insert("critical", "shake");
    notify.insert("hover", "glow");
    notify.insert("center", "fade");
    notify.insert("duration", 300);
    const QString css = Rofioma::swayncEffects(notify);
    QVERIFY(css.contains("@keyframes rf-enter"));
    QVERIFY(css.contains("animation: rf-enter 600ms"));
    QVERIFY(css.contains("notificationwindow .notification.critical"));
    QVERIFY(css.contains("rf-center 380ms"));
    QVERIFY(!css.contains("%1"));
    QCOMPARE(QJsonDocument::fromJson(Rofioma::swayncConfig(notify)).object().value("transition-time").toInt(), 300);

    // OMACRAFT_TEST_SHOTS=dir saves every style, for GTK's own CSS parser.
    const QString dir = qEnvironmentVariable("OMACRAFT_TEST_SHOTS");
    if (!dir.isEmpty()) {
        int n = 0;
        for (const char *enter : {"slide", "fade", "pop", "drop", "flip"})
            for (const char *critical : {"pulse", "glow", "shake"})
                for (const char *hover : {"lift", "glow"})
                    for (const char *center : {"slide", "fade", "pop"}) {
                        notify.insert("enter", enter);
                        notify.insert("critical", critical);
                        notify.insert("hover", hover);
                        notify.insert("center", center);
                        writeFile(QString("%1/swaync-%2.css").arg(dir).arg(n++),
                                  Rofioma::swayncCss({{"bg", "#101010"}, {"alt", "#202020"}, {"fg", "#eeeeee"}, {"muted", "#999999"},
                                                      {"accent", "#00ffaa"}, {"accentFg", "#111111"}, {"urgent", "#ff4444"}},
                                                     notify, Rofioma::defaults().value("look").toObject()).toUtf8());
                    }
    }

    notify.insert("enter", "none");
    notify.insert("critical", "none");
    notify.insert("hover", "none");
    notify.insert("center", "none");
    QVERIFY(!Rofioma::swayncEffects(notify).contains("@keyframes"));
}

void OmacraftTests::rofiomaKeepsPowerEffects() {
    QTemporaryDir home;
    Rofioma rofioma(home.path(), false);
    rofioma.set("power.enter", "burst");
    rofioma.set("power.hover", "pulse");
    rofioma.set("power.backdrop", "aurora");
    const QString id = rofioma.addMenu("Tools");
    rofioma.setMenu(id, "enter", "flip");
    Rofioma again(home.path(), false);
    const QJsonObject popups = readJson(again.outputDir() + "/popups.json");
    QCOMPARE(popups.value("power").toObject().value("enter").toString(), QString("burst"));
    QCOMPARE(popups.value("power").toObject().value("backdrop").toString(), QString("aurora"));
    QCOMPARE(popups.value("menus").toArray().first().toObject().value("enter").toString(), QString("flip"));
    // The page's lists and the overlay's styles are one set.
    QVERIFY(Rofioma::powerEnters().size() >= 9);
    QVERIFY(Rofioma::powerHovers().size() >= 6);
}

void OmacraftTests::rofiomaPicksOneCustomColor() {
    QTemporaryDir home;
    writeFile(home.filePath(".local/state/omarchy/current/theme/colors.toml"),
              "background = \"#101010\"\nforeground = \"#eeeeee\"\naccent = \"#00ff00\"\ncolor1 = \"#ff0000\"\n");
    Rofioma rofioma(home.path(), false);
    const QVariantMap before = rofioma.palette();
    rofioma.setCustomColor("accent", "#123ABC");
    const QVariantMap look = rofioma.config().value("look").toMap();
    QCOMPARE(look.value("colors").toString(), QString("custom"));
    QCOMPARE(rofioma.palette().value("accent").toString(), QString("#123abc"));
    // The other colours stay as the theme had them.
    QCOMPARE(rofioma.palette().value("bg"), before.value("bg"));
    QCOMPARE(rofioma.palette().value("fg"), before.value("fg"));
    rofioma.setCustomColor("accent", "not a colour");
    rofioma.setCustomColor("sky", "#000000");
    QCOMPARE(rofioma.palette().value("accent").toString(), QString("#123abc"));
}

// ---------------------------------------------------------------- marketplace

void OmacraftTests::marketReadsPlugins() {
    const auto list = Marketplace::parsePlugins(R"({"plugins":[
        {"id":"a.b","name":"Good","description":"Does things","author":"me","category":"Widgets","tags":["bar"],
         "repo":"https://github.com/me/good","installAvailable":true,"verificationStatus":"verified","stars":3,
         "previewThumbnail":"assets/img/plugins/1-good-card.webp","previewImage":"https://evil.example/x.webp"},
        {"id":"c.d","name":"Bad repo","repo":"http://github.com/me/bad"},
        {"id":"e.f","name":"Built in","repo":"https://github.com/me/x","sourceType":"builtin"},
        {"id":"","name":"No id","repo":"https://github.com/me/y"}]})");
    QCOMPARE(list.size(), 1);
    const QVariantMap good = list.first().data;
    QCOMPARE(good.value("id").toString(), QString("a.b"));
    QVERIFY(good.value("verified").toBool());
    QCOMPARE(good.value("thumbnail").toString(), QString("https://plugins.omarchy.org/assets/img/plugins/1-good-card.webp"));
    // A picture anywhere else is dropped.
    QVERIFY(good.value("image").toString().isEmpty());
    QVERIFY(list.first().search.contains("bar"));
    QVERIFY(Marketplace::parsePlugins("not json").isEmpty());
}

void OmacraftTests::marketReadsThemes() {
    const auto list = Marketplace::parseThemes(R"(<li><a href="https://github.com/JJDizz1L/aetheria" class="x"><img src="/assets/themes/aetheria.webp" alt="Aetheria theme screenshot" width="1"/><span>Aetheria</span></a></li>
        <li><a href="https://github.com/a/omarchy-all-hallows-theme/" class="x"><img src="/assets/themes/all-hallow-s-eve.webp" alt="All Hallow&#x27;s Eve theme screenshot"/></a></li>
        <li><a href="https://github.com/a/omarchy-all-hallows-theme" class="x"><img src="/assets/themes/dupe.webp" alt="Dupe theme screenshot"/></a></li>
        <li><a href="https://github.com/omacom/omarchy" class="x"><img src="/assets/logo.webp" alt="Logo"/></a></li>)");
    QCOMPARE(list.size(), 2);
    QCOMPARE(list.at(0).data.value("name").toString(), QString("Aetheria"));
    QCOMPARE(list.at(0).data.value("image").toString(), QString("https://omarchy.org/assets/themes/aetheria.webp"));
    QCOMPARE(list.at(0).data.value("author").toString(), QString("JJDizz1L"));
    QCOMPARE(list.at(1).data.value("name").toString(), QString("All Hallow's Eve"));
    QCOMPARE(list.at(1).data.value("folder").toString(), QString("all-hallows"));
}

void OmacraftTests::marketNamesThemesAsOmarchyDoes() {
    QCOMPARE(Marketplace::themeNameFor("https://github.com/a/omarchy-Tokyo-Night-theme.git"), QString("tokyo-night"));
    QCOMPARE(Marketplace::themeNameFor("https://github.com/a/aetheria"), QString("aetheria"));
    QCOMPARE(Marketplace::themeNameFor("https://github.com/a/-dash"), QString());
    QCOMPARE(Marketplace::themeNameFor("https://example.com/a/b"), QString());
}

void OmacraftTests::marketRefusesUnsafeRepositories() {
    QCOMPARE(Marketplace::safeRepository("https://github.com/a/b.git"), QString("https://github.com/a/b"));
    QCOMPARE(Marketplace::safeRepository("https://github.com/a/b/"), QString("https://github.com/a/b"));
    for (const char *bad : {"http://github.com/a/b", "ext::sh -c id", "--upload-pack=x", "https://github.com/a/b/c",
                            "https://github.com.evil.org/a/b", "git@github.com:a/b.git", "https://github.com/a/..",
                            "https://github.com/a/b c"})
        QVERIFY2(Marketplace::safeRepository(bad).isEmpty(), bad);
}

void OmacraftTests::marketKnowsThemeStates() {
    const QString repo = "https://github.com/a/noir";
    QHash<QString, QString> installed{{"noir", "https://github.com/a/noir.git"}, {"mine", ""}};
    QCOMPARE(Marketplace::themeState("other", repo, installed, ""), QString("available"));
    QCOMPARE(Marketplace::themeState("noir", repo, installed, ""), QString("installed"));
    QCOMPARE(Marketplace::themeState("noir", repo, installed, "noir"), QString("current"));
    // The folder is someone else's: installing would delete it.
    QCOMPARE(Marketplace::themeState("mine", repo, installed, ""), QString("taken"));
    QCOMPARE(Marketplace::themeState("noir", "https://github.com/b/noir", installed, ""), QString("taken"));
}

void OmacraftTests::marketBrowsesPages() {
    QTemporaryDir home;
    QJsonArray plugins;
    for (int i = 0; i < 30; ++i)
        plugins << QJsonObject{{"id", QString("p.%1").arg(i)}, {"name", QString("Plugin %1").arg(i, 2, 10, QChar('0'))},
                               {"repo", QString("https://github.com/a/p%1").arg(i)}, {"category", i % 2 ? "Widgets" : "System"},
                               {"stars", i}, {"installAvailable", i < 10}, {"verificationStatus", i < 5 ? "verified" : "unverified"}};
    const QByteArray json = QJsonDocument(QJsonObject{{"plugins", plugins}}).toJson();
    writeFile(home.filePath(".cache/omacraft/market/catalog.json"), json);
    Marketplace market(home.path(), false);
    market.load("plugins");
    QTRY_VERIFY(market.loaded("plugins"));

    QVariantMap page = market.browse("plugins", "", "", "stars", "all", 1);
    QCOMPARE(page.value("total").toInt(), 30);
    QCOMPARE(page.value("pages").toInt(), 2);
    QCOMPARE(page.value("items").toList().first().toMap().value("id").toString(), QString("p.29"));
    QCOMPARE(market.browse("plugins", "", "", "name", "all", 99).value("page").toInt(), 2);
    QCOMPARE(market.browse("plugins", "plugin 07", "", "name", "all", 1).value("total").toInt(), 1);
    QCOMPARE(market.browse("plugins", "", "Widgets", "name", "all", 1).value("total").toInt(), 15);
    QCOMPARE(market.browse("plugins", "", "", "name", "verified", 1).value("total").toInt(), 5);
    QCOMPARE(market.browse("plugins", "", "", "name", "installable", 1).value("total").toInt(), 10);

    market.setInstalledPlugins({{"p.3", true}, {"p.4", false}});
    page = market.browse("plugins", "", "", "name", "installed", 1);
    QCOMPARE(page.value("total").toInt(), 2);
    QCOMPARE(page.value("items").toList().first().toMap().value("state").toString(), QString("enabled"));
    QCOMPARE(market.categories().size(), 2);
}

// ---------------------------------------------------------------- real pointers

namespace {

// Puts QML in a real window with OmaCraft's backends, for tests that press the
// mouse. OMACRAFT_TEST_SHOTS=dir also saves what each one looks like.
struct Harness {
    QQmlApplicationEngine engine;
    QQuickWindow *window = nullptr;
    void load(const QByteArray &body, QSize size) {
        const QByteArray qml = "import QtQuick\nimport QtQuick.Controls\nApplicationWindow { visible: true; width: "
            + QByteArray::number(size.width()) + "; height: " + QByteArray::number(size.height()) + "; " + body + " }";
        engine.loadData(qml, QUrl("qrc:/Harness.qml"));
        QVERIFY(!engine.rootObjects().isEmpty());
        window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(window);
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QTest::qWait(250);
    }
    // By the visual tree: a Repeater's items aren't QObject children.
    QQuickItem *named(const QString &name, QQuickItem *from = nullptr) const {
        from = from ? from : window->contentItem();
        if (from->objectName() == name)
            return from;
        for (QQuickItem *child : from->childItems())
            if (QQuickItem *found = named(name, child))
                return found;
        return nullptr;
    }
    QPoint middle(QQuickItem *item, qreal fx = 0.5) const {
        return item->mapToScene(QPointF(item->width() * fx, item->height() / 2)).toPoint();
    }
    void drag(QPoint from, QPoint to) {
        QTest::mouseMove(window, from);
        QTest::mousePress(window, Qt::LeftButton, {}, from);
        for (int i = 1; i <= 10; ++i) {
            QTest::mouseMove(window, from + (to - from) * i / 10);
            QTest::qWait(10);
        }
        QTest::mouseRelease(window, Qt::LeftButton, {}, to);
        QTest::qWait(60);
    }
    void shot(const QString &name) {
        const QString dir = qEnvironmentVariable("OMACRAFT_TEST_SHOTS");
        if (!dir.isEmpty())
            window->grabWindow().save(dir + "/" + name + ".png");
    }
};

} // namespace

void OmacraftTests::widgetBoardDragsWidgets() {
    QTemporaryDir home;
    Rofioma rofioma(home.path(), false);
    Theme theme;
    Harness h;
    h.engine.rootContext()->setContextProperty("rofioma", &rofioma);
    h.engine.rootContext()->setContextProperty("theme", &theme);
    h.load("ScrollView { anchors.fill: parent; contentWidth: availableWidth; WidgetBoard { objectName: 'board'; width: 560 } }", {600, 1100});
    if (QTest::currentTestFailed()) return;
    const auto widgets = [&] { return rofioma.config().value("notify").toMap().value("widgets").toStringList(); };

    // Library to panel, between dnd and mpris.
    QQuickItem *tile = h.named("tile-volume");
    QQuickItem *mpris = h.named("row-mpris");
    QVERIFY(tile && mpris);
    h.drag(h.middle(tile, 0.3), h.middle(mpris) - QPoint(0, 18));
    QCOMPARE(widgets(), QStringList({"title", "dnd", "volume", "mpris", "notifications"}));
    // Moving over the row without a button held isn't a drag.
    QTest::mouseMove(h.window, h.middle(h.named("row-volume"), 0.3) + QPoint(10, 0));
    QTest::qWait(250);
    QVERIFY(h.named("board"));
    QVERIFY(!h.named("board")->property("dragging").toBool());
    h.shot("board-dropped");

    // Within the panel: the title dragged below mpris.
    h.drag(h.middle(h.named("row-title"), 0.3), h.middle(h.named("row-mpris"), 0.3) + QPoint(0, 12));
    QCOMPARE(widgets(), QStringList({"dnd", "volume", "mpris", "title", "notifications"}));

    // Out of the panel takes it away.
    QTest::qWait(250);
    QQuickItem *panel = h.named("panel");
    const QPoint outside = panel->mapToScene(QPointF(panel->width() / 2, panel->height() + 160)).toPoint();
    h.drag(h.middle(h.named("row-dnd"), 0.3), outside);
    QCOMPARE(widgets(), QStringList({"volume", "mpris", "title", "notifications"}));
    QVERIFY(h.named("tile-dnd"));
}

void OmacraftTests::colorWheelSetsOneColor() {
    QTemporaryDir home;
    Rofioma rofioma(home.path(), false);
    Theme theme;
    Harness h;
    h.engine.rootContext()->setContextProperty("rofioma", &rofioma);
    h.engine.rootContext()->setContextProperty("theme", &theme);
    h.load("ColorPicker { id: picker; objectName: 'picker'; onPicked: hex => rofioma.setCustomColor('accent', hex); Component.onCompleted: openWith('#ff0000') }", {700, 600});
    if (QTest::currentTestFailed()) return;
    QTest::qWait(400);
    h.shot("wheel");
    auto *picker = h.window->findChild<QObject *>("picker");
    QVERIFY(picker);
    QVERIFY(picker->property("opened").toBool());
    QCOMPARE(picker->property("hex").toString(), QString("#ff0000"));
    // A click on the wheel itself: down from its middle, so blue-violet.
    auto *item = picker->property("contentItem").value<QQuickItem *>();
    QVERIFY(item);
    QTest::mouseClick(h.window, Qt::LeftButton, {}, item->mapToScene(QPointF(item->width() / 2, 150)).toPoint());
    QVERIFY(picker->property("hex").toString() != QString("#ff0000"));
    const QString chosen = picker->property("hex").toString();
    QMetaObject::invokeMethod(picker, "picked", Q_ARG(QString, chosen));
    QCOMPARE(rofioma.palette().value("accent").toString(), chosen);
}

void OmacraftTests::marketPageOpensACard() {
    QTemporaryDir home;
    writeFile(home.filePath(".cache/omacraft/market/themes.html"),
              R"(<a href="https://github.com/a/noir" x><img src="/assets/themes/noir.webp" alt="<b>Noir</b> theme screenshot"/></a>)");
    Marketplace market(home.path(), false);
    market.load("themes");
    QTRY_VERIFY(market.loaded("themes"));
    Theme theme;
    Plugins plugins(home.path(), false);
    Harness h;
    h.engine.rootContext()->setContextProperty("market", &market);
    h.engine.rootContext()->setContextProperty("theme", &theme);
    h.engine.rootContext()->setContextProperty("plugins", &plugins);
    h.load("MarketPage { anchors.fill: parent; kind: 'themes'; heading: 'Themes'; noun: 'theme'; active: true }", {1100, 760});
    if (QTest::currentTestFailed()) return;
    QTRY_VERIFY(h.named("card-https://github.com/a/noir") != nullptr);
    QQuickItem *sheet = h.named("sheet");
    QVERIFY(sheet);
    QVERIFY(!sheet->isVisible());
    QTest::mouseClick(h.window, Qt::LeftButton, {}, h.middle(h.named("card-https://github.com/a/noir")));
    QTRY_VERIFY(sheet->isVisible());
    h.shot("market-sheet");
}

void OmacraftTests::popupCardTakesEveryEffect() {
    const QString card = QFINDTESTDATA("../plugins/rofioma/HydeCard.qml");
    QVERIFY(!card.isEmpty());
    QQmlEngine engine;
    QQmlComponent component(&engine, QUrl::fromLocalFile(card));
    QVERIFY2(component.isReady(), qPrintable(component.errorString()));
    for (const auto &style : Rofioma::powerHovers()) {
        std::unique_ptr<QObject> object(component.create());
        QVERIFY(object);
        object->setProperty("hoverStyle", style.toMap().value("id"));
        object->setProperty("width", 120);
        object->setProperty("height", 120);
        object->setProperty("hot", true);
        QTest::qWait(360);
        const qreal scale = object->property("scale").toReal();
        QVERIFY2(scale >= 1 && scale < 1.2, qPrintable(style.toMap().value("id").toString()));
    }
    const QString fx = QFINDTESTDATA("../plugins/rofioma/RofiFx.js");
    QQmlComponent runner(&engine);
    runner.setData("import QtQuick\nimport '" + QUrl::fromLocalFile(fx).toString().toUtf8() + "' as Fx\nQtObject {\n"
                   "  function at(s, c, i) { return Fx.enter(s, c, i, 6, 100, 3) }\n}", QUrl::fromLocalFile(QDir::tempPath() + "/t.qml"));
    QVERIFY2(runner.isReady(), qPrintable(runner.errorString()));
    std::unique_ptr<QObject> fns(runner.create());
    QVERIFY(fns);
    // Every entrance starts somewhere else and ends with the card in place.
    for (const auto &style : Rofioma::powerEnters()) {
        const QString id = style.toMap().value("id").toString();
        for (int i = 0; i < 6; ++i) {
            QVariant end;
            QMetaObject::invokeMethod(fns.get(), "at", Q_RETURN_ARG(QVariant, end), Q_ARG(QVariant, id), Q_ARG(QVariant, 1.0), Q_ARG(QVariant, i));
            const QVariantMap m = end.toMap();
            QCOMPARE(m.value("opacity").toDouble(), 1.0);
            QCOMPARE(m.value("scale").toDouble(), 1.0);
            QCOMPARE(m.value("x").toDouble(), 0.0);
            QCOMPARE(m.value("y").toDouble(), 0.0);
        }
    }
}

namespace {
QJsonObject readShellJson(const QString &home) {
    QFile file(home + "/.config/omarchy/shell.json");
    file.open(QIODevice::ReadOnly);
    return QJsonDocument::fromJson(file.readAll()).object();
}
QStringList enabledIds(const QJsonObject &shell) {
    QStringList ids;
    for (const auto &value : shell.value("plugins").toArray())
        ids << value.toObject().value("id").toString();
    return ids;
}
QStringList disabledIds(const QJsonObject &shell) {
    QStringList ids;
    for (const auto &value : shell.value("disabledPlugins").toArray())
        ids << value.toString();
    return ids;
}
void installLockPlugin(const QString &home, const QString &id) {
    writeFile(home + "/.config/omarchy/plugins/" + id + "/manifest.json",
              QString(R"({"id":"%1","kinds":["service"],"omarchy":{"clonedFrom":"omarchy.lock"}})").arg(id).toUtf8());
}
// The helper with its paths moved under dir, and the step only root can do gone.
QString helperInto(const QString &dir) {
    QFile source(QFINDTESTDATA("../packaging/login/omacraft-login"));
    source.open(QIODevice::ReadOnly);
    QString text = QString::fromUtf8(source.readAll());
    text.replace("theme_dir=/usr/share/sddm/themes/omacraft", "theme_dir=" + dir + "/theme");
    text.replace("conf_dir=/etc/sddm.conf.d", "conf_dir=" + dir + "/conf");
    text.replace("--clear-groups", "--keep-groups");
    QDir().mkpath(dir + "/conf");
    writeFile(dir + "/theme/Main.qml", "import QtQuick");
    writeFile(dir + "/helper", text.toUtf8());
    QFile::setPermissions(dir + "/helper", QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
    return dir + "/helper";
}
int runHelper(const QString &helper, const QStringList &arguments) {
    QProcess process;
    auto env = QProcessEnvironment::systemEnvironment();
    env.insert("PKEXEC_UID", QString::number(getuid()));
    process.setProcessEnvironment(env);
    process.start("bash", QStringList{helper} + arguments);
    process.waitForFinished(15000);
    return process.exitStatus() == QProcess::NormalExit ? process.exitCode() : -1;
}
}

void OmacraftTests::lockSwapNeverLeavesTheShellWithoutALock() {
    QTemporaryDir home;
    installLockPlugin(home.path(), "other.lock");
    installLockPlugin(home.path(), "omacraft.lock");
    writeFile(home.filePath(".config/omarchy/shell.json"),
              R"({"plugins":[{"id":"other.lock"}],"disabledPlugins":["omarchy.lock"],"idle":{"lock":300}})");
    Plugins plugins(home.path(), false);
    plugins.refresh();
    QVERIFY(plugins.isInstalled("omacraft.lock"));

    plugins.setEnabled("omacraft.lock", true);
    QTRY_VERIFY(!plugins.busy());
    QJsonObject shell = readShellJson(home.path());
    QCOMPARE(enabledIds(shell), QStringList{"omacraft.lock"});
    QVERIFY(disabledIds(shell).contains("omarchy.lock"));
    QCOMPARE(shell.value("idle").toObject().value("lock").toInt(), 300);

    plugins.setEnabled("omacraft.lock", false);
    QTRY_VERIFY(!plugins.busy());
    shell = readShellJson(home.path());
    QCOMPARE(enabledIds(shell), QStringList{"other.lock"});
    QVERIFY(disabledIds(shell).contains("omarchy.lock"));
}

void OmacraftTests::lockSwapFallsBackToOmarchysLock() {
    QTemporaryDir home;
    installLockPlugin(home.path(), "omacraft.lock");
    writeFile(home.filePath(".config/omarchy/shell.json"), R"({"plugins":[],"disabledPlugins":[]})");
    Plugins plugins(home.path(), false);
    plugins.refresh();
    plugins.setEnabled("omacraft.lock", true);
    QTRY_VERIFY(!plugins.busy());
    QVERIFY(disabledIds(readShellJson(home.path())).contains("omarchy.lock"));

    // What it replaced is remembered; a remembered plugin that's since gone
    // can't leave the shell with nothing.
    writeFile(home.filePath(".config/omacraft/lock-previous"), "deleted.plugin");
    plugins.setEnabled("omacraft.lock", false);
    QTRY_VERIFY(!plugins.busy());
    const QJsonObject shell = readShellJson(home.path());
    QVERIFY(!disabledIds(shell).contains("omarchy.lock"));
    QVERIFY(!enabledIds(shell).contains("omacraft.lock"));
    QVERIFY(!enabledIds(shell).contains("deleted.plugin"));
}

void OmacraftTests::lockSettingsSurviveAnything() {
    QQmlApplicationEngine engine;
    engine.loadData(R"(
        import QtQuick
        import "LockDefaults.js" as Defaults
        QtObject {
            property var bad: Defaults.clean({ blur: 9, fieldWidth: -5, fieldOpacity: "x", bgMode: "nope", unlockMs: 999999,
                                               colorText: "red;}", note: "a\nb", showClock: "maybe", blockX: 500, shake: "false" })
            property var nothing: Defaults.clean(null)
            property var text: Defaults.clean({ fieldWidth: "500", showClock: "true", blur: "" })
        }
    )", QUrl("qrc:/HarnessDefaults.qml"));
    QVERIFY(!engine.rootObjects().isEmpty());
    QObject *root = engine.rootObjects().first();
    const auto bad = root->property("bad").toMap();
    QCOMPARE(bad.value("blur").toDouble(), 1.0);
    QCOMPARE(bad.value("fieldWidth").toDouble(), 180.0);
    QCOMPARE(bad.value("fieldOpacity").toDouble(), 0.8);
    QCOMPARE(bad.value("bgMode").toString(), QString("wallpaper"));
    QCOMPARE(bad.value("unlockMs").toDouble(), 800.0);
    QCOMPARE(bad.value("colorText").toString(), QString());
    QCOMPARE(bad.value("note").toString(), QString("a b"));
    QCOMPARE(bad.value("showClock").toBool(), false);
    QCOMPARE(bad.value("blockX").toDouble(), 100.0);
    QCOMPARE(bad.value("shake").toBool(), false);
    QCOMPARE(root->property("nothing").toMap().value("fieldHeight").toDouble(), 67.0);
    const auto text = root->property("text").toMap();
    QCOMPARE(text.value("fieldWidth").toDouble(), 500.0);
    QCOMPARE(text.value("showClock").toBool(), true);
    QCOMPARE(text.value("blur").toDouble(), 1.0);
}

void OmacraftTests::lockLogonKeepsLooksAndReadsSddm() {
    QTemporaryDir home;
    QTemporaryDir etc;
    writeFile(etc.filePath("sddm.conf.d/10-theme.conf"), "[Theme]\nCurrent=omarchy\n");
    writeFile(etc.filePath("sddm.conf.d/autologin.conf"), "[Autologin]\nUser=skll\nSession=omarchy.desktop\n");
    writeFile(etc.filePath("sddm.conf.d/99-omarchy-login.conf"), "[Theme]\nCurrent=omarchy\n");
    LockLogon lock(nullptr, nullptr, home.path(), etc.path(), home.filePath("themes"), false);
    QCOMPARE(lock.loginTheme(), QString("omarchy"));
    QCOMPARE(lock.autologinUser(), QString("skll"));
    QVERIFY(!lock.autologinOverridden());

    // Omacraft's overrides sort after every file of Omarchy's, and win.
    writeFile(etc.filePath("sddm.conf.d/" + LockLogon::kThemeOverride), "[Theme]\nCurrent=omacraft\n");
    writeFile(etc.filePath("sddm.conf.d/" + LockLogon::kAutologinOverride), "[Autologin]\nUser=\nSession=\n");
    lock.reload();
    QCOMPARE(lock.loginTheme(), QString("omacraft"));
    QCOMPARE(lock.autologinUser(), QString());
    QVERIFY(lock.autologinOverridden());

    lock.set("lock", "blur", 0.25);
    lock.set("lock", "panel", "card");
    QFile saved(home.filePath(".config/omarchy/omacraft-lock.json"));
    QVERIFY(saved.open(QIODevice::ReadOnly));
    QCOMPARE(QJsonDocument::fromJson(saved.readAll()).object().value("panel").toString(), QString("card"));
    LockLogon again(nullptr, nullptr, home.path(), etc.path(), home.filePath("themes"), false);
    QCOMPARE(again.lockLook().value("blur").toDouble(), 0.25);
    QVERIFY(lock.canUndoLock());
    lock.undo("lock");
    QVERIFY(!lock.lockLook().contains("panel"));

    lock.set("nowhere", "blur", 1);
    QVERIFY(!QFile::exists(home.filePath(".config/omacraft/nowhere.json")));

    lock.setIdle("lock", 600);
    QCOMPARE(lock.lockSeconds(), 600);
    QCOMPARE(readShellJson(home.path()).value("idle").toObject().value("lock").toInt(), 600);
    lock.setIdle("bogus", 5);
    QVERIFY(!readShellJson(home.path()).value("idle").toObject().contains("bogus"));
}

void OmacraftTests::loginArgumentsCarryNoPaths() {
    QTemporaryDir home;
    LockLogon lock(nullptr, nullptr, home.path(), home.path(), home.filePath("themes"), false);
    lock.setMany("login", {{"bgImage", "/home/me/a.png"}, {"avatar", "/home/me/b.png"}, {"bgFolder", "/x"}, {"blankSeconds", 9},
                           {"bgMode", "folder"}, {"blur", 0.5}, {"showClock", true}});
    const QStringList arguments = lock.loginArguments();
    QVERIFY(arguments.contains("blur=0.5"));
    QVERIFY(arguments.contains("showClock=true"));
    for (const auto &argument : arguments) {
        QVERIFY2(!argument.contains('/'), qPrintable(argument));
        QVERIFY2(!argument.startsWith("bgMode=folder"), qPrintable(argument));
        QVERIFY2(!argument.startsWith("blankSeconds"), qPrintable(argument));
    }
    QVERIFY(!arguments.filter(QRegularExpression("^themeAccent=#")).isEmpty());
}

void OmacraftTests::loginNeedsAPicture() {
    QTemporaryDir home;
    LockLogon lock(nullptr, nullptr, home.path(), home.path(), home.filePath("themes"), false);
    QString why;
    lock.setMany("login", {{"bgMode", "image"}, {"bgImage", "/home/me/clip.mp4"}});
    QVERIFY(lock.loginBackgroundFile(&why).isEmpty());
    QVERIFY(!why.isEmpty());
    why.clear();
    lock.setMany("login", {{"bgImage", "/home/me/photo.JPG"}});
    QCOMPARE(lock.loginBackgroundFile(&why), QString("/home/me/photo.JPG"));
    QVERIFY(why.isEmpty());
    lock.setMany("login", {{"bgMode", "solid"}});
    QVERIFY(lock.loginBackgroundFile(&why).isEmpty());
    QVERIFY(why.isEmpty());
}

void OmacraftTests::loginHelperRefusesHostileInput() {
    QTemporaryDir dir;
    const QString helper = helperInto(dir.path());
    const QString conf = dir.filePath("theme/theme.conf.user");

    QCOMPARE(runHelper(helper, {"apply", "-", "-", "blur=0.5", "greeting={user}@{host}", "dotGlyph=\u25CF", "dateFormat=dddd, d MMMM", "colorText=#ff0000"}), 0);
    QFile written(conf);
    QVERIFY(written.open(QIODevice::ReadOnly));
    const QByteArray bytes = written.readAll();
    QVERIFY(bytes.contains("dateFormat=\"dddd, d MMMM\""));
    QVERIFY(bytes.contains("colorText=\"#ff0000\""));

    // None of these may change what's on disk.
    const QStringList hostile{
        "note=x\"\n[Theme]\nCurrent=evil", "note=a\\b", "note=semi;colon", "note=$(id)", "note=`id`", "note=a\nb",
        "bgImage=/etc/shadow", "avatar=/root/.ssh/id_rsa", "Current=evil", "../../etc/passwd=1", "noequals",
        "note=" + QString(161, 'x')};
    for (const auto &setting : hostile) {
        QVERIFY2(runHelper(helper, {"apply", "-", "-", setting}) != 0, qPrintable(setting));
        written.seek(0);
        QCOMPARE(written.readAll(), bytes);
    }
    QVERIFY(runHelper(helper, {"theme", "evil"}) != 0);
    QVERIFY(runHelper(helper, {"autologin", "maybe"}) != 0);
    QVERIFY(runHelper(helper, {"rm", "-rf", "/"}) != 0);
    QVERIFY(runHelper(helper, {}) != 0);

    // Pictures: read as the caller, sniffed by content, named by the helper.
    writeFile(dir.filePath("fake.png"), "#!/bin/sh\nnot a picture\n");
    QVERIFY(runHelper(helper, {"apply", dir.filePath("fake.png"), "-", "blur=0.5"}) != 0);
    QVERIFY(runHelper(helper, {"apply", "relative.png", "-", "blur=0.5"}) != 0);
    QVERIFY(runHelper(helper, {"apply", dir.filePath("missing.png"), "-", "blur=0.5"}) != 0);
    QImage image(4, 4, QImage::Format_RGB32);
    image.fill(Qt::red);
    QVERIFY(image.save(dir.filePath("real.jpeg"), "PNG"));
    QCOMPARE(runHelper(helper, {"apply", dir.filePath("real.jpeg"), "-", "blur=0.5"}), 0);
    QVERIFY(QFile::exists(dir.filePath("theme/background.png")));
    QFile rewritten(conf);
    QVERIFY(rewritten.open(QIODevice::ReadOnly));
    QVERIFY(rewritten.readAll().contains("bgImage=\"background.png\""));
    QVERIFY(QDir(dir.filePath("theme")).entryList({".incoming*"}, QDir::Files | QDir::Hidden).isEmpty());

    // A bad picture mid-apply leaves the look as it was, not half of a new one.
    rewritten.seek(0);
    const QByteArray good = rewritten.readAll();
    QVERIFY(runHelper(helper, {"apply", "-", dir.filePath("fake.png"), "blur=0.9"}) != 0);
    QFile after(conf);
    QVERIFY(after.open(QIODevice::ReadOnly));
    QCOMPARE(after.readAll(), good);
    QVERIFY(QDir(dir.filePath("theme")).entryList({".incoming*", "*.XXXXXX"}, QDir::Files | QDir::Hidden).isEmpty());
}

void OmacraftTests::loginHelperOverridesAndReverts() {
    QTemporaryDir dir;
    const QString helper = helperInto(dir.path());
    // Omarchy's own files, which must never be touched.
    writeFile(dir.filePath("conf/autologin.conf"), "[Autologin]\nUser=skll\n");
    writeFile(dir.filePath("conf/99-omarchy-login.conf"), "[Theme]\nCurrent=omarchy\n");

    QCOMPARE(runHelper(helper, {"theme", "omacraft"}), 0);
    QCOMPARE(runHelper(helper, {"autologin", "off"}), 0);
    auto sddm = LockLogon::readSddmConfig(dir.filePath("conf"));
    QCOMPARE(sddm.value("theme").toString(), QString("omacraft"));
    QCOMPARE(sddm.value("autologinUser").toString(), QString());

    QCOMPARE(runHelper(helper, {"theme", "omarchy"}), 0);
    QCOMPARE(runHelper(helper, {"autologin", "on"}), 0);
    sddm = LockLogon::readSddmConfig(dir.filePath("conf"));
    QCOMPARE(sddm.value("theme").toString(), QString("omarchy"));
    QCOMPARE(sddm.value("autologinUser").toString(), QString("skll"));
    QCOMPARE(QDir(dir.filePath("conf")).entryList(QDir::Files).size(), 2);

    QCOMPARE(runHelper(helper, {"apply", "-", "-", "blur=0.5"}), 0);
    QCOMPARE(runHelper(helper, {"reset"}), 0);
    QVERIFY(!QFile::exists(dir.filePath("theme/theme.conf.user")));
    QVERIFY(QFile::exists(dir.filePath("theme/Main.qml")));
}

void OmacraftTests::lockPageDragsTheBlockAndPicksLooks() {
    QTemporaryDir home;
    Theme theme;
    Plugins plugins(home.path(), false);
    LockLogon lock(&plugins, nullptr, home.path(), home.path(), home.filePath("themes"), false);
    Harness h;
    auto *context = h.engine.rootContext();
    context->setContextProperty("theme", &theme);
    context->setContextProperty("plugins", &plugins);
    context->setContextProperty("lockLogon", &lock);
    context->setContextProperty("startTab", "");
    h.load("LockLogonPage { anchors.fill: parent; active: true }", {1100, 760});
    if (QTest::currentTestFailed()) return;

    QQuickItem *grip = h.named("lockStageGrip");
    QVERIFY(grip);
    // Near the left third, near the middle: both snap.
    const QPoint start = grip->mapToScene({grip->width() * 0.5, grip->height() * 0.5}).toPoint();
    const QPoint end = grip->mapToScene({grip->width() * 0.16, grip->height() * 0.51}).toPoint();
    h.drag(start, end);
    QTRY_COMPARE(lock.lockLook().value("blockX").toDouble(), 15.0);
    QCOMPARE(lock.lockLook().value("blockY").toDouble(), 50.0);

    QQuickItem *looks = h.named("lockLooks");
    QVERIFY(looks);
    QTest::mouseClick(h.window, Qt::LeftButton, {}, looks->mapToScene({260, 50}).toPoint());
    QTRY_COMPARE(lock.lockLook().value("bgMode").toString(), QString("solid"));
    h.shot("lock-logon");
}

void OmacraftTests::aboutShowsCreditsAndTheRealLicence() {
    const auto builtIn = [](const QString &path) {
        QFile file(path);
        return file.open(QIODevice::ReadOnly) ? QString::fromUtf8(file.readAll()) : QString();
    };
    const QString license = builtIn(":/about/LICENSE");
    const QString notices = builtIn(":/about/THIRD-PARTY-NOTICES.md");
    QVERIFY(license.startsWith("MIT License"));
    for (const char *work : {"Omacut", "Omarchy", "figlet.js", "HANCORE", "Burn My Windows", "JaKooLit", "HyDE", "Lock Screen Explorer", "### GPL-3.0"})
        QVERIFY2(notices.contains(work), work);

    Theme theme;
    Harness h;
    auto *context = h.engine.rootContext();
    context->setContextProperty("theme", &theme);
    context->setContextProperty("aboutLicense", license);
    context->setContextProperty("aboutNotices", notices);
    h.load("AboutDialog { id: about; objectName: 'about' }", {1000, 700});
    if (QTest::currentTestFailed()) return;
    QVERIFY(h.named("aboutSite"));
    QVERIFY(h.named("aboutCopyright")->property("text").toString().contains("2026 skll"));
    h.shot("about");
    QObject *about = h.named("about");
    about->setProperty("tab", "credits");
    QVERIFY(h.named("aboutText")->property("text").toString().contains("Simon Schneegans"));
    QVERIFY(!h.named("aboutText")->property("text").toString().contains("Permission is hereby granted"));
    h.shot("about-credits");
    about->setProperty("tab", "licences");
    QVERIFY(h.named("aboutText")->property("text").toString().contains("Permission is hereby granted"));
    QVERIFY(h.named("aboutText")->property("text").toString().contains("gpl-3.0.html"));
    h.shot("about-licences");
}

void OmacraftTests::titleFontPickerOnlyChangesTheTitle()
{
    // The pick is saved in OmaCraft's window settings: Qt's test folder here.
    QStandardPaths::setTestModeEnabled(true);
    const QString saved = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + "/omacraft/window.ini";
    QFile::remove(saved);
    // Declared before the window, so it runs after the window has saved.
    const auto cleanup = qScopeGuard([saved] {
        QFile::remove(saved);
        QDir().rmdir(QFileInfo(saved).absolutePath());
        QStandardPaths::setTestModeEnabled(false);
    });
    QTemporaryDir cache;
    // omascii runs from the repository's copy, which must stay as committed.
    qputenv("PYTHONDONTWRITEBYTECODE", "1");
    const QString plugin = QFileInfo(QString(__FILE__)).absolutePath() + "/../plugins/omascii";
    Omascii omascii([plugin] { return plugin; });
    IntroReel reel(&omascii, cache.path());

    // Another font is another drawing of the title, cached on its own; the
    // usual font is no font picked at all.
    const QString usual = reel.cachePath("decrypt");
    reel.setFont("Slant");
    QVERIFY(reel.customFont());
    QCOMPARE(reel.font(), QString("Slant"));
    QVERIFY(reel.cachePath("decrypt") != usual);
    reel.setFont(IntroReel::titleFont());
    QVERIFY(!reel.customFont());
    QCOMPARE(reel.cachePath("decrypt"), usual);

    omascii.refresh();
    QTRY_VERIFY_WITH_TIMEOUT(reel.available(), 30000);
    const QVariantMap bootBefore = omascii.config();

    Theme theme;
    qmlRegisterType<AsciiView>("Omacraft", 1, 0, "AsciiView");
    Harness h;
    h.engine.rootContext()->setContextProperty("theme", &theme);
    h.engine.rootContext()->setContextProperty("introReel", &reel);
    h.load("IntroTitle { anchors.fill: parent; running: false }", {900, 640});
    if (QTest::currentTestFailed()) return;

    QQuickItem *button = h.named("titleFontButton");
    QVERIFY(button);
    QTRY_VERIFY(button->isVisible());
    QTest::mouseClick(h.window, Qt::LeftButton, {}, h.middle(button));
    QTRY_VERIFY_WITH_TIMEOUT(reel.fonts().size() > 100, 20000);
    for (const char key : QByteArray("slant"))
        QTest::keyClick(h.window, key);
    QTest::qWait(100);
    h.shot("title-font-picker");
    QTest::keyClick(h.window, Qt::Key_Return);
    QTRY_VERIFY(reel.font().contains("lant", Qt::CaseInsensitive));
    QVERIFY(reel.customFont());
    // The boot splash's own design is left as it was.
    QCOMPARE(omascii.config(), bootBefore);
}
