#include "screensaver.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <memory>

#include "omascii.h"
#include "proc.h"

namespace {

const QByteArray hookMarker = "# omacraft-omasavr-hook";

QByteArray readResource(const QString &path) {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}

QString readText(const QString &path) {
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? QString::fromUtf8(file.readAll()) : QString();
}

// What decides what the screensaver plays; the rest of the draft is how the
// page shows it.
const QStringList playedKeys{"art", "design", "mode", "effects", "order", "frameRate", "pause"};

// The ttfx effects, for picking them when omascii (and its groups) is missing.
QVariantList ttfxGroups() {
    return {
        QVariantMap{{"id", "core"}, {"name", "Core"},
                    {"effects", QStringList{"decrypt", "beams", "burn", "slide", "rain", "laseretch", "waves", "middleout",
                                            "vhstape", "sweep", "unstable"}}},
        QVariantMap{{"id", "more"}, {"name", "More ttfx"},
                    {"effects", QStringList{"expand", "pour", "print", "scattered", "slice", "spotlights", "wipe",
                                            "errorcorrect", "randomsequence", "swarm", "fireworks", "blackhole", "rings",
                                            "bubbles", "crumble", "binarypath", "overflow", "spray", "orbittingvolley",
                                            "smoke", "bouncyballs"}}},
        QVariantMap{{"id", "screensaver"}, {"name", "Screensaver"},
                    {"effects", QStringList{"matrix", "synthgrid", "thunderstorm", "colorshift", "highlight"}}},
    };
}

} // namespace

Screensaver::Screensaver(std::function<QString()> omasciiCli, const QString &home, const QString &hookPath,
                         const QString &omarchyPath, QObject *parent)
    : QObject(parent), m_cli(std::move(omasciiCli)), m_home(home.isEmpty() ? QDir::homePath() : home),
      m_hookPath(hookPath),
      m_omarchyPath(!omarchyPath.isEmpty() ? omarchyPath
                    : qEnvironmentVariableIsSet("OMARCHY_PATH") ? qEnvironmentVariable("OMARCHY_PATH")
                                                                 : QString("/usr/share/omarchy")) {
    m_draft = defaultSettings();
    m_renderDebounce.setSingleShot(true);
    m_renderDebounce.setInterval(60);
    connect(&m_renderDebounce, &QTimer::timeout, this, &Screensaver::render);
    m_persistDebounce.setSingleShot(true);
    m_persistDebounce.setInterval(400);
    connect(&m_persistDebounce, &QTimer::timeout, this, &Screensaver::persist);
}

// --- defaults ---

QVariantMap Screensaver::defaultDesign() {
    // Every key omascii renders with, so none comes from its saved boot design.
    return {
        {"text", "omarchy"}, {"font", "ANSI Shadow"}, {"source", "text"},
        {"hlayout", "default"}, {"vlayout", "default"}, {"width", 0}, {"whitespaceBreak", false},
        {"ttfRows", 8}, {"ttfCharset", "quadrant"},
        {"image", ""}, {"imageWidth", 80}, {"charset", "blocks"}, {"chars", ""}, {"imageColors", false},
        {"invert", false}, {"dither", false}, {"threshold", 50}, {"contrast", 1}, {"brightness", 1}, {"normalize", true},
        {"fill", ""}, {"flip", "none"}, {"shadow", "none"}, {"border", "none"}, {"padding", 0},
        // ttfx colours the screensaver, so the art itself stays plain.
        {"color", "foreground"}, {"colorMode", "solid"}, {"color2", "blue"}, {"colorPalette", "sunset"},
        {"gradient", "horizontal"}, {"inkBg", "none"}, {"fontColors", false},
        {"style", "animated"}, {"effects", QStringList{"decrypt"}}, {"maxFrames", 120},
    };
}

