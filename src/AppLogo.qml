import QtQuick

// OmaCraft's mark on the theme's accent. The logo comes light or dark, whichever
// reads on this accent, so it needs no shader and looks right in any theme.
Rectangle {
    id: logo
    property int size: 32
    width: size
    height: size
    radius: Math.round(size * 0.28)
    color: theme.accent

    Image {
        anchors.centerIn: parent
        width: Math.round(logo.size * 0.76)
        height: width
        source: Qt.color(theme.accentForeground).hslLightness > 0.5 ? "qrc:/logo-light.png" : "qrc:/logo-dark.png"
        sourceSize: Qt.size(256, 256)
        fillMode: Image.PreserveAspectFit
        mipmap: true
        smooth: true
    }
}
