#include "omacraft_tests.h"

#include "cursoricons.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>
#include <QtEndian>

namespace {

void put(const QString &path, const QByteArray &bytes) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(bytes);
}

void le32(QByteArray &out, quint32 value) {
    char bytes[4];
    qToLittleEndian(value, bytes);
    out.append(bytes, 4);
}

// An XCursor with one frame per (nominal, colour) pair, side x side, every
// pixel the same premultiplied ARGB, with a white 1px edge on the first row.
QByteArray xcursor(const QList<QPair<int, quint32>> &images, int side = 4, int delay = 50) {
    QByteArray out;
    le32(out, 0x72756358);
    le32(out, 16);
    le32(out, 0x10000);
    le32(out, quint32(images.size()));
    qsizetype at = 16 + images.size() * 12;
    for (const auto &image : images) {
        le32(out, 0xfffd0002);
        le32(out, quint32(image.first));
        le32(out, quint32(at));
        at += 36 + side * side * 4;
    }
    for (const auto &image : images) {
        for (quint32 v : {36u, 0xfffd0002u, quint32(image.first), 1u, quint32(side), quint32(side), 0u, 0u, quint32(delay)})
            le32(out, v);
        for (int i = 0; i < side * side; ++i)
            le32(out, i < side ? 0xffffffffu : image.second);
    }
    return out;
}

quint32 pixel(const QByteArray &file, const XCursor::Frame &frame, int index) {
    return qFromLittleEndian<quint32>(file.constData() + frame.offset + index * 4);
}

void theme(const QString &dir, const QString &index) { put(dir + "/index.theme", index.toUtf8()); }

} // namespace

void OmacraftTests::cursorIconsReadsAndTintsXCursors() {
    const QByteArray file = xcursor({{24, 0xff000000}, {24, 0xff101010}, {32, 0xff000000}});
    const auto all = XCursor::frames(file);
    QCOMPARE(all.size(), 3);
    QCOMPARE(all.first().delay, 50);
    // Two frames of 24 make an animation; 30 is nearer 32.
    QCOMPARE(XCursor::framesNear(all, 24).size(), 2);
    QCOMPARE(XCursor::framesNear(all, 30).first().nominal, 32);
    QCOMPARE(XCursor::image(file, all.first()).pixel(0, 2), QColor(Qt::black).rgba());

    // Junk, and a table that points past the end, are not cursors.
    QVERIFY(XCursor::frames("not a cursor").isEmpty());
    QByteArray cut = file.left(60);
    QVERIFY(XCursor::frames(cut).isEmpty());

    // A black arrow with a white edge: the body takes the colour, the edge stays.
    QVERIFY(XCursor::darkBody(file));
    const QColor red("#ff2020");
    const QByteArray tinted = XCursor::tinted(file, red, true);
    QCOMPARE(tinted.size(), file.size());
    QCOMPARE(tinted.left(16), file.left(16));
    const auto frame = XCursor::frames(tinted).first();
    QCOMPARE(QColor::fromRgba(pixel(tinted, frame, 8)).name(), red.name());
    QCOMPARE(pixel(tinted, frame, 0), 0xffffffffu);
    // Clear stays clear; half-clear stays premultiplied (no channel above alpha).
    QCOMPARE(XCursor::tintPixel(0, red, true), 0u);
    const quint32 half = XCursor::tintPixel(0x80000000, red, true);
    QCOMPARE(half >> 24, 0x80u);
    QVERIFY((half >> 16 & 0xff) <= 0x80);
    // A light body (white arrow, black edge) is tinted the other way round.
    QVERIFY(!XCursor::darkBody(xcursor({{32, 0xffffffff}})));
    QCOMPARE(QColor::fromRgba(XCursor::tintPixel(0xffffffff, red, false)).name(), red.name());
    QCOMPARE(XCursor::tintPixel(0xff000000, red, false), 0xff000000u);
}

void OmacraftTests::cursorIconsFindsTheNearestColourVariant() {
    const auto v = CursorsIcons::variantOf("Yaru-prussiangreen-dark");
    QCOMPARE(v.family, QString("Yaru"));
    QCOMPARE(v.color, QString("prussiangreen"));
    QCOMPARE(v.suffix, QString("dark"));
    QCOMPARE(CursorsIcons::variantOf("Yaru").color, QString("orange"));
    QCOMPARE(CursorsIcons::variantOf("Papirus-Dark").family, QString("Papirus"));
    QCOMPARE(CursorsIcons::variantOf("breeze").color, QString());

    const QStringList installed{"Yaru", "Yaru-blue", "Yaru-red", "Yaru-magenta", "Yaru-blue-dark", "Yaru-red-dark", "Adwaita"};
    QCOMPARE(CursorsIcons::nearestVariant("Yaru-blue", installed, QColor("#d02040")), QString("Yaru-red"));
    QCOMPARE(CursorsIcons::nearestVariant("Yaru-blue", installed, QColor("#71b4dc")), QString("Yaru-blue"));
    // The dark variant stays dark.
    QCOMPARE(CursorsIcons::nearestVariant("Yaru-blue-dark", installed, QColor("#d02040")), QString("Yaru-red-dark"));
    // A theme with no siblings is kept as it is.
    QCOMPARE(CursorsIcons::nearestVariant("Adwaita", installed, QColor("#d02040")), QString("Adwaita"));
}

