import QtQuick
import "LockDefaults.js" as Defaults

// The login screen: the lock screen's scene, on SDDM. Its settings are the text
// in theme.conf.user, which OmaCraft's root helper writes after checking every
// line, and they go through the same clean() as the lock's. The session pick and
// the way the password is handed over follow Omarchy's own theme.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: String(config.themeBackground || "#1a1b26")

    function settingsFromConfig() {
        const raw = {};
        for (const key in Defaults.rules)
            raw[key] = config[key];
        return Defaults.clean(raw);
    }
    readonly property var settings: settingsFromConfig()

    property string currentUser: userModel.lastUser
    property bool loginFailed: false
    property int failures: 0
    property string passwordText: ""
    property bool checking: false
    property int sessionIndex: {
        for (let i = 0; i < sessionModel.rowCount(); i++) {
            const name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString();
            if (name.indexOf("uwsm") !== -1)
                return i;
        }
        return sessionModel.lastIndex;
    }
    function sessionName() {
        return (sessionModel.data(sessionModel.index(sessionIndex, 0), Qt.DisplayRole) || "").toString();
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.checking = false;
            root.loginFailed = true;
            root.failures++;
            root.passwordText = "";
            scene.forcePasswordFocus();
        }
        function onLoginSucceeded() {
            root.loginFailed = false;
        }
    }

    LockScene {
        id: scene
        anchors.fill: parent
        settings: root.settings
        theme: ({
            background: String(config.themeBackground || "#1a1b26"),
            foreground: String(config.themeForeground || "#c0caf5"),
            accent: String(config.themeAccent || "#7aa2f7"),
            accent2: String(config.themeAccent || "#7aa2f7"),
            urgent: String(config.themeUrgent || "#f7768e")
        })
        backgroundFile: root.settings.bgImage !== "" ? String(Qt.resolvedUrl(root.settings.bgImage)) : ""
        userName: root.currentUser
        hostName: String(sddm.hostName || "")
        failureMessage: root.loginFailed ? "Wrong password" : ""
        failedAttempts: root.failures
        authenticating: root.checking
        passwordText: root.passwordText
        onPasswordTextEdited: password => root.passwordText = password
        onClearFailureRequested: root.loginFailed = false
        onSubmitPassword: password => {
            root.checking = true;
            sddm.login(root.currentUser, password, root.sessionIndex);
        }

        Row {
            spacing: 18
            anchors.horizontalCenter: parent.horizontalCenter

            component RowButton: Text {
                id: button
                signal clicked()
                textFormat: Text.PlainText
                color: scene.c.text
                opacity: hover.hovered ? 1 : 0.7
                font.family: scene.family
                font.pixelSize: 15
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: button.clicked() }
            }

            RowButton {
                visible: root.settings.showSession && sessionModel.rowCount() > 1
                text: "\u{f0a1b}  " + root.sessionName()
                onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount()
            }
            RowButton {
                visible: root.settings.showPower && sddm.canReboot
                text: "\u{f0709}"
                onClicked: sddm.reboot()
            }
            RowButton {
                visible: root.settings.showPower && sddm.canPowerOff
                text: "\u{f0425}"
                onClicked: sddm.powerOff()
            }
        }
    }

    Component.onCompleted: scene.forcePasswordFocus()
}
