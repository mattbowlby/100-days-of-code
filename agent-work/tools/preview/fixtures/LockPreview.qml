import QtQuick
import Quickshell
import Quickshell.Wayland

// Stand-in for phone-lock's session-lock surface: LockView on a full-screen
// panel, fed what the lock service would feed it. Rendered from a copy of the
// built plugin with this file beside LockView.qml (see ../README.md); drive it
// with --actions, e.g. 'plugins[0].view.showPasscode()'.
PanelWindow {
  anchors { top: true; bottom: true; left: true; right: true }
  color: "black"
  WlrLayershell.namespace: "omarchy-lock"
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Ignore

  property alias view: view

  LockView {
    id: view

    anchors.fill: parent
    // The harness's wallpaper, as a PNG it has written for this.
    backgroundPath: Quickshell.env("PREVIEW_WALLPAPER")
    inputEnabled: true
    onPasswordTextEdited: function(password) { view.passwordText = password }
    onSubmitPassword: function(password) { console.log("SUBMIT (" + password.length + " chars)") }
    onClearFailureRequested: view.failureMessage = ""
  }
}
