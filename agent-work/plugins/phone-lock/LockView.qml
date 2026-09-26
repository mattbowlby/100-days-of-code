// Inline delegates read the view's ids; see phone-bar/Bar.qml for why this
// pragma is here when upstream's shell carries none.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

// The phone's lock screen, in place of Omarchy's password field
// (bin/omarchy-phone-lock-build swaps this in; everything else about the lock
// -- PAM, fingerprint, blanking, recovery -- is Omarchy's lock service,
// unchanged). iOS's two steps: the time over the frosted wallpaper, then a
// swipe up (or a tap) for the passcode page with a round-key number pad. The
// passcode is the user's password; ABC swaps the pad for letters and symbols
// for one that is not all digits. A hardware keyboard types at any point.
//
// The properties and signals down to wakeRequested are the service's contract
// with its view, kept exactly; the build checks every one the service sets is
// still declared here.
Item {
  id: root

  property string backgroundPath: ""
  property string videoPosterPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  // Upstream's reasoning: nothing shows while the displays are blank, so a
  // video wallpaper must not keep decoding through it.
  property bool displaysBlank: false
  property bool powerSaverActive: false
  property string passwordText: ""

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  readonly property bool video: Util.isVideoPath(root.backgroundPath)
  readonly property bool feedActive: root.video && root.loadBackground && !root.displaysBlank && !root.powerSaverActive
  readonly property bool errorState: failureMessage.length > 0
  readonly property bool canType: inputEnabled && !authenticatingPassword

  // The passcode page is showing, rather than the time.
  property bool entering: false
  // "digits", "letters" or "symbols": what the pad shows.
  property string padMode: "digits"
  property bool shifted: false

  // Side by side on a landscape phone: the time on the left, the pad on the
  // right. Stacked otherwise.
  readonly property bool wide: width > height * 1.2
  readonly property int pad: Style.spacing.xxl
  readonly property int columnWidth: Math.min(wide ? Math.round(width / 2) : width, Style.space(420)) - pad * 2

  function forcePasswordFocus() {
    keys.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function showPasscode() {
    if (!inputEnabled) return
    wakeRequested()
    entering = true
    idle.restart()
    forcePasswordFocus()
  }

  function showTime() {
    entering = false
    padMode = "digits"
    shifted = false
    clearPassword()
  }

  function type(text) {
    if (!canType || text.length === 0) return
    wakeRequested()
    if (!entering) showPasscode()
    if (errorState) clearFailureRequested()
    passwordTextEdited(passwordText + text)
    if (shifted) shifted = false
    idle.restart()
  }

  function backspace() {
    if (!canType) return
    wakeRequested()
    if (passwordText.length > 0) passwordTextEdited(passwordText.slice(0, -1))
    idle.restart()
  }

  function submit() {
    if (!canType) return
    var submitted = passwordText
    passwordTextEdited("")
    if (submitted.length > 0) submitPassword(submitted)
  }

  // Back to the time after a while untouched, as iOS does -- unless something
  // is typed or being checked. A failure message left up goes with it.
  Timer {
    id: idle
    interval: 12000
    onTriggered: {
      if (root.passwordText.length > 0 || root.authenticatingPassword) return
      if (root.errorState) root.clearFailureRequested()
      root.showTime()
    }
  }

  // A wrong passcode: the dots shake, as iOS's do, and the page stays up.
  // Read directly: errorState is a binding on it and may not have caught up.
  onFailureMessageChanged: if (failureMessage.length > 0) { entering = true; shake.restart(); idle.restart() }
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
    else showTime()
  }
  Component.onCompleted: if (inputEnabled) Qt.callLater(forcePasswordFocus)

  // A hardware keyboard, on either page. Not a TextInput: the pad and the
  // keyboard both edit the service's copy of the text, and one path for both
  // keeps them from disagreeing.
  Item {
    id: keys

    focus: true
    Keys.onPressed: function(event) {
      root.wakeRequested()
      if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
        root.clearPassword()
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        root.submit()
      } else if (event.key === Qt.Key_Backspace) {
        root.backspace()
      } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127
          && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
        // Printable only: Delete sends DEL (127), and Alt or Super with a
        // letter is a shortcut, not a character. AltGr is neither.
        root.type(event.text)
      } else {
        return
      }
      event.accepted = true
    }
  }

  // ---------------------------------------------------------------- backdrop
  //
  // Upstream's wallpaper handling, unchanged: the image blurred, or a video
  // feed (loaded only while it can be seen) over its cached poster.
  Rectangle {
    anchors.fill: parent
    color: Color.background

    BackgroundMedia {
      id: wallpaper
      objectName: "lockWallpaper"
      anchors.fill: parent
      path: root.loadBackground ? (root.video ? root.videoPosterPath : root.backgroundPath) : ""
      version: root.backgroundVersion
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.ready
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
    }

    Loader {
      id: feedLoader
      objectName: "lockFeedLoader"
      anchors.fill: parent
      active: root.feedActive
      source: "LockFeedSurface.qml"
      visible: status === Loader.Ready
    }

    Rectangle {
      anchors.fill: feedLoader
      visible: root.video
      color: "#22000000"
    }

    // Darker behind the pad, so its keys read over any wallpaper.
    Rectangle {
      anchors.fill: parent
      color: Util.alpha(Color.background, root.entering ? 0.5 : 0.15)
      Behavior on color { ColorAnimation { duration: 200 } }
    }
  }

  // Any touch wakes the displays (they blank a few seconds into a lock); a
  // tap anywhere off the pad on the time page opens the pad.
  //
  // The swipe up is on this same area: a handler on the item that takes the
  // press sees it first, where one on the root would never see it at all.
  //
  // Judged on the page the press began on: a key's tap handler hears the
  // release before this does, and one that just left the passcode page
  // (Cancel) must not be followed by this opening it again.
  MouseArea {
    property bool pressedOnTime: false

    anchors.fill: parent
    onPressed: { pressedOnTime = !root.entering; root.wakeRequested() }
    onClicked: if (pressedOnTime && !root.entering) root.showPasscode()

    DragHandler {
      target: null
      enabled: !root.entering
      xAxis.enabled: false
      onTranslationChanged: if (active && translation.y < -Style.space(60)) root.showPasscode()
    }
  }

  // -------------------------------------------------------------- time page
  Column {
    id: timeColumn

    readonly property bool shown: !root.entering || root.wide

    x: root.wide ? root.pad : Math.round((root.width - width) / 2)
    y: root.wide ? Math.round((root.height - height) / 2) : Math.round(root.height * 0.1)
    width: root.wide ? root.columnWidth : root.width - root.pad * 2
    spacing: Style.spacing.sm
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    SystemClock {
      id: clock
      precision: SystemClock.Minutes
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: "\uf023"  // a padlock (Nerd Font)
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Style.font.title
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: Qt.formatDateTime(clock.date, "dddd d MMMM")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Style.font.title
    }

    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: Qt.formatDateTime(clock.date, "HH:mm")
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(Math.min(Style.space(84), root.height * 0.14))
      font.weight: Font.Light
    }
  }

  // The way in, at the bottom of the time page.
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(28)
    visible: !root.entering
    text: root.fingerprintConfigured ? "Touch the sensor or swipe up to unlock" : "Swipe up to unlock"
    color: Util.alpha(Color.lock.text, 0.8)
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  // ----------------------------------------------------------- passcode page
  Column {
    id: passcode

    x: root.wide ? Math.round(root.width / 2) + root.pad : Math.round((root.width - width) / 2)
    y: Math.max(root.pad, Math.round((root.height - height) / 2))
    width: root.columnWidth
    spacing: Style.spacing.lg
    opacity: root.entering ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    // What the page wants, or what went wrong.
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.authenticatingPassword ? "Checking…" : (root.errorState ? root.failureMessage : "Enter Passcode")
      textFormat: Text.PlainText
      color: root.errorState ? Color.lock.textError : Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      elide: Text.ElideRight
    }

    // One dot per character typed -- the length is the user's own, so there
    // are no empty slots to fill, as iOS shows for an alphanumeric passcode.
    Item {
      width: parent.width
      height: Style.space(14)

      Row {
        id: dots

        property real shift: 0

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: shift
        spacing: Style.spacing.md

        Repeater {
          // Past what fits, the row stops growing; a count would say how long
          // the passcode is to anyone looking over a shoulder anyway.
          model: Math.min(root.passwordText.length, 14)

          Rectangle {
            width: Style.space(12)
            height: width
            radius: width / 2
            color: Color.lock.text
          }
        }
      }

      SequentialAnimation {
        id: shake
        loops: 1
        NumberAnimation { target: dots; property: "shift"; to: -Style.space(14); duration: 50 }
        NumberAnimation { target: dots; property: "shift"; to: Style.space(14); duration: 80 }
        NumberAnimation { target: dots; property: "shift"; to: -Style.space(9); duration: 70 }
        NumberAnimation { target: dots; property: "shift"; to: 0; duration: 60 }
      }
    }

    // Both pads are built once and shown in turn: a Loader switching between
    // Components cannot make them here, as the rows each has are delegates of
    // their own, bound to this file (the pragma at the top).
    DigitPad {
      width: parent.width
      visible: root.padMode === "digits"
    }

    LetterPad {
      width: parent.width
      visible: root.padMode !== "digits"
    }

    // iOS's two text buttons under the pad's outer columns.
    Item {
      anchors.horizontalCenter: parent.horizontalCenter
      width: root.padMode === "digits" ? root.keySize * 3 + Style.spacing.xxl * 2 : parent.width
      height: Style.space(40)

      TextButton {
        anchors.left: parent.left
        label: root.padMode === "digits" ? "ABC" : "123"
        onActivated: { root.padMode = root.padMode === "digits" ? "letters" : "digits"; idle.restart() }
      }

      TextButton {
        anchors.right: parent.right
        label: root.passwordText.length > 0 ? "Delete" : "Cancel"
        onActivated: root.passwordText.length > 0 ? root.backspace() : root.showTime()
      }
    }
  }

  // ------------------------------------------------------------------ pads
  //
  // The number pad: iOS's round keys, three across, each digit with its
  // letters under it. Enter sits where iOS leaves a gap, as passcodes here
  // have no fixed length to submit at.
  readonly property var digitRows: [
    [["1", ""], ["2", "ABC"], ["3", "DEF"]],
    [["4", "GHI"], ["5", "JKL"], ["6", "MNO"]],
    [["7", "PQRS"], ["8", "TUV"], ["9", "WXYZ"]],
    [["", ""], ["0", ""], ["⏎", ""]]
  ]

  // Largest round key that fits three across and, with the rest of the page,
  // four down.
  readonly property int keySize: Math.max(Style.space(40), Math.min(Style.space(78),
    Math.floor((columnWidth - Style.spacing.xxl * 2) / 3),
    Math.floor((height - pad * 2 - Style.space(40) - Style.space(14) - Style.font.title * 2
      - Style.spacing.lg * 4 - Style.spacing.lg * 3) / 4)))

  component DigitPad: Column {
    spacing: Style.spacing.lg

    Repeater {
      model: root.digitRows

      Row {
        id: digitRow

        required property var modelData

        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        spacing: Style.spacing.xxl

        Repeater {
          model: digitRow.modelData

          RoundKey {
            required property var modelData

            digit: modelData[0]
            letters: modelData[1]
          }
        }
      }
    }
  }

  component RoundKey: Item {
    id: key

    property string digit: ""
    property string letters: ""
    readonly property bool isEnter: digit === "⏎"

    width: root.keySize
    height: root.keySize
    // The gap left of 0 is only a gap, but keeps its place in the row so 0
    // stays under 8.
    enabled: digit.length > 0
    opacity: digit.length === 0 ? 0 : (isEnter && root.passwordText.length === 0 ? 0.4 : 1)

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: Util.alpha(Color.lock.text, keyTap.pressed ? 0.4 : 0.14)
      border.width: Math.max(1, Style.space(1))
      border.color: Util.alpha(Color.lock.text, 0.22)
      Behavior on color { ColorAnimation { duration: 90 } }
    }

    Column {
      anchors.centerIn: parent

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: key.digit
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(root.keySize * (key.letters.length > 0 || key.isEnter ? 0.38 : 0.42))
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: key.letters.length > 0
        text: key.letters
        color: Util.alpha(Color.lock.text, 0.8)
        font.family: Style.font.family
        font.pixelSize: Math.round(root.keySize * 0.13)
        font.letterSpacing: Math.round(root.keySize * 0.03)
      }
    }

    TapHandler {
      id: keyTap
      onTapped: key.isEnter ? root.submit() : root.type(key.digit)
    }
  }

  // Letters and symbols, for a password that is not all digits: the
  // on-screen keyboard's rows, drawn here because nothing else can draw over
  // a lock.
  readonly property var letterRows: [
    "qwertyuiop".split(""),
    "asdfghjkl".split(""),
    ["⇧"].concat("zxcvbnm".split("")).concat(["⌫"]),
    ["#+=", " ", "⏎"]
  ]
  readonly property var symbolRows: [
    "1234567890".split(""),
    "-/:;()$&@\"".split(""),
    [".", ",", "?", "!", "'", "_", "*", "#", "⌫"],
    ["ABC", " ", "⏎"]
  ]
  readonly property int letterGap: Style.spacing.xs
  readonly property int letterWidth: Math.floor((columnWidth - letterGap * 9) / 10)
  readonly property int letterHeight: Math.min(Style.space(46), Math.round(keySize * 0.62))

  component LetterPad: Column {
    spacing: root.letterGap * 2

    Repeater {
      model: root.padMode === "symbols" ? root.symbolRows : root.letterRows

      Row {
        id: letterRow

        required property var modelData

        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        spacing: root.letterGap

        Repeater {
          model: letterRow.modelData

          LetterKey {
            required property var modelData

            cap: modelData
          }
        }
      }
    }
  }

  component LetterKey: Rectangle {
    id: letterKey

    property string cap: ""
    readonly property bool functional: cap.length > 1 || cap === "⇧" || cap === "⌫" || cap === "⏎"
    readonly property string shown: cap === " " ? "space"
      : (!functional && root.shifted ? cap.toUpperCase() : cap)

    // Space takes what the bottom row leaves; the other wide keys are one and
    // a half letters.
    width: cap === " " ? root.columnWidth - Math.round(root.letterWidth * 1.5) * 2 - root.letterGap * 2
      : (functional ? Math.round(root.letterWidth * 1.5) : root.letterWidth)
    height: root.letterHeight
    radius: Math.round(height * 0.22)
    color: Util.alpha(Color.lock.text, letterTap.pressed ? 0.4
      : (functional ? 0.1 : 0.18) + (cap === "⇧" && root.shifted ? 0.2 : 0))
    border.width: Math.max(1, Style.space(1))
    border.color: Util.alpha(Color.lock.text, 0.22)
    opacity: cap === "⏎" && root.passwordText.length === 0 ? 0.4 : 1

    Text {
      anchors.centerIn: parent
      text: letterKey.shown
      color: Color.lock.text
      font.family: Style.font.family
      font.pixelSize: Math.round(letterKey.height * (letterKey.functional || letterKey.cap === " " ? 0.36 : 0.5))
    }

    TapHandler {
      id: letterTap
      onTapped: {
        switch (letterKey.cap) {
        case "⇧": root.shifted = !root.shifted; idle.restart(); break
        case "⌫": root.backspace(); break
        case "⏎": root.submit(); break
        case "#+=": root.padMode = "symbols"; idle.restart(); break
        case "ABC": root.padMode = "letters"; idle.restart(); break
        default: root.type(letterKey.shown === "space" ? " " : letterKey.shown)
        }
      }
    }
  }

  component TextButton: Text {
    id: textButton

    property string label: ""
    signal activated()

    height: parent ? parent.height : implicitHeight
    verticalAlignment: Text.AlignVCenter
    leftPadding: Style.spacing.md
    rightPadding: Style.spacing.md
    text: label
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    opacity: buttonTap.pressed ? 0.5 : 1

    TapHandler {
      id: buttonTap
      onTapped: { root.wakeRequested(); textButton.activated() }
    }
  }
}
