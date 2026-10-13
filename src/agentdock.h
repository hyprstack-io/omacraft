#pragma once

#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <functional>

// The Agent Dock's settings, dock items and agents. The dock keeps its state
// in ~/.local/state/skll-agentdock/state.json and only reads it when it
// loads, so while the dock runs every change goes through its `set` IPC call;
// otherwise OMAcraft writes the file itself. Agents live in
// ~/.config/omarchy/agentdock.json, which the dock watches.
class AgentDock : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool running READ running NOTIFY changed)
    Q_PROPERTY(QVariantMap settings READ settings NOTIFY changed)
    Q_PROPERTY(QVariantList dock READ dock NOTIFY changed)
    Q_PROPERTY(QVariantList agents READ agents NOTIFY changed)
    Q_PROPERTY(bool customAgents READ customAgents NOTIFY changed)
    Q_PROPERTY(QString monitor READ monitor NOTIFY changed)
    Q_PROPERTY(QStringList monitors READ monitors NOTIFY monitorsChanged)
    Q_PROPERTY(QString pluginDir READ pluginDir NOTIFY changed)
    Q_PROPERTY(QString configPath READ configPath CONSTANT)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    // pluginDir finds the plugin's folder; running says whether the shell
    // has it enabled. Tests pass a temp home and leave running false.
    explicit AgentDock(std::function<QString()> pluginDir, std::function<bool()> running,
                       const QString &home = {}, QObject *parent = nullptr);

    bool available() const { return !pluginDir().isEmpty(); }
    bool running() const { return m_running && m_running(); }
    QVariantMap settings() const;
    QVariantList dock() const;
    QVariantList agents() const;
    bool customAgents() const;
    QString monitor() const { return m_config.value("monitor").toString(); }
    QStringList monitors() const { return m_monitors; }
    QString pluginDir() const { return m_pluginDir ? m_pluginDir() : QString(); }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }

    QString statePath() const { return m_home + "/.local/state/skll-agentdock/state.json"; }
    QString configPath() const { return m_home + "/.config/omarchy/agentdock.json"; }

    // Keys the dock accepts through `set`, so nothing else reaches its state.
    static QStringList settingKeys();
    // The dock's own defaults, for a state file that doesn't exist yet.
    static QJsonObject defaultState();
    static QVariantList defaultAgents();

    Q_INVOKABLE void reload();
    Q_INVOKABLE void set(const QString &key, const QVariant &value);
    Q_INVOKABLE void setAgentShown(const QString &id, bool shown);

    Q_INVOKABLE void moveItem(int from, int to);
    Q_INVOKABLE void removeItem(int index);
    Q_INVOKABLE void addSpacer();
    Q_INVOKABLE void addDivider();
    Q_INVOKABLE void addApp(const QString &desktopId);
    Q_INVOKABLE void addCommand(const QString &name, const QString &glyph, const QString &command);
    // Installed apps whose name or id matches query, for adding to the dock.
    Q_INVOKABLE QVariantList apps(const QString &query) const;

    Q_INVOKABLE void saveAgent(int index, const QVariantMap &agent);
    Q_INVOKABLE void removeAgent(int index);
    Q_INVOKABLE void resetAgents();
    Q_INVOKABLE void setMonitor(const QString &name);
    Q_INVOKABLE void refreshMonitors();

    Q_INVOKABLE void toggleDock();
    Q_INVOKABLE void openDockSettings();
    Q_INVOKABLE void dismissMessages();

signals:
    void changed();
    void monitorsChanged();
    void messageChanged();

private:
    QJsonObject readState() const;
    void writeConfig(const QJsonObject &config);
    void setDock(const QVariantList &items);
    QVariantMap describe(const QVariantMap &item) const;
    QVariantMap desktopEntry(const QString &id) const;
    void setError(const QString &message);
    void watch();

    std::function<QString()> m_pluginDir;
    std::function<bool()> m_running;
    QString m_home;
    QJsonObject m_state;
    QJsonObject m_config;
    QStringList m_monitors;
    QString m_error;
    QString m_notice;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};
