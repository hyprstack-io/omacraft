#pragma once

#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <functional>

// omabar16, the bar. Its themes and layouts come from the plugin's own
// data/Presets.js, so OMAcraft lists exactly what the customizer does. The
// bar's live state is shell.json's "bar" section; every change goes through
// the plugin's IPC, which applies it to the running bar and saves it, with
// its own undo history.
class Bar : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY presetsChanged)
    Q_PROPERTY(bool inUse READ inUse NOTIFY changed)
    Q_PROPERTY(QString barId READ barId NOTIFY changed)
    Q_PROPERTY(QString position READ position NOTIFY changed)
    Q_PROPERTY(bool transparent READ transparent NOTIFY changed)
    Q_PROPERTY(QVariantMap style READ style NOTIFY changed)
    Q_PROPERTY(QVariantMap layout READ layout NOTIFY changed)
    Q_PROPERTY(QString currentTheme READ currentTheme NOTIFY changed)
    Q_PROPERTY(QVariantList themes READ themes NOTIFY presetsChanged)
    Q_PROPERTY(QVariantList layouts READ layouts NOTIFY presetsChanged)
    Q_PROPERTY(QVariantList widgets READ widgets NOTIFY widgetsChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

public:
    explicit Bar(std::function<QString()> pluginDir, const QString &home = {}, bool runCommands = true,
                 QObject *parent = nullptr);

    bool available() const { return !m_themes.isEmpty(); }
    bool inUse() const { return barId() == "omabar16"; }
    QString barId() const;
    QString position() const;
    bool transparent() const;
    QVariantMap style() const;
    QVariantMap layout() const;
    QString currentTheme() const;
    QVariantList themes() const { return m_themes; }
    QVariantList layouts() const { return m_layouts; }
    QVariantList widgets() const { return m_widgets; }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }

    // Reads themes and layouts from a Presets.js file; false if it won't run.
    bool loadPresets(const QString &path, QString *problem = nullptr);
    void setShellConfig(const QJsonObject &shell);

    Q_INVOKABLE void reload();
    Q_INVOKABLE void useAsBar();
    Q_INVOKABLE void applyTheme(const QString &id);
    Q_INVOKABLE void applyLayout(const QString &id);
    Q_INVOKABLE void setPosition(const QString &position);
    Q_INVOKABLE void setTransparent(bool on);
    // value "" removes the key, so the bar falls back to its default.
    Q_INVOKABLE void setStyle(const QString &key, const QVariant &value);
    Q_INVOKABLE void setColor(const QString &part, const QString &hex);
    Q_INVOKABLE void addWidget(const QString &id, const QString &lane);
    Q_INVOKABLE void removeWidget(const QString &lane, int index);
    Q_INVOKABLE void moveWidget(const QString &fromLane, int fromIndex, const QString &toLane, int toIndex);
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    Q_INVOKABLE void revert();
    Q_INVOKABLE void exportTheme(const QString &id);
    Q_INVOKABLE void openCustomizer(const QString &tab);
    Q_INVOKABLE void refreshWidgets();
    Q_INVOKABLE QString glyphFor(const QString &id) const;
    Q_INVOKABLE void dismissMessages();

signals:
    void changed();
    void presetsChanged();
    void widgetsChanged();
    void messageChanged();

private:
    void ipc(const QStringList &arguments, const QString &doneNotice = {});
    void setError(const QString &message);
    void watch();

    std::function<QString()> m_pluginDir;
    QString m_home;
    bool m_runCommands;
    QString m_presetsPath;
    QJsonObject m_shell;
    QVariantList m_themes;
    QVariantList m_layouts;
    QVariantMap m_glyphs;
    QVariantList m_widgets;
    QString m_error;
    QString m_notice;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
};