QVariantMap Screensaver::defaultSettings() {
    return {
        {"art", "current"},
        {"design", defaultDesign()},
        {"mode", "omarchy"},
        {"effects", QStringList{"matrix-theme", "beams-aurora", "synthgrid-neon", "fireworks-neon", "thunderstorm-violet",
                                "rain-storm", "decrypt-green", "starfield", "plasma"}},
        {"order", "random"},
        {"frameRate", 120},
        {"pause", 0},
    };
}

QVariantMap Screensaver::withDefaults(const QVariantMap &settings) {
    QVariantMap out = defaultSettings();
    for (auto it = settings.begin(); it != settings.end(); ++it)
        if (out.contains(it.key()) && it.key() != "design")
            out.insert(it.key(), it.value());
    QVariantMap design = defaultDesign();
    const QVariantMap saved = settings.value("design").toMap();
    for (auto it = saved.begin(); it != saved.end(); ++it)
        if (design.contains(it.key()))
            design.insert(it.key(), it.value());
    // The plain-art keys stay plain whatever the file says.
    for (const auto &key : {"color", "colorMode", "inkBg", "fontColors"})
        design.insert(key, defaultDesign().value(key));
    out["design"] = design;
    if (!QStringList{"design", "omarchy", "current"}.contains(out.value("art").toString()))
        out["art"] = "current";
    if (!QStringList{"omarchy", "custom"}.contains(out.value("mode").toString()))
        out["mode"] = "omarchy";
    if (!QStringList{"random", "sequence"}.contains(out.value("order").toString()))
        out["order"] = "random";
    out["frameRate"] = std::clamp(out.value("frameRate").toInt(), 15, 240);
    out["pause"] = std::clamp(out.value("pause").toInt(), 0, 60);
    return out;
}

QStringList Screensaver::nativeEffects() {
    return {"ripple", "starfield", "neon", "tetris", "spiral", "crt", "plasma", "tunein", "helix"};
}

QString Screensaver::omasciiLib(const QString &cli) {
    if (cli.isEmpty())
        return {};
    const QString lib = QFileInfo(QFileInfo(QFileInfo(cli).canonicalFilePath()).absolutePath() + "/../lib").canonicalFilePath();
    return QFileInfo(lib + "/build.py").exists() ? lib : QString();
}

QString Screensaver::applyProblem(const QVariantMap &draft) {
    const QVariantMap design = draft.value("design").toMap();
    if (draft.value("art").toString() == "design") {
        if (design.value("source").toString() == "image" && design.value("image").toString().isEmpty())
            return "Choose an image first.";
        if (design.value("source").toString() != "image" && design.value("text").toString().trimmed().isEmpty())
            return "Type some text first.";
    }
    if (draft.value("mode").toString() == "custom" && draft.value("effects").toStringList().isEmpty())
        return "Pick at least one effect, or use Omarchy's own.";
    return {};
}

QByteArray Screensaver::hookScript() { return readResource(":/omasavr-hook.sh"); }

QString Screensaver::toHtml(const QString &text) {
    QString html = text.toHtmlEscaped();
    html.replace(' ', "&nbsp;");
    html.replace('\n', "<br>");
    return html;
}

// --- state ---

bool Screensaver::dirty() const {
    if (m_applied.isEmpty())
        return true;
    for (const auto &key : playedKeys) {
        // The design only matters when it's the art.
        if (key == "design" && m_draft.value("art") != "design")
            continue;
        if (m_draft.value(key) != m_applied.value(key))
            return true;
    }
    return false;
}

bool Screensaver::hasBackup() const { return QFileInfo::exists(backupPath()); }

int Screensaver::artCols() const {
    int cols = 0;
    for (const auto &line : m_art.split('\n'))
        cols = std::max(cols, int(line.size()));
    return cols;
}

int Screensaver::artRows() const { return m_art.isEmpty() ? 0 : m_art.split('\n').size(); }

QString Screensaver::designJson() const {
    return QString::fromUtf8(QJsonDocument(QJsonObject::fromVariantMap(design())).toJson(QJsonDocument::Compact));
}

