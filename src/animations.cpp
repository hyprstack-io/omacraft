#include "animations.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include "proc.h"

Animations::Animations(std::function<QString()> pluginDir, const QString &home, QObject *parent)
    : QObject(parent), m_pluginDir(std::move(pluginDir)), m_home(home.isEmpty() ? QDir::homePath() : home) {}

QString Animations::script() const {
    const QString dir = m_pluginDir ? m_pluginDir() : QString();
    const QString path = dir + "/bin/omarchy-animations";
    return !dir.isEmpty() && QFileInfo::exists(path) ? path : QString();
}

bool Animations::readStatus(const QByteArray &json) {
    const auto object = QJsonDocument::fromJson(json).object();
    if (object.isEmpty())
        return false;
    m_preset = object.value("preset").toString();
    m_speed = object.value("speed").toDouble(1.0);
    m_last = object.value("last").toString();
    m_file = object.value("file").toString();
    m_presets = object.value("presets").toArray().toVariantList();
    emit changed();
    return true;
}

void Animations::refresh() {
    const QString path = script();
    if (path.isEmpty()) {
        m_presets.clear();
        emit changed();
        return;
    }
    Proc::run(this, "python3", {path, "status", "--json"}, [this](const Proc::Result &result) {
        if (!result.ok() || !readStatus(result.out))
            setError("Couldn't read the animation presets: " + result.message());
    });
}

void Animations::run(const QStringList &arguments, bool record) {
    const QString path = script();
    if (path.isEmpty()) {
        setError("The Animations plugin isn't installed. Install it on the Plugins page.");
        return;
    }
    if (record) {
        m_undo << Choice{m_preset, m_speed};
        m_redo.clear();
    }
    dismissMessages();
    setBusy(true);
    Proc::run(this, "python3", QStringList{path} + arguments, [this](const Proc::Result &result) {
        setBusy(false);
        if (result.ok()) {
            m_notice = QString::fromUtf8(result.out).trimmed();
            emit messageChanged();
        } else {
            setError(result.message());
        }
        refresh();
    });
}

void Animations::apply(const QString &preset) {
    if (preset == m_preset)
        return;
    run({"apply", preset, "--speed", QString::number(m_speed)}, true);
}

void Animations::setSpeed(double speed) {
    const double rounded = qRound(qBound(0.25, speed, 3.0) * 100) / 100.0;
    if (qFuzzyCompare(rounded, m_speed))
        return;
    run({"speed", QString::number(rounded)}, true);
}

void Animations::toggle() { run({"toggle"}, true); }
void Animations::next() { run({"next"}, true); }
void Animations::previous() { run({"prev"}, true); }

void Animations::undo() {
    if (m_undo.isEmpty())
        return;
    const Choice choice = m_undo.takeLast();
    m_redo << Choice{m_preset, m_speed};
    run({"apply", choice.preset, "--speed", QString::number(choice.speed)}, false);
}

void Animations::redo() {
    if (m_redo.isEmpty())
        return;
    const Choice choice = m_redo.takeLast();
    m_undo << Choice{m_preset, m_speed};
    run({"apply", choice.preset, "--speed", QString::number(choice.speed)}, false);
}

void Animations::preview(const QString &preset) {
    const QString path = script();
    if (path.isEmpty())
        return;
    Proc::run(this, "python3", {path, "preview", preset, "--speed", QString::number(m_speed)},
              [this, preset](const Proc::Result &result) {
        m_lua = result.ok() ? QString::fromUtf8(result.out) : result.message();
        m_luaPreset = preset;
        emit luaChanged();
    });
}

void Animations::openCustomPresets() {
    // Starts the file with the plugin's documented shape, so there's
    // something to copy from.
    const QString path = customPath();
    if (!QFileInfo::exists(path)) {
        const QByteArray example = R"({
  "curves": {
    "mySpring": { "type": "spring", "mass": 1, "stiffness": 220, "dampening": 18 }
  },
  "presets": [
    {
      "id": "mine",
      "name": "Mine",
      "description": "My own take",
      "animations": {
        "windowsIn": [4, "mySpring", "popin 75%"],
        "windowsOut": [2, "linear", "popin 75%"],
        "workspaces": [5, "mySpring", "slidefade 20%"]
      }
    }
  ]
}
)";
        QString problem;
        if (!Proc::writeAtomically(path, example, &problem)) {
            setError(problem);
            return;
        }
    }
    if (!Proc::detach("omarchy-launch-editor", {path}) && !Proc::detach("xdg-open", {path}))
        setError("Couldn't open an editor for " + path);
}

void Animations::dismissMessages() {
    m_error.clear();
    m_notice.clear();
    emit messageChanged();
}

void Animations::setBusy(bool busy) {
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void Animations::setError(const QString &message) {
    m_error = message;
    m_notice.clear();
    emit messageChanged();
}
