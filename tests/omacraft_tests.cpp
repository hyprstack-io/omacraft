#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPainter>
#include <QTemporaryDir>
#include <QtTest>
#include <sys/stat.h>

#include "agentdock.h"
#include "animations.h"
#include "asciiview.h"
#include "bar.h"
#include "edgetab.h"
#include "introreel.h"
#include "omascii.h"
#include "bootsplash.h"
#include "burn.h"
#include "hyprcraft.h"
#include "launcher.h"
#include "omascii.h"
#include "plugins.h"
#include "proc.h"
#include "rofioma.h"
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
