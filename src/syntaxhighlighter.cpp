#include "syntaxhighlighter.h"

#include <QTextDocument>

#include "buildconfig.h"

namespace {

// What each kind of span looks like on the window's dark surface; keywords
// and sections take the Omarchy theme's accent.
struct Look {
    const char *kind;
    const char *color;
    bool bold;
    bool italic;
};
constexpr Look looks[] = {
    {"string", "#a6da95", false, false},
    {"number", "#f5a97f", false, false},
    {"constant", "#f5a97f", false, false},
    {"comment", "#6e6e78", false, true},
    {"variable", "#7dc4e4", false, false},
    {"key", "#8aadf4", false, false},
    {"error", "#ed8796", false, false},
};

const QStringList shellKeywords{
    "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case", "esac", "function",
    "in", "return", "local", "export", "readonly", "set", "unset", "source", "exit", "break", "continue",
    "select", "declare", "shift", "trap", "eval", "exec"};
const QStringList luaKeywords{
    "and", "break", "do", "else", "elseif", "end", "for", "function", "goto", "if", "in", "local", "not",
    "or", "repeat", "return", "then", "until", "while"};

void markMatches(QList<QString> &kinds, const QString &line, const QRegularExpression &pattern, const QString &kind,
                 int group = 0, bool overStrings = false) {
    for (auto it = pattern.globalMatch(line); it.hasNext();) {
        const auto match = it.next();
        const int start = match.capturedStart(group);
        if (start < 0)
            continue;
        for (int i = start; i < match.capturedEnd(group); ++i) {
            if (kinds[i].isEmpty() || (overStrings && kinds[i] == "dstring"))
                kinds[i] = kind;
        }
    }
}

void markWords(QList<QString> &kinds, const QString &line, const QStringList &words, const QString &kind) {
    static const QRegularExpression word("\\b[A-Za-z_]+\\b");
    for (auto it = word.globalMatch(line); it.hasNext();) {
        const auto match = it.next();
        if (!words.contains(match.captured()))
            continue;
        bool free = true;
        for (int i = match.capturedStart(); i < match.capturedEnd(); ++i)
            free = free && kinds[i].isEmpty();
        if (free) {
            for (int i = match.capturedStart(); i < match.capturedEnd(); ++i)
                kinds[i] = kind;
        }
    }
}

}

SyntaxHighlighter::SyntaxHighlighter(QObject *parent) : QSyntaxHighlighter(parent) {}

void SyntaxHighlighter::setQuickDocument(QQuickTextDocument *document) {
    if (document == m_quickDocument)
        return;
    m_quickDocument = document;
    setDocument(document ? document->textDocument() : nullptr);
    emit documentChanged();
}

void SyntaxHighlighter::setLanguage(const QString &language) {
    if (language == m_language)
        return;
    m_language = language;
    rehighlight();
    emit languageChanged();
}

void SyntaxHighlighter::setAccent(const QColor &accent) {
    if (accent == m_accent)
        return;
    m_accent = accent;
    rehighlight();
    emit accentChanged();
}

QTextCharFormat SyntaxHighlighter::format(const QString &kind) const {
    QTextCharFormat format;
    if (kind == "keyword" || kind == "section") {
        format.setForeground(m_accent);
        format.setFontWeight(kind == "section" ? QFont::Bold : QFont::DemiBold);
        return format;
    }
    for (const Look &look : looks) {
        if (kind == QLatin1String(look.kind)) {
            format.setForeground(QColor(look.color));
            if (look.bold)
                format.setFontWeight(QFont::Bold);
            format.setFontItalic(look.italic);
            if (kind == "error")
                format.setUnderlineStyle(QTextCharFormat::WaveUnderline);
        }
    }
    return format;
}

void SyntaxHighlighter::highlightBlock(const QString &text) {
    int state = 0;
    const QList<Span> list = spans(m_language, text, qMax(0, previousBlockState()), &state);
    setCurrentBlockState(state);
    for (const Span &span : list)
        setFormat(span.start, span.length, format(span.kind));
}