void OmacraftTests::cursorIconsImportsOnlyWhatIsSafe() {
    QTemporaryDir home, system, outside, source;
    put(outside.filePath("secret"), "keep out");
    // A pack with an icon theme, a bare cursor folder, a link out and a link in.
    theme(source.filePath("pack/Good"), "[Icon Theme]\nName=Good\nDirectories=48x48/apps\n\n[48x48/apps]\nSize=48\n");
    put(source.filePath("pack/Good/48x48/apps/folder.svg"), "<svg/>");
    QVERIFY(QFile::link(outside.filePath("secret"), source.filePath("pack/Good/48x48/apps/leak.svg")));
    QVERIFY(QFile::link("folder.svg", source.filePath("pack/Good/48x48/apps/folder-alias.svg")));
    put(source.filePath("pack/Bare/cursors/left_ptr"), xcursor({{24, 0xff000000}}));
    // Taken: a system theme of the same name.
    theme(system.filePath("Taken"), "[Icon Theme]\nName=Taken\nDirectories=a\n");
    theme(source.filePath("pack/Taken"), "[Icon Theme]\nName=Taken\nDirectories=a\n");

    CursorsIcons icons(nullptr, home.path(), {system.path()}, false);
    icons.importFrom(source.filePath("pack"));
    const QString good = home.filePath(".local/share/icons/Good");
    QVERIFY(QFileInfo(good + "/48x48/apps/folder.svg").isFile());
    QVERIFY(!QFileInfo(good + "/48x48/apps/leak.svg").exists());
    QVERIFY(!QFileInfo(good + "/48x48/apps/leak.svg").isSymLink());
    QVERIFY(QFileInfo(good + "/48x48/apps/folder-alias.svg").isSymLink());
    QVERIFY(QFileInfo::exists(home.filePath(".local/share/icons/Bare/index.theme")));
    QVERIFY(icons.notice().contains("Good"));
    QVERIFY(icons.notice().contains("Taken (already installed)"));
    // The source is copied, not moved, and the staging folder is gone.
    QVERIFY(QFileInfo::exists(source.filePath("pack/Good/index.theme")));
    QVERIFY(QDir(home.filePath(".cache/omacraft")).entryList({"import-*"}, QDir::Dirs).isEmpty());

    QStringList ids;
    for (const QVariant &row : icons.iconThemes())
        ids << row.toMap().value("id").toString();
    QVERIFY(ids.contains("Good"));
    bool bare = false;
    for (const QVariant &row : icons.cursorThemes())
        bare = bare || row.toMap().value("id").toString() == "Bare";
    QVERIFY(bare);
    QCOMPARE(icons.iconSamples("Good").size(), 1);

    // System themes stay; imported ones go to the stash, not the bin.
    icons.remove("Taken");
    QVERIFY(QFileInfo::exists(system.filePath("Taken/index.theme")));
    icons.remove("Good");
    QVERIFY(!QFileInfo::exists(good));
    QCOMPARE(QDir(home.filePath(".local/share/omacraft/stash/icons")).entryList({"Good-*"}, QDir::Dirs).size(), 1);

    // Something that's neither an archive nor a folder is refused.
    put(source.filePath("notes.txt"), "hi");
    icons.importFrom(source.filePath("notes.txt"));
    QVERIFY(icons.error().contains("isn't an archive"));
}

