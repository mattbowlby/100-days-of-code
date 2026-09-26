import QtQuick
// Synchronous read through XHR (needs QML_XHR_ALLOW_FILE_READ=1).
QtObject {
  id: fv
  property string path
  property bool watchChanges
  property bool printErrors
  property bool blockLoading
  property string _text: ""
  signal loaded()
  signal loadFailed(var error)
  signal fileChanged()
  function text() { return _text }
  function reload() { Qt.callLater(load) }
  function load() {
    if (!path) return
    var x = new XMLHttpRequest()
    try { x.open("GET", "file://" + path, false); x.send() } catch (e) { loadFailed(e); return }
    if (x.responseText && x.responseText.length > 0) { _text = x.responseText; loaded() } else loadFailed("empty")
  }
  onPathChanged: reload()
}
