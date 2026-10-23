#include "edgetab.h"

#include <algorithm>

#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocalSocket>
#include <QScreen>
#include <QStandardPaths>
#include <QWindow>
#include <LayerShellQt/window.h>

#include "proc.h"

namespace {

const QStringList kEdges{"top", "bottom", "left", "right"};

// In the user's runtime directory, so another user's OmaCraft is never "the
// one running".
QString socketPath() {
    const QString runtime = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    return (runtime.isEmpty() ? QDir::tempPath() : runtime) + "/omacraft.sock";
}

}

EdgeTab::EdgeTab(const QString &home, QObject *parent)
    : QObject(parent), m_path(home + "/.config/omacraft/edge-tab.json") {
    QFile file(m_path);
    if (file.open(QIODevice::ReadOnly)) {
        const QJsonObject saved = QJsonDocument::fromJson(file.readAll()).object();
        if (kEdges.contains(saved.value("edge").toString()))
            m_edge = saved.value("edge").toString();
        m_offset = std::clamp(saved.value("offset").toDouble(0.5), 0.0, 1.0);
    }
}

bool EdgeTab::supported() const {
    return QGuiApplication::platformName().startsWith("wayland");
}

QRectF EdgeTab::placement(const QString &edge, qreal offset, const QSizeF &screen, const QSizeF &tab) {
    const qreal t = std::clamp(offset, 0.0, 1.0);
    if (edge == "left" || edge == "right") {
        const qreal y = t * std::max(0.0, screen.height() - tab.height());
        return QRectF(edge == "left" ? 0 : screen.width() - tab.width(), y, tab.width(), tab.height());
    }
    const qreal x = t * std::max(0.0, screen.width() - tab.width());
    return QRectF(x, edge == "top" ? 0 : screen.height() - tab.height(), tab.width(), tab.height());
}

QPair<QString, qreal> EdgeTab::nearest(const QPointF &point, const QPointF &grab, const QSizeF &screen, const QSizeF &tab) {
    const qreal toLeft = point.x(), toRight = screen.width() - point.x();
    const qreal toTop = point.y(), toBottom = screen.height() - point.y();
    const qreal least = std::min({toLeft, toRight, toTop, toBottom});
    const QString edge = least == toLeft ? "left" : least == toRight ? "right" : least == toTop ? "top" : "bottom";
    // The tab turns on the side edges; the grab point keeps its place along it.
    const bool side = edge == "left" || edge == "right";
    const QSizeF size = side ? QSizeF(std::min(tab.width(), tab.height()), std::max(tab.width(), tab.height()))
                             : QSizeF(std::max(tab.width(), tab.height()), std::min(tab.width(), tab.height()));
    const qreal along = side ? point.y() - std::min(grab.y(), size.height())
                             : point.x() - std::min(grab.x(), size.width());
    const qreal room = side ? screen.height() - size.height() : screen.width() - size.width();
    return {edge, room > 0 ? std::clamp(along / room, 0.0, 1.0) : 0.5};
}

bool EdgeTab::passToRunning(const QStringList &arguments) {
    QLocalSocket socket;
    socket.connectToServer(socketPath());
    if (!socket.waitForConnected(300))
        return false;
    socket.write(arguments.join('\n').toUtf8() + '\n');
    socket.waitForBytesWritten(300);
    socket.disconnectFromServer();
    return true;
}

void EdgeTab::listen() {
    // A socket left by one that crashed would keep this one from listening.
    QLocalServer::removeServer(socketPath());
    m_server.listen(socketPath());
    connect(&m_server, &QLocalServer::newConnection, this, [this] {
        while (QLocalSocket *socket = m_server.nextPendingConnection()) {
            connect(socket, &QLocalSocket::disconnected, socket, &QObject::deleteLater);
            connect(socket, &QLocalSocket::readyRead, socket, [this, socket] {
                const QStringList args = QString::fromUtf8(socket->readAll()).split('\n');
                emit restoreRequested(args.value(0), args.value(1));
            });
        }
    });
}

QSizeF EdgeTab::tabSize() const {
    if (!m_window)
        return {};
    return QSizeF(m_window->width(), m_window->height());
}

void EdgeTab::attach(QWindow *window, QWindow *mainWindow) {
    if (!window || !supported())
        return;
    if (m_window == window) {
        apply();
        return;
    }
    if (mainWindow && mainWindow->screen())
        window->setScreen(mainWindow->screen());
    m_window = window;
    auto *layer = LayerShellQt::Window::get(window);
    // Above every panel (a dock's surface can cover a whole edge).
    layer->setLayer(LayerShellQt::Window::LayerOverlay);
    layer->setScope("omacraft-tab");
    layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
    // Clear of the space the bar and others reserve. Placement counts from
    // the screen's edge, so that space offsets it a little, but evenly, and a
    // drag still follows the pointer.
    layer->setExclusiveZone(0);
    connect(window, &QWindow::widthChanged, this, &EdgeTab::apply);
    connect(window, &QWindow::heightChanged, this, &EdgeTab::apply);
    apply();
}

void EdgeTab::apply() {
    if (!m_window)
        return;
    auto *layer = LayerShellQt::Window::get(m_window);
    const QSizeF screen = m_window->screen() ? m_window->screen()->geometry().size() : QSizeF(1920, 1080);
    const QRectF at = placement(m_edge, m_offset, screen, tabSize());
    using A = LayerShellQt::Window;
    if (vertical()) {
        layer->setAnchors(A::Anchors((m_edge == "left" ? A::AnchorLeft : A::AnchorRight) | A::AnchorTop));
        layer->setMargins(QMargins(0, qRound(at.y()), 0, 0));
    } else {
        layer->setAnchors(A::Anchors((m_edge == "top" ? A::AnchorTop : A::AnchorBottom) | A::AnchorLeft));
        layer->setMargins(QMargins(qRound(at.x()), 0, 0, 0));
    }
}

void EdgeTab::dragTo(const QPointF &local, const QPointF &grab) {
    if (!m_window)
        return;
    const QSizeF screen = m_window->screen() ? m_window->screen()->geometry().size() : QSizeF(1920, 1080);
    // Where the pointer is on the screen: the tab's own place plus the
    // point inside it.
    const QPointF point = placement(m_edge, m_offset, screen, tabSize()).topLeft() + local;
    const auto [edge, offset] = nearest(point, grab, screen, tabSize());
    if (edge == m_edge && qFuzzyCompare(1 + offset, 1 + m_offset))
        return;
    m_edge = edge;
    m_offset = offset;
    emit placed();
    apply();
}

void EdgeTab::save() {
    Proc::writeAtomically(m_path, QJsonDocument(QJsonObject{{"edge", m_edge}, {"offset", m_offset}}).toJson());
}
