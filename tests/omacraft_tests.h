#pragma once

#include <QObject>

// Declared here rather than in the .cpp: moc can't read the raw string
// fixtures the test bodies use.
class OmacraftTests : public QObject {
    Q_OBJECT

private slots:
    void themeFallsBack();
    void themeReadsAccent();
    void savesAtomically();
    void expandsHomeAndQuotes();
    void readsBarSections();
    void installsByLinkingTheSource();
    void removingALinkKeepsTheCode();
    void removingAFolderSetsItAsideAndInstallBringsItBack();
    void installReplacesABrokenLinkButNotAFolder();
    void sourcesCanBeMoved();
    void readsAnimationStatus();
    void dockStartsFromItsDefaults();
    void dockSavesSettingsWhileStopped();
    void dockItemsMoveAndKeepOnlyTheirFields();
    void dockAgentsGoToTheConfigFile();
    void dockHidesAgentTabs();
    void barReadsPresetsJs();
    void barSaysWhenItIsNotTheBar();
    void omasciiChecksBeforeApplying();
    void omasciiReadsEveryFontList();
    void hyprcraftServesOnlyTheApp();
    void hyprcraftFindsTheFirstBuild();
};
