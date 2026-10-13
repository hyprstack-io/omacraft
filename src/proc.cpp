#include "proc.h"

#include <QDir>
#include <QFileInfo>
#include <QPointer>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>

namespace Proc {

QString Result::message() const {
    QString text = QString::fromUtf8(err).trimmed();
    if (text.isEmpty())
        text = QString::fromUtf8(out).trimmed();
    // Long tracebacks bury the point; the last lines carry it.
    QStringList lines = text.split('\n');
    if (lines.size() > 6)
        lines = lines.mid(lines.size() - 6);
    return lines.join('\n');
}

void run(QObject *context, const QString &program, const QStringList &arguments, Done done, int timeoutMs) {
    auto *process = new QProcess(context);
    auto finished = std::make_shared<bool>(false);

    auto finish = [process, done, finished](int exitCode, const QByteArray &extraErr) {
        if (*finished)
            return;
        *finished = true;
        Result result;
        result.exitCode = exitCode;
        result.out = process->readAllStandardOutput();
        result.err = process->readAllStandardError() + extraErr;
        process->deleteLater();
        if (done)
            done(result);
    };

    QObject::connect(process, &QProcess::finished, process, [process, finish](int code, QProcess::ExitStatus status) {
        finish(status == QProcess::NormalExit ? code : -1, {});
    });
    QObject::connect(process, &QProcess::errorOccurred, process, [process, program, finish](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart)
            finish(-1, QString("%1 couldn't start: %2").arg(program, process->errorString()).toUtf8());
    });

    if (timeoutMs > 0) {
        QPointer<QProcess> guard(process);
        QTimer::singleShot(timeoutMs, process, [guard, program, finish] {
            if (guard && guard->state() != QProcess::NotRunning) {
                guard->kill();
                finish(-1, QString("%1 took too long and was stopped").arg(program).toUtf8());
            }
        });
    }

    process->start(program, arguments);
}

bool detach(const QString &program, const QStringList &arguments) {
    return QProcess::startDetached(program, arguments);
}

bool inTerminal(const QString &command) {
    return detach("omarchy-launch-floating-terminal-with-presentation", {command});
}

QString shellQuote(const QString &value) {
    QString quoted = value;
    quoted.replace("'", "'\\''");
    return "'" + quoted + "'";
}

QString expandHome(const QString &path, const QString &home) {
    if (path == "~")
        return home;
    if (path.startsWith("~/"))
        return home + path.mid(1);
    return path;
}

bool writeAtomically(const QString &path, const QByteArray &bytes, QString *error) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly) || file.write(bytes) != bytes.size() || !file.commit()) {
        if (error)
            *error = QString("Couldn't save %1: %2").arg(path, file.errorString());
        return false;
    }
    return true;
}

QString which(const QString &program) {
    return QStandardPaths::findExecutable(program);
}

} // namespace Proc
