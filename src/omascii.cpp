#include "omascii.h"

#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include "proc.h"

Omascii::Omascii(std::function<QString()> pluginDir, QObject *parent)
    : QObject(parent), m_pluginDir(std::move(pluginDir)) {
    m_renderDebounce.setSingleShot(true);
    m_renderDebounce.setInterval(60);
    connect(&m_renderDebounce, &QTimer::timeout, this, &Omascii::render);
    // Saving runs omascii once more, so wait for typing to settle.
    m_persistDebounce.setSingleShot(true);
    m_persistDebounce.setInterval(500);
    connect(&m_persistDebounce, &QTimer::timeout, this, &Omascii::persist);
}

QString Omascii::cli() const {
    const QString dir = m_pluginDir ? m_pluginDir() : QString();
    if (!dir.isEmpty() && QFileInfo(dir + "/bin/omascii").isExecutable())
        return dir + "/bin/omascii";
    return Proc::which("omascii");
}

QString Omascii::configJson() const {
    return QString::fromUtf8(QJsonDocument(QJsonObject::fromVariantMap(m_config)).toJson(QJsonDocument::Compact));
}

QString Omascii::applyProblem(const QVariantMap &config) {
    if (config.value("style").toString() == "animated" && config.value("effects").toList().isEmpty())
        return "Pick at least one intro effect, or switch the boot style to Static.";
    if (config.value("source").toString() == "image" && config.value("image").toString().isEmpty())
        return "Choose an image first.";
    if (config.value("source").toString() != "image" && config.value("text").toString().trimmed().isEmpty())
        return "Type some text first.";
    return {};
}

QVariantList Omascii::parseFonts(const QByteArray &json) {
    QVariantList fonts;
    for (const auto &value : QJsonDocument::fromJson(json).array()) {
        const auto font = value.toObject();
        QString detail;
        if (font.contains("title"))
            detail = font.value("title").toString() + (font.value("type").toString() == "color" ? " · colour" : "");
        else if (font.contains("height"))
            detail = QString("%1 rows%2").arg(font.value("height").toInt()).arg(font.value("extra").toBool() ? " · added" : "");
        else if (font.contains("source"))
            detail = font.value("source").toString();
        fonts << QVariantMap{{"name", font.value("name").toString()}, {"detail", detail}};
    }
    return fonts;
}

void Omascii::refresh() {
    emit availableChanged();
    const QString program = cli();
    if (program.isEmpty())
        return;
    Proc::run(this, program, {"status", "--json"}, [this](const Proc::Result &result) {
        const auto status = QJsonDocument::fromJson(result.out).object();
        if (!result.ok() || status.isEmpty()) {
            setError("omascii couldn't read its settings: " + result.message());
            return;
        }
        m_config = status.value("config").toObject().toVariantMap();
        QVariantMap options;
        for (const auto &key : {"layouts", "styles", "effects", "coreEffects", "charsets", "flips", "shadows", "borders",
                                "colorModes", "gradients", "effectGroups", "palettes"})
            options.insert(key, status.value(key).toArray().toVariantList());
        options["paletteStops"] = status.value("paletteStops").toObject().toVariantMap();
        options["fontCount"] = status.value("fontCount").toInt();
        options["tdf"] = status.value("tdf").toObject().toVariantMap();
        options["ttf"] = status.value("ttf").toObject().toVariantMap();
        m_options = options;
        m_palette = status.value("palette").toObject().toVariantMap();
        m_boot = QVariantMap{{"installed", status.value("installed").toBool()},
                             {"theme", status.value("plymouthTheme").toString()},
                             {"applied", status.value("applied").toObject().toVariantMap()},
                             {"savedCount", status.value("savedCount").toInt()}};
        m_loaded = true;
        emit statusChanged();
        emit configChanged();
        render();
        loadFonts();
        loadSaved();
    });
}

void Omascii::change(const QVariantMap &next) {
    if (next == m_config)
        return;
    m_undo << m_config;
    if (m_undo.size() > 200)
        m_undo.removeFirst();
    m_redo.clear();
    m_config = next;
    emit configChanged();
    m_renderDebounce.start();
    m_persistDebounce.start();
}