void OmacraftTests::cursorIconsAppliesFollowsAndUndoes() {
    QTemporaryDir home, system;
    put(home.filePath(".local/state/omarchy/current/theme/colors.toml"), "accent = \"#e01b24\"\nforeground = \"#dddddd\"\nblue = \"#3584e4\"\n");
    put(home.filePath(".local/state/omarchy/current/theme/icons.theme"), "Fam-blue\n");
    put(home.filePath(".config/hypr/hyprland.lua"), "require(\"default.hypr.omarchy\")\n");
    theme(system.filePath("Base"), "[Icon Theme]\nName=Base Cursors\n");
    put(system.filePath("Base/cursors/left_ptr"), xcursor({{24, 0xff000000}, {48, 0xff000000}}));
    QVERIFY(QFile::link("left_ptr", system.filePath("Base/cursors/default")));
    for (const QString &id : {"Fam-blue", "Fam-red", "Fam-magenta"})
        theme(system.filePath(id), "[Icon Theme]\nName=" + id + "\nDirectories=48x48/places\n\n[48x48/places]\nSize=48\n");
    put(system.filePath("Fam-blue/48x48/places/folder.png"), "png");

    CursorsIcons icons(nullptr, home.path(), {system.path()}, false);
    icons.useCursor("Base");
    QCOMPARE(icons.cursorTheme(), QString("Base"));
    QVERIFY(QFile(home.filePath(".local/share/icons/default/index.theme")).open(QIODevice::ReadOnly));
    QFile index(home.filePath(".local/share/icons/default/index.theme"));
    QVERIFY(index.open(QIODevice::ReadOnly));
    QVERIFY(index.readAll().contains("Inherits=Base"));
    QFile lua(home.filePath(".config/hypr/omacraft_cursor.lua"));
    QVERIFY(lua.open(QIODevice::ReadOnly));
    QVERIFY(lua.readAll().contains("hl.env(\"XCURSOR_SIZE\", \"24\")"));
    QFile main(home.filePath(".config/hypr/hyprland.lua"));
    QVERIFY(main.open(QIODevice::ReadOnly));
    QCOMPARE(main.readAll().count("hypr.omacraft_cursor"), 1);

    // Tinted: a red copy of Base, with its alias kept as an alias.
    icons.setCursorMode("follow");
    QCOMPARE(icons.cursorTheme(), QString("omacraft-tinted-e01b24"));
    const QString tinted = home.filePath(".local/share/icons/omacraft-tinted-e01b24");
    QVERIFY(QFileInfo(tinted + "/cursors/default").isSymLink());
    QFile red(tinted + "/cursors/left_ptr");
    QVERIFY(red.open(QIODevice::ReadOnly));
    const QByteArray bytes = red.readAll();
    QCOMPARE(QColor::fromRgba(pixel(bytes, XCursor::frames(bytes).first(), 8)).name(), QString("#e01b24"));
    // Generated tints aren't offered as themes of their own.
    for (const QVariant &row : icons.cursorThemes())
        QVERIFY(!row.toMap().value("id").toString().startsWith(CursorsIcons::kTintedPrefix));
    // A new colour replaces the old tint rather than piling up.
    icons.setTintKey("blue");
    QCOMPARE(icons.cursorTheme(), QString("omacraft-tinted-3584e4"));
    QVERIFY(!QFileInfo::exists(tinted));
    QCOMPARE(icons.cursorSamples(icons.cursorTheme(), 48).size(), 1);

    icons.setCursorSize(48);
    QFile sized(home.filePath(".config/hypr/omacraft_cursor.lua"));
    QVERIFY(sized.open(QIODevice::ReadOnly));
    QVERIFY(sized.readAll().contains("\"48\""));

    // Icons: a pick, then its family in the theme's colour.
    icons.useIcons("Fam-blue");
    QCOMPARE(icons.iconMode(), QString("fixed"));
    QCOMPARE(icons.iconTheme(), QString("Fam-blue"));
    icons.setTintKey("accent");
    icons.setIconMode("follow");
    QCOMPARE(icons.iconTheme(), QString("Fam-red"));
    icons.undo();
    QCOMPARE(icons.iconMode(), QString("fixed"));
    QCOMPARE(icons.iconTheme(), QString("Fam-blue"));

    // The theme-set hook's pass picks the colour again from the file.
    put(home.filePath(".local/state/omarchy/current/theme/colors.toml"), "accent = \"#b34cb3\"\n");
    icons.setIconMode("follow");
    QCOMPARE(icons.iconTheme(), QString("Fam-magenta"));
    QVERIFY(QFile::copy(home.filePath(".config/omacraft/appearance.json"), home.filePath("before.json")));
    CursorsIcons::syncNow(home.path(), {system.path()}, false);
    QFile kept(home.filePath(".config/omacraft/appearance.json")), before(home.filePath("before.json"));
    QVERIFY(kept.open(QIODevice::ReadOnly) && before.open(QIODevice::ReadOnly));
    QCOMPARE(kept.readAll(), before.readAll());

    // Back to Omarchy's: its theme's icons, its cursor, and nothing of ours left.
    icons.restoreDefaults();
    QCOMPARE(icons.iconMode(), QString("omarchy"));
    QCOMPARE(icons.iconTheme(), QString("Fam-blue"));
    QVERIFY(!QFileInfo::exists(home.filePath(".local/share/icons/default/index.theme")));
    QVERIFY(!QFileInfo::exists(home.filePath(".config/hypr/omacraft_cursor.lua")));
    QVERIFY(QDir(home.filePath(".local/share/icons")).entryList({"omacraft-tinted-*"}, QDir::Dirs).isEmpty());
}