void Screensaver::loadSettings() {
    const auto file = QJsonDocument::fromJson(readText(settingsPath()).toUtf8()).object();
    m_draft = withDefaults(file.value("draft").toObject().toVariantMap());
    m_applied = file.value("applied").toObject().toVariantMap();
    // The font list opens on the design's own set.
    const QString font = design().value("font").toString();
    m_fontSet = font.startsWith("TDF ") ? "tdf" : font.startsWith("TTF ") ? "ttf" : "figlet";
    emit configChanged();
    emit fontsChanged();
}

void Screensaver::persist() {
    QJsonObject file{{"draft", QJsonObject::fromVariantMap(m_draft)}};
    if (!m_applied.isEmpty())
        file["applied"] = QJsonObject::fromVariantMap(m_applied);
    QString error;
    if (!Proc::writeAtomically(settingsPath(), QJsonDocument(file).toJson(QJsonDocument::Indented), &error))
        setError("Couldn't save Screensaver's settings: " + error);
}

void Screensaver::refresh() {
    emit availableChanged();
    loadSettings();
    refreshSystem();
    m_options = {{"effectGroups", ttfxGroups()}};
    const QString program = m_cli();
    if (program.isEmpty()) {
        // Without omascii: Omarchy's logo or the file as it is, and ttfx's effects.
        m_loaded = true;
        emit statusChanged();
        render();
        return;
    }
    // Read-only: omascii's option lists, nothing of its saved design.
    Proc::run(this, program, {"status", "--json"}, [this](const Proc::Result &result) {
        const auto status = QJsonDocument::fromJson(result.out).object();
        if (result.ok() && !status.isEmpty()) {
            QVariantMap options;
            for (const auto &key : {"layouts", "charsets", "flips", "shadows", "borders", "effectGroups"})
                options.insert(key, status.value(key).toArray().toVariantList());
            if (options.value("effectGroups").toList().isEmpty())
                options["effectGroups"] = ttfxGroups();
            // Without its lib, omascii's own effects can't play in the terminal.
            if (omasciiLib(m_cli()).isEmpty()) {
                QVariantList groups;
                for (const auto &group : options.value("effectGroups").toList())
                    if (group.toMap().value("id") != "omascii")
                        groups << group;
                options["effectGroups"] = groups;
            }
            m_options = options;
        }
        m_loaded = true;
        emit statusChanged();
        render();
        loadFonts();
    });
}

void Screensaver::refreshSystem() {
    // The idle times live in shell.json; the shell follows the file.
    const auto shell = QJsonDocument::fromJson(readText(shellPath()).toUtf8()).object();
    const auto idle = shell.value("idle").toObject();
    m_idleSeconds = idle.value("screensaver").toInt(150);
    m_lockSeconds = idle.value("lock").toInt(300);

    const QByteArray hook = readResource(m_hookPath);
    m_hook = hook.isEmpty() && !QFileInfo::exists(m_hookPath) ? "none"
           : !hook.contains(hookMarker)                          ? "foreign"
           : hook == hookScript()                                ? "ours"
                                                                 : "outdated";
    emit systemChanged();

    Proc::run(this, "omarchy-toggle-enabled", {"screensaver-off"}, [this](const Proc::Result &result) {
        // Exit 0 means the "off" toggle is set; a missing command means on.
        const bool on = result.exitCode != 0;
        if (on != m_enabled) {
            m_enabled = on;
            emit systemChanged();
        }
    });
}

// --- editing ---

void Screensaver::change(const QVariantMap &next) {
    if (next == m_draft)
        return;
    m_undo << m_draft;
    if (m_undo.size() > 200)
        m_undo.removeFirst();
    m_redo.clear();
    m_draft = next;
    emit configChanged();
    m_renderDebounce.start();
    m_persistDebounce.start();
}

void Screensaver::changeDesign(const QString &key, const QVariant &value) {
    QVariantMap next = m_draft;
    QVariantMap design = next.value("design").toMap();
    design.insert(key, value);
    next["design"] = design;
    // Editing the design means using it.
    next["art"] = "design";
    change(next);
}

