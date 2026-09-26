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
// dev.omarchyphone.bar; the host falls back to the desktop bar on its own if
// this fails to load.
//
// It also owns the screen-edge gestures and the control centre, because the
// host lets only a bar open other plugins' surfaces (see "gestures" below).
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

  // ------------------------------------------------- bar-widget panel protocol
  //
  // Upstream's panels -- audio, network, bluetooth, power, monitor -- are not
  // summoned through the panel loader. shell.summon() sees a plugin whose kinds
  // are bar-widget with no loader kind and routes it to shell.bar instead, so
  // without these four functions `omarchy-shell shell toggle omarchy.audio`
  // answers "no live bar widget for" and every one of those panels is
  // unreachable from a phone bar. Implementing them is what makes the whole
  // upstream panel set work here.
  property var widgetItems: ({})

  function registerWidgetItem(widgetId, item) {
    var id = String(widgetId || "")
    if (!id) return
    var next = ({})
    for (var key in widgetItems) next[key] = widgetItems[key]
    next[id] = item
    widgetItems = next
  }

  function unregisterWidgetItem(widgetId) {
    var id = String(widgetId || "")
    if (!widgetItems[id]) return
    var next = ({})
    for (var key in widgetItems) if (key !== id) next[key] = widgetItems[key]
    widgetItems = next
  }

  function findPanelWidget(pluginId) {
    return widgetItems[String(pluginId || "")] || null
  }

  function summonBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.open !== "function") return false
    item.open()
    return true
  }

  function hideBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.close !== "function") return false
    item.close()
    return true
  }

  function isBarWidgetOpen(pluginId) {
    var item = findPanelWidget(pluginId)
    return !!item && item.opened === true
  }

  // The phone bar has one run of widgets, so the section name is accepted and
  // ignored rather than pretended into left/center/right.
  function panelWidgetIdAt(section, index) {
    var position = Math.round(Number(index)) - 1
    var entry = statusEntries[position]
    return entry && entry.id ? String(entry.id) : ""
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

  // --------------------------------------------------------------- gestures
  //
  // The screen edges, moved here from the old phone-gestures service. They had
  // to move: the host now lets a plugin summon, hide or toggle only itself --
  // unless it is the bar (shell.qml barPluginMayControl) -- so a separate
  // gesture service could no longer open anything but its own id.
  //
  // Bottom edge, swipe up   -> home
  // Top edge, swipe down    -> control centre
  readonly property string homeId: "dev.omarchyphone.home"

  // Thin on purpose: the strips sit above application windows and swallow any
  // touch that lands in them, so every pixel of height is one an app loses.
  readonly property int edgeSize: Style.space(16)
  readonly property int triggerDistance: Style.space(40)

  // Home is the empty workspace the home screen shows through (see
  // phone-home/Home.qml), so going home is going to one. `hyprctl dispatch` no
  // longer takes the old "workspace empty" form -- its arguments are Lua now --
  // hence eval (NOTES.md).
  //
  // Only from a workspace that has windows. "empty" resolves to the lowest
  // empty workspace anywhere, not the current one, so swiping up while already
  // home on workspace 5 would otherwise slide over to an emptier-numbered 3.
  //
  // Summoning the home plugin as well sends its pager to the first page. That
  // happens on every swipe, from an app too, which is one step short of iOS
  // (it returns to the page you left); the shell cannot tell from here which
  // case it is in, because the Lua above runs out of process.
  readonly property string goHomeLua:
    "local w = hl.get_active_workspace(); "
    + "if w and w.windows > 0 then hl.dispatch(hl.dsp.focus({ workspace = \"empty\" })) end"

  function goHome() {
    Quickshell.execDetached(["hyprctl", "eval", goHomeLua])
    if (shell && typeof shell.summon === "function") shell.summon(homeId, "")
  }

  component EdgeSwipe: PanelWindow {
    id: edgeWindow

    // "top" or "bottom"; the swipe runs away from the edge it starts on.
    required property string edge

    signal triggered()

    anchors {
      top: edgeWindow.edge === "top"
      bottom: edgeWindow.edge === "bottom"
      left: true
      right: true
    }

    // A strip on the bar's edge starts where the bar ends, not over it: the
    // bar's status widgets open Omarchy's panels on a tap, and a gesture
    // surface above them would eat every one of those taps.
    // qmllint disable unqualified unresolved-type
    margins {
      top: edgeWindow.edge === "top" && root.position !== "bottom" ? root.barSize : 0
      bottom: edgeWindow.edge === "bottom" && root.position === "bottom" ? root.barSize : 0
    }
    // qmllint enable unqualified unresolved-type

    implicitHeight: root.edgeSize
    color: "transparent"

    // Out of the way while the control centre is up: it is on the same layer,
    // and a strip over its card would eat taps meant for the tiles.
    visible: !root.controlOpen

    WlrLayershell.namespace: "omarchy-phone-edge-" + edgeWindow.edge
    // Overlay, not Top. Hyprland discards touches on Top-layer surfaces while a
    // window is exclusively fullscreen and hands them to the window instead, so
    // on Top a fullscreen video could never be swiped out of. A session lock
    // draws above every layer regardless.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      anchors.fill: parent

      // The compositor keeps sending a touch's moves to the surface it went
      // down on, so the drag stays measurable after the finger leaves this
      // strip. preventStealing is for the other half: nothing in the item tree
      // may take the drag over once it has started here.
      preventStealing: true

      // -1 is "no gesture", distinct from a press that started at y = 0.
      property real pressY: -1

      onPressed: function(mouse) { pressY = mouse.y }

      onPositionChanged: function(mouse) {
        if (pressY < 0) return
        var travelled = edgeWindow.edge === "bottom" ? pressY - mouse.y : mouse.y - pressY
        if (travelled < root.triggerDistance) return

        // Fire during the drag, not on release: waiting for the lift reads as
        // the phone being slow rather than deliberate.
        pressY = -1
        edgeWindow.triggered()
      }

      onReleased: pressY = -1
      onCanceled: pressY = -1
    }
  }

  // ---------------------------------------------------------- control centre
  //
  // Swipe down from the top. Replaces the old phone-quicksettings overlay, which
  // the host's per-plugin scoping left unable to open anything. Living in the
  // bar it can: Omarchy's own panels are bar widgets, and this is the bar.
  //
  // Every tile is the home screen's tile -- the same rounded square, the same
  // frosted plate -- so the phone has one shape for everything tappable.
  property bool controlOpen: false

  // Panels open the upstream panel through summonBarWidget(), which needs the
  // widget loaded in the status row, so a tile shows only while its widget is.
  // Actions run a command; every one is an existing Omarchy tool.
  //
  // Glyphs are Nerd Font codepoints on the default family, written as escapes
  // and checked by rendering them (NOTES.md): f1eb wifi, f293 bluetooth, f028
  // volume, f240 battery, f108 display, f023 lock, f030 camera, f186 moon,
  // f0f4 cup.
  readonly property var controlTiles: [
    { panel: "omarchy.network",   icon: "", label: "Network" },
    { panel: "omarchy.bluetooth", icon: "", label: "Bluetooth" },
    { panel: "omarchy.audio",     icon: "", label: "Sound" },
    { panel: "omarchy.power",     icon: "", label: "Battery" },
    { panel: "omarchy.monitor",   icon: "", label: "Display" },
    { command: ["omarchy-system-lock"],                               icon: "", label: "Lock" },
    { command: ["omarchy-capture-screenshot", "fullscreen", "save"],  icon: "", label: "Screenshot" },
    { command: ["omarchy-toggle-nightlight"],                         icon: "", label: "Night Light" },
    { command: ["omarchy-toggle-idle"],                               icon: "", label: "Stay Awake" }
  ]

  readonly property var visibleControlTiles: {
    var out = []
    for (var i = 0; i < controlTiles.length; i++) {
      var tile = controlTiles[i]
      if (tile.panel && !widgetItems[tile.panel]) continue
      out.push(tile)
    }
    return out
  }

  function openControl() {
    // One sheet at a time: a panel the sheet opened earlier closes first.
    if (activePopout) requestPopout(null)
    controlOpen = true
  }

  function closeControl() {
    controlOpen = false
  }

  // The sheet goes first, then the tile's work: a panel wants the room, and a
  // screenshot taken with the sheet still up is a screenshot of the sheet.
  property var pendingTile: null

  function activateTile(tile) {
    closeControl()
    pendingTile = tile
    tileDelay.restart()
  }

  Timer {
    id: tileDelay

    // Long enough for the layer to unmap before a capture reads the screen.
    interval: 250
    onTriggered: {
      var tile = root.pendingTile
      root.pendingTile = null
      if (!tile) return
      if (tile.panel) root.summonBarWidget(tile.panel)
      else if (tile.command) Quickshell.execDetached(tile.command)
    }
  }

  // The control centre sheet: a frosted card of tiles dropping from the top,
  // over everything, dismissed by a tap anywhere off it.
  component ControlCentre: PanelWindow {
    id: sheetWindow

    // Tiles use the home screen's proportions: four across, a rounded square
    // at 0.27 of its side, glyph at 0.45. The size is worked out from the width
    // so four always fit, whatever the theme's font scale does.
    readonly property int pad: Style.spacing.xxl
    readonly property int gap: Style.spacing.lg
    readonly property int tileSize: Math.min(Style.space(64),
      Math.floor((Math.min(width, Style.space(420)) - pad * 2 - gap * 3) / 4))

    visible: root.controlOpen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.namespace: "omarchy-phone-control"
    // Overlay: above the edge strips and any Top-layer panel it replaces.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Off the card is "tapped away" -- the only dismissal a phone has. The
    // whole screen behind the card is dimmed with the theme's background, and
    // being over the blur rule's ignore_alpha, frosted as well: what is behind
    // recedes, as it does under iOS's control centre.
    Rectangle {
      anchors.fill: parent
      color: Util.alpha(Color.background, 0.35)

      MouseArea {
        anchors.fill: parent
        onClicked: root.closeControl()
      }
    }

    Rectangle {
      id: card

      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: (root.position === "bottom" ? 0 : root.barSize) + sheetWindow.gap
      width: Math.min(parent.width - sheetWindow.gap * 2, Style.space(420))
      height: tileGrid.height + sheetWindow.pad * 2
      radius: Math.round(sheetWindow.tileSize * 0.27) + sheetWindow.pad / 2
      color: Util.alpha(Color.background, 0.45)
      border.width: Math.max(1, Style.space(1))
      border.color: Util.alpha(Color.foreground, 0.16)

      // Taps on the card's own background are not taps away.
      MouseArea { anchors.fill: parent }

      Grid {
        id: tileGrid

        anchors.centerIn: parent
        columns: 4
        columnSpacing: sheetWindow.gap
        rowSpacing: sheetWindow.gap

        Repeater {
          model: root.visibleControlTiles

          delegate: Item {
            id: controlTile

            required property var modelData

            width: sheetWindow.tileSize
            height: sheetWindow.tileSize + Style.spacing.xs + tileLabel.implicitHeight

            Rectangle {
              id: controlPlate

              width: sheetWindow.tileSize
              height: sheetWindow.tileSize
              radius: Math.round(sheetWindow.tileSize * 0.27)
              color: Util.alpha(Color.background, 0.32)
              border.width: Math.max(1, Style.space(1))
              border.color: Util.alpha(Color.foreground, 0.22)
              scale: controlTap.pressed ? 0.92 : 1
              Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

              Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Util.alpha(Color.foreground, controlTap.pressed ? 0.2 : 0.08)
              }

              Text {
                anchors.centerIn: parent
                text: controlTile.modelData.icon
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Math.round(sheetWindow.tileSize * 0.45)
              }
            }

            Text {
              id: tileLabel

              anchors.top: controlPlate.bottom
              anchors.topMargin: Style.spacing.xs
              width: parent.width
              text: controlTile.modelData.label
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              maximumLineCount: 1
            }

            TapHandler {
              id: controlTap
              onTapped: root.activateTile(controlTile.modelData)
            }
          }
        }
      }
    }
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

  Variants {
    model: Quickshell.screens

    delegate: Component {
      EdgeSwipe {
        required property var modelData

        screen: modelData
        edge: "bottom"
        onTriggered: root.goHome()
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
        onTriggered: root.openControl()
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      ControlCentre {
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

    // See-through, as the rest of the phone's shell is: the theme's bar colour
    // over a Hyprland blur (config/hypr/looknfeel.lua), so the wallpaper and
    // the home screen show through frosted rather than behind a solid strip.
    // Halved, not replaced: Util.alpha() would overwrite a theme's own
    // bar.background-alpha, and a theme that asks for a clear bar should get
    // one.
    color: Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b,
      Color.bar.background.a * 0.5)
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
            root.registerWidgetItem(widgetId, item)
          }

          Component.onDestruction: root.unregisterWidgetItem(widgetId)
        }
      }
    }
  }
}
