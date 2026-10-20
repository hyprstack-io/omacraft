#pragma once

#include <QColor>
#include <QQuickPaintedItem>
#include <QTextDocument>

// omascii's coloured HTML, painted into one texture. A Text with RichText
// turns every background-coloured span into its own scene graph node, and
// Qt 6.12's batch renderer crashes (prepareAlphaBatches) on enough of them,
// as TheDraw fonts have. Its size is the art's at `zoom`, so it stays sharp
// where a scaled Text would blur.
class AsciiView : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QString html READ html WRITE setHtml NOTIFY htmlChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(QString fontFamily READ fontFamily WRITE setFontFamily NOTIFY fontChanged)
    Q_PROPERTY(int pixelSize READ pixelSize WRITE setPixelSize NOTIFY fontChanged)
    Q_PROPERTY(qreal zoom READ zoom WRITE setZoom NOTIFY zoomChanged)
    // The art's size at zoom 1, for fitting it.
    Q_PROPERTY(qreal naturalWidth READ naturalWidth NOTIFY naturalSizeChanged)
    Q_PROPERTY(qreal naturalHeight READ naturalHeight NOTIFY naturalSizeChanged)

public:
    explicit AsciiView(QQuickItem *parent = nullptr);

    QString html() const { return m_html; }
    void setHtml(const QString &html);
    QColor color() const { return m_color; }
    void setColor(const QColor &color);
    QString fontFamily() const { return m_fontFamily; }
    void setFontFamily(const QString &family);
    int pixelSize() const { return m_pixelSize; }
    void setPixelSize(int size);
    qreal zoom() const { return m_zoom; }
    void setZoom(qreal zoom);
    qreal naturalWidth() const { return m_natural.width(); }
    qreal naturalHeight() const { return m_natural.height(); }

    void paint(QPainter *painter) override;

signals:
    void htmlChanged();
    void colorChanged();
    void fontChanged();
    void zoomChanged();
    void naturalSizeChanged();

private:
    void relayout();

    QTextDocument m_document;
    QString m_html;
    QColor m_color = Qt::white;
    QString m_fontFamily = "monospace";
    int m_pixelSize = 14;
    qreal m_zoom = 1;
    QSizeF m_natural{0, 0};
};
