import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtWebEngine

// One Kasm session in its own window (`omacraft kasm-view`, started by
// hyprvyzr). A slim header in OmaCraft's style carries the session's name,
// where it runs, and its controls; the rest is the session. Hyprland's own
// border goes round it, and the header's underline turns accent → accent-2.
//
//   Ctrl Shift M   minimise to the bar        Ctrl Shift T   tile / popup
//   Ctrl Shift F   fullscreen                 Ctrl Shift R   reload
//   Ctrl Shift W   end the session            (plain keys all go to Kasm)
ApplicationWindow {
    id: win
    width: 1440
    height: 900
    visible: true
    title: "HyprVYZR · " + session.title + (session.server ? " · " + session.server : "")
    color: theme.window

    Material.theme: theme.dark ? Material.Dark : Material.Light
    Material.accent: Qt.color(theme.accent)
    Material.background: theme.window
    Material.foreground: theme.text

    readonly property color accentColor: Qt.color(theme.accent)
    readonly property color accent2: Qt.hsla((accentColor.hslHue + 50 / 360) % 1, Math.max(0.35, accentColor.hslSaturation),
                                             accentColor.hslLightness, 1)
    property bool tiled: false
    property bool confirmEnd: false
    property bool fullscreenWeb: false

    function endSession() {
        session.act("end");
        Qt.quit();
    }

    Shortcut { sequence: "Ctrl+Shift+M"; onActivated: session.act("hide") }
    Shortcut { sequence: "Ctrl+Shift+T"; onActivated: { win.tiled = !win.tiled; session.act(win.tiled ? "tile" : "float"); } }
    Shortcut { sequence: "Ctrl+Shift+F"; onActivated: win.visibility === Window.FullScreen ? win.showNormal() : win.showFullScreen() }
    Shortcut { sequence: "Ctrl+Shift+R"; onActivated: web.reload() }
    Shortcut { sequence: "Ctrl+Shift+W"; onActivated: win.confirmEnd = true }

    component HeadButton: Rectangle {
        id: hb
        property string glyph
        property string tip
        property bool danger: false
        signal clicked()
        implicitWidth: 34
        implicitHeight: 28
        color: hbHover.hovered ? (danger ? theme.dangerFill : theme.hover) : "transparent"
        border.color: hbHover.hovered ? (danger ? theme.dangerBorder : theme.border) : "transparent"
        Label {
            anchors.centerIn: parent
            text: hb.glyph
            color: hbHover.hovered ? (hb.danger ? theme.dangerText : theme.text) : theme.textMuted
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
        }
        HoverHandler { id: hbHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: hb.clicked() }
        ToolTip.visible: hbHover.hovered
        ToolTip.delay: 400
        ToolTip.text: tip
    }

    header: Rectangle {
        visible: !win.fullscreenWeb
        height: visible ? 40 : 0
        color: theme.sidebar

        // The underline: the HyprStack gradient, sliding while it loads.
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: win.accentColor }
                GradientStop { position: 1; color: win.accent2 }
            }
        }
        Rectangle {
            visible: web.loading
            anchors.bottom: parent.bottom
            height: 2
            width: parent.width * Math.max(0.08, web.loadProgress / 100)
            color: theme.text
            opacity: 0.6
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 10

            // The mark: VYZR in a square, the brand's small form.
            Rectangle {
                width: 24; height: 24
                color: "transparent"
                border.width: 2
                border.color: win.accentColor
                Label {
                    anchors.centerIn: parent
                    text: "\u{f0379}"
                    color: win.accent2
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                }
            }
            Label {
                text: session.title
                color: theme.text
                font.family: "JetBrains Mono"
                font.weight: Font.DemiBold
                font.pixelSize: 13
            }
            Label {
                text: (session.kind === "native" ? "\u{f0868}  native" : session.kind === "local" ? "\u{f048b}  this machine" : "\u{f048d}  " + session.server)
                color: theme.textMuted
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }
            Item { Layout.fillWidth: true }
            Label {
                text: "Ctrl Shift M minimise · T tile · W end"
                color: theme.textFaint
                font.family: "JetBrains Mono"
                font.pixelSize: 10
            }
            HeadButton { glyph: "\u{f0450}"; tip: "Reload  (Ctrl Shift R)"; onClicked: web.reload() }
            HeadButton {
                glyph: win.tiled ? "\u{f05b7}" : "\u{f0d0a}"
                tip: win.tiled ? "Pop out as a floating window  (Ctrl Shift T)" : "Tile into the layout  (Ctrl Shift T)"
                onClicked: { win.tiled = !win.tiled; session.act(win.tiled ? "tile" : "float"); }
            }
            HeadButton {
                glyph: "\u{f0293}"
                tip: "Fullscreen  (Ctrl Shift F)"
                onClicked: win.visibility === Window.FullScreen ? win.showNormal() : win.showFullScreen()
            }
            HeadButton { glyph: "\u{f05b0}"; tip: "Minimise to the bar  (Ctrl Shift M)"; onClicked: session.act("hide") }
            HeadButton { glyph: "\u{f0156}"; tip: "End the session  (Ctrl Shift W)"; danger: true; onClicked: win.confirmEnd = true }
        }
    }

    WebEngineView {
        id: web
        anchors.fill: parent
        visible: session.valid
        profile: kasmProfile
        url: session.valid ? session.url : ""
        settings.javascriptCanAccessClipboard: true
        settings.javascriptCanPaste: true
        settings.fullScreenSupportEnabled: true
        settings.focusOnNavigationEnabled: true

        // A native image's password, made for this one run.
        onAuthenticationDialogRequested: function(request) {
            if (session.authUser() !== "" && request.type === AuthenticationDialogRequest.AuthenticationTypeHTTP) {
                request.accepted = true;
                request.dialogAccept(session.authUser(), session.authPassword());
            }
        }
        // Only the session's own self-signed certificate on this machine.
        onCertificateError: function(error) {
            if (session.acceptCertificate(error.url)) {
                error.acceptCertificate();
            } else {
                error.rejectCertificate();
                failure.text = "The certificate for " + error.url + " isn't trusted: " + error.description;
            }
        }
        onFullScreenRequested: function(request) {
            request.accept();
            win.fullscreenWeb = request.toggleOn;
            request.toggleOn ? win.showFullScreen() : win.showNormal();
        }
        // Kasm asks for the clipboard and, for audio input, the microphone.
        onPermissionRequested: function(permission) {
            if (permission.permissionType === WebEnginePermission.PermissionType.ClipboardReadWrite)
                permission.grant();
            else
                permission.deny();
        }
        onLoadingChanged: function(info) {
            if (info.status === WebEngineView.LoadFailedStatus)
                failure.text = "Couldn't load the session: " + info.errorString;
            else if (info.status === WebEngineView.LoadSucceededStatus)
                failure.text = "";
        }
        // Links that open a new window stay out of the session: they go to the
        // everyday browser.
        onNewWindowRequested: function(request) {
            Qt.openUrlExternally(request.requestedUrl);
        }
    }

    // Problems: a bad spec or a failed load.
    Rectangle {
        anchors.fill: parent
        visible: !session.valid || failure.text !== ""
        color: theme.window
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 60, 520)
            spacing: 12
            Label { text: "This session didn't open"; color: theme.text; font.pixelSize: 18; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignHCenter }
            Label {
                id: failure
                Layout.fillWidth: true
                text: session.valid ? "" : session.problem
                color: theme.textMuted
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Button { text: "Try again"; visible: session.valid; onClicked: { failure.text = ""; web.reload(); } }
                Button { text: "Close"; flat: true; onClicked: win.endSession() }
            }
        }
    }

    // Ending is for good: ask once.
    Rectangle {
        anchors.fill: parent
        visible: win.confirmEnd
        color: "#cc000000"
        MouseArea { anchors.fill: parent; onClicked: win.confirmEnd = false }
        Rectangle {
            anchors.centerIn: parent
            width: 420
            height: endCol.implicitHeight + 40
            color: theme.raised
            border.color: theme.border
            ColumnLayout {
                id: endCol
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12
                Label { text: "End " + session.title + "?"; color: theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: theme.textMuted
                    text: session.kind === "native" ? "The container is removed, and everything in it with it." : "The session is destroyed on " + session.server + ". Minimise it instead to keep it running."
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    Button { text: "Minimise instead"; flat: true; onClicked: { win.confirmEnd = false; session.act("hide"); } }
                    Button { text: "Cancel"; flat: true; onClicked: win.confirmEnd = false }
                    Button { text: "End"; Material.background: theme.danger; Material.foreground: "white"; onClicked: win.endSession() }
                }
            }
        }
        Keys.onEscapePressed: win.confirmEnd = false
    }

    // Closing the window ends the session too (Kasm would otherwise keep it
    // running unseen); minimising is the way to keep it.
    onClosing: function(close) {
        if (!win.confirmEnd && session.valid && failure.text === "") {
            close.accepted = false;
            win.confirmEnd = true;
        } else {
            session.act("end");
        }
    }
}