void Omascii::setOption(const QString &key, const QVariant &value) {
    QVariantMap next = m_config;
    next.insert(key, key == "image" ? QVariant(Proc::expandHome(value.toString(), QDir::homePath())) : value);
    // Picking a font or an image means using it, as in the overlay.
    if (key == "font")
        next["source"] = "text";
    else if (key == "image")
        next["source"] = "image";
    change(next);
}

void Omascii::toggleEffect(const QString &effect) {
    QStringList effects = m_config.value("effects").toStringList();
    if (effects.contains(effect))
        effects.removeAll(effect);
    else
        effects << effect;
    setOption("effects", effects);
}

void Omascii::setEffects(const QStringList &effects) { setOption("effects", effects); }

void Omascii::undo() {
    if (m_undo.isEmpty())
        return;
    m_redo << m_config;
    m_config = m_undo.takeLast();
    emit configChanged();
    m_renderDebounce.start();
    m_persistDebounce.start();
}

void Omascii::redo() {
    if (m_redo.isEmpty())
        return;
    m_undo << m_config;
    m_config = m_redo.takeLast();
    emit configChanged();
    m_renderDebounce.start();
    m_persistDebounce.start();
}

void Omascii::render() {
    const QString program = cli();
    if (program.isEmpty() || m_config.isEmpty())
        return;
    // One render at a time; a change during one renders again after it, so
    // fast typing never queues up stale pictures.
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
            m_previewHtml = result.value("html").toString();
            m_previewCols = result.value("cols").toInt();
            m_previewRows = result.value("rows").toInt();
            m_previewForeground = result.value("foreground").toString("#ffffff");
            m_previewBackground = result.value("background").toString("#000000");
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
    process->start(program, {"render", "--json", "--config-json", configJson()});
    emit previewChanged();
}

void Omascii::persist() {
    const QString program = cli();
    if (program.isEmpty())
        return;
    Proc::run(this, program, {"set", "--config-json", configJson()}, [this](const Proc::Result &result) {
        if (!result.ok())
            setError("Couldn't save the settings: " + result.message());
    });
}

void Omascii::setFontSet(const QString &set) {
    if (set == m_fontSet)
        return;
    m_fontSet = set;
    m_allFonts.clear();
    emit fontsChanged();
    loadFonts();
}

void Omascii::setFontFilter(const QString &filter) {
    if (filter == m_fontFilter)
        return;
    m_fontFilter = filter;
    emit fontsChanged();
}

QVariantList Omascii::fonts() const {
    const QString needle = m_fontFilter.trimmed().toLower();
    if (needle.isEmpty())
        return m_allFonts;
    QVariantList matched;
    for (const auto &font : m_allFonts) {
        const auto map = font.toMap();
        if (map.value("name").toString().toLower().contains(needle)
            || map.value("detail").toString().toLower().contains(needle))
            matched << font;
    }
    return matched;
}

void Omascii::loadFonts() {
    const QString program = cli();
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
        m_allFonts = result.ok() ? parseFonts(result.out) : QVariantList();
        if (!result.ok())
            setError("Couldn't list the fonts: " + result.message());
        emit fontsChanged();
    });
}

void Omascii::loadSaved() {
    const QString program = cli();
    if (program.isEmpty())
        return;
    Proc::run(this, program, {"saved", "--json"}, [this](const Proc::Result &result) {
        m_saved = QJsonDocument::fromJson(result.out).array().toVariantList();
        emit savedChanged();
    });
}

void Omascii::loadImages() {
    const QString program = cli();
    if (program.isEmpty())
        return;
    Proc::run(this, program, {"images", "--json"}, [this](const Proc::Result &result) {
        m_images = QJsonDocument::fromJson(result.out).array().toVariantList();
        emit imagesChanged();
    });
}

