import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtWebEngine

// The HyprFIGZ configurator, running inside OMAcraft. The web view only
// starts the first time the page is opened, since Chromium is heavy.
Item {
    id: page

    property bool active: false
    property bool keysFree: false
    signal openPage(string name)

    readonly property bool dialogOpen: false
    property bool started: false
    property string lastDownload: ""
    property string loadError: ""
    // The web view takes the keyboard, so OMAcraft's letter keys stand down
    // on this page; Ctrl and number keys still switch pages.
    readonly property bool capturesKeys: true
    readonly property var shortcuts: [
        { keys: "Ctrl R", action: "Reload HyprFIGZ (your work is kept)" },
        { keys: "Ctrl 1…7", action: "Switch pages (letter keys go to HyprFIGZ here)" }
    ]

    function handleEscape() { return false; }
    function acceptDialog() {}

    onActiveChanged: if (active) { hyprcraft.refresh(); started = true; }

    Shortcut { sequence: "Ctrl+R"; context: Qt.ApplicationShortcut; enabled: page.active && page.started; onActivated: web.item && web.item.reload() }

    Connections {
        target: hyprcraftProfile
        function onDownloadRequested(download) {
            download.downloadDirectory = hyprcraft.downloadDir;
            download.accept();
            page.lastDownload = download.downloadFileName;
            download.isFinishedChanged.connect(() => {
                if (!download.isFinished) return;
                const ok = download.state === WebEngineDownloadRequest.DownloadCompleted;
                hyprcraft.downloaded(download.downloadDirectory + "/" + download.downloadFileName, ok, download.interruptReasonString);
            });
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        PageHeader {
            title: "HyprFIGZ"
            subtitle: "Hyprland and Omarchy configurator: pick Omarchy or plain Hyprland at the top · exports go to ~/Downloads/HyprCraft"
            glyph: "\u{f0b0b}"
            Label {
                visible: page.lastDownload !== ""
                text: "Saved " + page.lastDownload
                color: theme.textMuted
                font.pixelSize: 11
            }
            Button { text: "Exports"; flat: true; focusPolicy: Qt.NoFocus; onClicked: hyprcraft.openDownloads() }
            Button { text: "Reload"; flat: true; focusPolicy: Qt.NoFocus; enabled: page.started && hyprcraft.available; onClicked: web.item && web.item.reload() }
        }

        MessageBar {
            error: page.loadError
            onDismissed: page.loadError = ""
        }

        // An Omarchy bundle just came out of the Export dialog.
        Card {
            Layout.fillWidth: true
            visible: hyprcraft.bundle !== ""
            implicitHeight: bundleRow.implicitHeight + 24
            RowLayout {
                id: bundleRow
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                Label {
                    Layout.fillWidth: true
                    text: "Install " + hyprcraft.bundle.replace(/^.*\//, "") + " into Omarchy? Its install.sh backs up every file it replaces, checks Hyprland's config, and runs in a terminal so you can watch."
                    color: theme.text
                    wrapMode: Text.WordWrap
                }
                Button { text: "Not now"; flat: true; focusPolicy: Qt.NoFocus; onClicked: hyprcraft.dismissBundle() }
                AccentButton { text: "Install"; onClicked: hyprcraft.installBundle() }
            }
        }

        MessageBar {
            visible: !hyprcraft.available
            error: "HyprFIGZ's built app wasn't found. OMAcraft looks in the installed plugin's app folder, in ~/Projects/HyprCraft/omarchy-plugin/app, and in the copy the package installs. Build it with `npm run build:plugin` in ~/Projects/HyprCraft, or reinstall OMAcraft."
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: hyprcraft.available
            clip: true

            Loader {
                id: web
                anchors.fill: parent
                anchors.margins: 1
                active: page.started && hyprcraft.available
                sourceComponent: WebEngineView {
                    profile: hyprcraftProfile
                    url: hyprcraft.url
                    backgroundColor: "#020617"
                    settings.javascriptCanAccessClipboard: true
                    settings.javascriptCanPaste: true
                    onPermissionRequested: permission => {
                        // HyprFIGZ copies configs to the clipboard; nothing else.
                        if (permission.permissionType === WebEnginePermission.PermissionType.ClipboardReadWrite)
                            permission.grant();
                        else
                            permission.deny();
                    }
                    onLoadingChanged: info => {
                        if (info.status === WebEngineView.LoadFailedStatus) {
                            page.loadError = "HyprFIGZ didn't load: " + info.errorString + " (" + info.url + ")";
                            console.warn(page.loadError);
                        } else if (info.status === WebEngineView.LoadSucceededStatus) {
                            page.loadError = "";
                            console.info("HyprFIGZ loaded from " + hyprcraft.appDir);
                        }
                    }
                    onNewWindowRequested: request => Qt.openUrlExternally(request.requestedUrl)
                    onNavigationRequested: request => {
                        // Links out of the app open in the browser, not over it.
                        if (request.url.toString().indexOf("hyprcraft://") !== 0 && request.isMainFrame) {
                            request.reject();
                            Qt.openUrlExternally(request.url);
                        }
                    }
                }
            }
            BusyIndicator {
                anchors.centerIn: parent
                running: web.status === Loader.Loading || (web.item && web.item.loading)
                visible: running
            }
        }
    }
}
