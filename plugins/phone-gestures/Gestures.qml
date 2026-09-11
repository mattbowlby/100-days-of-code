pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Screen-edge gestures. A "service" kind, so the host instantiates it once and
// keeps it alive for the session -- the edge strips must exist whether or not
// anything they open is loaded.
//
// This exists as its own plugin rather than living inside phone-appgrid because
// the bottom edge is not the app grid's property: a phone's edge regions are a
// shared resource that several things want a piece of. Keeping one owner means
// the next gesture is a branch here, not a second surface fighting for the same
// pixels.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  readonly property string appGridId: "dev.omarchyphone.appgrid"

  // The strip is deliberately thin. It sits above application windows and
  // swallows anything that lands in it, so every pixel of height is a pixel an
  // app cannot be touched on. Android spends roughly this much on the same
  // gesture, and it is enough to catch a thumb starting at the bezel.
  readonly property int edgeSize: Style.space(16)

  // How far up the finger has to travel before this counts as a swipe rather
  // than a stray touch near the bezel.
  readonly property int triggerDistance: Style.space(40)

  function openAppGrid() {
    if (shell && typeof shell.toggle === "function") shell.toggle(root.appGridId, "")
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      BottomEdge {
        required property var modelData

        screen: modelData
      }
    }
  }

  component BottomEdge: PanelWindow {
    id: edge

    anchors { bottom: true; left: true; right: true }
    implicitHeight: root.edgeSize
    color: "transparent"

    WlrLayershell.namespace: "omarchy-phone-edge-bottom"

    // Top, not Overlay: the app grid and any future lock surface must be able
    // to sit above this rather than have their input eaten by it.
    WlrLayershell.layer: WlrLayer.Top

    // Never reserve space -- this is an input region, not furniture.
    exclusionMode: ExclusionMode.Ignore

    // Nothing here should ever take the keyboard.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
      anchors.fill: parent

      // Once the press is taken, keep the grab: the finger leaves this strip
      // almost immediately on the way up, and the move events have to keep
      // arriving here for the gesture to be measurable at all.
      preventStealing: true

      // -1 means "no gesture in progress", which is distinct from a press that
      // started at y = 0.
      property real pressY: -1

      onPressed: function(mouse) { pressY = mouse.y }

      onPositionChanged: function(mouse) {
        if (pressY < 0) return

        // Fire during the drag rather than on release. Waiting for the finger
        // to lift puts a visible pause between the gesture and the response,
        // which reads as the phone being slow rather than deliberate.
        if (pressY - mouse.y >= root.triggerDistance) {
          pressY = -1
          root.openAppGrid()
        }
      }

      onReleased: pressY = -1
      onCanceled: pressY = -1
    }
  }
}
