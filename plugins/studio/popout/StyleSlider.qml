import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A labeled slider with a live readout for the Studio popout. `released`
// fires once the drag ends, so a bar style is written once per change.
Row {
  id: styleSlider

  property QtObject bar: null
  property string label: ""
  property real value: 0
  property real maximum: 1
  property real step: 0.05
  property bool integer: false
  property string unit: "%"
  property color foreground: Commons.Color.popups.text
  property real labelWidth: Style.space(72)

  signal released(real value)

  function format(v) {
    return unit === "%" ? Math.round(v * 100) + "%" : Math.round(v) + unit
  }

  spacing: Style.space(8)

  Text {
    width: styleSlider.labelWidth
    anchors.verticalCenter: parent.verticalCenter
    text: styleSlider.label
    color: Util.alpha(styleSlider.foreground, 0.6)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }

  PanelSlider {
    id: slider
    anchors.verticalCenter: parent.verticalCenter
    width: styleSlider.width - styleSlider.labelWidth - readout.width - styleSlider.spacing * 2
    bar: styleSlider.bar
    fillColor: styleSlider.foreground
    knobColor: styleSlider.foreground
    minimum: 0
    maximum: styleSlider.maximum
    step: styleSlider.step
    integer: styleSlider.integer
    value: styleSlider.value
    onReleased: function(v) { styleSlider.released(v) }
  }

  Text {
    id: readout
    width: Style.space(44)
    anchors.verticalCenter: parent.verticalCenter
    horizontalAlignment: Text.AlignRight
    text: styleSlider.format(slider.liveValue)
    color: styleSlider.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
  }
}