QList<SyntaxHighlighter::Span> SyntaxHighlighter::spans(const QString &language, const QString &line, int previousState,
                                                        int *state) {
    if (state)
        *state = 0;
    QList<QString> kinds(line.size());
    const QString trimmed = line.trimmed();

    if (language == "packages") {
        const int hash = line.indexOf('#');
        const QString names = hash < 0 ? line : line.left(hash);
        static const QRegularExpression word("\\S+");
        for (auto it = word.globalMatch(names); it.hasNext();) {
            const auto match = it.next();
            if (!Profile::isValidPackageName(match.captured())) {
                for (int i = match.capturedStart(); i < match.capturedEnd(); ++i)
                    kinds[i] = "error";
            }
        }
        for (int i = hash; hash >= 0 && i < line.size(); ++i)
            kinds[i] = "comment";
    } else if (language != "plain") {
        // Strings and comments first, in one pass, so a # in a string or a
        // quote in a comment doesn't start anything.
        const bool shell = language == "shell";
        const bool ini = language == "ini";
        const QString blockOpen = language == "css" ? "/*" : language == "lua" ? "--[[" : QString();
        const QString blockClose = language == "css" ? "*/" : language == "lua" ? "]]" : QString();
        int i = 0;
        if (previousState == 1 && !blockClose.isEmpty()) {
            const int end = line.indexOf(blockClose);
            const int stop = end < 0 ? line.size() : end + blockClose.size();
            for (; i < stop; ++i)
                kinds[i] = "comment";
            if (end < 0 && state)
                *state = 1;
        }
        if (ini && (trimmed.startsWith('#') || trimmed.startsWith(';'))) {
            for (int j = 0; j < line.size(); ++j)
                kinds[j] = "comment";
            i = line.size();
        }
        while (i < line.size()) {
            const QChar c = line.at(i);
            if (!blockOpen.isEmpty() && line.mid(i, blockOpen.size()) == blockOpen) {
                const int end = line.indexOf(blockClose, i + blockOpen.size());
                const int stop = end < 0 ? line.size() : end + blockClose.size();
                for (; i < stop; ++i)
                    kinds[i] = "comment";
                if (end < 0 && state)
                    *state = 1;
                continue;
            }
            const bool comment = (shell && c == '#' && (i == 0 || line.at(i - 1).isSpace()))
                                 || (language == "json" && line.mid(i, 2) == "//")
                                 || (language == "lua" && line.mid(i, 2) == "--");
            if (comment) {
                for (; i < line.size(); ++i)
                    kinds[i] = "comment";
                break;
            }
            // ini values are free text ("Don't"), so only double quotes there.
            if (c == '"' || (c == '\'' && !ini)) {
                const QString kind = c == '"' ? "dstring" : "string";
                const int start = i++;
                // Shell single quotes have no escapes.
                const bool escapes = !(shell && c == '\'');
                while (i < line.size() && line.at(i) != c) {
                    if (escapes && line.at(i) == '\\')
                        ++i;
                    ++i;
                }
                i = qMin(i + 1, int(line.size()));
                for (int j = start; j < i; ++j)
                    kinds[j] = kind;
                continue;
            }
            ++i;
        }

        static const QRegularExpression number("(?<![A-Za-z_\\-])\\b\\d+(\\.\\d+)?\\b");
        if (shell) {
            static const QRegularExpression variable("\\$(\\{[^}]*\\}|[A-Za-z_][A-Za-z0-9_]*|[0-9@#?*!$-])");
            static const QRegularExpression assignment("^\\s*(?:export\\s+|local\\s+|readonly\\s+)?([A-Za-z_][A-Za-z0-9_]*)(?=\\+?=)");
            markMatches(kinds, line, variable, "variable", 0, true);
            markMatches(kinds, line, assignment, "key", 1);
            markWords(kinds, line, shellKeywords, "keyword");
            markMatches(kinds, line, number, "number");
        } else if (ini) {
            static const QRegularExpression section("^\\s*\\[[^\\]]*\\]");
            static const QRegularExpression key("^\\s*([^=\\s#;\\[][^=]*?)\\s*(?==)");
            static const QRegularExpression constant("\\b(yes|no|true|false|on|off|Never|Optional|Required|TrustAll)\\b");
            markMatches(kinds, line, section, "section");
            markMatches(kinds, line, key, "key", 1);
            markMatches(kinds, line, constant, "constant");
            markMatches(kinds, line, number, "number");
        } else if (language == "json") {
            static const QRegularExpression key("(\"(?:[^\"\\\\]|\\\\.)*\")\\s*:");
            static const QRegularExpression constant("\\b(true|false|null)\\b");
            for (auto it = key.globalMatch(line); it.hasNext();) {
                const auto match = it.next();
                for (int j = match.capturedStart(1); j < match.capturedEnd(1); ++j)
                    kinds[j] = "key";
            }
            markMatches(kinds, line, constant, "constant");
            markMatches(kinds, line, number, "number");
        } else if (language == "lua") {
            static const QRegularExpression constant("\\b(true|false|nil)\\b");
            markMatches(kinds, line, constant, "constant");
            markWords(kinds, line, luaKeywords, "keyword");
            markMatches(kinds, line, number, "number");
        } else if (language == "css") {
            static const QRegularExpression property("([A-Za-z-]+)\\s*:(?!:)");
            static const QRegularExpression color("#[0-9a-fA-F]{3,8}\\b");
            static const QRegularExpression atRule("@[A-Za-z-]+");
            markMatches(kinds, line, color, "constant");
            markMatches(kinds, line, atRule, "keyword");
            markMatches(kinds, line, property, "key", 1);
            markMatches(kinds, line, number, "number");
        }
    }

    QList<Span> list;
    for (int i = 0; i < kinds.size();) {
        QString kind = kinds[i];
        int j = i + 1;
        while (j < kinds.size() && kinds[j] == kind)
            ++j;
        if (kind == "dstring")
            kind = "string";
        if (!kind.isEmpty()) {
            if (!list.isEmpty() && list.last().kind == kind && list.last().start + list.last().length == i)
                list.last().length += j - i;
            else
                list.append({i, j - i, kind});
        }
        i = j;
    }
    return list;
}
