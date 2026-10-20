#include "bootsplash.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>

#include "proc.h"

namespace {

QString stateHome() {
    const QString xdg = qEnvironmentVariable("XDG_STATE_HOME");
    return xdg.isEmpty() ? QDir::homePath() + "/.local/state" : xdg;
}

} // namespace

BootSplash::BootSplash(QObject *parent)
    : BootSplash("/etc/plymouth/plymouthd.conf", "/usr/share/plymouth/themes",
                 stateHome() + "/omascii/previous-theme", parent) {}

BootSplash::BootSplash(const QString &confPath, const QString &themesDir, const QString &previousPath,
                       QObject *parent)
    : QObject(parent), m_confPath(confPath), m_themesDir(themesDir), m_previousPath(previousPath) {
    // plymouth-set-default-theme rewrites the file, which drops a file watch,
    // so watch the folder as well.
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &BootSplash::reload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &BootSplash::reload);
    reload();
}

bool BootSplash::available() const {
    return QFileInfo::exists(m_themesDir + "/" + kTheme + "/" + kTheme + ".plymouth");
}

QString BootSplash::themeIn(const QByteArray &conf) {
    static const QRegularExpression line(R"(^\s*Theme\s*=\s*(\S+))", QRegularExpression::MultilineOption);
    return line.match(QString::fromUtf8(conf)).captured(1);
}

QString BootSplash::switchCommand(const QString &name) {
    return QString("sudo plymouth-set-default-theme %1 && "
                   "if command -v limine-mkinitcpio >/dev/null; then sudo limine-mkinitcpio; else sudo mkinitcpio -P; fi && "
                   "echo && echo %2")
        .arg(Proc::shellQuote(name), Proc::shellQuote(name + " is now the boot screen."));
}

QString BootSplash::previousTheme() const {
    QFile file(m_previousPath);
    QString previous;
    if (file.open(QIODevice::ReadOnly))
        previous = QString::fromUtf8(file.readAll()).trimmed();
    if (!previous.isEmpty() && previous != kTheme && QFileInfo::exists(m_themesDir + "/" + previous))
        return previous;
    return "omarchy";
}

void BootSplash::reload() {
    QFile file(m_confPath);
    const QString theme = file.open(QIODevice::ReadOnly) ? themeIn(file.readAll()) : QString();
    if (theme == m_waitingFor)
        m_waitingFor.clear();
    m_theme = theme;
    watch();
    emit changed();
}

void BootSplash::watch() {
    if (!m_watcher.files().isEmpty())
        m_watcher.removePaths(m_watcher.files());
    if (QFileInfo::exists(m_confPath))
        m_watcher.addPath(m_confPath);
    const QString dir = QFileInfo(m_confPath).absolutePath();
    if (m_watcher.directories().isEmpty() && QFileInfo::exists(dir))
        m_watcher.addPath(dir);
}

void BootSplash::setOn(bool on) {
    m_error.clear();
    if (on == this->on() && m_waitingFor.isEmpty()) {
        emit changed();
        return;
    }
    if (on && !available()) {
        m_error = "The HyprStack boot theme isn't installed. Reinstall the omacraft package to get it.";
        emit changed();
        return;
    }
    QString target = kTheme;
    if (on) {
        if (!m_theme.isEmpty() && m_theme != kTheme)
            Proc::writeAtomically(m_previousPath, (m_theme + "\n").toUtf8());
    } else {
        target = previousTheme();
    }
    if (!Proc::inTerminal(switchCommand(target))) {
        m_error = "Couldn't open a terminal to change the boot screen.";
        emit changed();
        return;
    }
    m_waitingFor = target;
    emit changed();
}
