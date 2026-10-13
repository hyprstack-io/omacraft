#pragma once

#include <QByteArray>
#include <QObject>
#include <QString>
#include <QStringList>
#include <functional>

// Small helpers every page shares: running the plugins' command-line tools
// without blocking the window, and saving files the way Omarchy's own tools do.
namespace Proc {

struct Result {
    int exitCode = -1;
    QByteArray out;
    QByteArray err;
    bool ok() const { return exitCode == 0; }
    // The tool's own words when it fails, so the window can show them.
    QString message() const;
};

using Done = std::function<void(const Result &)>;

// Runs program with arguments and calls done on the main thread. The process
// belongs to context, so it stops with it. A program that can't start reports
// exit code -1 and says so in err.
void run(QObject *context, const QString &program, const QStringList &arguments, Done done = {},
         int timeoutMs = 60000);

// Starts program and leaves it running on its own, for terminals and windows.
bool detach(const QString &program, const QStringList &arguments);

// Runs a shell command in Omarchy's floating terminal, for anything that asks
// for a password or takes long enough to watch.
bool inTerminal(const QString &command);

// Quotes one argument for /bin/sh.
QString shellQuote(const QString &value);

// "~/x" to "/home/me/x"; anything else unchanged.
QString expandHome(const QString &path, const QString &home);

// Writes beside the target, then renames over it, so a crash never leaves a
// half-written file. Creates the parent folder.
bool writeAtomically(const QString &path, const QByteArray &bytes, QString *error = nullptr);

// Where a program is on PATH, or empty.
QString which(const QString &program);

} // namespace Proc
