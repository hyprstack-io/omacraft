#pragma once

#include <QJsonObject>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <functional>

class AgentDock;

// HyprVYZR: Kasm Workspaces on the desktop. The omacraft.hyprvyzr plugin
// carries the `hyprvyzr` command (servers, keys in the keyring, sessions,
// native Docker images, the local install), the carousel overlay and the bar
// folder; this page drives all of it through that command, and writes what
// OmaCraft owns itself:
//
//   ~/.config/hypr/omacraft_hyprvyzr.lua   the carousel's keys (one per tab)
//   ~/.config/omacraft/hyprvyzr.json       how the carousel draws its card
//   shell.json bar layout                  the bar folder, in place
//   the side dock's items                  through AgentDock
//
// Credentials go to the command on stdin and from there to the keyring; they
// never sit in a property, an argument or a file this class writes.
class Hyprvyzr : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(QVariantList servers READ servers NOTIFY changed)
    Q_PROPERTY(QVariantList workspaces READ workspaces NOTIFY changed)
    Q_PROPERTY(QStringList workspaceErrors READ workspaceErrors NOTIFY changed)
    Q_PROPERTY(QVariantList sessions READ sessions NOTIFY changed)
    Q_PROPERTY(QVariantMap local READ local NOTIFY changed)
    Q_PROPERTY(QVariantMap config READ config NOTIFY changed)
    Q_PROPERTY(QString busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)
    Q_PROPERTY(QVariantMap keys READ keys NOTIFY changed)
    Q_PROPERTY(QVariantList keyTabs READ keyTabs CONSTANT)
    Q_PROPERTY(bool onBar READ onBar NOTIFY changed)
    Q_PROPERTY(bool onDock READ onDock NOTIFY changed)
    Q_PROPERTY(QString cardEffect READ cardEffect NOTIFY changed)
    Q_PROPERTY(double cardSpeed READ cardSpeed NOTIFY changed)
    Q_PROPERTY(bool showTitle READ showTitle NOTIFY changed)
    Q_PROPERTY(QString cardBorderUrl READ cardBorderUrl NOTIFY changed)

public:
    // pluginDir: where omacraft.hyprvyzr is. dock: the side dock, for its
    // launchers (may be null). Tests pass a temp home and runCommands false.
    explicit Hyprvyzr(std::function<QString()> pluginDir, AgentDock *dock = nullptr, const QString &home = {},
                      bool runCommands = true, QObject *parent = nullptr);

    static constexpr const char *kPluginId = "omacraft.hyprvyzr";

    bool available() const;
    QString cli() const;
    QVariantList servers() const { return m_servers; }
    QVariantList workspaces() const { return m_workspaces; }
    QStringList workspaceErrors() const { return m_workspaceErrors; }
    QVariantList sessions() const { return m_sessions; }
    QVariantMap local() const { return m_local; }
    QVariantMap config() const { return m_config.toVariantMap(); }
    QString busy() const { return m_busy; }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }
    QVariantMap keys() const { return m_keys; }
    static QVariantList keyTabs();
    bool onBar() const;
    bool onDock() const;
    QString cardEffect() const { return m_cardEffect; }
    double cardSpeed() const { return m_cardSpeed; }
    bool showTitle() const { return m_showTitle; }
    QString cardBorderUrl() const;

    QString keysPath() const { return m_home + "/.config/hypr/omacraft_hyprvyzr.lua"; }
    QString settingsPath() const { return m_home + "/.config/omacraft/hyprvyzr.json"; }
    QString configPath() const { return m_home + "/.config/hyprvyzr/hyprvyzr.json"; }
    QString shellPath() const { return m_home + "/.config/omarchy/shell.json"; }

    // The generated keys file for {tab: key}, and the keys a file binds.
    static QString keysFile(const QVariantMap &keys);
    static QVariantMap keysIn(const QString &file);
    // The command a launcher (dock, folder) runs to open the carousel on tab.
    static QString carouselCommand(const QString &tab);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void refreshWorkspaces(bool force = false);
    Q_INVOKABLE void refreshSessions();
    // fields: name, url, user, kind (remote|local), insecure, ssh, apiKey, apiSecret.
    Q_INVOKABLE void addServer(const QVariantMap &fields);
    Q_INVOKABLE void removeServer(const QString &id);
    Q_INVOKABLE void testServer(const QString &id);
    Q_INVOKABLE void openDashboard(const QString &id);
    Q_INVOKABLE void launch(const QString &key);
    // show, hide, toggle, float, tile, end.
    Q_INVOKABLE void sessionAction(const QString &action, const QString &id);
    Q_INVOKABLE void openCarousel(const QString &tab = {});
    // An empty key clears that tab's key.
    Q_INVOKABLE bool bindKey(const QString &tab, const QString &key);
    Q_INVOKABLE void setOnBar(bool on);
    Q_INVOKABLE void setOnDock(bool on);
    // native.enabled, native.tag, native.shm, window, size, local.port.
    Q_INVOKABLE void setConfig(const QString &key, const QVariant &value);
    Q_INVOKABLE void setCardEffect(const QString &id);
    Q_INVOKABLE void setCardSpeed(double speed);
    Q_INVOKABLE void setShowTitle(bool on);
    Q_INVOKABLE void installLocal();
    Q_INVOKABLE void openLocal();
    Q_INVOKABLE void pullNative(const QString &name);
    Q_INVOKABLE void removeNative(const QString &name);
    Q_INVOKABLE void applyTheme(const QString &serverId);
    Q_INVOKABLE void dismissMessages();

