#pragma once

#include <QObject>

// Declared here rather than in the .cpp: moc can't read the raw string
// fixtures the test bodies use.
class OmacraftTests : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void themeFallsBack();
    void themeReadsAccent();
    void themeFollowsLightAndDark();
    void savesAtomically();
    void expandsHomeAndQuotes();
    void readsBarSections();
    void switchesPluginsWithoutBarIcons();
    void switchingAPluginEditsShellJsonInPlace();
    void installsByLinkingTheSource();
    void flagsAFolderThatReusesAPluginId();
    void removingALinkKeepsTheCode();
    void removingAFolderSetsItAsideAndInstallBringsItBack();
    void installReplacesABrokenLinkButNotAFolder();
    void sourcesCanBeMoved();
    void readsAnimationStatus();
    void readsAnimationLookOverrides();
    void animationPresetsCarryTheirMotion();
    void dockStartsFromItsDefaults();
    void dockSavesSettingsWhileStopped();
    void dockItemsMoveAndKeepOnlyTheirFields();
    void dockAgentsGoToTheConfigFile();
    void dockHidesAgentTabs();
    void dockLookHasDefaults();
    void barReadsPresetsJs();
    void barSaysWhenItIsNotTheBar();
    void barReadsStudioPresetsWithImports();
    void barEditsShellJsonInPlaceWithUndo();
    void barLayoutsKeepWidgetSettings();
    void barHidesWidgetsAndBringsThemBack();
    void barAddsOmarchyAndBase16Themes();
    void edgeTabFollowsThePointerRoundTheEdge();
    void barThemesSaveImportAndSanitize();
    void omasciiChecksBeforeApplying();
    void omasciiReadsEveryFontList();
    void hyprcraftServesOnlyTheApp();
    void hyprcraftFindsTheFirstBuild();
    void hyprcraftKnowsAnOmarchyBundle();
    void launcherReadsItsStyles();
    void launcherWritesInPlaceAndKeepsOtherKeys();
    void burnReadsItsEffects();
    void wallPickerNormalizesKeys();
    void wallPickerBindsThroughHyprlandLua();
    void burnWritesInPlaceAndKeepsOtherKeys();
    void foldersReadTheirBarEntries();
    void foldersScanInstalledApps();
    void foldersEditShellJsonInPlace();
    void wallpaperKnowsAFavoriteByAnyName();
    void wallpaperMergesPagesWithoutRepeats();
    void wallpaperWritesInOrderAndFlipsAtOnce();
    void barUnderlineTextReadsOnTheBar();
    void themeSyncBuildsABorderGradient();
    void themeSyncFollowsAndPutsBack();
    void asciiViewPaintsBackgroundSpans();
    void omasciiPresetIsOneUndoStep();
    void bootSplashReadsTheThemeAndWhereToGoBack();
    void screensaverNeverTouchesTheBootScreen();
    void screensaverKeepsItsArtPlain();
    void screensaverKnowsWhoseHookItIs();
    void screensaverSetsTheIdleTimeInPlace();
    void screensaverScriptsParse();
};
