#pragma once

#include <QObject>
#include <QVariantList>
#include <functional>

// Hyprland animation presets, through the skll.animations plugin's own
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
    QList<Choice> m_undo;
    QList<Choice> m_redo;
};
