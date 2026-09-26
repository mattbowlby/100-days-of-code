pragma Singleton
import QtQuick
import Quickshell
// TOPLEVELS set in the environment puts one window on the focused workspace.
QtObject { property var focusedWorkspace: ({ id: 1, toplevels: { values: (Quickshell.env("TOPLEVELS") ? [1] : []) } }) }
