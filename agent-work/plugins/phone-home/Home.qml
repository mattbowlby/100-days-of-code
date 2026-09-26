// Inline components read root's metrics; see plugins/phone-bar/Bar.qml for why
// this pragma is here when upstream's shell carries none.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// The home screen: pages of apps and a dock, in the manner of iOS.
//
// It lives on the Bottom layer, under every window, and never closes. An empty
// workspace therefore *is* the home screen, and "going home" is moving to an
// empty workspace rather than summoning a surface over the app in use -- which
// is also what keeps one-window-per-workspace (NOTES.md) intact: launching from
// here normally opens the app on the empty workspace the home screen was
// showing. (Normally: a launch is asynchronous, so swiping away before the
// window maps puts it wherever focus went, and a single-instance app raises its
// existing window on whatever workspace that already has.)
//
// It replaces phone-appgrid. That plugin was an overlay, and the host now hands
// an app library only to plugins whose kinds include "menu", so the grid came
// up empty; this manifest declares both.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  readonly property var appLibrary: shell ? shell.appLibrary : null

  // The surface's logical size. Until the panel below is mapped it reads the
  // reference phone's, so nothing divides by zero before then.
  readonly property real surfaceWidth: panel.width > 0 ? panel.width : 360
  readonly property real surfaceHeight: panel.height > 0 ? panel.height : 780

  // Where the status bar is, from the host's scalar view of it, so the grid and
  // the dock keep clear of whichever edge it is on. Anything but "bottom" is
  // the top, because that is how phone-bar anchors itself: a portrait phone
  // has no room for a bar down one side.
  readonly property var barState: shell ? shell.bar : null
  readonly property bool barAtBottom: !!barState && barState.position === "bottom"
  readonly property int barSpace: !barState ? Style.bar.sizeHorizontal
    : (barState.barHidden ? 0 : (barState.barSize > 0 ? barState.barSize : Style.bar.sizeHorizontal))

  readonly property int columns: 4
  readonly property int dockSlots: 4
  readonly property int pagePadding: Style.spacing.xxl

  // Shortest side past which the screen is an unfolded foldable or a tablet --
  // Android's sw600dp line. There the pager shows two pages side by side, the
  // way a book opens, instead of four icons stretched across the panel. The
  // shortest side, not the width: a phone turned to landscape is 780 wide and
  // 360 tall, and two pages of one row each is worse than one page. (Fold 5's
  // inner panel is about 604 at scale 3 -- just over, as it should be.)
  readonly property int wideThreshold: 600
  readonly property bool wide: Math.min(surfaceWidth, surfaceHeight) >= wideThreshold
  readonly property real pageWidth: wide ? surfaceWidth / 2 : surfaceWidth

  // One shape for every app, everywhere this plugin draws one: a frosted
  // rounded square of this size. Nothing else in the file picks a tile size.
  // 58 is iOS's 60pt-on-375 ratio at 360 wide. It scales with the theme's font
  // and spacing, so it is capped by its column: a large base-size would
  // otherwise push four tiles past a 344px Fold cover screen.
  readonly property int tileSize: Math.min(Style.space(58),
    Math.floor((pageWidth - pagePadding * 2) / columns * 0.72))
  readonly property real tileRadius: Math.round(tileSize * 0.27)

  // App artwork is inset on the tile rather than clipped to it. Icons arrive as
  // circles, squares and bare logos; clipping a circle to a rounded square cuts
  // its edge, while insetting it keeps the outline -- the tile's -- identical.
  readonly property int glyphSize: Math.round(tileSize * 0.64)

  readonly property int labelGap: Style.spacing.sm
  readonly property int cellHeight: tileSize + labelGap + Math.ceil(labelMetrics.height) + Style.spacing.xxl

  // A caption's line is taller than its pixel size; measure it, don't assume.
  FontMetrics {
    id: labelMetrics
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }

  // ------------------------------------------------------------------ apps
  //
  // Each app is {appId, label, iconName}. The dock takes its apps out of the
  // grid, as on iOS: an app lives in one place on the home screen, never two.
  //
  // The icon is kept as a name and resolved where it is drawn, not here. The
  // library indexes icons asynchronously and publishes a finished index by
  // swapping a property, without announcing appsChanged; only a binding that
  // calls iconSource() sees that, so a URL frozen at rebuild time would stay on
  // the fallback icon until something else changed.
  property var dockApps: []
  property var gridApps: []

  // Desktop ids for the dock, one per line; blank lines and # comments ignored.
  // With no file, the dock is Omarchy's own defaults, whichever are installed;
  // a file with no ids in it is an empty dock, because that is what it says.
  // omarchy-phone-install writes a starter file holding exactly those defaults,
  // so the watch below has a file to watch from the first boot and the dock
  // is edited in place rather than conjured from nothing.
  readonly property string dockFile: Quickshell.env("HOME") + "/.config/omarchy-phone/dock"
  property var dockIds: null
  readonly property var defaultDockIds: ["chromium", "foot", "org.gnome.Nautilus", "Google Messages"]

  // Desktop ids reach this file with and without ".desktop", and hand-written
  // dock files will not match case exactly, so both sides are compared as this.
  function idKey(appId) {
    return String(appId || "").replace(/\.desktop$/i, "").toLowerCase()
  }

  function parseDock(text) {
    var out = []
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].replace(/#.*$/, "").trim()
      if (line) out.push(line)
    }
    return out
  }

  function rebuild() {
    if (!appLibrary) {
      dockApps = []
      gridApps = []
      return
    }

    var rows = appLibrary.sortedEntries("")
    var all = []
    var byKey = ({})
    for (var i = 0; i < rows.length; i++) {
      var entry = rows[i].entry
      var appId = String((entry && entry.id) || "")
      var key = idKey(appId)
      if (!key || byKey[key]) continue
      var app = { appId: appId, label: appLibrary.entryName(entry), iconName: String(entry.icon || "") }
      all.push(app)
      byKey[key] = app
    }

    var wanted = dockIds !== null ? dockIds : defaultDockIds
    var dock = []
    var docked = ({})
    for (var j = 0; j < wanted.length && dock.length < dockSlots; j++) {
      var hit = byKey[idKey(wanted[j])]
      if (!hit || docked[hit.appId]) continue
      dock.push(hit)
      docked[hit.appId] = true
    }

    dockApps = dock
    gridApps = all.filter(function(app) { return !docked[app.appId] })
  }

  // Changes arrive in bursts -- at startup the library, the dock file and three
  // appsChanged emissions from the library's own loading all land within
  // moments -- and every
  // rebuild replaces the models, so every tile is recreated and its image
  // reloaded. Deferring coalesces a burst into one rebuild.
  function scheduleRebuild() {
    Qt.callLater(rebuild)
  }

  onAppLibraryChanged: {
    // Same as upstream's menu on open: packages installed since the shell
    // started may have placed icons after the index was built.
    if (appLibrary) appLibrary.refreshIcons()
    scheduleRebuild()
  }
  onDockIdsChanged: scheduleRebuild()

  // Installs and removals while the phone is on; the library says so itself.
  Connections {
    target: root.appLibrary
    function onAppsChanged() { root.scheduleRebuild() }
  }

  FileView {
    path: root.dockFile
    watchChanges: true
    printErrors: false
    onLoaded: root.dockIds = root.parseDock(text())
    onLoadFailed: root.dockIds = null
    // text() is stale inside the change signal; reload and let onLoaded parse,
    // the same route Commons/Color.qml takes for its watched file.
    onFileChanged: reload()
  }

  // A tap that has not visibly done anything yet invites a second, and the
  // library starts a fresh process per launch with nothing to stop a repeat --
  // a double-tapped browser is two windows, and two workspaces. The menu gets
  // away without this by closing on launch; the home screen stays under the
  // finger, so it holds further launches off for a moment instead.
  property bool launching: false

  Timer {
    id: launchCooldown
    interval: 1500
    onTriggered: root.launching = false
  }

  function launch(app) {
    if (!appLibrary || !app || launching) return
    launching = true
    launchCooldown.restart()
    appLibrary.launch(app.appId, app.label)
  }

  // ------------------------------------------------------------------ tile
  //
  // The one app shape. Frosted rather than glossy: a translucent plate of the
  // theme's background, lifted by a faint wash of its foreground and edged with
  // a hairline, with Hyprland's layer blur (config/hypr/looknfeel.lua) doing the
  // see-through part underneath -- the Omarchy look, not iOS's liquid glass.
  //
  // Both washes, because themes come in both polarities. A foreground wash
  // alone is frost on a dark theme and a grey smudge on a light one, whose
  // foreground is near-black; the background plate under it is what reads as
  // frost on either, the way Omarchy's own menus are background-tinted.
  component AppTile: Item {
    id: tile

    required property var app
    property bool showLabel: true

    implicitWidth: root.tileSize
    implicitHeight: showLabel ? root.cellHeight : root.tileSize

    Rectangle {
      id: plate

      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      width: root.tileSize
      height: root.tileSize
      radius: root.tileRadius
      color: Util.alpha(Color.background, 0.32)
      border.width: Math.max(1, Style.space(1))
      border.color: Util.alpha(Color.foreground, 0.22)

      // The press answers under the thumb before the app has even started,
      // which is most of what makes a launcher feel quick.
      scale: press.pressed ? 0.92 : 1
      Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

      Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Util.alpha(Color.foreground, press.pressed ? 0.2 : 0.08)
      }

      Image {
        anchors.centerIn: parent
        width: root.glyphSize
        height: root.glyphSize
        // Qt scales sourceSize by the device pixel ratio itself.
        sourceSize.width: root.glyphSize
        sourceSize.height: root.glyphSize
        fillMode: Image.PreserveAspectFit
        source: tile.app && root.appLibrary ? root.appLibrary.iconSource(tile.app.iconName) : ""
        asynchronous: true
        smooth: true
        mipmap: true
      }
    }

    Text {
      visible: tile.showLabel
      anchors.top: plate.bottom
      anchors.topMargin: root.labelGap
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width
      text: tile.app ? tile.app.label : ""
      color: Color.foreground
      // Labels sit straight on the wallpaper, whatever it is. An outline in the
      // theme's background keeps them legible on any part of it without drawing
      // a plate behind every word; a raised shadow is one pixel on one side and
      // disappears into a busy wallpaper at caption size.
      style: Text.Outline
      styleColor: Util.alpha(Color.background, 0.55)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      maximumLineCount: 1
    }

    // The whole cell is the target, label included. A TapHandler rather than a
    // MouseArea: past the drag threshold in any direction it lets go, so a
    // swipe that starts on an icon is a swipe and never a launch -- a MouseArea
    // would still click on a vertical drag that ends inside its own cell.
    TapHandler {
      id: press
      onTapped: root.launch(tile.app)
    }
  }

  // ------------------------------------------------------------------ pages
  //
  // The pager scrolls by spread: one page on a phone, two side by side on an
  // unfolded screen. Rows are however many whole cells fit, up to six, and
  // share the height between them evenly, as iOS spaces its rows.
  readonly property int rows: Math.max(1, Math.min(6, Math.floor(pager.height / cellHeight)))
  readonly property int perPage: rows * columns
  readonly property int pageCount: Math.max(1, Math.ceil(gridApps.length / perPage))

  // A lone page on an unfolded screen is centred rather than left beside an
  // empty one; two pages or more open as a book.
  readonly property int pagesPerSpread: wide && pageCount > 1 ? 2 : 1
  readonly property int spreadCount: Math.ceil(pageCount / pagesPerSpread)

  // The bottom gesture strip is phone-bar's (see its EdgeSwipe); the dock sits
  // clear of it so a swipe up for home never starts on an icon.
  readonly property int gestureClearance: Style.space(16) + Style.spacing.lg

  function pageApps(page) {
    return gridApps.slice(page * perPage, (page + 1) * perPage)
  }

  // The first page on screen, kept across anything that rebuilds the pager's
  // model -- unfolding, rotating, an install that adds a page. The model is a
  // count, and a new count sends a ListView back to its first item.
  property int anchorPage: 0

  // True from a model reset until the page is restored. A reset lands the
  // pager on index 0 even mid-swipe, while `moving` is still true, and that
  // must not be taken for the user choosing page one.
  property bool restoring: false

  // A jump, not a scroll: the user did not ask to watch every page go past.
  function restorePage() {
    var spread = Math.max(0, Math.min(Math.floor(anchorPage / pagesPerSpread), spreadCount - 1))
    var duration = pager.highlightMoveDuration
    pager.highlightMoveDuration = 0
    pager.currentIndex = spread
    pager.highlightMoveDuration = duration
    restoring = false
  }

  function scheduleRestore() {
    restoring = true
    Qt.callLater(restorePage)
  }

  onSpreadCountChanged: scheduleRestore()
  onPagesPerSpreadChanged: scheduleRestore()

  // Asked for while already home -- a second swipe up -- the pager returns to
  // the first page, as iOS's home button does. currentIndex rather than a
  // position call, so the page dots follow.
  function open(payloadJson) {
    anchorPage = 0
    pager.currentIndex = 0
  }

  // Never closes; see the header. The host may still call this when it hides
  // plugins, and it has nothing to do.
  function close() {}

  PanelWindow {
    id: panel

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    WlrLayershell.namespace: "omarchy-phone-home"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Ignore rather than reserve: this is the backdrop windows tile over, and
    // it must neither push them aside nor be pushed by the bar. The bar's strip
    // is kept clear by the content's margins below instead.
    exclusionMode: ExclusionMode.Ignore

    ListView {
      id: pager

      anchors.top: parent.top
      anchors.topMargin: (root.barAtBottom ? 0 : root.barSpace) + Style.spacing.lg
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: dots.top

      orientation: ListView.Horizontal
      snapMode: ListView.SnapOneItem
      highlightRangeMode: ListView.StrictlyEnforceRange
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      // A beat before a tile shows its press, so a swipe that starts on an icon
      // does not flash it first. Short enough that a tap still feels instant.
      pressDelay: 80
      // Setting currentIndex -- open(), a restore -- moves the highlight, and
      // the view follows it. The default is 400px a second, three seconds back
      // across four pages; a fixed quarter second is a swipe's pace.
      highlightMoveDuration: 250
      highlightMoveVelocity: -1
      // Every spread is built and kept: a phone's worth of apps is a few pages,
      // and a spread built mid-swipe is a dropped frame under the thumb.
      cacheBuffer: width * Math.max(1, root.spreadCount - 1)
      model: root.spreadCount

      // Only a swipe moves the anchor; a model reset also changes currentIndex,
      // and that must not overwrite the page being restored.
      onCurrentIndexChanged: if (moving && !root.restoring) root.anchorPage = currentIndex * root.pagesPerSpread

      delegate: Row {
        id: spread

        required property int index

        width: pager.width
        height: pager.height
        leftPadding: (width - root.pagesPerSpread * root.pageWidth) / 2

        Repeater {
          model: root.pagesPerSpread

          delegate: Item {
            id: page

            required property int index
            readonly property int pageIndex: spread.index * root.pagesPerSpread + index

            width: root.pageWidth
            height: spread.height

            Grid {
              // The height left after whole rows, shared out: half a gap above
              // the first row, a full one between rows.
              readonly property int gap: Math.floor((parent.height - root.rows * root.cellHeight) / root.rows)

              anchors.top: parent.top
              anchors.topMargin: gap / 2
              anchors.horizontalCenter: parent.horizontalCenter
              columns: root.columns
              columnSpacing: 0
              rowSpacing: gap

              Repeater {
                model: root.pageApps(page.pageIndex)

                delegate: AppTile {
                  required property var modelData

                  app: modelData
                  width: (root.pageWidth - root.pagePadding * 2) / root.columns
                  height: root.cellHeight
                }
              }
            }
          }
        }
      }
    }

    // Where you are among the pages, drawn only when there is more than one. It
    // holds its place either way, so the rows do not jump when a second page
    // arrives.
    Row {
      id: dots

      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: dock.visible ? dock.top : parent.bottom
      anchors.bottomMargin: dock.visible ? Style.spacing.lg : dock.anchors.bottomMargin
      height: Style.space(8)
      spacing: Style.space(7)
      opacity: root.spreadCount > 1 ? 1 : 0

      Repeater {
        model: root.spreadCount

        delegate: Rectangle {
          required property int index

          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(6)
          height: width
          radius: width / 2
          color: Util.alpha(Color.foreground, index === pager.currentIndex ? 0.95 : 0.35)
        }
      }
    }

    // The dock: the same tiles, unlabelled, on one frosted shelf, clear of the
    // bottom gesture strip and of the bar when the bar is at the bottom.
    Rectangle {
      id: dock

      readonly property int inset: Style.spacing.lg + Style.spacing.xs

      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: root.gestureClearance + (root.barAtBottom ? root.barSpace : 0)
      width: Math.min(parent.width - root.pagePadding * 2,
        root.dockSlots * root.tileSize + (root.dockSlots + 1) * inset * 2)
      height: root.tileSize + inset * 2
      // Concentric with the end tiles, which sit `inset` from each edge.
      radius: root.tileRadius + inset
      visible: root.dockApps.length > 0

      color: Util.alpha(Color.background, 0.28)
      border.width: Math.max(1, Style.space(1))
      border.color: Util.alpha(Color.foreground, 0.14)

      // Two or more apps spread across the whole shelf, as iOS's do, rather
      // than huddling in the middle of it; a single app sits centred.
      Row {
        anchors.centerIn: parent
        spacing: (dock.width - dock.inset * 2 - root.dockApps.length * root.tileSize)
          / Math.max(1, root.dockApps.length - 1)

        Repeater {
          model: root.dockApps

          delegate: AppTile {
            required property var modelData

            app: modelData
            showLabel: false
          }
        }
      }
    }
  }
}
