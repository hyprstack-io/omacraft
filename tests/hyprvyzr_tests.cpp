// HyprVYZR: the keys file, the bar folder's edit of shell.json, and the
// session window's spec file. Everything runs in a temp home with commands off.

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QtTest>

#include "hyprvyzr.h"
#include "omacraft_tests.h"

namespace {

void put(const QString &path, const QByteArray &bytes) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(bytes);
}

QByteArray take(const QString &path) {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}

} // namespace

void OmacraftTests::hyprvyzrKeysRoundTrip()
{
    const QVariantMap keys{{"all", "SUPER + ALT + V"}, {"running", "SUPER + CTRL + ALT + V"}};
    const QString file = Hyprvyzr::keysFile(keys);
    QVERIFY(file.contains("hl.unbind(\"SUPER + ALT + V\")"));
    QVERIFY(file.contains(R"(o.bind("SUPER + ALT + V", "HyprVYZR: all", "omarchy-shell shell toggle omacraft.hyprvyzr '{\"tab\":\"all\"}'"))"));
    QVERIFY(file.contains("\"HyprVYZR: running\""));
    QVERIFY(!file.contains("HyprVYZR: remote"));
    QCOMPARE(Hyprvyzr::keysIn(file), keys);
    // An unknown tab never reaches the file.
    QCOMPARE(Hyprvyzr::carouselCommand("../x"), Hyprvyzr::carouselCommand("all"));
}

void OmacraftTests::hyprvyzrBindsAndRefusesClashes()
{
    QTemporaryDir home;
    const QString main = home.path() + "/.config/hypr/hyprland.lua";
    put(main, "require(\"hypr.bindings\")\n");
    Hyprvyzr hv({}, nullptr, home.path(), false);

    QVERIFY(!hv.bindKey("all", "SUPER + ALT"));
    QVERIFY(!hv.error().isEmpty());
    QVERIFY(hv.bindKey("all", "super alt v"));
    QCOMPARE(hv.keys().value("all").toString(), QString("SUPER + ALT + V"));
    // One key, one tab.
    QVERIFY(!hv.bindKey("remote", "SUPER + ALT + V"));
    QVERIFY(hv.bindKey("remote", "SUPER + SHIFT + ALT + V"));
    QVERIFY(!hv.bindKey("nowhere", "SUPER + F12"));
    // hyprland.lua gains the require once, with a copy of how it was.
    QCOMPARE(QString::fromUtf8(take(main)).count("hypr.omacraft_hyprvyzr"), 1);
    QCOMPARE(QDir(home.path() + "/.config/hypr").entryList({"hyprland.lua.before-hyprvyzr-*"}).size(), 1);
    // Cleared, and read back by a fresh instance.
    QVERIFY(hv.bindKey("all", ""));
    Hyprvyzr again({}, nullptr, home.path(), false);
    QCOMPARE(again.keys(), (QVariantMap{{"remote", "SUPER + SHIFT + ALT + V"}}));
}

void OmacraftTests::hyprvyzrPutsItsFolderOnTheBarInPlace()
{
    QTemporaryDir home;
    const QString shell = home.path() + "/.config/omarchy/shell.json";
    put(shell, R"({"theme":"x","bar":{"id":"omabar16","layout":{"left":[{"id":"clock"}],"center":[],"right":[{"id":"tray"}]}},"plugins":[{"id":"a"}]})");
    Hyprvyzr hv({}, nullptr, home.path(), false);
    QVERIFY(!hv.onBar());

    hv.setOnBar(true);
    QVERIFY(hv.onBar());
    QJsonObject json = QJsonDocument::fromJson(take(shell)).object();
    const QJsonArray right = json["bar"].toObject()["layout"].toObject()["right"].toArray();
    QCOMPARE(right.size(), 2);
    QCOMPARE(right.at(0).toObject()["id"].toString(), QString("omacraft.hyprvyzr"));
    // Everything else is kept.
    QCOMPARE(json["theme"].toString(), QString("x"));
    QCOMPARE(json["plugins"].toArray().size(), 1);
    QVERIFY(QFile::exists(shell + ".hyprvyzr-bak"));

    // Twice is still once; off takes it out.
    hv.setOnBar(true);
    hv.setOnBar(false);
    QVERIFY(!hv.onBar());
    json = QJsonDocument::fromJson(take(shell)).object();
    QCOMPARE(json["bar"].toObject()["layout"].toObject()["right"].toArray().size(), 1);

    // A broken shell.json is left alone.
    put(shell, "{ not json");
    Hyprvyzr broken({}, nullptr, home.path(), false);
    broken.setOnBar(true);
    QVERIFY(!broken.error().isEmpty());
    QCOMPARE(take(shell), QByteArray("{ not json"));
}

void OmacraftTests::kasmViewReadsAPrivateSpecOnce()
{
    QTemporaryDir runtime;
    qputenv("XDG_RUNTIME_DIR", runtime.path().toUtf8());
    const QString spec = runtime.path() + "/hyprvyzr/abc123.json";
    put(spec, R"({"id":"abc123","title":"Chrome","server":"This machine","kind":"native",
                 "url":"https://127.0.0.1:41000/","auth":{"user":"kasm_user","password":"pw"},
                 "insecureLocal":true,"cli":"/nowhere"})");
    QFile::setPermissions(spec, QFile::ReadOwner | QFile::WriteOwner);

    KasmView view(spec);
    QVERIFY2(view.valid(), qPrintable(view.problem()));
    QCOMPARE(view.title(), QString("Chrome"));
    QCOMPARE(view.authUser(), QString("kasm_user"));
    // Read once: the link and password don't stay on disk.
    QVERIFY(!QFile::exists(spec));
    // Its own certificate only: same loopback host and port.
    QVERIFY(view.acceptCertificate(QUrl("https://127.0.0.1:41000/websockify")));
    QVERIFY(!view.acceptCertificate(QUrl("https://127.0.0.1:41001/")));
    QVERIFY(!view.acceptCertificate(QUrl("https://example.com:41000/")));
}

void OmacraftTests::kasmViewRefusesASharedSpec()
{
    QTemporaryDir runtime;
    qputenv("XDG_RUNTIME_DIR", runtime.path().toUtf8());
    // Readable by others: refused, and not deleted (it isn't ours to judge).
    const QString open = runtime.path() + "/hyprvyzr/abc123.json";
    put(open, R"({"id":"abc123","url":"https://reqt.net/#/connect/kasm/1/2/t"})");
    QFile::setPermissions(open, QFile::ReadOwner | QFile::WriteOwner | QFile::ReadOther);
    QVERIFY(!KasmView(open).valid());

    // Outside hyprvyzr's runtime folder: refused.
    const QString elsewhere = runtime.path() + "/abc123.json";
    put(elsewhere, R"({"id":"abc123","url":"https://reqt.net/"})");
    QFile::setPermissions(elsewhere, QFile::ReadOwner | QFile::WriteOwner);
    QVERIFY(!KasmView(elsewhere).valid());

    // Not https: refused, and never a self-signed pass for a remote host.
    const QString plain = runtime.path() + "/hyprvyzr/def456.json";
    put(plain, R"({"id":"def456","url":"http://reqt.net/","insecureLocal":true})");
    QFile::setPermissions(plain, QFile::ReadOwner | QFile::WriteOwner);
    KasmView view(plain);
    QVERIFY(!view.valid());
    QVERIFY(!view.acceptCertificate(QUrl("https://reqt.net/")));
}
