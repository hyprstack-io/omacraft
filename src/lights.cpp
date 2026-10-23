#include "lights.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>

#include <csignal>

#include "effects.h"
#include "layout.h"

namespace {

QVariantList presetList(const QList<Preset> &presets) {
    QVariantList list;
    for (const auto &p : presets) {
        QStringList colors;
        for (const auto &c : p.colors)
            colors << c.name();
        list << QVariantMap{{"id", p.id}, {"name", p.name}, {"description", p.description}, {"colors", colors}};
    }
    return list;
}

const Preset *currentPreset(const Scene &scene) {
    return scene.mode == "animation" ? Effects::findAnimation(scene.animation) : Effects::findPattern(scene.pattern);
}

// The AlienFX plugin keeps ThemeSync on while this file exists.
QString alienfxThemeSyncFile() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
           + "/omarchy-alienfx-plugin/themesync.enabled";
}

} // namespace

Lights::Lights(const QString &configDirectory, const QString &themeDirectory, const QString &statusPath, QObject *parent)
    : QObject(parent),
      m_store(configDirectory),
      m_palette(themeDirectory),
      m_statusPath(statusPath.isEmpty() ? DriverStatus::defaultPath() : statusPath) {
    m_scene = m_store.scene();

    // The preview runs at 30 frames a second while an animation is shown.
    m_tick.setInterval(33);
    connect(&m_tick, &QTimer::timeout, this, &Lights::render);
    m_clock.start();

    connect(&m_store, &Store::changed, this, [this] {
        // Edited elsewhere (OmaCraft, or the other window): take it as is.
        if (m_store.scene() == m_scene)
            return;
        m_scene = m_store.scene();
        emit changed();
        updateTimer();
        render();
    });
    connect(&m_palette, &PaletteWatcher::changed, this, [this] {
        emit themeChanged();
        if (m_scene.followTheme)
            emit changed();
        render();
    });

    m_driverPoll.setInterval(2000);
    connect(&m_driverPoll, &QTimer::timeout, this, &Lights::refreshDriver);
    m_driverPoll.start();
    refreshDriver();

    updateTimer();
    render();
}

// --- reading ---

QVariantList Lights::keys() const {
    QVariantList list;
    for (const auto &key : Layout::x15().keys())
        list << QVariantMap{{"id", key.id}, {"label", key.label}, {"x", key.x}, {"y", key.y},
                            {"w", key.w}, {"h", key.h}, {"lit", key.lit()}};
    return list;
}

QStringList Lights::colors() const {
    QStringList out;
    for (const auto &c : Effects::slotColors(m_scene, m_palette.palette()))
        out << c.name();
    return out;
}

QStringList Lights::slotNames() const {
    if (m_scene.mode == "paint")
        return {"Colour 1", "Colour 2", "Colour 3", "Unpainted keys"};
    const Preset *preset = currentPreset(m_scene);
    return preset ? preset->slotNames : QStringList{"—", "—", "—", "—"};
}

QVariantList Lights::patterns() const { return presetList(Effects::patterns()); }
QVariantList Lights::animations() const { return presetList(Effects::animations()); }

QStringList Lights::themeColors() const {
    QStringList out;
    for (const auto &c : m_palette.palette().slotColors())
        out << c.name();
    return out;
}

QString Lights::driverError() const {
    if (!m_driver.keyboardError.isEmpty() && !m_driver.chassisError.isEmpty())
        return m_driver.keyboardError + "\n" + m_driver.chassisError;
    return m_driver.keyboardError.isEmpty() ? m_driver.chassisError : m_driver.keyboardError;
}

bool Lights::alienfxThemeSync() const { return QFileInfo::exists(alienfxThemeSyncFile()); }

QStringList Lights::thumbnail(const QString &mode, const QString &id) const {
    Scene still = m_scene;
    still.on = true;
    still.mode = mode;
    still.brightness = 100;
    const Preset *preset = nullptr;
    if (mode == "animation") {
        still.animation = id;
        preset = Effects::findAnimation(id);
    } else {
        still.pattern = id;
        preset = Effects::findPattern(id);
    }
    if (preset && !(still.followTheme))
        still.colors = preset->colors;
    // A moment into the animation, when most of them have something to show.
    const auto colors = Effects::render(Layout::x15(), still, m_palette.palette(), 2.2);
    QStringList out;
    for (const auto &c : colors)
        out << Effects::finish(c, still).name();
    return out;
}

// --- the preview ---

void Lights::setPreviewing(bool on) {
    if (on == m_previewing)
        return;
    m_previewing = on;
    emit previewingChanged();
    updateTimer();
    render();
}

void Lights::updateTimer() {
    if (m_previewing && Effects::animated(m_scene))
        m_tick.start();
    else
        m_tick.stop();
}

