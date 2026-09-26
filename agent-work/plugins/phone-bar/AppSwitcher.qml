// Inline delegates read the switcher's ids; see Bar.qml for why this pragma is
// here when upstream's shell carries none.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons

// The app switcher: swipe up from the bottom edge and hold. Every open app as
// a card -- a still of its window under its name -- in a row to swipe
// through. Tap a card to go to that app; drag it up to close it.
//
// One window per workspace (NOTES.md) makes an app and a window the same
// thing here, and going to one is focusing its window, which takes Hyprland to
// its workspace.
PanelWindow {
  id: switcher

  // The Bar root: its bar geometry, and closeSwitcher() to put this away.
  required property var bar

  visible: bar.switcherOpen
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"

  WlrLayershell.namespace: "omarchy-phone-switcher"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore

  // Apps, not scratchpads: special workspaces have negative ids and are a
  // deliberate stack, not something to switch to.
  readonly property var apps: {
    var out = []
    var all = Hyprland.toplevels.values
    for (var i = 0; i < all.length; i++) {
      var ws = all[i].workspace
      if (ws && ws.id >= 0) out.push(all[i])
    }
    return out
  }

  // Cards keep the screen's shape, as iOS's do, a little under three quarters
  // of its width so the neighbours show at the sides.
  readonly property int cardWidth: Math.round(Math.min(width * 0.72, Style.space(420)))
  readonly property int cardHeight: height > 0 ? Math.round(cardWidth * height / width) : cardWidth
  readonly property int cardRadius: Math.round(Style.space(58) * 0.27)

  // Hyprland addresses are hex; Quickshell hands them over as bare digits, and
  // a leading 0x is tolerated in case it ever does not. Checked before they go
  // into Lua, so nothing else ever can.
  function selector(toplevel) {
    var address = toplevel ? String(toplevel.address || "").replace(/^0x/, "") : ""
    // "0" is Quickshell's placeholder before Hyprland has reported the address.
    return /^[0-9a-f]+$/.test(address) && address !== "0" ? "address:0x" + address : ""
  }

  function focusApp(toplevel) {
    var target = selector(toplevel)
    bar.closeSwitcher()
    if (!target) return
    Quickshell.execDetached(["hyprctl", "eval",
      "hl.dispatch(hl.dsp.focus({ window = \"" + target + "\" }))"])
  }

  // The app's name, as iOS labels its cards, not the window's title -- which
  // for a browser is the page and for a terminal the working directory. The
  // title stands in when no desktop entry matches the app id.
  function appName(toplevel) {
    // Read only so the binding depends on it: the entry scan finishes
    // asynchronously and reruns on installs, and a lookup made before would
    // otherwise keep the title fallback for good.
    var entries = DesktopEntries.applications.values
    var appId = toplevel && toplevel.wayland ? String(toplevel.wayland.appId || "") : ""
    var entry = appId ? DesktopEntries.heuristicLookup(appId) : null
    return entry && entry.name ? entry.name : String((toplevel && toplevel.title) || "")
  }

  // Opens on the app that was in front, as iOS's does, rather than wherever
  // the row was left last time.
  // currentIndex first, then the jump: the other way round, the index change
  // would slide the row from the old card after the jump. On the first open
  // the surface only learns its size after it is shown, so a resize while
  // open repositions too.
  function showCurrent() {
    var index = Math.max(0, apps.indexOf(Hyprland.activeToplevel))
    cards.currentIndex = index
    cards.positionViewAtIndex(index, ListView.Center)
  }

  onVisibleChanged: if (visible) showCurrent()
  onWidthChanged: if (visible) showCurrent()

  function closeApp(toplevel) {
    var target = selector(toplevel)
    if (!target) return
    Quickshell.execDetached(["hyprctl", "eval",
      "hl.dispatch(hl.dsp.window.close({ window = \"" + target + "\" }))"])
  }

  // A tap off every card goes back to where things were.
  MouseArea {
    anchors.fill: parent
    onClicked: switcher.bar.closeSwitcher()
  }

  // Behind the cards: the screen dimmed and, through the blur rule, frosted.
  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.background, 0.45)
  }

  Text {
    anchors.centerIn: parent
    visible: switcher.apps.length === 0
    text: "No open apps"
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.title
  }

  ListView {
    id: cards

    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.right: parent.right
    height: switcher.cardHeight + titleMetrics.height + Style.spacing.md

    orientation: ListView.Horizontal
    spacing: Style.spacing.xxl
    // The card in the middle of the screen is the current one, with the
    // neighbours peeking in at both sides.
    preferredHighlightBegin: (width - switcher.cardWidth) / 2
    preferredHighlightEnd: (width + switcher.cardWidth) / 2
    highlightRangeMode: ListView.StrictlyEnforceRange
    highlightMoveDuration: 0
    snapMode: ListView.SnapToItem
    model: switcher.apps

    // The row takes presses across its whole band, so a tap between cards or
    // on a title never reaches the background; it closes the switcher here.
    // A tap on a card also focuses its app, which closes it too.
    TapHandler {
      onTapped: switcher.bar.closeSwitcher()
    }

    delegate: Item {
      id: card

      required property var modelData
      required property int index

      width: switcher.cardWidth
      height: cards.height

      Text {
        id: title

        anchors.left: parent.left
        anchors.right: parent.right
        text: switcher.appName(card.modelData)
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
      }

      Rectangle {
        id: frame

        // How far the card is being dragged up (negative), kept here because
        // the handler zeroes its own translation before announcing a release.
        property real dy: 0

        y: title.height + Style.spacing.md + Math.min(0, dy)
        width: switcher.cardWidth
        height: switcher.cardHeight
        radius: switcher.cardRadius
        color: Util.alpha(Color.background, 0.8)
        border.width: Math.max(1, Style.space(1))
        border.color: Util.alpha(Color.foreground, 0.22)
        opacity: 1 - Math.min(0.6, Math.max(0, -dy) / switcher.cardHeight)

        // The window's still, with the card's rounded corners: a Rectangle's
        // clip is always square, so the corners are masked instead -- the way
        // upstream's image picker rounds its thumbnails.
        Rectangle {
          id: shotMask
          anchors.fill: shot
          radius: frame.radius
          visible: false
          layer.enabled: true
        }

        Item {
          id: shot

          anchors.fill: parent
          anchors.margins: frame.border.width
          layer.enabled: true
          layer.smooth: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: shotMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
          }

          // Captured only while the switcher is up: a still taken once would
          // be as old as the card, and the switcher lives all session.
          ScreencopyView {
            anchors.fill: parent
            captureSource: card.modelData.wayland
            live: switcher.visible
          }
        }

        TapHandler {
          onTapped: switcher.focusApp(card.modelData)
        }

        // Up and away closes the app; not far enough, and it settles back.
        // No target: the handler would otherwise move the frame itself and
        // overwrite its y binding; the distance goes through dy instead.
        DragHandler {
          id: drag

          target: null
          xAxis.enabled: false
          onTranslationChanged: if (active) frame.dy = translation.y
          onActiveChanged: {
            if (active) return
            if (-frame.dy > switcher.cardHeight * 0.3) switcher.closeApp(card.modelData)
            frame.dy = 0
          }
        }
      }
    }
  }

  FontMetrics {
    id: titleMetrics
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }
}
