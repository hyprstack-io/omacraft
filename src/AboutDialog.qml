import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// About Us. Credits and licences are THIRD-PARTY-NOTICES.md and LICENSE from the
// source tree, built in, so what's shown here is what ships and can't fall behind.
Rectangle {
    id: about
    property string tab: "about"
    signal closed()

    readonly property string credits: {
        const cut = aboutNotices.indexOf("## Licence texts");
        return cut > 0 ? aboutNotices.slice(0, cut) : aboutNotices;
    }
    readonly property string licences: {
        const cut = aboutNotices.indexOf("## Licence texts");
        return "## OmaCraft\n\n```\n" + aboutLicense + "\n```\n\n" + (cut > 0 ? aboutNotices.slice(cut) : "");
    }

    // Only web links leave the app; the notices' links to files in the repo don't.
    function openLink(link) {
        if (/^https:\/\//.test(link))
            Qt.openUrlExternally(link);
    }

    anchors.fill: parent
    color: "#cc000000"
    z: 60

    MouseArea { anchors.fill: parent; onClicked: about.closed() }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(820, parent.width - 48)
        height: Math.min(640, parent.height - 48)
        radius: 12
        color: theme.raised
        border.color: theme.borderStrong
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Label { text: "About Us"; color: theme.text; font.pixelSize: 17; font.weight: Font.DemiBold }
                Item { Layout.fillWidth: true }
                Segmented {
                    objectName: "aboutTabs"
                    model: [{ id: "about", name: "OmaCraft" }, { id: "credits", name: "Credits" }, { id: "licences", name: "Licences" }]
                    current: about.tab
                    onPicked: id => about.tab = id
                }
                Button { text: "Close"; flat: true; focusPolicy: Qt.NoFocus; onClicked: about.closed() }
                KeyCap { text: "Esc" }
            }

            // --- who and what ---
            ColumnLayout {
                visible: about.tab === "about"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                Item { Layout.fillHeight: true }
                AppLogo { size: 104; Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: 8 }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "OmaCraft"
                    color: theme.text
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Version " + Qt.application.version
                    color: theme.textMuted
                    font.family: "monospace"
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 6
                    text: "One home for your Omarchy plugins."
                    color: theme.textSoft
                }
                Label {
                    objectName: "aboutSite"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10
                    text: "HyprStack.io"
                    color: theme.accent
                    font.pixelSize: 16
                    font.underline: siteHover.hovered
                    font.weight: Font.DemiBold
                    HoverHandler { id: siteHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: about.openLink("https://hyprstack.io") }
                }
                Label {
                    objectName: "aboutCopyright"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10
                    text: "Copyright © 2026 skll"
                    color: theme.textSoft
                }
                Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: 90
                    Layout.rightMargin: 90
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "OmaCraft and its plugins are free software under the MIT licence; Dotfile Generator states Apache-2.0. "
                        + "It stands on other people's work: see Credits for every author, and Licences for the full texts, including the GPL-3.0 projects we credit."
                    color: theme.textMuted
                    font.pixelSize: 12
                }
                Item { Layout.fillHeight: true }
            }

            // --- the notices, as they ship ---
            ScrollView {
                id: reader
                visible: about.tab !== "about"
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true

                Text {
                    objectName: "aboutText"
                    width: reader.availableWidth - 12
                    text: about.tab === "licences" ? about.licences : about.credits
                    textFormat: Text.MarkdownText
                    wrapMode: Text.WordWrap
                    color: theme.textSoft
                    font.pixelSize: 12
                    onLinkActivated: link => about.openLink(link)
                    HoverHandler { cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor }
                }
            }
        }
    }
}