void Lights::render() {
    const auto colors = Effects::render(Layout::x15(), m_scene, m_palette.palette(), m_clock.elapsed() / 1000.0);
    QVariantList frame;
    frame.reserve(colors.size());
    for (const auto &c : colors)
        frame << Effects::finish(c, m_scene).name();
    if (frame != m_frame) {
        m_frame = frame;
        emit frameChanged();
    }
}

// --- editing ---

void Lights::apply(const Scene &next, bool coalesce) {
    if (next == m_scene)
        return;
    QString problem;
    if (!m_store.save(next, &problem)) {
        setError(problem);
        return;
    }
    if (!coalesce) {
        m_undo << m_scene;
        if (m_undo.size() > 200)
            m_undo.removeFirst();
    }
    m_redo.clear();
    m_scene = next;
    emit historyChanged();
    emit changed();
    updateTimer();
    render();
}

void Lights::setOn(bool on) {
    Scene next = m_scene;
    next.on = on;
    apply(next);
}

void Lights::setMode(const QString &mode) {
    if (mode != "paint" && mode != "pattern" && mode != "animation")
        return;
    Scene next = m_scene;
    next.mode = mode;
    next.on = true;
    // An empty canvas starts from what was showing, so painting begins
    // from something rather than a dark board.
    if (mode == "paint" && next.paint.isEmpty())
        next.paint = Effects::bake(Layout::x15(), m_scene, m_palette.palette());
    apply(next);
}

void Lights::choosePattern(const QString &id) {
    const Preset *preset = Effects::findPattern(id);
    if (!preset)
        return;
    Scene next = m_scene;
    next.mode = "pattern";
    next.pattern = id;
    next.on = true;
    // Each design comes in its own colours unless the theme is chosen.
    next.colors = preset->colors;
    apply(next);
}

void Lights::chooseAnimation(const QString &id) {
    const Preset *preset = Effects::findAnimation(id);
    if (!preset)
        return;
    Scene next = m_scene;
    next.mode = "animation";
    next.animation = id;
    next.on = true;
    next.colors = preset->colors;
    apply(next);
}

void Lights::step(int delta) {
    const bool animation = m_scene.mode == "animation";
    const auto &list = animation ? Effects::animations() : Effects::patterns();
    const QString current = animation ? m_scene.animation : m_scene.pattern;
    int at = 0;
    for (int i = 0; i < list.size(); ++i)
        if (list[i].id == current)
            at = i;
    const QString id = list[(at + delta + list.size()) % list.size()].id;
    animation ? chooseAnimation(id) : choosePattern(id);
}

void Lights::setFollowTheme(bool on) {
    Scene next = m_scene;
    next.followTheme = on;
    apply(next);
}

void Lights::setSlotColor(int slot, const QString &hex) {
    const QColor color(hex);
    if (slot < 0 || slot > 3 || !color.isValid())
        return;
    Scene next = m_scene;
    // Picking a colour while following the theme starts from the theme's
    // colours, so the other slots don't jump.
    if (next.followTheme)
        next.colors = m_palette.palette().slotColors();
    next.followTheme = false;
    next.colors[slot] = color;
    apply(next);
}

void Lights::resetColors() {
    const Preset *preset = currentPreset(m_scene);
    if (!preset)
        return;
    Scene next = m_scene;
    next.colors = preset->colors;
    next.followTheme = false;
    apply(next);
}

void Lights::setSpeed(double speed) {
    Scene next = m_scene;
    next.speed = std::clamp(speed, 0.25, 3.0);
    apply(next);
}

void Lights::setBrightness(int brightness) {
    Scene next = m_scene;
    next.brightness = std::clamp(brightness, 0, 100);
    apply(next);
}

void Lights::setVivid(int vivid) {
    Scene next = m_scene;
    next.vivid = std::clamp(vivid, 0, 100);
    apply(next);
}

void Lights::setWord(const QString &word) {
    Scene next = m_scene;
    next.word = word.left(32);
    // The ghost typist types the word too; anywhere else it means the word design.
    const bool typist = m_scene.mode == "animation" && m_scene.animation == "typist";
    if (!typist) {
        next.mode = "pattern";
        next.pattern = "word";
    }
    // Typing is one undo step per word, not per letter.
    apply(next, (typist || (m_scene.mode == "pattern" && m_scene.pattern == "word")) && !m_undo.isEmpty());
}

void Lights::setChassis(const QString &chassis) {
    Scene next = m_scene;
    next.chassis = chassis;
    if (Scene::fromJson(next.toJson()).chassis != chassis)
        return;
    apply(next);
}

// --- painting ---

void Lights::setBrush(const QString &brush) {
    static const QRegularExpression valid("^(#[0-9a-fA-F]{6}|@[0-3])$");
    if (!valid.match(brush).hasMatch() || brush == m_brush)
        return;
    m_brush = brush.toLower();
    emit brushChanged();
}

