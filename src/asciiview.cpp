#include "asciiview.h"

#include <QAbstractTextDocumentLayout>
#include <QFont>
#include <QPainter>

AsciiView::AsciiView(QQuickItem *parent) : QQuickPaintedItem(parent) {
    // As a Text lays out rich text: no margin around the art.
    m_document.setDocumentMargin(0);
    m_document.setUndoRedoEnabled(false);
    relayout();
}

void AsciiView::setHtml(const QString &html) {
    if (html == m_html)
        return;
    m_html = html;
    relayout();
    emit htmlChanged();
}

void AsciiView::setColor(const QColor &color) {
    if (color == m_color)
        return;
    m_color = color;
    update();
    emit colorChanged();
}

void AsciiView::setFontFamily(const QString &family) {
    if (family == m_fontFamily)
        return;
    m_fontFamily = family;
    relayout();
    emit fontChanged();
}

void AsciiView::setPixelSize(int size) {
    if (size == m_pixelSize || size <= 0)
        return;
    m_pixelSize = size;
    relayout();
    emit fontChanged();
}

void AsciiView::setZoom(qreal zoom) {
    // A fit computed for a stage smaller than its margins comes out negative.
    zoom = qMax<qreal>(0.01, zoom);
    if (qFuzzyCompare(zoom, m_zoom))
        return;
    m_zoom = zoom;
    setImplicitSize(m_natural.width() * m_zoom, m_natural.height() * m_zoom);
    update();
    emit zoomChanged();
}

void AsciiView::relayout() {
    QFont font(m_fontFamily);
    font.setStyleHint(QFont::Monospace);
    font.setPixelSize(m_pixelSize);
    m_document.setDefaultFont(font);
    m_document.setHtml(m_html);
    const QSizeF natural = m_html.isEmpty() ? QSizeF(0, 0) : m_document.size();
    if (natural != m_natural) {
        m_natural = natural;
        emit naturalSizeChanged();
    }
    setImplicitSize(m_natural.width() * m_zoom, m_natural.height() * m_zoom);
    update();
}

void AsciiView::paint(QPainter *painter) {
    if (m_html.isEmpty())
        return;
    painter->scale(m_zoom, m_zoom);
    QAbstractTextDocumentLayout::PaintContext context;
    context.palette.setColor(QPalette::Text, m_color);
    m_document.documentLayout()->draw(painter, context);
}
