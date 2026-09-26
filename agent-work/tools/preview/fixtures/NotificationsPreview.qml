import QtQuick
import Quickshell
import qs.Commons

// Stand-in for phone-notifications' Service.qml: just the model and calls
// Banners.qml uses, with three notifications in it. Rendered from a copy of the
// built plugin with this file beside Banners.qml (see ../README.md).
Item {
  id: svc

  readonly property string icons: Quickshell.env("OMARCHY_PATH") + "/applications/icons/"
  property string barPosition: "top"
  property int barClearance: Style.bar.sizeHorizontal + Style.gapsOut
  property alias popupModel: rows

  ListModel { id: rows }

  function durationFor(urgency, expireTimeout) { return urgency === 2 ? 0 : 8000 }
  function dismissPopup(index) { console.log("DISMISS " + index) }
  function expirePopup(index) { console.log("EXPIRE " + index) }
  function invokePopupDefault(index) { console.log("INVOKE " + index) }

  Component.onCompleted: {
    var now = Date.now()
    rows.append({ app: "Messages", appIcon: "", image: icons + "Google Messages.png", summary: "Anna",
      body: "Are we still on for lunch tomorrow? I found a place near the station.",
      glyph: "", urgency: 1, expireTimeout: 0, timestamp: now })
    rows.append({ app: "WhatsApp", appIcon: "", image: icons + "WhatsApp.png", summary: "Family",
      body: "Dad: photos from the weekend are up", glyph: "", urgency: 1, expireTimeout: 0,
      timestamp: now - 5 * 60000 })
    rows.append({ app: "Battery", appIcon: "", image: "", summary: "Battery low", body: "10% remaining",
      glyph: "", urgency: 2, expireTimeout: 0, timestamp: now - 2 * 3600000 })
  }

  Banners { notifications: svc }
}
