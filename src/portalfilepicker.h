// Adapted from Omacut's portal file picker (MIT, David Heinemeier Hansson).
#pragma once

#include <QVariantMap>

#include "filepicker.h"

class PortalFilePicker : public FilePicker {
    Q_OBJECT

public:
    explicit PortalFilePicker(QObject *parent = nullptr);

    void chooseFolder(const QString &purpose, const QString &title, const QString &startFolder) override;
    void chooseIso(const QString &startFolder) override;

private slots:
    void handleResponse(uint response, const QVariantMap &results);

private:
    enum class Action {
        None,
        Folder,
        Iso
    };

    void requestFile(const QString &title, QVariantMap options, Action action);
    bool connectToRequestPath(const QString &path);
    void clearPending();

    QString m_pendingPath;
    QString m_pendingPurpose;
    Action m_pendingAction = Action::None;
};
