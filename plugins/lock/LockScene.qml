import QtQuick
import QtQuick.Effects
import "LockDefaults.js" as Defaults

// The lock screen itself, with no ties to the shell, so one file draws the real
// lock, OmaCraft's preview and the login screen. Whatever hosts it passes in the
// cleaned settings, the theme and the live state, and answers its signals. It
// never sees a password check: it hands over what was typed and is told how it went.
Item {
    id: scene

    property var settings: Defaults.clean({})
    property var theme: ({ background: "#1a1b26", foreground: "#c0caf5", accent: "#7aa2f7", accent2: "#bb9af7", urgent: "#f7768e" })
    property string backgroundFile: ""
    property int backgroundVersion: 0
    property string userName: ""
    property string hostName: ""
    property string defaultPlaceholder: "Enter password"
    property string checkingText: "Checking…"
    property string fingerprintNotice: ""

    property bool fingerprintConfigured: false
    property bool fingerprintUnavailable: false
    property bool authenticating: false
    property string failureMessage: ""
    property int failedAttempts: 0
    property bool inputEnabled: true
    property bool loadBackground: true
    property string passwordText: ""
    // Drawn scaled down by a thumbnail: skip the expensive parts.
    property bool thumbnail: false
    // Sized by its host, at the screen's own scale.
    property real uiScale: 1
    // Decode the picture smaller than the scene, for previews.
    property real pictureScale: 1

    // Set by the host when the password was right; the scene leaves, and the
    // host releases the session on its own timer whatever happens here.
    property bool leaving: false
    // The curtain's progress for the way in and out, 0 hidden to 1 shown.
    property real presence: 1

    // Below the block, for the login screen's session and power rows.
    default property alias extras: extraSlot.data

    signal submitPassword(string password)
    signal passwordTextEdited(string password)
    signal clearFailureRequested()
    signal wakeRequested()

    readonly property var s: settings
    readonly property var c: Defaults.colours(s, theme)
    readonly property string family: s.fontFamily || "JetBrainsMono Nerd Font"
    readonly property string file: loadBackground ? Defaults.backgroundFile(s, backgroundFile, "") : ""
    readonly property bool hasPicture: file !== ""
    readonly property bool errorState: failureMessage.length > 0
    readonly property bool showCursor: inputEnabled && !authenticating && failureMessage.length === 0
    property date now: new Date()
    property bool syncingPasswordText: false

    function forcePasswordFocus() { passwordInput.forceActiveFocus(); }
    function clearPassword() { passwordTextEdited(""); }
    function dropsAutoRepeat(key) { return key !== Qt.Key_Backspace && key !== Qt.Key_Delete; }
    function syncPasswordText() {
        if (passwordInput.text === passwordText) return;
        syncingPasswordText = true;
        passwordInput.text = passwordText;
        syncingPasswordText = false;
    }
    // Plays the way-in again, for the preview's Play button.
    function replayIn() {
        scene.presence = 0;
        arrive.restart();
    }
    function format(text) {
        return text.replace(/\{user\}/g, scene.userName).replace(/\{host\}/g, scene.hostName);
    }
    function clockText() {
        const pattern = (s.clock24h ? "HH:mm" : "h:mm") + (s.clockSeconds ? ":ss" : "");
        return Qt.formatTime(now, pattern) + (s.clock24h ? "" : (now.getHours() < 12 ? " am" : " pm"));
    }
    function alpha(color, a) {
        const q = Qt.color(color);
        return Qt.rgba(q.r, q.g, q.b, a);
    }

    onPasswordTextChanged: syncPasswordText()
    onInputEnabledChanged: if (inputEnabled) Qt.callLater(forcePasswordFocus)
    onFailedAttemptsChanged: if (s.shake && failedAttempts > 0 && !thumbnail) shake.restart()
    Component.onCompleted: {
        syncPasswordText();
        if (inputEnabled) Qt.callLater(forcePasswordFocus);
        if (s.lockIn !== "none" && !thumbnail) replayIn();
    }
    // Never left hidden: a surface used again starts from shown, whatever happened.
    onLeavingChanged: {
        if (leaving) {
            arrive.stop();
            depart.restart();
        } else {
            depart.stop();
            presence = 1;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: (s.showClock || s.showDate) && !scene.thumbnail
        triggeredOnStart: true
        onTriggered: scene.now = new Date()
    }

    NumberAnimation {
        id: arrive
        target: scene; property: "presence"
        from: 0; to: 1
        duration: scene.s.lockInMs
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: depart
        target: scene; property: "presence"
        to: 0
        duration: scene.s.unlockMs
        easing.type: Easing.InOutCubic
    }

    // The motion in play: the one being entered or left.
    readonly property string motion: leaving ? s.unlockOut : s.lockIn
    readonly property real gone: 1 - presence

    TextMetrics {
        id: dotMetrics
        font.family: scene.family
        font.pixelSize: dotSize
        text: scene.s.dotGlyph.repeat(passwordInput.text.length)
    }
    readonly property int fieldFontSize: Math.round(19 * uiScale)
    readonly property int dotSize: Math.round(22 * uiScale)
    readonly property real dotScale: dotMetrics.advanceWidth > 0
        ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth) : 1

    Rectangle {
        anchors.fill: parent
        color: scene.c.background

        // --- the picture ---
        Item {
            id: backdrop
            anchors.fill: parent
            clip: true
            // Only on the way in: leaving, the picture stays, as the compositor is black behind it.
            opacity: !scene.leaving && scene.motion === "fade" ? scene.presence : 1

            Rectangle {
                anchors.fill: parent
                visible: scene.s.bgMode === "gradient"
                rotation: 0
                gradient: Gradient {
                    orientation: scene.s.bgAngle >= 45 && scene.s.bgAngle < 135 || scene.s.bgAngle >= 225 && scene.s.bgAngle < 315 ? Gradient.Horizontal : Gradient.Vertical
                    GradientStop { position: 0; color: scene.s.bgColor || scene.theme.background }
                    GradientStop { position: 1; color: scene.s.bgColor2 || scene.theme.accent }
                }
            }
            Rectangle {
                anchors.fill: parent
                visible: scene.s.bgMode === "solid"
                color: scene.s.bgColor || scene.theme.background
            }

            Image {
                id: picture
                anchors.centerIn: parent
                width: parent.width * (1 + drifting)
                height: parent.height * (1 + drifting)
                property real drifting: 0
                visible: scene.hasPicture
                source: scene.hasPicture ? Defaults.fileUrl(scene.file) + "?v=" + scene.backgroundVersion : ""
                asynchronous: true
                cache: true
                // A broken or missing picture leaves the plain colour behind it.
                sourceSize: scene.s.bgFit === "tile" || scene.s.bgFit === "center" ? undefined : Qt.size(Math.max(1, scene.width * scene.pictureScale), Math.max(1, scene.height * scene.pictureScale))
                fillMode: scene.s.bgFit === "fit" ? Image.PreserveAspectFit
                        : scene.s.bgFit === "stretch" ? Image.Stretch
                        : scene.s.bgFit === "center" ? Image.Pad
                        : scene.s.bgFit === "tile" ? Image.Tile : Image.PreserveAspectCrop
                layer.enabled: true
                layer.effect: MultiEffect {
                    autoPaddingEnabled: false
                    blurEnabled: !scene.thumbnail && scene.s.blur > 0
                    // Focus pulls the blur in and out, so the sharp wallpaper meets the desktop.
                    blur: scene.motion === "focus" ? scene.s.blur * scene.presence : scene.s.blur
                    blurMax: 128
                    blurMultiplier: 1.25
                    brightness: scene.s.brightness
                    contrast: scene.s.contrast
                    saturation: scene.s.saturation
                }
                SequentialAnimation on drifting {
                    running: scene.s.drift && !scene.thumbnail && scene.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.06; duration: 30000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: 30000; easing.type: Easing.InOutSine }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: scene.s.colorDim || "#000000"
                opacity: scene.s.dim
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: scene.inputEnabled
            enabled: scene.inputEnabled
            onClicked: { scene.wakeRequested(); scene.forcePasswordFocus(); }
            onPositionChanged: scene.wakeRequested()
        }

        // --- what's laid over it ---
        Item {
            id: stageContent
            anchors.fill: parent
            opacity: scene.motion === "none" ? 1 : scene.presence
            scale: scene.motion === "zoom" ? 0.94 + 0.06 * scene.presence : 1
            transform: Translate {
                y: scene.motion === "rise" ? 0.06 * scene.height * scene.gone : 0
                x: scene.motion === "curtain" ? (scene.s.blockX < 50 ? -1 : 1) * 0.2 * scene.width * scene.gone : 0
            }

            Rectangle {
                id: panel
                visible: scene.s.panel !== "none"
                readonly property string kind: scene.s.panel
                readonly property real thickness: (kind === "bottom" ? scene.height : scene.width) * scene.s.panelSize / 100
                x: kind === "right" ? scene.width - width
                 : kind === "card" ? Math.max(8, Math.min(scene.width - width - 8, blockHolder.x + blockHolder.width / 2 - width / 2)) : 0
                y: kind === "bottom" ? scene.height - height
                 : kind === "card" ? Math.max(8, Math.min(scene.height - height - 8, blockHolder.y + blockHolder.height / 2 - height / 2)) : 0
                width: kind === "bottom" ? scene.width : kind === "card" ? Math.min(scene.width - 16, Math.max(thickness, blockHolder.width + 64 * scene.uiScale)) : thickness
                height: kind === "card" ? Math.min(scene.height - 16, blockHolder.height + 72 * scene.uiScale) : kind === "bottom" ? thickness : scene.height
                radius: kind === "card" ? scene.s.panelRadius * scene.uiScale : 0
                color: scene.alpha(scene.c.panel, scene.s.panelOpacity)
            }

            // The block: its centre sits at blockX, blockY and it stays on the screen.
            Item {
                id: blockHolder
                width: block.width
                height: block.height
                x: Math.max(8, Math.min(scene.width - width - 8, scene.width * scene.s.blockX / 100 - width / 2))
                y: Math.max(8, Math.min(scene.height - height - 8, scene.height * scene.s.blockY / 100 - height / 2))

                readonly property int textAlign: scene.s.align === "left" ? Text.AlignLeft : scene.s.align === "right" ? Text.AlignRight : Text.AlignHCenter

                Column {
                    id: block
                    spacing: scene.s.gap * scene.uiScale
                    width: Math.min(scene.width - 16, Math.max(field.width, implicitContent))
                    readonly property real implicitContent: Math.max(clock.visible ? clock.implicitWidth : 0,
                                                                     greeting.visible ? greeting.implicitWidth : 0,
                                                                     note.visible ? Math.min(note.implicitWidth, 640 * scene.uiScale) : 0)

                    function hAnchor(item) {
                        return scene.s.align === "left" ? 0 : scene.s.align === "right" ? width - item.width : (width - item.width) / 2;
                    }

                    Item {
                        id: avatarHolder
                        visible: scene.s.showAvatar
                        width: scene.s.avatarSize * scene.uiScale
                        height: width
                        x: block.hAnchor(avatarHolder)
                        readonly property real curve: scene.s.avatarShape === "circle" ? width / 2 : scene.s.avatarShape === "squircle" ? width * 0.28 : 0
                        Rectangle {
                            id: avatarFallback
                            anchors.fill: parent
                            radius: avatarHolder.curve
                            color: scene.alpha(scene.c.border, 0.22)
                            border.color: scene.c.border
                            border.width: Math.max(1, 2 * scene.uiScale)
                            visible: avatarImage.status !== Image.Ready
                            Text {
                                anchors.centerIn: parent
                                text: scene.userName.slice(0, 1).toUpperCase()
                                textFormat: Text.PlainText
                                color: scene.c.text
                                font.family: scene.family
                                font.pixelSize: parent.width * 0.42
                            }
                        }
                        Image {
                            id: avatarImage
                            anchors.fill: parent
                            source: scene.s.avatar ? Defaults.fileUrl(scene.s.avatar) : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(width * 2, height * 2)
                            asynchronous: true
                            visible: false
                        }
                        Rectangle {
                            id: avatarMask
                            anchors.fill: parent
                            radius: avatarHolder.curve
                            visible: false
                            layer.enabled: true
                        }
                        MultiEffect {
                            anchors.fill: parent
                            visible: avatarImage.status === Image.Ready
                            source: avatarImage
                            maskEnabled: true
                            maskSource: avatarMask
                        }
                    }

                    Text {
                        id: clock
                        visible: scene.s.showClock
                        width: block.width
                        textFormat: Text.PlainText
                        text: scene.clockText()
                        color: scene.c.clock
                        opacity: scene.s.clockOpacity
                        font.family: scene.family
                        font.pixelSize: scene.s.clockSize * scene.uiScale
                        font.weight: scene.s.clockWeight === "bold" ? Font.Bold : scene.s.clockWeight === "light" ? Font.Light : Font.Normal
                        horizontalAlignment: blockHolder.textAlign
                    }
                    Text {
                        visible: scene.s.showDate
                        width: block.width
                        textFormat: Text.PlainText
                        text: Qt.formatDate(scene.now, scene.s.dateFormat)
                        color: scene.c.clock
                        opacity: 0.85 * scene.s.clockOpacity
                        font.family: scene.family
                        font.pixelSize: scene.s.dateSize * scene.uiScale
                        horizontalAlignment: blockHolder.textAlign
                    }
                    Text {
                        id: greeting
                        visible: scene.s.showGreeting
                        width: block.width
                        textFormat: Text.PlainText
                        text: scene.format(scene.s.greeting)
                        color: scene.c.text
                        font.family: scene.family
                        font.pixelSize: scene.s.greetingSize * scene.uiScale
                        horizontalAlignment: blockHolder.textAlign
                        elide: Text.ElideRight
                    }

                    // The field: always on the screen, always taking keys.
                    Item {
                        id: field
                        width: Math.min(scene.width - 16, scene.s.fieldWidth * scene.uiScale)
                        height: scene.s.fieldHeight * scene.uiScale
                        x: block.hAnchor(field) + shakeOffset
                        property real shakeOffset: 0
                        readonly property real ring: scene.s.borderWidth * scene.uiScale
                        readonly property real curve: scene.s.fieldStyle === "pill" ? height / 2
                                                    : scene.s.fieldStyle === "line" ? 0 : scene.s.fieldRadius * scene.uiScale
                        property real glow: 1

                        SequentialAnimation on glow {
                            running: scene.s.pulse && !scene.thumbnail && scene.inputEnabled && !scene.errorState
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { to: 0.45; duration: 1400; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 1400; easing.type: Easing.InOutSine }
                        }

                        // The fill, then the ring around it with its middle cut out,
                        // so a see-through field shows the picture and not the ring.
                        Rectangle {
                            visible: scene.s.fieldStyle !== "line"
                            anchors.fill: parent
                            anchors.margins: field.ring
                            radius: Math.max(0, field.curve - field.ring)
                            color: scene.alpha(scene.c.surface, scene.s.fieldOpacity)
                        }
                        Item {
                            id: ringHole
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: field.ring
                                radius: Math.max(0, field.curve - field.ring)
                            }
                        }
                        Rectangle {
                            id: ring
                            visible: false
                            anchors.fill: parent
                            radius: field.curve
                            layer.enabled: true
                            color: scene.errorState ? scene.c.error : scene.c.border
                            gradient: scene.s.borderGradient && !scene.errorState ? ringGradient : null
                            Gradient {
                                id: ringGradient
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: scene.c.border }
                                GradientStop { position: 1; color: scene.c.border2 }
                            }
                        }
                        MultiEffect {
                            visible: scene.s.fieldStyle !== "line" && field.ring > 0
                            anchors.fill: parent
                            source: ring
                            opacity: field.glow
                            maskEnabled: true
                            maskInverted: true
                            maskSource: ringHole
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }
                        Rectangle {
                            visible: scene.s.fieldStyle === "line"
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(1, field.ring)
                            opacity: field.glow
                            color: scene.errorState ? scene.c.error : scene.c.border
                        }

                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            anchors.topMargin: field.ring
                            anchors.bottomMargin: field.ring
                            anchors.leftMargin: field.ring + 18 * scene.uiScale + reserve
                            anchors.rightMargin: field.ring + 18 * scene.uiScale + reserve
                            readonly property real reserve: scene.fingerprintConfigured || scene.fingerprintUnavailable ? fingerprintIcon.implicitWidth + 12 : 0
                            verticalAlignment: TextInput.AlignVCenter
                            horizontalAlignment: scene.s.align === "left" ? TextInput.AlignLeft : scene.s.align === "right" ? TextInput.AlignRight : TextInput.AlignHCenter
                            activeFocusOnPress: true
                            clip: true
                            enabled: scene.inputEnabled && !scene.authenticating
                            readOnly: scene.authenticating
                            echoMode: TextInput.Password
                            passwordCharacter: scene.s.dotGlyph
                            passwordMaskDelay: 0
                            color: scene.c.text
                            selectionColor: scene.alpha(scene.c.border, 0.45)
                            selectedTextColor: scene.c.text
                            font.family: scene.family
                            font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(scene.dotSize * scene.dotScale)) : scene.fieldFontSize
                            cursorVisible: activeFocus && scene.showCursor && text.length > 0
                            cursorDelegate: Rectangle {
                                width: 2
                                color: scene.c.text
                                visible: passwordInput.cursorVisible
                            }

                            onTextChanged: {
                                if (!scene.syncingPasswordText) scene.passwordTextEdited(text);
                                if (text.length > 0) scene.wakeRequested();
                                if (text.length > 0 && scene.failureMessage.length > 0) scene.clearFailureRequested();
                            }
                            onAccepted: {
                                const submitted = scene.passwordText;
                                scene.passwordTextEdited("");
                                if (submitted.length > 0) scene.submitPassword(submitted);
                            }
                            Keys.onPressed: event => {
                                scene.wakeRequested();
                                if (event.isAutoRepeat && scene.dropsAutoRepeat(event.key)) {
                                    event.accepted = true;
                                    return;
                                }
                                if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                                    scene.passwordTextEdited("");
                                    event.accepted = true;
                                }
                            }
                        }

                        Text {
                            anchors.fill: passwordInput
                            textFormat: Text.PlainText
                            visible: passwordInput.text.length === 0
                            text: scene.authenticating ? scene.checkingText
                                : scene.failureMessage.length > 0 ? scene.failureMessage
                                : (scene.s.placeholder || scene.defaultPlaceholder)
                            color: scene.authenticating ? scene.c.text : scene.failureMessage.length > 0 ? scene.c.error : scene.alpha(scene.c.text, 0.66)
                            font.family: scene.family
                            font.pixelSize: scene.fieldFontSize
                            font.italic: !scene.authenticating && scene.failureMessage.length > 0
                            horizontalAlignment: passwordInput.horizontalAlignment
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            id: fingerprintIcon
                            objectName: "fingerprintIndicator"
                            textFormat: Text.PlainText
                            anchors.right: parent.right
                            anchors.rightMargin: field.ring + 18 * scene.uiScale
                            anchors.verticalCenter: parent.verticalCenter
                            visible: scene.fingerprintConfigured || scene.fingerprintUnavailable
                            text: scene.fingerprintUnavailable ? "\u{f0eb1}" : "\u{f0237}"
                            color: scene.fingerprintUnavailable ? scene.c.error : scene.alpha(scene.c.text, 0.66)
                            font.family: scene.family
                            font.pixelSize: Math.round(scene.fieldFontSize * 1.1)
                        }
                    }

                    Text {
                        visible: scene.fingerprintUnavailable && scene.fingerprintNotice !== ""
                        width: block.width
                        textFormat: Text.PlainText
                        text: scene.fingerprintNotice
                        color: scene.c.error
                        font.family: scene.family
                        font.pixelSize: 16 * scene.uiScale
                        font.italic: true
                        horizontalAlignment: blockHolder.textAlign
                    }
                    Text {
                        id: note
                        visible: scene.s.showNote && scene.s.note !== ""
                        width: block.width
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        text: scene.format(scene.s.note)
                        color: scene.alpha(scene.c.text, 0.72)
                        font.family: scene.family
                        font.pixelSize: scene.s.noteSize * scene.uiScale
                        horizontalAlignment: blockHolder.textAlign
                    }
                    Item {
                        id: extraSlot
                        width: block.width
                        height: childrenRect.height
                        visible: children.length > 0
                    }
                }
            }
        }

        SequentialAnimation {
            id: shake
            NumberAnimation { target: field; property: "shakeOffset"; to: -10; duration: 45 }
            NumberAnimation { target: field; property: "shakeOffset"; to: 9; duration: 70 }
            NumberAnimation { target: field; property: "shakeOffset"; to: -6; duration: 60 }
            NumberAnimation { target: field; property: "shakeOffset"; to: 3; duration: 50 }
            NumberAnimation { target: field; property: "shakeOffset"; to: 0; duration: 40 }
        }
    }
}
