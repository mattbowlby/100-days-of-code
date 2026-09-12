// `component PhoneBarPanel` below reads root.position and root.barSize, and the
// Variants delegate instantiates it. Without this pragma those outer-id reads
// are resolved against the delegate's context instead of being bound to this
// component, which is exactly the capture qmllint flags. Upstream's shell has no
// pragma anywhere and relies on the legacy unbound behaviour, so this line is a
// deliberate addition rather than an oversight -- do not tidy it away.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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

  // Status widgets come from shell.json's bar.layout.right -- the same key the
  // desktop bar reads -- so a phone bar is configured the ordinary way and
  // Util.normalizeLayoutSection handles both "id" strings and {id, ...settings}
  // objects. The fallback is a phone default rather than upstream's, whose
  // right section carries seven widgets: more than 360 logical px has room for.
  readonly property var defaultStatusEntries: [
    { id: "dev.omarchyphone.keyboard" },
    { id: "omarchy.bluetooth" },
    { id: "omarchy.network" },
    { id: "omarchy.power" }
  ]

  readonly property var statusEntries: {
    var section = barConfig && barConfig.layout ? barConfig.layout.right : null
    var configured = Util.normalizeLayoutSection(section)
    return configured.length > 0 ? configured : defaultStatusEntries
  }

  // Everything on an entry except its id is that widget's settings, matching
  // BarModel.entrySettings.
  function entrySettings(entry) {
    if (!entry) return ({})
    var copy = ({})
    for (var key in entry) {
      if (key === "id") continue
      copy[key] = entry[key]
    }
    return copy
  }

  // ------------------------------------------------------------ bar protocol
  //
  // The surface hosted widgets read off their injected `bar`. Measured rather
  // than guessed: 15 members across plugins/panels/*/Panel.qml and Ui/*.qml.
  // Ui/BarWidget.qml and Ui/WidgetButton.qml guard every one of theirs, but
  // plugin widgets do not -- network/Panel.qml dereferences bar.foreground and
  // bar.fontFamily straight, and with a null bar that is a TypeError per
  // binding on every shell start. (Careful with `Style.bar.iconSlot` and
  // friends when re-measuring: those are Style tokens, not members of this.)
  readonly property color foreground: Color.bar.text
  readonly property color barForeground: Color.bar.text
  readonly property color background: Color.bar.background
  readonly property color urgent: Color.bar.active
  readonly property string fontFamily: Style.font.family

  // A portrait phone bar is always horizontal, whichever edge it sits on.
  readonly property bool vertical: false
  readonly property bool foregroundAnimationEnabled: false

  // bar.x is read for popup positioning and is deliberately NOT declared here:
  // this root is an Item, so it already has x, and QQuickItem.x is final --
  // shadowing it is a runtime error, not a style question.

  // One popout at a time, the same discipline upstream keeps: opening a second
  // closes the first. Worth implementing rather than stubbing -- without it two
  // panels can sit open at once, and on 360px there is not room for one.
  property var activePopout: null

  function requestPopout(owner) {
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  // Cycling left/right through neighbouring panels is a pointer affordance with
  // no phone equivalent, so it is deliberately inert rather than unimplemented.
  function switchPanelFrom(owner, direction) {}

  // Hover has no phone equivalent either -- but these must EXIST, not merely be
  // guarded against. Ui/WidgetButton.qml tests `if (root.bar)` and then calls
  // bar.showTooltip(...), so the guard asks whether a bar is set, not whether
  // it can do this. Injecting a bar without them is what turned a null-bar
  // TypeError into a not-a-function TypeError.
  function showTooltip(target, text) {}
  function hideTooltip(target) {}

  // Written by clock/Panel.qml and weather/Panel.qml, so it has to be settable.
  property bool centerHoverRevealSuppressed: false

  // Read by Ui/KeyboardPanel.qml to find what a tap should dismiss.
  property var clickTargets: []

  function targetWindow(target) {
    return target && target.QsWindow ? target.QsWindow.window : null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && targetWindow(target) === window
  }

  // Widgets launch commands through the bar rather than owning a Process each.
  function run(command) {
    if (!command) return
    Util.execDetached(command)
  }

  // The phone bar shows at most one instance of any widget id, and nothing here
  // needs to address its siblings.
  function moduleWidgets(pluginId) {
    return []
  }

  SystemClock {
    id: clock

    // Minutes, not Seconds. The bar renders HH:mm, so a per-second tick would
    // wake the GPU sixty times more often to draw an identical frame -- which
    // on a phone is battery spent on nothing.
    precision: SystemClock.Minutes
  }


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

    // Hand-rolled rather than hosting omarchy.clock, and that is a
    // requirement difference rather than duplicated work: the clock widget
    // carries a calendar popout and its stock format is "dddd HH:mm", where a
    // phone status bar wants bare HH:mm and no popout.
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

    // First-party bar widgets, hosted rather than reimplemented. shell.qml
    // registers these from plugins/panels/* regardless of which bar is active
    // (omarchy.power, omarchy.network, omarchy.bluetooth, omarchy.audio, ...),
    // so the phone gets their live data, icons and theming for nothing.
    Row {
      id: statusRow

      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.lg
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.md

      Repeater {
        model: root.statusEntries

        delegate: Loader {
          id: widgetLoader

          required property var modelData

          readonly property string widgetId: modelData && modelData.id ? String(modelData.id) : ""
          readonly property var registryEntry: widgetId && root.barWidgetRegistry
            ? root.barWidgetRegistry.widgets[widgetId]
            : null

          // A configured id with no registered widget renders nothing rather
          // than breaking the row -- a plugin can be uninstalled while its id
          // is still listed in shell.json.
          active: registryEntry !== null && registryEntry !== undefined
          sourceComponent: registryEntry ? registryEntry.component : null
          anchors.verticalCenter: parent.verticalCenter

          function injectProps() {
            var item = widgetLoader.item
            if (!item) return
            if ("bar" in item) item.bar = root
            if ("moduleName" in item) item.moduleName = widgetId
            if ("settings" in item) item.settings = root.entrySettings(modelData)
          }

          onLoaded: {
            // Injected twice, the second deferred, exactly as upstream's
            // ModuleSlot.injectProps does. A widget's bindings evaluate before
            // onLoaded runs, so during a live plugin reload they can see a null
            // bar for a frame and log a TypeError per binding -- 228 of them in
            // one observed reload. A clean start does not hit it; the deferred
            // pass is what covers the reload path.
            injectProps()
            Qt.callLater(injectProps)
          }
        }
      }
    }
  }
}
