import QtQuick
// Never runs anything: a start is logged as an EXEC line, stdin writes are
// logged as their length only (they may be secrets), and the process "exits"
// on the next turn of the event loop so queues built on onExited keep moving.
QtObject {
  id: proc
  property var command
  property bool running: false
  property var stdout
  property var stderr
  property var environment
  property bool stdinEnabled: false
  signal started()
  signal exited(int exitCode, int exitStatus)
  function write(data) { console.log("EXEC stdin " + String(data).length + " chars") }
  function finish() { running = false; exited(0, 0) }
  onRunningChanged: {
    if (!running) return
    console.log("EXEC " + JSON.stringify(command))
    started()
    Qt.callLater(finish)
  }
}
