import QtQuick

// One cursor from a theme, as cursorIcons.cursorSamples hands it over: an
// XCursor drawn frame by frame at its own timing (a spinning wait cursor
// spins), or a Hyprcursor's picture.
Item {
    id: sprite

    property var sample: null
    property bool playing: true
    property int frame: 0
    readonly property int frames: sample && sample.delays ? sample.delays.length : 1

    implicitWidth: 32
    implicitHeight: 32

    onSampleChanged: frame = 0

    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        // Frames come from the provider's cache once seen, so they swap
        // without a blank in between.
        asynchronous: false
        cache: true
        source: !sprite.sample ? ""
              : sprite.sample.file ? sprite.sample.file
              : "image://cursor/" + (sprite.frame % sprite.frames) + "/" + sprite.sample.nominal + "/" + sprite.sample.hex
    }

    Timer {
        running: sprite.playing && sprite.visible && sprite.frames > 1
        repeat: true
        interval: sprite.sample && sprite.sample.delays ? Math.max(16, sprite.sample.delays[sprite.frame % sprite.frames]) : 50
        onTriggered: sprite.frame = (sprite.frame + 1) % sprite.frames
    }
}
