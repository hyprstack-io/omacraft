#pragma once

#include <QLocalServer>
#include <QObject>
#include <QPointF>
#include <QRectF>
#include <QSizeF>
#include <QString>
#include <QVariant>

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
    // How it looks, set on the Plugin Suite page: its size along the edge
    // (length) and out from it (thickness), opacity when the pointer's
    // away, and what it shows.
    Q_PROPERTY(int length READ length NOTIFY styled)
    Q_PROPERTY(int thickness READ thickness NOTIFY styled)
    Q_PROPERTY(qreal opacity READ opacity NOTIFY styled)
    Q_PROPERTY(bool showIcon READ showIcon NOTIFY styled)
    Q_PROPERTY(bool showTitle READ showTitle NOTIFY styled)
    Q_PROPERTY(QString title READ title NOTIFY styled)

public:
    explicit EdgeTab(const QString &home, QObject *parent = nullptr);

    QString edge() const { return m_edge; }
    qreal offset() const { return m_offset; }
    bool vertical() const { return m_edge == "left" || m_edge == "right"; }
    bool supported() const;
    int length() const { return m_length; }
    int thickness() const { return m_thickness; }
    qreal opacity() const { return m_opacity; }
    bool showIcon() const { return m_showIcon; }
    bool showTitle() const { return m_showTitle; }
    QString title() const { return m_title; }

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
    // One setting by name (edge, offset, length, thickness, opacity,
    // showIcon, showTitle, title), kept in range and saved.
    Q_INVOKABLE void setOption(const QString &key, const QVariant &value);
    // Back to how it first looked, at the bottom centre.
    Q_INVOKABLE void reset();

signals:
    void placed();
    void styled();
    // Another launch asked for the window, maybe on a page and tab.
    void restoreRequested(const QString &page, const QString &tab);

private:
    void apply();
    QSizeF tabSize() const;

    QString m_path;
    // Bottom centre at first: the bar takes the top, docks the sides.
    QString m_edge = "bottom";
    qreal m_offset = 0.5;
    int m_length = 150;
    int m_thickness = 46;
    qreal m_opacity = 1.0;
    bool m_showIcon = true;
    bool m_showTitle = true;
    QString m_title = "OmaCraft";
    QWindow *m_window = nullptr;
    QLocalServer m_server;
};
