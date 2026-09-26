pragma Singleton
import QtQuick
// No desktop entries: names fall back to window titles in the preview.
QtObject {
  property var applications: ({ values: [] })
  function heuristicLookup(name) { return null }
}