void Screensaver::setOption(const QString &key, const QVariant &value) {
    if (!defaultDesign().contains(key) || QStringList{"color", "colorMode", "inkBg", "fontColors"}.contains(key))
        return;
    if (key == "image") {
        QVariantMap next = m_draft;
        QVariantMap design = next.value("design").toMap();
        design["image"] = Proc::expandHome(value.toString(), m_home);
        design["source"] = "image";
        next["design"] = design;
        next["art"] = "design";
        change(next);
        return;
    }
    if (key == "font") {
        QVariantMap next = m_draft;
        QVariantMap design = next.value("design").toMap();
        design["font"] = value;
        design["source"] = "text";
        next["design"] = design;
        next["art"] = "design";
        change(next);
        return;
    }
    changeDesign(key, value);
}

void Screensaver::setArtSource(const QString &source) {
    if (!QStringList{"design", "omarchy", "current"}.contains(source))
        return;
    QVariantMap next = m_draft;
    next["art"] = source;
    change(next);
}

void Screensaver::setMode(const QString &mode) {
    if (mode != "omarchy" && mode != "custom")
        return;
    QVariantMap next = m_draft;
    next["mode"] = mode;
    change(next);
}

void Screensaver::toggleEffect(const QString &effect) {
    QStringList list = effects();
    if (list.contains(effect))
        list.removeAll(effect);
    else
        list << effect;
    setEffects(list);
}

void Screensaver::setEffects(const QStringList &list) {
    QVariantMap next = m_draft;
    next["effects"] = list;
    // Picking effects means playing them.
    if (!list.isEmpty())
        next["mode"] = "custom";
    change(next);
}

void Screensaver::setOrder(const QString &order) {
    if (order != "random" && order != "sequence")
        return;
    QVariantMap next = m_draft;
    next["order"] = order;
    change(next);
}

void Screensaver::setFrameRate(int fps) {
    QVariantMap next = m_draft;
    next["frameRate"] = std::clamp(fps, 15, 240);
    change(next);
}

void Screensaver::setPause(int seconds) {
    QVariantMap next = m_draft;
    next["pause"] = std::clamp(seconds, 0, 60);
    change(next);
}

void Screensaver::undo() {
    if (m_undo.isEmpty())
        return;
    m_redo << m_draft;
    m_draft = m_undo.takeLast();
    emit configChanged();
    m_renderDebounce.start();
    m_persistDebounce.start();
}

void Screensaver::redo() {
    if (m_redo.isEmpty())
        return;
    m_undo << m_draft;
    m_draft = m_redo.takeLast();
    emit configChanged();
    m_renderDebounce.start();
    m_persistDebounce.start();
}

// --- the art ---

void Screensaver::render() {
    const QString source = artSource();
    if (source != "design") {
        const QString path = source == "omarchy" ? logoPath() : artPath();
        m_art = readText(path).replace(QChar(0x00a0), ' ');
        while (m_art.endsWith('\n'))
            m_art.chop(1);
        if (m_art.isEmpty())
            setError(source == "omarchy" ? "Omarchy's logo wasn't found at " + path + "."
                                         : "The screensaver text is empty or missing: " + path + ".");
        emit previewChanged();
        return;
    }
    const QString program = m_cli();
    if (program.isEmpty()) {
        setError("Designing art needs omascii. Install the omascii plugin on the Plugin Suite page.");
        return;
    }
    // One render at a time; a change during one renders again after it.
    if (rendering()) {
        m_renderAgain = true;
        return;
    }
    m_render = new QProcess(this);
    QProcess *process = m_render;
    connect(process, &QProcess::finished, this, [this, process](int code) {
        const auto result = QJsonDocument::fromJson(process->readAllStandardOutput()).object();
        const QString err = QString::fromUtf8(process->readAllStandardError()).trimmed();
        process->deleteLater();
        if (code == 0 && !result.isEmpty()) {
            m_art = result.value("text").toString();
            if (m_error.startsWith("Preview: ")) {
                m_error.clear();
                emit messageChanged();
            }
        } else {
            setError("Preview: " + (err.isEmpty() ? "omascii couldn't draw this" : err.section('\n', -1)));
        }
        emit previewChanged();
        if (m_renderAgain) {
            m_renderAgain = false;
            render();
        }
    });
    // render only prints; it saves nothing.
    process->start(program, {"render", "--json", "--config-json", designJson()});
    emit previewChanged();
}

