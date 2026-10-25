#include "introreel.h"

#include <QFileInfo>

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRandomGenerator>
#include <QStandardPaths>

#include "omascii.h"
#include "proc.h"

IntroReel::IntroReel(Omascii *omascii, const QString &cacheDir, QObject *parent)
    : QObject(parent), m_omascii(omascii),
      m_cacheDir(cacheDir.isEmpty()
                     ? QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + "/omacraft/intro"
                     : cacheDir) {
    // The effects and colours arrive with omascii's status, and change with it.
    connect(m_omascii, &Omascii::statusChanged, this, &IntroReel::sync);
    connect(m_omascii, &Omascii::configChanged, this, &IntroReel::sync);
    sync();
}

IntroReel::~IntroReel() {
    // A render still running when OmaCraft quits would report back to a reel
    // that's half gone: cut it loose and stop it first.
    for (QProcess *process : findChildren<QProcess *>()) {
        process->disconnect();
        process->kill();
        process->waitForFinished(1000);
    }
}

QString IntroReel::titleFont() {
    // TheDraw fonts are fetched on request (omascii tdf fetch); until
    // balistcx is there, the title is drawn in a FIGlet font omascii carries.
    const QString data = qEnvironmentVariable("XDG_DATA_HOME", QDir::homePath() + "/.local/share");
    const QString dir = qEnvironmentVariable("OMASCII_TDF_DIR", data + "/omascii/tdf");
    return QFileInfo::exists(dir + "/balistcx.tdf") ? QString("TDF balistcx") : QString("ANSI Shadow");
}

QVariantMap IntroReel::titleConfig(const QVariantMap &boot) {
    QVariantMap config = boot;
    config.insert("source", "text");
    config.insert("text", "OMACRAFT");
    config.insert("font", titleFont());
    config.insert("hlayout", "default");
    config.insert("vlayout", "default");
    config.insert("width", 120);
    config.insert("whitespaceBreak", false);
    config.insert("style", "animated");
    config.insert("border", "none");
    config.insert("padding", 0);
    config.insert("shadow", "none");
    config.insert("flip", "none");
    config.insert("fill", "");
    config.insert("maxFrames", 150);
    // Clean letters in the theme's colours: the design's ink backgrounds and
    // split colours turn this font's box lines into solid blocks.
    config.insert("inkBg", "none");
    config.insert("colorMode", "gradient");
    config.insert("gradient", "horizontal");
    config.insert("color", "accent");
    config.insert("color2", "foreground");
    config.insert("fontColors", false);
    return config;
}

QString IntroReel::configJson() const {
    return QString::fromUtf8(QJsonDocument(QJsonObject::fromVariantMap(titleConfig(m_omascii->config())))
                                 .toJson(QJsonDocument::Compact));
}

QString IntroReel::cachePath(const QString &effect) const {
    QCryptographicHash hash(QCryptographicHash::Sha1);
    hash.addData(effect.toUtf8());
    hash.addData(configJson().toUtf8());
    hash.addData(QJsonDocument(QJsonObject::fromVariantMap(m_omascii->palette())).toJson(QJsonDocument::Compact));
    return m_cacheDir + "/" + effect + "-" + QString::fromLatin1(hash.result().toHex().left(12)) + ".json";
}

void IntroReel::sync() {
    if (!m_omascii->loaded() || !m_omascii->available())
        return;
    const QStringList effects = m_omascii->options().value("effects").toStringList();
    // Only what the title is drawn from: the design's text or picture don't matter.
    const QString drawnFrom = configJson()
        + QJsonDocument(QJsonObject::fromVariantMap(m_omascii->palette())).toJson(QJsonDocument::Compact);
    if (effects == m_effects && drawnFrom == m_drawnFrom)
        return;
    m_drawnFrom = drawnFrom;
    const QString was = effect();
    if (effects != m_effects) {
        m_effects = effects;
        emit effectsChanged();
    }
    if (m_effects.isEmpty())
        return;
    // A different one each launch; after that, stay on the one showing.
    const int keep = m_effects.indexOf(was);
    m_index = keep >= 0 ? keep : int(QRandomGenerator::global()->bounded(m_effects.size()));
    emit effectChanged();
    Proc::run(this, m_omascii->cli(), {"render", "--json", "--config-json", configJson()},
              [this](const Proc::Result &result) {
        const QString html = QJsonDocument::fromJson(result.out).object().value("html").toString();
        if (result.ok() && !html.isEmpty()) {
            m_still = html;
            emit stillChanged();
        }
    });
    // The intro showing keeps playing until it's ready in the new colours.
    load();
}

void IntroReel::next() { show((m_index + 1) % qMax(1, int(m_effects.size()))); }

void IntroReel::previous() { show((m_index - 1 + m_effects.size()) % qMax(1, int(m_effects.size()))); }

void IntroReel::show(int index) {
    if (m_effects.isEmpty() || index < 0 || index >= m_effects.size())
        return;
    m_index = index;
    emit effectChanged();
    load();
}

void IntroReel::load() {
    const QString wanted = effect();
    if (wanted.isEmpty())
        return;
    if (readCached(wanted)) {
        setLoading(false);
        prefetch();
        return;
    }
    // The old intro keeps playing until this one is ready.
    setLoading(true);
    render(wanted);
}

bool IntroReel::readCached(const QString &effect) {
    QFile file(cachePath(effect));
    if (!file.open(QIODevice::ReadOnly))
        return false;
    const QJsonObject object = QJsonDocument::fromJson(file.readAll()).object();
    QStringList frames;
    for (const auto &frame : object.value("frames").toArray())
        frames << frame.toString();
    if (frames.isEmpty())
        return false;
    m_frames = frames;
    m_fps = qMax(1, object.value("fps").toInt(50));
    m_hold = qMax(0, object.value("hold").toInt(60));
    emit framesChanged();
    return true;
}

void IntroReel::render(const QString &effect) {
    const QString program = m_omascii->cli();
    if (program.isEmpty() || m_rendering.contains(effect))
        return;
    m_rendering.insert(effect);
    const QString path = cachePath(effect);
    Proc::run(this, program, {"frames", effect, "--json", "--config-json", configJson()},
              [this, effect, path](const Proc::Result &result) {
        m_rendering.remove(effect);
        if (result.ok() && !QJsonDocument::fromJson(result.out).object().value("frames").toArray().isEmpty()) {
            QDir().mkpath(m_cacheDir);
            Proc::writeAtomically(path, result.out);
        }
        if (effect == this->effect()) {
            // Nothing to show for it: move on rather than sit on a broken one.
            if (!readCached(effect)) {
                setLoading(false);
                return;
            }
            setLoading(false);
        }
        prefetch();
    }, 120000);
}

void IntroReel::prefetch() {
    // One render at a time, for the effect after this one.
    if (!m_rendering.isEmpty() || m_effects.size() < 2)
        return;
    const QString upcoming = m_effects.value((m_index + 1) % m_effects.size());
    if (!QFile::exists(cachePath(upcoming)))
        render(upcoming);
}

void IntroReel::setLoading(bool loading) {
    if (m_loading == loading)
        return;
    m_loading = loading;
    emit loadingChanged();
}
