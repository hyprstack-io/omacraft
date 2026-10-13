#pragma once

#include <QColor>
#include <QList>
#include <QPointer>
#include <QQuickTextDocument>
#include <QRegularExpression>
#include <QSyntaxHighlighter>
#include <QTextCharFormat>

// Colours the editor's text for the file's language: shell, ini (conf files,
// systemd units), json, lua, css, packages (a package list, where a name
// pacman wouldn't take shows as an error), or plain.
class SyntaxHighlighter : public QSyntaxHighlighter {
    Q_OBJECT
    Q_PROPERTY(QQuickTextDocument *document READ quickDocument WRITE setQuickDocument NOTIFY documentChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(QColor accent READ accent WRITE setAccent NOTIFY accentChanged)

public:
    explicit SyntaxHighlighter(QObject *parent = nullptr);

    QQuickTextDocument *quickDocument() const { return m_quickDocument; }
    void setQuickDocument(QQuickTextDocument *document);
    QString language() const { return m_language; }
    void setLanguage(const QString &language);
    QColor accent() const { return m_accent; }
    void setAccent(const QColor &accent);

    // The spans a line gets, for tests: start, length, and the format's name.
    struct Span {
        int start;
        int length;
        QString kind;
        bool operator==(const Span &other) const = default;
    };
    static QList<Span> spans(const QString &language, const QString &line, int previousState = 0, int *state = nullptr);

signals:
    void documentChanged();
    void languageChanged();
    void accentChanged();

protected:
    void highlightBlock(const QString &text) override;

private:
    QTextCharFormat format(const QString &kind) const;

    QPointer<QQuickTextDocument> m_quickDocument;
    QString m_language = "plain";
    QColor m_accent = QColor("#FFD60A");
};