void Lights::paintKey(const QString &id) {
    const int index = Layout::x15().indexOf(id);
    if (index < 0 || !Layout::x15().keys()[index].lit())
        return;
    Scene next = m_scene;
    next.mode = "paint";
    next.on = true;
    if (next.paint.value(id) == m_brush && m_scene.mode == "paint")
        return;
    next.paint.insert(id, m_brush);
    // A drag across keys is one stroke, and one undo step.
    apply(next, m_stroke);
    m_stroke = true;
}

void Lights::eraseKey(const QString &id) {
    if (!m_scene.paint.contains(id))
        return;
    Scene next = m_scene;
    next.paint.remove(id);
    apply(next, m_stroke);
    m_stroke = true;
}

void Lights::fillAll() {
    Scene next = m_scene;
    next.mode = "paint";
    next.on = true;
    for (const auto &key : Layout::x15().keys())
        if (key.lit())
            next.paint.insert(key.id, m_brush);
    apply(next);
}

void Lights::clearPaint() {
    Scene next = m_scene;
    next.paint.clear();
    apply(next);
}

void Lights::bakeToPaint() {
    Scene next = m_scene;
    next.paint = Effects::bake(Layout::x15(), m_scene, m_palette.palette());
    next.mode = "paint";
    next.on = true;
    apply(next);
    m_notice = "Copied onto the canvas. Click keys to change them.";
    emit messageChanged();
}

// --- history ---

void Lights::undo() {
    if (m_undo.isEmpty())
        return;
    const Scene previous = m_undo.takeLast();
    QString problem;
    if (!m_store.save(previous, &problem)) {
        m_undo << previous;
        setError(problem);
        return;
    }
    m_redo << m_scene;
    m_scene = previous;
    m_stroke = false;
    emit historyChanged();
    emit changed();
    updateTimer();
    render();
}

void Lights::redo() {
    if (m_redo.isEmpty())
        return;
    const Scene next = m_redo.takeLast();
    QString problem;
    if (!m_store.save(next, &problem)) {
        m_redo << next;
        setError(problem);
        return;
    }
    m_undo << m_scene;
    m_scene = next;
    m_stroke = false;
    emit historyChanged();
    emit changed();
    updateTimer();
    render();
}

void Lights::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}

void Lights::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}

// --- the lighting service ---

void Lights::refreshDriver() {
    const DriverStatus status = DriverStatus::read(m_statusPath);
    const bool was = m_driver.running();
    if (status.pid != m_driver.pid || status.keyboard != m_driver.keyboard
        || status.keyboardError != m_driver.keyboardError || status.chassisError != m_driver.chassisError
        || status.running() != was) {
        m_driver = status;
        emit driverChanged();
    }
}

void Lights::runService(const QStringList &arguments, bool starting) {
    m_driverBusy = true;
    emit driverChanged();
    auto *process = new QProcess(this);
    connect(process, &QProcess::finished, this, [this, process, starting](int code) {
        process->deleteLater();
        if (starting && code != 0) {
            // No installed unit (a build run from the project): start the
            // service from this binary instead, for this session.
            const QString self = QCoreApplication::applicationFilePath();
            const bool isAlienflare = QFileInfo(self).fileName() == "alienflare";
            const QString program = isAlienflare ? self : QStandardPaths::findExecutable("alienflare");
            if (program.isEmpty() || !QProcess::startDetached(program, {"--daemon"}))
                setError("The lighting service didn't start: install AlienFlare (bin/install) so its "
                         "alienflare.service is there.");
        }
        if (!starting) {
            // A service started by hand isn't systemd's to stop.
            if (m_driver.running())
                ::kill(pid_t(m_driver.pid), SIGTERM);
        }
        QTimer::singleShot(700, this, [this] {
            m_driverBusy = false;
            refreshDriver();
            emit driverChanged();
        });
    });
    connect(process, &QProcess::errorOccurred, this, [process](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            emit process->finished(1, QProcess::CrashExit);
    });
    process->start("systemctl", arguments);
}

void Lights::startDriver() {
    runService({"--user", "enable", "--now", "alienflare.service"}, true);
}

void Lights::stopDriver() {
    runService({"--user", "disable", "--now", "alienflare.service"}, false);
}

void Lights::disableAlienfxThemeSync() {
    auto *process = new QProcess(this);
    connect(process, &QProcess::finished, this, [this, process](int code) {
        process->deleteLater();
        if (code != 0)
            setError("alienfx-ctl couldn't turn ThemeSync off: "
                     + QString::fromUtf8(process->readAllStandardError()).trimmed());
        emit driverChanged();
    });
    connect(process, &QProcess::errorOccurred, this, [this, process](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            process->deleteLater();
            setError("alienfx-ctl isn't on the PATH, so AlienFX's ThemeSync can't be turned off from here.");
        }
    });
    process->start("alienfx-ctl", {"themesync", "off"});
}