void Screensaver::setFontSet(const QString &set) {
    if (set == m_fontSet)
        return;
    m_fontSet = set;
    m_allFonts.clear();
    emit fontsChanged();
    loadFonts();
}

void Screensaver::setFontFilter(const QString &filter) {
    if (filter == m_fontFilter)
        return;
    m_fontFilter = filter;
    emit fontsChanged();
}

QVariantList Screensaver::fonts() const {
    const QString needle = m_fontFilter.trimmed().toLower();
    if (needle.isEmpty())
        return m_allFonts;
    QVariantList matched;
    for (const auto &font : m_allFonts) {
        const auto map = font.toMap();
        if (map.value("name").toString().toLower().contains(needle) || map.value("detail").toString().toLower().contains(needle))
            matched << font;
    }
    return matched;
}

void Screensaver::loadFonts() {
    const QString program = m_cli();
    if (program.isEmpty())
        return;
    QStringList arguments{"fonts", "--json"};
    if (m_fontSet == "tdf")
        arguments << "--tdf";
    else if (m_fontSet == "ttf")
        arguments << "--ttf";
    m_loadingFonts = true;
    emit fontsChanged();
    const QString set = m_fontSet;
    Proc::run(this, program, arguments, [this, set](const Proc::Result &result) {
        if (set != m_fontSet)
            return;
        m_loadingFonts = false;
        m_allFonts = result.ok() ? Omascii::parseFonts(result.out) : QVariantList();
        emit fontsChanged();
    });
}

void Screensaver::loadImages() {
    const QString program = m_cli();
    if (program.isEmpty())
        return;
    Proc::run(this, program, {"images", "--json"}, [this](const Proc::Result &result) {
        m_images = QJsonDocument::fromJson(result.out).array().toVariantList();
        emit imagesChanged();
    });
}

void Screensaver::loadFrames(const QString &effect) {
    const QString lib = omasciiLib(m_cli());
    m_frames.clear();
    if (lib.isEmpty() || m_art.trimmed().isEmpty() || !m_scratch.isValid()) {
        m_loadingFrames = false;
        emit framesChanged();
        if (lib.isEmpty())
            setError("Previewing effects needs omascii's build.py beside its command.");
        return;
    }
    const QString logo = m_scratch.filePath("art.txt");
    QString error;
    if (!Proc::writeAtomically(logo, m_art.toUtf8() + "\n", &error)) {
        setError("Couldn't prepare the preview: " + error);
        return;
    }
    m_loadingFrames = true;
    emit framesChanged();
    // --preview-json prints one effect's frames and returns before building
    // or installing anything; --out is required but never written.
    const QStringList arguments{lib + "/build.py", "--logo", logo, "--out", m_scratch.filePath("unused"),
                                "--preview-json", effect, "--max-frames", "120", "--color", "foreground"};
    Proc::run(this, "python3", arguments, [this](const Proc::Result &result) {
        m_loadingFrames = false;
        const auto object = QJsonDocument::fromJson(result.out).object();
        if (!result.ok() || object.isEmpty()) {
            setError("Couldn't build the preview: " + result.message());
            emit framesChanged();
            return;
        }
        QStringList frames;
        for (const auto &frame : object.value("frames").toArray())
            frames << frame.toString();
        m_frames = frames;
        m_fps = qMax(1, object.value("fps").toInt(50));
        emit framesChanged();
    }, 180000);
}

// --- applying ---

