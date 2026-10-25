#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>

#include "palette.h"
#include "scene.h"
#include "store.h"

// The keyboard lights as the window edits them, exposed to QML as `lights`.
// Every change is saved to the scene file straight away (with undo), and the
// lighting service picks it up from there; this class never writes the
// hardware itself. OmaCraft's Alienflare page uses this same class.
class Lights : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList keys READ keys CONSTANT)
    Q_PROPERTY(QVariantList frame READ frame NOTIFY frameChanged)
    Q_PROPERTY(bool previewing READ previewing WRITE setPreviewing NOTIFY previewingChanged)

    Q_PROPERTY(bool on READ on NOTIFY changed)
    Q_PROPERTY(QString mode READ mode NOTIFY changed)
    Q_PROPERTY(QString pattern READ pattern NOTIFY changed)
    Q_PROPERTY(QString animation READ animation NOTIFY changed)
    Q_PROPERTY(bool followTheme READ followTheme NOTIFY changed)
    // The four slots in use (the theme's when following it), as #rrggbb.
    Q_PROPERTY(QStringList colors READ colors NOTIFY changed)
    // What each slot is for in the current design or animation.
    Q_PROPERTY(QStringList slotNames READ slotNames NOTIFY changed)
    Q_PROPERTY(double speed READ speed NOTIFY changed)
    Q_PROPERTY(int brightness READ brightness NOTIFY changed)
    Q_PROPERTY(int vivid READ vivid NOTIFY changed)
    Q_PROPERTY(QString word READ word NOTIFY changed)
    Q_PROPERTY(QString chassis READ chassis NOTIFY changed)
    Q_PROPERTY(QString brush READ brush NOTIFY brushChanged)
    Q_PROPERTY(int paintedCount READ paintedCount NOTIFY changed)

    Q_PROPERTY(QVariantList patterns READ patterns CONSTANT)
    Q_PROPERTY(QVariantList animations READ animations CONSTANT)
    Q_PROPERTY(QStringList themeColors READ themeColors NOTIFY themeChanged)

    Q_PROPERTY(bool canUndo READ canUndo NOTIFY historyChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY historyChanged)
    Q_PROPERTY(QString error READ error NOTIFY messageChanged)
    Q_PROPERTY(QString notice READ notice NOTIFY messageChanged)

    // The lighting service: whether it runs, what it writes through, and
    // what is wrong with the keyboard or the chassis.
    Q_PROPERTY(bool driverRunning READ driverRunning NOTIFY driverChanged)
    Q_PROPERTY(QString driverKeyboard READ driverKeyboard NOTIFY driverChanged)
    Q_PROPERTY(QString driverError READ driverError NOTIFY driverChanged)
    Q_PROPERTY(bool driverBusy READ driverBusy NOTIFY driverChanged)
    // The AlienFX plugin repaints the keyboard from the theme on its own
    // when its ThemeSync is on, which fights the scene.
    Q_PROPERTY(bool alienfxThemeSync READ alienfxThemeSync NOTIFY driverChanged)

public:
    explicit Lights(const QString &configDirectory = {}, const QString &themeDirectory = {},
                    const QString &statusPath = {}, QObject *parent = nullptr);

    QVariantList keys() const;
    QVariantList frame() const { return m_frame; }
    bool previewing() const { return m_previewing; }
    void setPreviewing(bool on);

    const Scene &scene() const { return m_scene; }
    bool on() const { return m_scene.on; }
    QString mode() const { return m_scene.mode; }
    QString pattern() const { return m_scene.pattern; }
    QString animation() const { return m_scene.animation; }
    bool followTheme() const { return m_scene.followTheme; }
    QStringList colors() const;
    QStringList slotNames() const;
    double speed() const { return m_scene.speed; }
    int brightness() const { return m_scene.brightness; }
    int vivid() const { return m_scene.vivid; }
    QString word() const { return m_scene.word; }
    QString chassis() const { return m_scene.chassis; }
    QString brush() const { return m_brush; }
    int paintedCount() const { return m_scene.paint.size(); }

    QVariantList patterns() const;
    QVariantList animations() const;
    QStringList themeColors() const;

    bool canUndo() const { return !m_undo.isEmpty(); }
    bool canRedo() const { return !m_redo.isEmpty(); }
    QString error() const { return m_error; }
    QString notice() const { return m_notice; }

    bool driverRunning() const { return m_driver.running(); }
    QString driverKeyboard() const { return m_driver.keyboard; }
    QString driverError() const;
    bool driverBusy() const { return m_driverBusy; }
    bool alienfxThemeSync() const;

    // A design or animation as a still, one colour per key, in its own
    // colours or the theme's, for the tiles that pick one.
    Q_INVOKABLE QStringList thumbnail(const QString &mode, const QString &id) const;

    Q_INVOKABLE void setOn(bool on);
    Q_INVOKABLE void toggle() { setOn(!m_scene.on); }
    Q_INVOKABLE void setMode(const QString &mode);
    Q_INVOKABLE void choosePattern(const QString &id);
    Q_INVOKABLE void chooseAnimation(const QString &id);
    // The next (+1) or previous (-1) design or animation, in the current mode.
    Q_INVOKABLE void step(int delta);
    Q_INVOKABLE void setFollowTheme(bool on);
    // Sets one slot, leaving the theme for the scene's own colours.
    Q_INVOKABLE void setSlotColor(int slot, const QString &hex);
    // The current design's or animation's own colours back.
    Q_INVOKABLE void resetColors();
    Q_INVOKABLE void setSpeed(double speed);
    Q_INVOKABLE void setBrightness(int brightness);
    Q_INVOKABLE void setVivid(int vivid);
    Q_INVOKABLE void setWord(const QString &word);
    Q_INVOKABLE void setChassis(const QString &chassis);

    // Painting: the brush is a slot ("@0".."@3") or a #rrggbb.
    Q_INVOKABLE void setBrush(const QString &brush);
    Q_INVOKABLE void paintKey(const QString &id);
    Q_INVOKABLE void eraseKey(const QString &id);
    Q_INVOKABLE void fillAll();
    Q_INVOKABLE void clearPaint();
    // Copies the current design (or animation frame) onto the canvas.
    Q_INVOKABLE void bakeToPaint();
    // Ends a stroke, so the next key painted is a new undo step.
    Q_INVOKABLE void endStroke() { m_stroke = false; }

    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    Q_INVOKABLE void dismissMessages();

    Q_INVOKABLE void startDriver();
    Q_INVOKABLE void stopDriver();
    Q_INVOKABLE void disableAlienfxThemeSync();

signals:
    void changed();
    void frameChanged();
    void previewingChanged();
    void brushChanged();
    void themeChanged();
    void historyChanged();
    void messageChanged();
    void driverChanged();

private:
    // Saves `next` as the scene, with an undo step unless `coalesce`.
    void apply(const Scene &next, bool coalesce = false);
    void render();
    void updateTimer();
    void refreshDriver();
    void runService(const QStringList &arguments, bool starting);
    void setError(const QString &message);

    Store m_store;
    PaletteWatcher m_palette;
    Scene m_scene;
    QList<Scene> m_undo;
    QList<Scene> m_redo;
    bool m_stroke = false;
    QString m_brush = "@0";
    QVariantList m_frame;
    // Off until a view shows it, so OmaCraft renders nothing for an unopened page.
    bool m_previewing = false;
    QTimer m_tick;
    QElapsedTimer m_clock;
    QString m_error;
    QString m_notice;

    QString m_statusPath;
    DriverStatus m_driver;
    bool m_driverBusy = false;
    QTimer m_driverPoll;
};
