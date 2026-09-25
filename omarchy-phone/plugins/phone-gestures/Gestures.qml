pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Screen-edge gestures. A "service" kind, so the host instantiates it once and
// keeps it alive for the session -- the edge strips must exist whether or not
// anything they open is loaded.
//
// Bottom edge, swipe up   -> app grid
// Top edge, swipe down    -> quick settings
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
  readonly property string quickSettingsId: "dev.omarchyphone.quicksettings"

  // The strip is deliberately thin. It sits above application windows and
  // swallows anything that lands in it, so every pixel of height is a pixel an
  // app cannot be touched on. Android spends roughly this much on the same
  // gesture, and it is enough to catch a thumb starting at the bezel.
  readonly property int edgeSize: Style.space(16)

  // How far up the finger has to travel before this counts as a swipe rather
  // than a stray touch near the bezel.
  readonly property int triggerDistance: Style.space(40)

  function summon(pluginId) {
    if (shell && typeof shell.toggle === "function") shell.toggle(pluginId, "")
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      EdgeSwipe {
        required property var modelData

        screen: modelData
        edge: "bottom"
        onTriggered: root.summon(root.appGridId)
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      EdgeSwipe {
        required property var modelData

        screen: modelData
        edge: "top"
        onTriggered: root.summon(root.quickSettingsId)
      }
    }
  }

  component EdgeSwipe: PanelWindow {
    id: edgeWindow

    // "top" or "bottom". The swipe runs away from the edge it starts on, so
    // this is the only difference between the two strips.
    required property string edge

    signal triggered()

    anchors {
      top: edgeWindow.edge === "top"
      bottom: edgeWindow.edge === "bottom"
      left: true
      right: true
    }

    // The top strip sits below the status bar rather than over it. The bar's
    // widgets are tappable -- they open Omarchy's panels -- and a gesture
    // surface on top of them would eat every one of those taps.
    // The linter cannot resolve PanelWindow's grouped `margins`; upstream's own
    // plugins/bar/Bar.qml raises the same pair. Suppressed for these lines only.
    // qmllint disable unqualified unresolved-type
    margins {
      top: edgeWindow.edge === "top" ? Style.bar.sizeHorizontal : 0
    }
    // qmllint enable unqualified unresolved-type

    implicitHeight: root.edgeSize
    color: "transparent"

    WlrLayershell.namespace: "omarchy-phone-edge-" + edgeWindow.edge

    // Top, not Overlay: the app grid, quick settings and any future lock
    // surface must be able to sit above this rather than have input eaten.
    WlrLayershell.layer: WlrLayer.Top

    // Never reserve space -- this is an input region, not furniture.
    exclusionMode: ExclusionMode.Ignore

    // Nothing here should ever take the keyboard.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
      anchors.fill: parent

      // Once the press is taken, keep the grab: the finger leaves this strip
      // almost immediately, and the move events have to keep arriving here for
      // the gesture to be measurable at all.
      preventStealing: true

      // -1 means "no gesture in progress", which is distinct from a press that
      // started at y = 0.
      property real pressY: -1

      onPressed: function(mouse) { pressY = mouse.y }

      onPositionChanged: function(mouse) {
        if (pressY < 0) return

        // Away from the edge: up from the bottom, down from the top.
        var travelled = edgeWindow.edge === "bottom" ? pressY - mouse.y : mouse.y - pressY
        if (travelled < root.triggerDistance) return

        // Fire during the drag rather than on release. Waiting for the finger
        // to lift puts a visible pause between the gesture and the response,
        // which reads as the phone being slow rather than deliberate.
        pressY = -1
        edgeWindow.triggered()
      }

      onReleased: pressY = -1
      onCanceled: pressY = -1
    }
  }
}
