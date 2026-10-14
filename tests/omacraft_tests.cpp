#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QtTest>
#include <sys/stat.h>

#include "agentdock.h"
#include "animations.h"
#include "bar.h"
#include "burn.h"
#include "hyprcraft.h"
#include "launcher.h"
#include "omascii.h"
#include "plugins.h"
#include "proc.h"
#include "theme.h"
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
        "left":[{"id":"a"}],"center":[{"id":"b"}],"right":[{"id":"c"},{"id":"omacraft.agentdock"}]}}})").object();
    QCOMPARE(Plugins::sectionIn(shell, "omacraft.agentdock"), QString("right"));
    QCOMPARE(Plugins::sectionIn(shell, "b"), QString("center"));
    QCOMPARE(Plugins::sectionIn(shell, "missing"), QString());
    QCOMPARE(Plugins::barIn(shell), QString("omabar16"));
    QCOMPARE(Plugins::barIn(QJsonObject()), QString("omarchy.bar"));
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
    dock.set("activeTab", "sneaky"); // not a setting the dock takes from OMAcraft
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
var LAYOUTS = [{ id: "min", label: "Minimal", layout: { left: [{ id: "a" }], center: [], right: [{ id: "b" }, { id: "c" }] } }]
var GLYPHS = { "omarchy.clock": "\u{F0954}" }
)");
    writeFile(home.path() + "/.config/omarchy/omabar16/themes.json", R"([{"id":"user-x","label":"Mine","style":{"shape":"arrow"}}])");
    writeFile(home.path() + "/.local/state/omarchy/current/theme/colors.toml", "accent = \"#abcdef\"\nblue = \"#0000ff\"\n");
    writeFile(home.path() + "/.config/omarchy/shell.json", R"({"bar":{"id":"omabar16","style":{"shape":"round","gap":6}}})");

    Bar bar([plugin] { return plugin; }, home.path(), false);
    QVERIFY2(bar.available(), qPrintable(bar.error()));
    QCOMPARE(bar.themes().size(), 3);
    const auto pills = bar.themes().at(0).toMap();
    QCOMPARE(pills.value("group").toString(), QString("Looks"));
    QCOMPARE(pills.value("swatches").toStringList(), QStringList({"#abcdef", "#0000ff"}));
    QCOMPARE(bar.themes().at(1).toMap().value("swatches").toStringList(), QStringList({"#112233"}));
    QCOMPARE(bar.themes().at(2).toMap().value("group").toString(), QString("Yours"));
    QCOMPARE(bar.layouts().at(0).toMap().value("counts").toString(), QString("1 · 0 · 2"));
    QCOMPARE(bar.glyphFor("omarchy.clock"), QString::fromUcs4(U"\U000F0954"));
    QVERIFY(bar.inUse());
    QCOMPARE(bar.currentTheme(), QString("pills"));
}

void OmacraftTests::barSaysWhenItIsNotTheBar()
{
    QTemporaryDir home;
    Bar bar({}, home.path(), false);
    QVERIFY(!bar.available());
    QVERIFY(!bar.inUse());
    QCOMPARE(bar.barId(), QString("omarchy.bar"));
    bar.applyTheme("pills");
    QVERIFY(bar.error().contains("isn't your bar"));
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


// --- launcher (OMArofi) ---

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
