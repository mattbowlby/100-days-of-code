pragma Singleton
import QtQuick
import Quickshell
// TOPLEVELS set in the environment puts that many windows (default 1) in, each
// on its own workspace; the first is on the focused one. One monitor, whose
// active workspace is the focused one.
QtObject {
  id: hypr
  readonly property int count: Quickshell.env("TOPLEVELS") ? (parseInt(Quickshell.env("TOPLEVELS")) || 1) : 0
  readonly property var mockToplevels: {
    var out = []
    var titles = ["Chromium", "foot", "Files", "Messages", "Maps", "Photos"]
    for (var i = 0; i < count; i++)
      out.push({ address: (0x55aa00 + i).toString(16), title: titles[i % titles.length], workspace: { id: i + 1 }, wayland: null })
    return out
  }
  property var focusedWorkspace: ({ id: 1, hasFullscreen: false, toplevels: { values: mockToplevels.slice(0, 1) } })
  property var toplevels: ({ values: mockToplevels })
  function monitorFor(screen) { return { activeWorkspace: hypr.focusedWorkspace } }
}
