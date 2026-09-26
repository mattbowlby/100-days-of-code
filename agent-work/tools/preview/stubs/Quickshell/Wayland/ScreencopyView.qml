import QtQuick
// A window still is not available offscreen: a neutral stand-in panel.
Rectangle {
  property var captureSource
  property bool live
  property bool paintCursor
  color: "#3b3f55"
  Text { anchors.centerIn: parent; text: "window"; color: "#8890b0"; font.pixelSize: 14 }
}
