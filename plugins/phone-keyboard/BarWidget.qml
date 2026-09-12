import QtQuick
import qs.Ui

// Bar toggle for the on-screen keyboard.
//
// The keyboard cannot raise itself -- Quickshell has no input-method protocol,
// so nothing tells the shell a text field took focus -- which means summoning
// has to be explicit. A bar widget is the cheapest explicit thing that is
// always on screen and always in the same place.
//
// Declaring `bar-widget` alongside `overlay` is safe: shell.qml's
// isBarWidgetPanelPlugin() returns false for any plugin that also carries a
// loader kind, so the overlay loader keeps ownership and
// `omarchy-shell shell toggle` still reaches Keyboard.qml rather than being
// rerouted through the bar.
BarWidget {
  id: root

  moduleName: "dev.omarchyphone.keyboard"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button

    anchors.fill: parent
    bar: root.bar

    // Font Awesome's keyboard, from the Nerd Font that `monospace` resolves to
    // here (JetBrainsMono Nerd Font covers f000-f385). Left on the bar's own
    // family deliberately -- the omarchy icon font only carries e900-e907 and
    // has no keyboard glyph.
    text: "\uf11c"

    tooltipText: "On-screen keyboard"

    onPressed: function(mouseButton) {
      if (!root.bar) return
      root.bar.run("omarchy-shell shell toggle dev.omarchyphone.keyboard")
    }
  }
}
