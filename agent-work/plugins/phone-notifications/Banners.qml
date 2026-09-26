// Inline delegates read the banners' ids; see phone-bar/Bar.qml for why this
// pragma is here when upstream's shell carries none.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "NotificationLogic.js" as NotificationLogic

// iOS-style banners, in place of the notification service's desktop toasts
// (bin/omarchy-phone-notifications-build swaps this in for them). They drop in
// at the top of the screen, centred and as wide as the phone allows, on the
// home screen's frosted plate. Tap one to open it; swipe it sideways to clear
// it. A finger resting on one holds it on screen.
//
// Everything else -- which notifications arrive, how long each stays, what a
// tap does, do-not-disturb, history -- is the service's, unchanged.
Item {
  id: banners

  // The notification service (Service.qml) whose popups these are.
  required property var notifications

  // One surface per output, as the service's own toasts have.
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: bannerWindow

      required property var modelData

      screen: modelData
      visible: banners.notifications.popupModel.count > 0

      // The service's namespace, so rules written for Omarchy's toasts --
      // and this port's blur rule -- still find it.
      WlrLayershell.namespace: "omarchy-notifications"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"

      // Full screen and fixed in size, as upstream's is, so a banner coming or
      // going never resizes the surface; touches go through everywhere but
      // the banners themselves.
      anchors { top: true; bottom: true; left: true; right: true }
      mask: Region { item: list }

      // Below a top bar, or at the top edge when the bar is elsewhere.
      readonly property var placement: NotificationLogic.popupPlacement(
        banners.notifications.barPosition, banners.notifications.barClearance, Style.gapsOut)

      ListView {
        id: list

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: bannerWindow.placement.margins.top
        // The home screen's margins and its search sheet's widest.
        width: Math.min(bannerWindow.width - Style.spacing.xxl * 2, Style.space(480))
        // As tall as the banners, up to half the screen; past that -- a
        // history replay, a burst -- they scroll.
        height: Math.min(contentHeight, Math.round(bannerWindow.height / 2))
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        spacing: Style.spacing.sm
        // Every banner stays created, scrolled out of view or not: each
        // carries its own countdown, which a delegate destroyed and made
        // again would restart. Few enough (history keeps ten) to be cheap.
        cacheBuffer: 100000

        // Newest first: the service inserts new rows at the top.
        model: banners.notifications.popupModel

        add: Transition {
          NumberAnimation { property: "y"; from: -Style.space(96); duration: 260; easing.type: Easing.OutCubic }
        }
        displaced: Transition {
          NumberAnimation { property: "y"; duration: 200; easing.type: Easing.OutCubic }
        }
        remove: Transition {
          NumberAnimation { property: "opacity"; to: 0; duration: 150 }
        }

        delegate: Banner { }
      }
    }
  }

  // A notification's icon: its own image (a photo, an avatar) first, then its
  // app's icon. `check` keeps Qt's missing-texture placeholder out when the
  // theme has no such icon.
  function iconSource(image, appIcon) {
    var value = String(image || "") || String(appIcon || "")
    if (value.length === 0) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  // The time the age labels count from, kept current while banners are up.
  property real clock: Date.now()

  Timer {
    interval: 30000
    repeat: true
    running: banners.notifications.popupModel.count > 0
    triggeredOnStart: true
    onTriggered: banners.clock = Date.now()
  }

  // "now" under a minute, then minutes, hours, days: a critical banner left
  // up, or a replayed history row, says how long ago it came.
  function age(timestamp) {
    var seconds = (banners.clock - Number(timestamp || 0)) / 1000
    if (!isFinite(seconds) || seconds < 60) return "now"
    if (seconds < 3600) return Math.floor(seconds / 60) + "m ago"
    if (seconds < 86400) return Math.floor(seconds / 3600) + "h ago"
    return Math.floor(seconds / 86400) + "d ago"
  }

  component Banner: Item {
    id: slot

    required property int index
    required property string app
    required property string appIcon
    required property string summary
    required property string body
    required property string image
    required property string glyph
    required property int urgency
    required property double expireTimeout
    required property double timestamp

    width: ListView.view ? ListView.view.width : 0
    height: card.height

    // The service's clock for this banner, run as its own toasts run it; held
    // while a finger is on the banner, as iOS holds one being read.
    readonly property real lifetime: banners.notifications.durationFor(urgency, expireTimeout)
    property real remainingLifetime: 1.0
    readonly property bool ticking: lifetime > 0 && !press.pressed && !swipe.active

    // New text from the sender deserves a full look (upstream does the same).
    onSummaryChanged: remainingLifetime = 1.0
    onBodyChanged: remainingLifetime = 1.0
    onImageChanged: remainingLifetime = 1.0

    Timer {
      interval: 50
      repeat: true
      running: slot.ticking
      onTriggered: {
        if (slot.lifetime <= 0) return
        slot.remainingLifetime -= 50.0 / slot.lifetime
        if (slot.remainingLifetime <= 0) {
          slot.remainingLifetime = 0
          banners.notifications.expirePopup(slot.index)
        }
      }
    }

    readonly property int pad: Style.spacing.md
    readonly property int iconSize: Style.space(38)
    readonly property string iconUrl: banners.iconSource(image, appIcon)
    readonly property bool hasBody: NotificationLogic.sanitizeBody(body, app, appIcon).length > 0

    Rectangle {
      id: card

      // How far the banner is being swiped (either way), kept here because
      // the handler zeroes its own translation before announcing a release.
      property real dx: 0

      x: dx
      width: slot.width
      height: Math.max(slot.iconSize, textColumn.implicitHeight) + slot.pad * 2
      // The home screen's search sheet, at banner size.
      radius: Style.space(22)
      color: Util.alpha(Color.background, 0.72)
      // Critical ones carry the theme's urgent colour on a heavier rim.
      border.width: slot.urgency === 2 ? Math.max(2, Style.space(2)) : Math.max(1, Style.space(1))
      border.color: slot.urgency === 2 ? Color.urgent : Util.alpha(Color.foreground, 0.18)
      opacity: 1 - Math.min(0.7, Math.abs(dx) / Math.max(1, width))

      Behavior on x {
        enabled: !swipe.active
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }

      // The app's icon on the home screen's tile plate, the one app shape.
      Rectangle {
        id: plate

        x: slot.pad
        anchors.verticalCenter: parent.verticalCenter
        width: slot.iconSize
        height: slot.iconSize
        radius: Math.round(slot.iconSize * 0.27)
        color: Util.alpha(Color.background, 0.32)
        border.width: Math.max(1, Style.space(1))
        border.color: Util.alpha(Color.foreground, 0.22)

        Image {
          id: icon

          anchors.centerIn: parent
          width: Math.round(slot.iconSize * 0.72)
          height: width
          source: slot.iconUrl
          sourceSize.width: width * Screen.devicePixelRatio
          sourceSize.height: height * Screen.devicePixelRatio
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
          visible: status === Image.Ready
        }

        // No icon to show: the sender's glyph if it gave one (Omarchy's own
        // toasts do), else a bell.
        Text {
          anchors.centerIn: parent
          visible: icon.status !== Image.Ready
          // Plain text: the glyph comes from the sender's hints, and rich
          // text there could load images (upstream's card does the same).
          text: slot.glyph.length > 0 ? slot.glyph : ""
          textFormat: Text.PlainText
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Math.round(slot.iconSize * 0.5)
        }
      }

      Column {
        id: textColumn

        anchors.left: plate.right
        anchors.leftMargin: slot.pad
        anchors.right: parent.right
        anchors.rightMargin: slot.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        // The app's name and the banner's age, iOS's header line.
        Item {
          width: parent.width
          height: appLabel.implicitHeight

          Text {
            id: appLabel

            anchors.left: parent.left
            anchors.right: ageLabel.left
            anchors.rightMargin: Style.spacing.sm
            text: slot.app
            textFormat: Text.PlainText
            color: Util.alpha(Color.foreground, 0.7)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          Text {
            id: ageLabel

            anchors.right: parent.right
            text: banners.age(slot.timestamp)
            color: Util.alpha(Color.foreground, 0.7)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        // Plain text: the spec makes the summary one line of plain text, and
        // anything richer from a sender would only be markup injection.
        Text {
          width: parent.width
          visible: slot.summary.length > 0
          text: slot.summary
          textFormat: Text.PlainText
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          wrapMode: Text.Wrap
          elide: Text.ElideRight
          maximumLineCount: 2
        }

        // The body keeps the little markup the service allows, cleaned by the
        // service's own rules, as its toasts show it.
        Text {
          width: parent.width
          visible: slot.hasBody
          text: NotificationLogic.styledBody(slot.body, slot.app, slot.appIcon)
          textFormat: Text.StyledText
          color: Util.alpha(Color.foreground, 0.85)
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
          elide: Text.ElideRight
          maximumLineCount: 3
        }
      }

      TapHandler {
        id: press
        onTapped: banners.notifications.invokePopupDefault(slot.index)
      }

      // Sideways and away clears it; not far enough, and it settles back. No
      // target, as in the app switcher: the distance goes through dx, and a
      // release is judged on the grab so a cancelled touch never clears one.
      DragHandler {
        id: swipe

        target: null
        yAxis.enabled: false
        onTranslationChanged: if (active) card.dx = translation.x
        onGrabChanged: function(transition, point) {
          if (transition === PointerDevice.UngrabExclusive
              && Math.abs(card.dx) > card.width * 0.35) banners.notifications.dismissPopup(slot.index)
          else if (transition === PointerDevice.UngrabExclusive
              || transition === PointerDevice.CancelGrabExclusive) card.dx = 0
        }
      }
    }
  }
}
