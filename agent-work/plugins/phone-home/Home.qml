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

  // The surface's logical size, written by the panel below once it is mapped.
  // The defaults are the reference phone, so nothing divides by zero before.
  property real surfaceWidth: 360
  property real surfaceHeight: 780

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
  // Each app is {appId, label, icon}. The dock takes its apps out of the grid,
  // as on iOS: an app lives in one place on the home screen, never two.
  property var dockApps: []
  property var gridApps: []

  // Desktop ids for the dock, one per line; blank lines and # comments ignored.
  // With no file, the dock is Omarchy's own defaults, whichever are installed.
  readonly property string dockFile: Quickshell.env("HOME") + "/.config/omarchy-phone/dock"
  property var dockIds: []
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
      var app = { appId: appId, label: appLibrary.entryName(entry), icon: appLibrary.iconSource(entry.icon) }
      all.push(app)
      byKey[key] = app
    }

    var wanted = dockIds.length > 0 ? dockIds : defaultDockIds
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

  onAppLibraryChanged: rebuild()
  onDockIdsChanged: rebuild()

  // Installs and removals while the phone is on; the library says so itself.
  Connections {
    target: root.appLibrary
    function onAppsChanged() { root.rebuild() }
  }

  FileView {
    path: root.dockFile
    watchChanges: true
    printErrors: false
    onLoaded: root.dockIds = root.parseDock(text())
    onLoadFailed: root.dockIds = []
    // text() is stale inside the change signal; reload and let onLoaded parse,
    // the same route Commons/Color.qml takes for its watched file.
    onFileChanged: reload()
  }
}