signals:
    void changed();
    void busyChanged();
    void messageChanged();
    // After a server was added, so the page can clear its form.
    void serverAdded(const QString &id);

private:
    using Done = std::function<void(int exitCode, const QByteArray &out, const QString &err)>;
    void runCli(const QStringList &args, Done done, const QByteArray &input = {}, int timeoutMs = 60000,
                const QString &busyText = {});
    void inTerminal(const QStringList &args, const QString &title);
    void loadSettings();
    void saveSettings();
    void readShell();
    bool editShell(const std::function<QString(QJsonObject &)> &edit);
    void setError(const QString &message);
    void setNotice(const QString &message);
    void setBusy(const QString &text);

    std::function<QString()> m_pluginDir;
    AgentDock *m_dock;
    QString m_home;
    bool m_runCommands;

    QVariantList m_servers;
    QVariantList m_workspaces;
    QStringList m_workspaceErrors;
    QVariantList m_sessions;
    QVariantMap m_local;
    QJsonObject m_config;
    QVariantMap m_keys;
    QJsonObject m_shell;
    QString m_busy;
    QString m_error;
    QString m_notice;
    QString m_cardEffect = "trace";
    double m_cardSpeed = 1.0;
    bool m_showTitle = true;
    QTimer m_sessionPoll;
};

// A Kasm session's own window (`omacraft kasm-view <spec>`): the session in
// a web view under a slim OmaCraft header with minimise-to-bar, popup/tile,
// fullscreen and end. The spec file, written by `hyprvyzr` with the session's
// link (it carries its token) and any password, is read once and deleted.
class KasmView : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString id READ id CONSTANT)
    Q_PROPERTY(QString title READ title CONSTANT)
    Q_PROPERTY(QString server READ server CONSTANT)
    Q_PROPERTY(QString kind READ kind CONSTANT)
    Q_PROPERTY(QUrl url READ url CONSTANT)
    Q_PROPERTY(bool valid READ valid CONSTANT)
    Q_PROPERTY(QString problem READ problem CONSTANT)

public:
    explicit KasmView(const QString &specPath, QObject *parent = nullptr);

    QString id() const { return m_id; }
    QString title() const { return m_title; }
    QString server() const { return m_server; }
    QString kind() const { return m_kind; }
    QUrl url() const { return m_url; }
    bool valid() const { return m_problem.isEmpty(); }
    QString problem() const { return m_problem; }

    // The web view asks for these.
    Q_INVOKABLE QString authUser() const { return m_user; }
    Q_INVOKABLE QString authPassword() const { return m_password; }
    // Only a native or local session's own certificate (127.0.0.1/localhost,
    // flagged by hyprvyzr) is accepted when it isn't trusted.
    Q_INVOKABLE bool acceptCertificate(const QUrl &url) const;
    // The session's controls, through hyprvyzr: hide, float, tile, end.
    Q_INVOKABLE void act(const QString &action);

    static bool isLoopback(const QUrl &url);

private:
    QString m_id, m_title, m_server, m_kind, m_user, m_password, m_cli, m_problem;
    QUrl m_url;
    bool m_insecureLocal = false;
};
