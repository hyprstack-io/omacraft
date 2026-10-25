import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Pick a font family from the installed ones (searchable), with a sample
// drawn in it. An empty value means "use the default".
RowLayout {
  id: picker

  property var families: []
  property string value: ""
  property string defaultLabel: "Default"
  property string sample: "Aa 12:45"

  signal picked(string family)

  spacing: 8

  SearchableDropdown {
    Layout.fillWidth: true
    showLabel: false
    placeholderText: "Search " + picker.families.length + " fonts..."
    options: [{ value: "", label: picker.defaultLabel }].concat(picker.families.map(function(f) { return { value: f, label: f } }))
    value: picker.value
    // A family typed in by hand earlier, or since uninstalled, still shows.
    triggerLabel: picker.value !== "" && picker.families.indexOf(picker.value) === -1 ? picker.value : ""
    fontFamily: Style.font.menuFamily
    onChanged: function(v) { picker.picked(v) }
  }

  Text {
    Layout.preferredWidth: 90
    horizontalAlignment: Text.AlignRight
    elide: Text.ElideRight
    text: picker.sample
    color: Commons.Color.menu.text
    font.family: picker.value !== "" ? picker.value : Style.font.family
    font.pixelSize: Style.font.body + 2
  }
}
