pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Quick settings.
//
// Deliberately not a reimplementation of anything. Omarchy already ships good
// audio, network, bluetooth, power and display panels, and the phone bar now
// implements the bar-widget panel protocol that summons them, so this sheet is
// a set of thumb-sized tiles that open the real thing. A 280px upstream panel
// is close to phone-sized already.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false

  // Glyphs are Nerd Font codepoints on the default family, checked by rendering
  // them rather than trusting a table -- see NOTES.md. The omarchy icon font
  // carries only e900-e907 and has none of these.
  //
  // Written as \\uXXXX escapes, not literal characters: a literal glyph does not
  // survive every path a file takes to disk, and the failure is silent -- the
  // string is simply empty and the tile renders its label with no icon.
  readonly property var tiles: [
    { id: "omarchy.audio",     icon: "\uf028", label: "Sound" },
    { id: "omarchy.network",   icon: "\uf1eb", label: "Network" },
    { id: "omarchy.bluetooth", icon: "\uf293", label: "Bluetooth" },
    { id: "omarchy.power",     icon: "\uf240", label: "Power" },
    { id: "omarchy.monitor",   icon: "\uf108", label: "Display" }
  ]

  readonly property int columns: 3
  readonly property int tileHeight: Style.space(84)

  function open(payloadJson) {
    opened = true
  }

  function close() {
    opened = false
  }

  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide("dev.omarchyphone.quicksettings")
  }

  // Close first, then summon. Both are layer surfaces and the panel wants the
  // room; leaving the sheet up would have it sitting on top of what it opened.
  function openPanel(pluginId) {
    dismiss()
    if (shell && typeof shell.toggle === "function") shell.toggle(pluginId, "")
  }

  PanelWindow {
    id: panel

    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.namespace: "omarchy-phone-quicksettings"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore

    // The sheet occupies the top; everything below it dismisses on a tap. That
    // is the phone equivalent of clicking off a popup, and the only one there
    // is without an Escape key.
    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    Rectangle {
      id: sheet

      anchors { top: parent.top; left: parent.left; right: parent.right }
      anchors.topMargin: Style.bar.sizeHorizontal
      height: grid.height + Style.spacing.lg * 2
      color: Color.menu.background

      // Swallows taps that land on the sheet's own background, so only the area
      // outside it counts as "tapped off".
      MouseArea {
        anchors.fill: parent
      }

      Grid {
        id: grid

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Style.spacing.lg

        columns: root.columns
        spacing: Style.spacing.md

        readonly property int tileWidth:
          (sheet.width - Style.spacing.lg * 2 - (root.columns - 1) * Style.spacing.md) / root.columns

        Repeater {
          model: root.tiles

          delegate: Rectangle {
            id: tile

            required property var modelData

            width: grid.tileWidth
            height: root.tileHeight
            radius: Style.cornerRadius
            color: press.pressed ? Color.menu.selectedBackground : Color.menu.background
            border.width: Math.max(1, Style.space(1))
            border.color: Color.menu.border

            Column {
              anchors.centerIn: parent
              spacing: Style.spacing.xs

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.modelData.icon
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.display
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.modelData.label
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            // The whole tile is the target, not the glyph.
            MouseArea {
              id: press
              anchors.fill: parent
              onClicked: root.openPanel(tile.modelData.id)
            }
          }
        }
      }
    }
  }
}
