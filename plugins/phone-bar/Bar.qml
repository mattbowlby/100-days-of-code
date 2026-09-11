// `component PhoneBarPanel` below reads root.position and root.barSize, and the
// Variants delegate instantiates it. Without this pragma those outer-id reads
// are resolved against the delegate's context instead of being bound to this
// component, which is exactly the capture qmllint flags. Upstream's shell has no
// pragma anywhere and relies on the legacy unbound behaviour, so this line is a
// deliberate addition rather than an oversight -- do not tidy it away.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.Commons

// Phone status bar. Replaces omarchy.bar when shell.json sets bar.id to
// omarchy.phone.bar; the host falls back to the desktop bar on its own if this
// fails to load.
Item {
  id: root

  // Injected by the host after construction -- shell.qml's configureBar() does
  // duck-typed assignment in the bar Loader's onLoaded. None of these can be
  // `required`: the host builds a plugin bar from a URL and only then assigns,
  // so a required property would never be satisfied and the component would
  // fail to instantiate. Upstream's own Bar.qml can use `required` because the
  // default bar is built inline from a Component with its bindings in place.
  property string omarchyPath: ""
  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property var barConfig: null

  readonly property string position: barConfig && barConfig.position ? String(barConfig.position) : "top"

  // The theme's own bar height, not a touch-target height. A status bar is not
  // a tap target -- Android's sits around 24dp and this token is in the same
  // range -- and making it tappable would demand ~48px, which is 6% of a
  // 780px-tall panel spent on chrome. Panels open on an edge swipe instead,
  // which is the gesture a thumb makes anyway.
  readonly property int barSize: Style.bar.sizeHorizontal

  SystemClock {
    id: clock

    // Minutes, not Seconds. The bar renders HH:mm, so a per-second tick would
    // wake the GPU sixty times more often to draw an identical frame -- which
    // on a phone is battery spent on nothing.
    precision: SystemClock.Minutes
  }

  readonly property var batteryDevice: UPower.displayDevice
  readonly property bool batteryPresent: !!(batteryDevice && batteryDevice.isPresent)
  readonly property int batteryPercent: batteryPresent ? Math.round(batteryDevice.percentage * 100) : 0
  readonly property bool charging: batteryPresent && batteryDevice.state === UPowerDeviceState.Charging

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PhoneBarPanel {
        required property var modelData

        screen: modelData
      }
    }
  }

  component PhoneBarPanel: PanelWindow {
    id: barWindow

    anchors {
      top: root.position !== "bottom"
      bottom: root.position === "bottom"
      left: true
      right: true
    }

    implicitHeight: root.barSize
    color: Color.bar.background
    surfaceFormat.opaque: false

    // Its own namespace, so a layer rule can target the phone bar without also
    // catching the desktop one in a session that has both installed.
    WlrLayershell.namespace: "omarchy-phone-bar"
    WlrLayershell.layer: WlrLayer.Top

    Text {
      id: clockLabel

      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.lg
      anchors.verticalCenter: parent.verticalCenter

      text: Qt.formatDateTime(clock.date, "HH:mm")
      color: Color.bar.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }

    Text {
      id: batteryLabel

      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.lg
      anchors.verticalCenter: parent.verticalCenter

      visible: root.batteryPresent
      text: (root.charging ? "+" : "") + root.batteryPercent + "%"

      // Low and not charging is the one state the bar should raise its voice
      // for; Color.bar.active is the theme's own attention colour.
      color: !root.charging && root.batteryPercent <= 15 ? Color.bar.active : Color.bar.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }
}
