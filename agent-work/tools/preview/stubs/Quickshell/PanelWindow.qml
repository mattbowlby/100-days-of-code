import QtQuick
import QtQuick.Window
Window {
  property PanelAnchors anchors: PanelAnchors {}
  property PanelMargins margins: PanelMargins {}
  property real implicitHeight: 0
  property real implicitWidth: 0
  property int exclusionMode: 0
  property int exclusiveZone: 0
  property var fakeScreen: null
  property string wlrNamespace: ""
  property int wlrLayer: 2
  property int wlrKeyboardFocus: 0
  property SurfaceFormat surfaceFormat: SurfaceFormat {}
  visible: true
  flags: Qt.FramelessWindowHint
  Component.onCompleted: Quickshell.register(this)
}