void Screensaver::writeRunner() {
    QDir().mkpath(runnerDir());
    const QList<QPair<QString, QString>> files{{":/omasavr-screensaver.sh", "omasavr-screensaver"},
                                               {":/omasavr-native.py", "omasavr-native.py"}};
    for (const auto &[resource, name] : files) {
        const QString path = runnerDir() + "/" + name;
        QString error;
        if (!Proc::writeAtomically(path, readResource(resource), &error)) {
            setError("Couldn't write " + path + ": " + error);
            return;
        }
        QFile::setPermissions(path, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner | QFile::ReadGroup
                                        | QFile::ExeGroup | QFile::ReadOther | QFile::ExeOther);
    }
}

void Screensaver::apply() { apply(false); }
void Screensaver::tryIt() { apply(true); }

void Screensaver::apply(bool launchAfter) {
    const QString problem = applyProblem(m_draft);
    if (!problem.isEmpty()) {
        setError(problem);
        return;
    }
    m_persistDebounce.stop();
    if (artSource() != "design") {
        finishApply(artSource() == "omarchy" ? readText(logoPath()) : QString(), launchAfter);
        return;
    }
    // The design as it is now, not a preview still on its way.
    Proc::run(this, m_cli(), {"render", "--json", "--config-json", designJson()},
              [this, launchAfter](const Proc::Result &result) {
        const QString text = QJsonDocument::fromJson(result.out).object().value("text").toString();
        if (!result.ok() || text.trimmed().isEmpty()) {
            setError("omascii couldn't draw the art: " + result.message());
            return;
        }
        finishApply(text, launchAfter);
    });
}

