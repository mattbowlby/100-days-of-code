pragma Singleton
import QtQuick
// No windows, and none active, in the preview.
QtObject { property var activeToplevel: null; property var toplevels: ({ values: [] }) }
