import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "LockDefaults.js" as Defaults

// Lock & Logon: the screens between you and the desktop. Lock edits a look the
// shell follows as it's saved; Idle sets when it all happens; Login is a draft
// until Apply, since SDDM's files take the password. Nothing here touches how
// you sign in: passwords are always checked by Omarchy's own PAM services.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    property string tab: startTab === "idle" || startTab === "login" ? startTab : "lock"
    readonly property bool dialogOpen: false
    readonly property bool ours: lockLogon.lockInUse === "omacraft.lock"
    readonly property string target: tab === "login" ? "login" : "lock"
    readonly property var shortcuts: [
        { keys: "L / I / G", action: "Lock, Idle and Login tabs" },
        { keys: "P", action: "Play the transitions on the stage" },
        { keys: "Ctrl Z", action: "Undo the last change" },
        { keys: "Ctrl Enter", action: "Apply the login design" }
    ]

    function handleEscape() {
        if (lockLogon.error !== "" || lockLogon.notice !== "") {
            lockLogon.dismissMessages();
            return true;
        }
        return false;
    }
    function acceptDialog() {}
    function minutes(seconds) {
        if (seconds <= 0) return "Off";
        if (seconds < 60) return seconds + " s";
        const whole = Math.floor(seconds / 60);
        const rest = seconds % 60;
        return whole + " min" + (rest > 0 ? " " + rest + " s" : "");
    }

    Shortcut { sequence: "L"; enabled: page.active && page.keysFree; onActivated: page.tab = "lock" }
    Shortcut { sequence: "I"; enabled: page.active && page.keysFree; onActivated: page.tab = "idle" }
    Shortcut { sequence: "G"; enabled: page.active && page.keysFree; onActivated: page.tab = "login" }
    Shortcut { sequence: "P"; enabled: page.active && page.keysFree && page.tab !== "idle"; onActivated: (page.tab === "login" ? loginTab : lockTab).play() }
    Shortcut { sequence: "Ctrl+Z"; enabled: page.active && page.tab !== "idle"; onActivated: lockLogon.undo(page.target) }
    Shortcut { sequence: "Ctrl+Return"; enabled: page.active && page.tab === "login" && !lockLogon.busy; onActivated: lockLogon.applyLogin() }

    // A time, with a word to turn it off.
    component TimeRow: RowLayout {
        id: timeRow
        property string label
        property int seconds: 0
        property int maximum: 3600
        signal changed(int seconds)
        Layout.fillWidth: true
        spacing: 10
        Label { Layout.preferredWidth: 150; text: timeRow.label; color: theme.textSoft }
        Slider {
            id: timeSlider
            Layout.fillWidth: true
            from: 30; to: timeRow.maximum; stepSize: 30
            enabled: timeRow.seconds > 0
            value: Math.max(30, timeRow.seconds)
            focusPolicy: Qt.NoFocus
            onPressedChanged: if (!pressed) timeRow.changed(Math.round(value))
        }
        Label {
            Layout.preferredWidth: 90
            horizontalAlignment: Text.AlignRight
            text: page.minutes(timeRow.seconds > 0 ? Math.round(timeSlider.value) : 0)
            color: theme.accent
            font.family: "monospace"
        }
        Switch {
            focusPolicy: Qt.NoFocus
            checked: timeRow.seconds > 0
            onToggled: timeRow.changed(checked ? Math.round(timeSlider.value) : 0)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        PageHeader {
            title: "Lock & Logon"
            subtitle: page.tab === "lock" ? "Layout, colour, pictures and how it comes and goes."
                    : page.tab === "idle" ? "When the screensaver, lock and display-off happen."
                    : "The screen you sign in on, with the same tools."
            glyph: "\u{f033e}"
            Segmented {
                objectName: "lockTabs"
                model: [{ id: "lock", name: "Lock" }, { id: "idle", name: "Idle" }, { id: "login", name: "Login" }]
                current: page.tab
                onPicked: id => page.tab = id
            }
        }

        MessageBar {
            error: lockLogon.error !== "" ? lockLogon.error : plugins.error
            notice: lockLogon.notice !== "" ? lockLogon.notice : plugins.notice
            onDismissed: { lockLogon.dismissMessages(); plugins.dismissMessages(); }
        }

        // --- Lock ---
        ColumnLayout {
            visible: page.tab === "lock"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Card {
                objectName: "lockInUseCard"
                Layout.fillWidth: true
                implicitHeight: lockUse.implicitHeight + 20
                RowLayout {
                    id: lockUse
                    anchors.fill: parent
                    anchors.margins: 10
                    anchors.leftMargin: 14
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Label {
                            text: page.ours ? "This design is your lock screen" : "In use now: " + lockLogon.lockInUseName
                            color: theme.text
                            font.weight: Font.DemiBold
                        }
                        Label {
                            Layout.fillWidth: true
                            text: page.ours ? "Changes reach the lock as you make them."
                                : "This design stays a draft until you switch. Your passwords and fingerprint work the same; the old lock comes back if the shell doesn't answer."
                            color: theme.textMuted
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }
                    Button {
                        visible: page.ours
                        text: "See it"
                        flat: true
                        focusPolicy: Qt.NoFocus
                        onClicked: lockLogon.previewLock()
                        ToolTip.visible: hovered
                        ToolTip.text: "Shows the real lock over the desktop. Click anywhere to close it."
                    }
                    AccentButton {
                        objectName: "useOurLock"
                        enabled: !plugins.busy
                        text: plugins.busy ? "Switching…" : page.ours ? "Put back the previous lock" : "Use this lock"
                        onClicked: lockLogon.useOurLock(!page.ours)
                    }
                }
            }

            LockDesign {
                id: lockTab
                target: "lock"
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        // --- Idle ---
        ScrollView {
            visible: page.tab === "idle"
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                id: idleColumn
                width: parent.width
                spacing: 12

                readonly property int blankSeconds: page.ours ? Defaults.clean(lockLogon.lockLook).blankSeconds : 5

                Card {
                    Layout.fillWidth: true
                    implicitHeight: 136
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        SectionLabel { text: lockLogon.stayAwake ? "Staying awake: nothing below happens" : "When you step away" }
                        IdleTimeline {
                            objectName: "idleTimeline"
                            Layout.fillWidth: true
                            opacity: lockLogon.stayAwake ? 0.35 : 1
                            screensaver: lockLogon.screensaverSeconds
                            lock: lockLogon.lockSeconds
                            blank: idleColumn.blankSeconds
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    implicitHeight: idleRows.implicitHeight + 28
                    ColumnLayout {
                        id: idleRows
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10
                        TimeRow {
                            label: "Screensaver after"
                            seconds: lockLogon.screensaverSeconds
                            onChanged: seconds => lockLogon.setIdle("screensaver", seconds)
                        }
                        TimeRow {
                            label: "Lock after"
                            seconds: lockLogon.lockSeconds
                            onChanged: seconds => lockLogon.setIdle("lock", seconds)
                        }
                        Label {
                            visible: lockLogon.lockSeconds === 0
                            Layout.fillWidth: true
                            text: "The screen won't lock by itself. Anyone at the keyboard gets your session."
                            color: theme.warningText
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                        SliderRow {
                            enabled: page.ours
                            label: "Display off after"
                            from: 2; to: 300; stepSize: 1; decimals: 0; suffix: " s"
                            value: idleColumn.blankSeconds
                            onMoved: v => lockLogon.set("lock", "blankSeconds", v)
                        }
                        Label {
                            Layout.fillWidth: true
                            text: page.ours ? "Counted from the lock, and from your last key while locked."
                                            : lockLogon.lockInUseName + " sets this itself; it's five seconds on Omarchy's lock. Use OmaCraft's lock to change it."
                            color: theme.textDim
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                        SwitchRow {
                            label: "Stay awake"
                            hint: "Holds off the screensaver and the lock until you turn this off, as the bar's coffee cup does."
                            checked: lockLogon.stayAwake
                            onToggled: on => lockLogon.setStayAwake(on)
                        }
                    }
                }

                RowLayout {
                    spacing: 8
                    Button { text: "Show the lock"; flat: true; focusPolicy: Qt.NoFocus; onClicked: lockLogon.previewLock() }
                    Button { text: "Lock now"; flat: true; focusPolicy: Qt.NoFocus; onClicked: lockLogon.lockNow() }
                    Button { text: "Screensaver page"; flat: true; focusPolicy: Qt.NoFocus; onClicked: page.openPage("saver") }
                }
            }
        }

        // --- Login ---
        ColumnLayout {
            visible: page.tab === "login"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Card {
                Layout.fillWidth: true
                implicitHeight: loginUse.implicitHeight + 20
                ColumnLayout {
                    id: loginUse
                    anchors.fill: parent
                    anchors.margins: 10
                    anchors.leftMargin: 14
                    spacing: 8

                    // Autologin means this screen is rarely seen: say so first.
                    RowLayout {
                        objectName: "autologinRow"
                        visible: lockLogon.autologinUser !== "" || lockLogon.autologinOverridden
                        Layout.fillWidth: true
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Label {
                                text: lockLogon.autologinUser !== "" ? "You sign in automatically as " + lockLogon.autologinUser
                                                                     : "Automatic login is off"
                                color: lockLogon.autologinUser !== "" ? theme.warningText : theme.text
                                font.weight: Font.DemiBold
                            }
                            Label {
                                Layout.fillWidth: true
                                text: lockLogon.autologinUser !== ""
                                    ? "Your disk password gets you in, so this screen only shows after you log out. With automatic login off, you'd type a second password at every boot."
                                    : "This screen shows at every boot. Omarchy's own setup is untouched, so turning this back on restores it."
                                color: theme.textMuted
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }
                        Switch {
                            focusPolicy: Qt.NoFocus
                            enabled: !lockLogon.busy && lockLogon.helperInstalled
                            checked: lockLogon.autologinUser !== ""
                            onToggled: lockLogon.setAutologin(checked)
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Label {
                                text: lockLogon.loginTheme === "omacraft" ? "OmaCraft's login theme is in use" : "In use now: " + (lockLogon.loginTheme || "SDDM's default") + "'s login theme"
                                color: theme.text
                                font.weight: Font.DemiBold
                            }
                            Label {
                                Layout.fillWidth: true
                                text: !lockLogon.loginThemeInstalled || !lockLogon.helperInstalled
                                    ? "The theme and its helper come with the OmaCraft package. Design here now, then run bin/install to apply it."
                                    : lockLogon.loginApplied ? "This design is what the login screen shows." : "Changes here are a draft until you apply them. Applying asks for your password. Colours that follow the theme are fixed at that moment."
                                color: theme.textMuted
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }
                        Button { text: "Same as the lock"; flat: true; focusPolicy: Qt.NoFocus; onClicked: lockLogon.copyLockToLogin() }
                        Button {
                            visible: lockLogon.loginThemeInstalled
                            text: "Try in a window"
                            flat: true
                            focusPolicy: Qt.NoFocus
                            onClicked: lockLogon.tryGreeter()
                        }
                        Button {
                            visible: lockLogon.loginThemeInstalled && lockLogon.helperInstalled
                            text: lockLogon.loginTheme === "omacraft" ? "Back to Omarchy's" : "Use this theme"
                            flat: true
                            focusPolicy: Qt.NoFocus
                            enabled: !lockLogon.busy
                            onClicked: lockLogon.useLoginTheme(lockLogon.loginTheme !== "omacraft")
                        }
                        AccentButton {
                            objectName: "applyLogin"
                            enabled: !lockLogon.busy && !lockLogon.loginApplied && lockLogon.helperInstalled
                            text: lockLogon.busy ? "Waiting…" : lockLogon.loginApplied ? "Applied" : "Apply  (Ctrl Enter)"
                            onClicked: lockLogon.applyLogin()
                        }
                    }
                }
            }

            LockDesign {
                id: loginTab
                target: "login"
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
