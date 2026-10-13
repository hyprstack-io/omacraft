// The file picker interface follows Omacut (MIT, David Heinemeier Hansson):
// the app talks to this, the portal implements it, and tests inject a fake.
#pragma once

#include <QObject>
#include <QUrl>

class FilePicker : public QObject {
    Q_OBJECT

public:
    explicit FilePicker(QObject *parent = nullptr) : QObject(parent) {}
    virtual ~FilePicker() = default;

    // purpose comes back with the answer, so one picker serves several fields.
    virtual void chooseFolder(const QString &purpose, const QString &title, const QString &startFolder) = 0;
    virtual void chooseIso(const QString &startFolder) = 0;

signals:
    void folderSelected(const QString &purpose, const QUrl &url);
    void isoSelected(const QUrl &url);
    void failed(const QString &message);
};
