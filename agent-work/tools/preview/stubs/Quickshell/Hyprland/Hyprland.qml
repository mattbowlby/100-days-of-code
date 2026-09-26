pragma Singleton
import QtQuick
import Quickshell
// TOPLEVELS set in the environment puts one window on the focused workspace.
// One monitor, whose active workspace is the focused one.
QtObject {
  id: hypr
  property var focusedWorkspace: ({ id: 1, hasFullscreen: false, toplevels: { values: (Quickshell.env("TOPLEVELS") ? [1] : []) } })
  function monitorFor(screen) { return { activeWorkspace: hypr.focusedWorkspace } }
}
