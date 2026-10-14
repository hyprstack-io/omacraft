#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <functional>

// Hyprland animation presets, through the omacraft.animations plugin's own
// omarchy-animations script, so the bar widget and OMAcraft always agree.
class Animations : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(QVariantList presets READ presets NOTIFY changed)
    Q_PROPERTY(QString preset READ preset NOTIFY changed)
    Q_PROPERTY(double speed READ speed NOTIFY changed)
    Q_PROPERTY(QString last READ last NOTIFY changed)
    Q_PROPERTY(QString file READ file NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)
    Q_PROPERTY(QString lua READ lua NOTIFY luaChanged)
    Q_PROPERTY(QString luaPreset READ luaPreset NOTIFY luaChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY changed)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY changed)
    Q_PROPERTY(QString customPath READ customPath CONSTANT)
    // Overrides on top of the preset: window and workspace shapes, and a
    // gradient window border that can spin.
    Q_PROPERTY(QString windowStyle READ windowStyle NOTIFY changed)
    Q_PROPERTY(QString workspaceStyle READ workspaceStyle NOTIFY changed)
    Q_PROPERTY(QString border READ border NOTIFY changed)
    Q_PROPERTY(bool borderLoop READ borderLoop NOTIFY changed)
    Q_PROPERTY(int borderSpeed READ borderSpeed NOTIFY changed)
    Q_PROPERTY(QVariantList borders READ borders NOTIFY changed)
    Q_PROPERTY(QStringList windowStyles READ windowStyles NOTIFY changed)
    Q_PROPERTY(QStringList workspaceStyles READ workspaceStyles NOTIFY changed)

public:
    // pluginDir finds the plugin's folder each time, since it can be
    // installed, removed and moved while OMAcraft runs.
    explicit Animations(std::function<QString()> pluginDir, const QString &home = {}, QObject *parent = nullptr);

    bool available() const { return !script().isEmpty(); }
    QVariantList presets() const { return m_presets; }
    QString preset() const { return m_preset; }
    double speed() const { return m_speed; }
    QString last() const { return m_last; }
    QString file() const { return m_file; }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }
    QString lua() const { return m_lua; }
    QString luaPreset() const { return m_luaPreset; }
    bool canUndo() const { return !m_undo.isEmpty(); }
    bool canRedo() const { return !m_redo.isEmpty(); }
    QString customPath() const { return m_home + "/.config/omarchy/animation-presets.json"; }
    QString windowStyle() const { return m_windowStyle; }
    QString workspaceStyle() const { return m_workspaceStyle; }
    QString border() const { return m_border; }
    bool borderLoop() const { return m_borderLoop; }
    int borderSpeed() const { return m_borderSpeed; }
    QVariantList borders() const { return m_borders; }
    QStringList windowStyles() const { return m_windowStyles; }
    QStringList workspaceStyles() const { return m_workspaceStyles; }

    QString script() const;

    // Reads `omarchy-animations status --json` into the fields above.
    bool readStatus(const QByteArray &json);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void apply(const QString &preset);
    Q_INVOKABLE void setSpeed(double speed);
    Q_INVOKABLE void toggle();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void preview(const QString &preset);
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    Q_INVOKABLE void openCustomPresets();
    Q_INVOKABLE void setWindowStyle(const QString &style);
    Q_INVOKABLE void setWorkspaceStyle(const QString &style);
    Q_INVOKABLE void setBorder(const QString &id);
    Q_INVOKABLE void setBorderLoop(bool on);
    Q_INVOKABLE void setBorderSpeed(int seconds);
    Q_INVOKABLE void dismissMessages();

signals:
    void changed();
    void busyChanged();
    void messageChanged();
    void luaChanged();

private:
    struct Choice {
        QString preset;
        double speed;
    };
    void run(const QStringList &arguments, bool record);
    void setBusy(bool busy);
    void setError(const QString &message);

    std::function<QString()> m_pluginDir;
    QString m_home;
    QVariantList m_presets;
    QString m_preset;
    double m_speed = 1.0;
    QString m_last;
    QString m_file;
    bool m_busy = false;
    QString m_error;
    QString m_notice;
    QString m_lua;
    QString m_luaPreset;
    QString m_windowStyle = "preset";
    QString m_workspaceStyle = "preset";
    QString m_border = "theme";
    bool m_borderLoop = false;
    int m_borderSpeed = 6;
    QVariantList m_borders;
    QStringList m_windowStyles;
    QStringList m_workspaceStyles;
    QList<Choice> m_undo;
    QList<Choice> m_redo;
};
