pragma Singleton
import QtQuick
QtObject {
  property var screens: [ { name: "DSI-1", width: Number(env("PREVIEW_W")), height: Number(env("PREVIEW_H")) } ]
  property var windows: []
  property var executed: []
  function env(name) { return PreviewEnv.values[name] !== undefined ? String(PreviewEnv.values[name]) : "" }
  function execDetached(argv) { executed = executed.concat([argv]); console.log("EXEC " + JSON.stringify(argv)) }
  function iconPath(name, check) { return "" }
  function register(w) { windows = windows.concat([w]) }
}
