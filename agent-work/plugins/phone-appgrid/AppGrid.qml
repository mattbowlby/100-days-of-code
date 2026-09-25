// Inline delegates read root and grid ids; see plugins/phone-bar/Bar.qml for
// why this pragma is here when upstream's shell carries none.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Full-screen app launcher. Summoned with `omarchy-shell shell toggle
// dev.omarchyphone.appgrid`; a swipe handle comes in a later chunk.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false

  readonly property var appLibrary: shell ? shell.appLibrary : null

  // Rebuilt on open rather than bound. sortedEntries() walks every desktop
  // entry and re-sorts; a binding would re-run that whenever the library
  // changes, including while the grid is closed and nothing can see it.
  property var entries: []

  // A thumb wants 48px minimum. 84 gives the icon room and still lays out four
  // columns across 360 logical px once the margins are taken.
  readonly property int cellSize: Style.space(84)
  readonly property int iconSize: Style.space(44)

  function rebuild() {
    if (!appLibrary) {
      entries = []
      return
    }

    var rows = appLibrary.sortedEntries("")
    var out = []
    for (var i = 0; i < rows.length; i++) {
      var entry = rows[i].entry
      var appId = String((entry && entry.id) || "")
      if (!appId) continue
      out.push({
        appId: appId,
        label: appLibrary.entryName(entry),
        icon: appLibrary.iconSource(entry.icon)
      })
    }
    entries = out
  }

  function open(payloadJson) {
    // Packages installed since the shell started may have placed icons after
    // the index was built; AppLibrary exposes this for exactly that case.
    if (appLibrary) appLibrary.refreshIcons()
    rebuild()
    opened = true
  }

  // The host calls close() on its own when it hides a panel; dismiss() is the
  // one to call from inside, so the host's open-state does not drift.
  function close() {
    opened = false
  }

  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide("dev.omarchyphone.appgrid")
  }

  function launch(appId, label) {
    if (appLibrary) appLibrary.launch(appId, label)
    dismiss()
  }

  PanelWindow {
    id: panel

    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }

    // Opaque, not a scrim. Color.menu.scrim is 50% alpha because it dims behind
    // a centred card; the app grid is not a modal over content, it is the home
    // screen, and at 50% the desktop reads straight through the labels.
    color: Color.background

    WlrLayershell.namespace: "omarchy-phone-appgrid"

    // Top, not Overlay, and inset by the bar's own height: the status bar stays
    // visible above the grid the way a phone's does, and keeping the surface
    // out of that strip settles it by geometry rather than by relying on
    // same-layer stacking order, which is map order and not something to lean on.
    WlrLayershell.layer: WlrLayer.Top
    // The linter cannot resolve PanelWindow's grouped `margins` property.
    // Upstream's own plugins/bar/Bar.qml raises the identical pair of warnings
    // on its margins block, and the runtime honours it -- the surface maps
    // inset to y=26. Suppressed for these lines only; both categories stay on
    // everywhere else. (A prose comment must not begin with the linter's own
    // name, or every word in it is read as a category.)
    // qmllint disable unqualified unresolved-type
    margins {
      top: Style.bar.sizeHorizontal
    }
    // qmllint enable unqualified unresolved-type

    // Never take an exclusion zone: the grid covers the screen for as long as
    // it is up, and reserving space would shove every tiled window aside.
    exclusionMode: ExclusionMode.Ignore

    // Tapping past the last icon closes the grid. On a phone this is the only
    // dismissal there is -- no Escape key, and no window chrome to click off.
    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    GridView {
      id: grid

      anchors.fill: parent
      anchors.margins: Style.spacing.lg
      cellWidth: root.cellSize
      cellHeight: root.cellSize
      model: root.entries
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      delegate: Item {
        id: cell

        required property var modelData

        width: grid.cellWidth
        height: grid.cellHeight

        Column {
          anchors.centerIn: parent
          spacing: Style.spacing.xs

          Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.iconSize
            height: root.iconSize
            sourceSize.width: root.iconSize
            sourceSize.height: root.iconSize
            source: cell.modelData.icon
            smooth: true
            asynchronous: true
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: grid.cellWidth - Style.spacing.sm * 2
            text: cell.modelData.label
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
          }
        }

        // The whole cell is the target, not just the icon -- 84px of it.
        MouseArea {
          anchors.fill: parent
          onClicked: root.launch(cell.modelData.appId, cell.modelData.label)
        }
      }
    }
  }
}