void Omascii::saveToLibrary(const QString &name) {
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        setError("Give the design a name to save it.");
        return;
    }
    Proc::run(this, cli(), {"saved", "add", "--name", trimmed, "--config-json", configJson()},
              [this, trimmed](const Proc::Result &result) {
        if (result.ok())
            setNotice(QString("Saved “%1” to My boot screens.").arg(trimmed));
        else
            setError(result.message());
        loadSaved();
    });
}

void Omascii::useSaved(const QString &id) {
    Proc::run(this, cli(), {"saved", "use", id}, [this](const Proc::Result &result) {
        if (!result.ok()) {
            setError(result.message());
            return;
        }
        // Loading one is a change like any other, so it can be undone.
        m_undo << m_config;
        m_redo.clear();
        refresh();
        setNotice("Loaded into the designer.");
    });
}

void Omascii::renameSaved(const QString &id, const QString &name) {
    Proc::run(this, cli(), {"saved", "rename", id, name.trimmed()}, [this](const Proc::Result &result) {
        if (!result.ok())
            setError(result.message());
        loadSaved();
    });
}

void Omascii::removeSaved(const QString &id) {
    Proc::run(this, cli(), {"saved", "rm", id}, [this](const Proc::Result &result) {
        if (!result.ok())
            setError(result.message());
        loadSaved();
    });
}

void Omascii::inTerminal(const QStringList &arguments, const QString &after) {
    QStringList quoted{Proc::shellQuote(cli())};
    for (const auto &argument : arguments)
        quoted << Proc::shellQuote(argument);
    const QString command = quoted.join(' ') + after;
    if (!Proc::inTerminal(command))
        setError("Couldn't open a terminal to run omascii.");
}

void Omascii::applyToBoot() {
    const QString problem = applyProblem(m_config);
    if (!problem.isEmpty()) {
        setError(problem);
        return;
    }
    m_persistDebounce.stop();
    // Installing needs sudo and rebuilds the initramfs, so it runs where the
    // password prompt and progress can be seen.
    inTerminal({"apply", "--config-json", configJson()});
    setNotice("Applying in a terminal. It asks for your password, then rebuilds the initramfs.");
}

void Omascii::restoreBoot() {
    inTerminal({"restore"});
    setNotice("Restoring the previous boot screen in a terminal.");
}

void Omascii::exportGif() {
    const QString problem = applyProblem(m_config);
    if (!problem.isEmpty()) {
        setError(problem);
        return;
    }
    m_persistDebounce.stop();
    const QStringList effects = m_config.value("effects").toStringList();
    const QString first = m_config.value("style").toString() == "animated" && !effects.isEmpty() ? effects.first() : "";
    QStringList set{Proc::shellQuote(cli()), "set", "--config-json", Proc::shellQuote(configJson())};
    QStringList preview{Proc::shellQuote(cli()), "preview"};
    if (!first.isEmpty())
        preview << Proc::shellQuote(first);
    const QString command = set.join(' ') + " >/dev/null && " + preview.join(' ')
                          + " | tail -n 1 | xargs -r -d '\\n' xdg-open";
    if (!Proc::inTerminal(command))
        setError("Couldn't open a terminal to build the GIF.");
}

void Omascii::fetchTheDraw() { inTerminal({"tdf", "fetch"}); }
void Omascii::fetchMoreFonts() { inTerminal({"fonts", "fetch"}); }

void Omascii::loadFrames(const QString &effect) {
    const QString program = cli();
    if (program.isEmpty())
        return;
    m_loadingFrames = true;
    m_frames.clear();
    emit framesChanged();
    Proc::run(this, program, {"frames", effect, "--json", "--config-json", configJson()},
              [this](const Proc::Result &result) {
        m_loadingFrames = false;
        const auto object = QJsonDocument::fromJson(result.out).object();
        if (!result.ok() || object.isEmpty()) {
            setError("Couldn't build the intro: " + result.message());
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

void Omascii::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}

void Omascii::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}

void Omascii::setNotice(const QString &message) {
    m_notice = message;
    m_error.clear();
    emit messageChanged();
}