void Screensaver::finishApply(const QString &text, bool launchAfter) {
    // "current" keeps the file as it is; anything else replaces it, after a
    // copy of what was there before Screensaver first changed it.
    if (artSource() != "current") {
        if (text.trimmed().isEmpty()) {
            setError("There's no art to write.");
            return;
        }
        if (!hasBackup() && QFileInfo::exists(artPath())) {
            QDir().mkpath(QFileInfo(backupPath()).absolutePath());
            QFile::copy(artPath(), backupPath());
        }
        QString error;
        QString body = text;
        if (!body.endsWith('\n'))
            body += '\n';
        if (!Proc::writeAtomically(artPath(), body.toUtf8(), &error)) {
            setError("Couldn't write " + artPath() + ": " + error);
            return;
        }
    }

    writeRunner();
    QVariantMap applied;
    for (const auto &key : playedKeys)
        applied.insert(key, m_draft.value(key));
    applied["omasciiLib"] = omasciiLib(m_cli());
    applied["at"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    m_applied = applied;
    persist();
    emit configChanged();
    emit systemChanged();

    const bool needsHook = mode() == "custom" && m_hook != "ours";
    if (needsHook && m_hook == "foreign") {
        setError("Saved, but " + m_hookPath + " is something else's, so the picked effects can't play. "
                 "Screensaver leaves that file alone.");
        return;
    }
    if (needsHook) {
        setNotice("Saved. The picked effects need Screensaver's hook in /usr/local/bin; it asks for your password once.");
        installHook();
        if (launchAfter && m_busy) {
            // Start it once the password prompt is done, if the hook went in.
            auto once = std::make_shared<QMetaObject::Connection>();
            *once = connect(this, &Screensaver::systemChanged, this, [this, once] {
                if (m_busy)
                    return;
                disconnect(*once);
                if (m_hook == "ours")
                    launch();
            });
        }
        return;
    }
    setNotice(mode() == "custom" ? "Saved: the screensaver plays your effects over this art."
                                 : "Saved: the screensaver plays Omarchy's own effects over this art.");
    if (launchAfter)
        launch();
}

void Screensaver::launch() {
    if (!Proc::detach("omarchy-launch-screensaver", {"force"}))
        setError("Couldn't start the screensaver (omarchy-launch-screensaver).");
}

void Screensaver::restoreBackup() {
    if (!hasBackup())
        return;
    QString error;
    if (!Proc::writeAtomically(artPath(), readResource(backupPath()), &error)) {
        setError("Couldn't put the art back: " + error);
        return;
    }
    QVariantMap next = m_draft;
    next["art"] = "current";
    change(next);
    if (m_applied.value("art").toString() != "current") {
        m_applied["art"] = "current";
        persist();
    }
    render();
    setNotice("The screensaver text from before Screensaver is back.");
}

// --- the screensaver itself ---

void Screensaver::setEnabled(bool on) {
    if (on == m_enabled)
        return;
    // Omarchy's own toggle, so its menu and indicator agree.
    Proc::run(this, "omarchy-toggle-screensaver", {}, [this](const Proc::Result &result) {
        if (!result.ok())
            setError("Couldn't switch the screensaver: " + result.message());
        refreshSystem();
    });
}

void Screensaver::setIdleSeconds(int seconds) {
    seconds = std::clamp(seconds, 10, 7200);
    QFile file(shellPath());
    if (!file.open(QIODevice::ReadWrite)) {
        setError("Couldn't open " + shellPath() + ": " + file.errorString());
        return;
    }
    const QByteArray before = file.readAll();
    QJsonParseError parseError;
    QJsonObject shell = QJsonDocument::fromJson(before.trimmed().isEmpty() ? "{}" : before, &parseError).object();
    if (parseError.error != QJsonParseError::NoError) {
        setError("shell.json doesn't read as JSON (" + parseError.errorString() + "), so the time wasn't saved.");
        return;
    }
    QJsonObject idle = shell.value("idle").toObject();
    idle["screensaver"] = seconds;
    shell["idle"] = idle;
    // In place, not through a rename: the shell's file watcher stays on it.
    const QByteArray bytes = QJsonDocument(shell).toJson(QJsonDocument::Indented);
    if (!file.seek(0) || file.write(bytes) != bytes.size() || !file.resize(bytes.size())) {
        setError("Couldn't save " + shellPath() + ": " + file.errorString());
        return;
    }
    m_idleSeconds = seconds;
    emit systemChanged();
}

void Screensaver::privileged(const QString &script, const QStringList &arguments, std::function<void(bool)> done) {
    m_busy = true;
    emit systemChanged();
    Proc::run(this, "pkexec", QStringList{"/bin/sh", "-c", script, "omasavr"} + arguments,
              [this, done](const Proc::Result &result) {
        m_busy = false;
        if (result.exitCode == 126)
            setError("The password prompt was dismissed, so nothing changed.");
        else if (result.exitCode == 127)
            setError("pkexec couldn't get authorization. Omarchy runs a polkit agent at login; is it still running?");
        else if (!result.ok())
            setError(result.message());
        if (done)
            done(result.ok());
        refreshSystem();
    }, 300000);
}

void Screensaver::installHook() {
    if (m_hook == "foreign") {
        setError(m_hookPath + " is something else's, so Screensaver leaves it alone.");
        return;
    }
    const QString source = runnerDir() + "/hook";
    QString error;
    if (!Proc::writeAtomically(source, hookScript(), &error)) {
        setError("Couldn't prepare the hook: " + error);
        return;
    }
    // Only ever this one file, and never over someone else's.
    privileged(R"(if [ -e "$2" ] && ! grep -q 'omacraft-omasavr-hook' "$2"; then echo "$2 isn't Screensaver's" >&2; exit 1; fi
install -Dm755 "$1" "$2")", {source, m_hookPath}, [this](bool ok) {
        if (ok)
            setNotice("Hook installed: the screensaver plays your effects.");
    });
}

void Screensaver::removeHook() {
    if (m_hook != "ours" && m_hook != "outdated")
        return;
    privileged(R"(grep -q 'omacraft-omasavr-hook' "$1" && rm -f "$1")", {m_hookPath}, [this](bool ok) {
        if (ok)
            setNotice("Hook removed: the screensaver is Omarchy's own again.");
    });
}

void Screensaver::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}

void Screensaver::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}

void Screensaver::setNotice(const QString &message) {
    m_notice = message;
    m_error.clear();
    emit messageChanged();
}
