#pragma once

#include <QLocalServer>
#include <QObject>
#include <QPointF>
#include <QRectF>
#include <QSizeF>
#include <QString>

class QWindow;

// OmaCraft closed or minimised: not gone, but folded into a small tab on
// the edge of the screen, a layer-shell surface the compositor keeps above
// the windows. The tab can be dragged anywhere around the screen's edge and
// stays where it's left, across runs (~/.config/omacraft/edge-tab.json). A
// click on it, or launching OmaCraft again, brings the window back.
//
// It also keeps OmaCraft to one window: a second `omacraft [page] [tab]`
// hands its page to the first through a local socket and quits.
class EdgeTab : public QObject {
    Q_OBJECT
    // top | bottom | left | right
    Q_PROPERTY(QString edge READ edge NOTIFY placed)
    // Where along that edge, 0 (top or left end) to 1.
    Q_PROPERTY(qreal offset READ offset NOTIFY placed)
    Q_PROPERTY(bool vertical READ vertical NOTIFY placed)
    // Only Wayland compositors with layer shell can hold a tab on the edge.
    Q_PROPERTY(bool supported READ supported CONSTANT)

public:
    explicit EdgeTab(const QString &home, QObject *parent = nullptr);

    QString edge() const { return m_edge; }
    qreal offset() const { return m_offset; }
    bool vertical() const { return m_edge == "left" || m_edge == "right"; }
    bool supported() const;

    // The tab's rectangle on a screen of that size, for an edge and offset.
    static QRectF placement(const QString &edge, qreal offset, const QSizeF &screen, const QSizeF &tab);
    // The edge nearest a point, and how far along it the tab goes so the
    // point sits at grab inside it.
    static QPair<QString, qreal> nearest(const QPointF &point, const QPointF &grab, const QSizeF &screen, const QSizeF &tab);

    // Hand the arguments to a running OmaCraft; true if one took them.
    static bool passToRunning(const QStringList &arguments);
    // Become the one that's running; restoreRequested comes from others.
    void listen();

    // Make window the tab (once, before it's first shown) on mainWindow's screen.
    Q_INVOKABLE void attach(QWindow *window, QWindow *mainWindow);
    // The pointer at local inside the tab, which was grabbed at grab:
    // follow it round the edge.
    Q_INVOKABLE void dragTo(const QPointF &local, const QPointF &grab);
    // Drag over: write where it was left.
    Q_INVOKABLE void save();

signals:
    void placed();
    // Another launch asked for the window, maybe on a page and tab.
    void restoreRequested(const QString &page, const QString &tab);

private:
    void apply();
    QSizeF tabSize() const;

    QString m_path;
    // Bottom centre at first: the bar takes the top, docks the sides.
    QString m_edge = "bottom";
    qreal m_offset = 0.5;
    QWindow *m_window = nullptr;
    QLocalServer m_server;
};
