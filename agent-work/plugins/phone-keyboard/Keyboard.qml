pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// On-screen keyboard.
//
// Greenfield, despite the name of Ui/KeyboardPanel.qml: that file is a
// layer-shell popup card for panels summoned *by* the keyboard, not a virtual
// one. Quickshell exposes no virtual-keyboard or input-method type either --
// Quickshell.Wayland has layer shell, session lock, screencopy, idle and
// toplevel management and nothing else -- so keys are injected out of process
// with wtype(1), which implements zwp_virtual_keyboard_v1.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool shifted: false

  readonly property int keyHeight: Style.space(44)
  readonly property int keyGap: Style.spacing.xs

  // "letters" or "symbols". Named keyLayer, not layer: QQuickItem.layer is
  // final (the layer-effects property) and shadowing it is a runtime error.
  // Shift applies only to letters -- symbol keys have no
  // case, so it is left inert there rather than given a second meaning.
  property string keyLayer: "letters"

  readonly property var letterRows: [
    "qwertyuiop",
    "asdfghjkl",
    "zxcvbnm"
  ]

  // Ten per row, matching the letter grid, so the key width is the same in both
  // layers and nothing shifts under the thumb when the layer changes.
  readonly property var symbolRows: [
    "1234567890",
    "-/:;()$&@\"",
    ".,?!'+=#%*"
  ]

  // keyLayer, never `layer`: the bare name resolves to QQuickItem.layer, an
  // object that is never equal to "symbols", and the symbols never showed.
  readonly property var currentRows: keyLayer === "symbols" ? symbolRows : letterRows

  function open(payloadJson) {
    shifted = false
    keyLayer = "letters"
    opened = true
  }

  function close() {
    opened = false
  }

  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide("dev.omarchyphone.keyboard")
  }

  // Every key goes through one queue and one wtype at a time. Detached wtype
  // processes, one per tap, can land out of order under a fast thumb -- and on
  // the lock screen a scrambled password is a failed unlock, three of which
  // lock the account for ten minutes (pam_faillock). Text queued while a run is
  // going is typed together in the next one.
  property var pendingKeys: []

  function typeText(text) {
    // Never queue nothing: an empty run would leave the reader waiting for a
    // NUL that is never written, and the queue behind it stuck.
    if (!text) return
    var queue = pendingKeys.slice()
    var last = queue.length > 0 ? queue[queue.length - 1] : null
    if (last && last.text !== undefined) last.text += text
    else queue.push({ text: text })
    pendingKeys = queue
    pumpKeys()
  }

  // Named keys go through press/release rather than as text; identifiers are
  // resolved by libxkbcommon.
  function typeKey(keyName) {
    pendingKeys = pendingKeys.concat([{ key: keyName }])
    pumpKeys()
  }

  function pumpKeys() {
    if (typer.running || pendingKeys.length === 0) return
    var next = pendingKeys[0]
    pendingKeys = pendingKeys.slice(1)
    if (next.key !== undefined) {
      typer.secret = ""
      typer.command = ["wtype", "-P", next.key, "-p", next.key]
    } else {
      typer.secret = next.text
      typer.command = typer.textCommand
    }
    typer.running = true
  }

  // Text goes to wtype on stdin, never in argv: a process's arguments are
  // readable by every user on the machine, and on the lock screen this text is
  // the password. `wtype -` wants EOF, so a shell reads up to a NUL and pipes
  // it on. Written to stdin rather than interpolated, so no character on this
  // keyboard -- `;`, `$`, a backtick -- is ever parsed. The same stdin route as
  // upstream's network panel takes for a Wi-Fi password.
  Process {
    id: typer

    property string secret: ""
    readonly property var textCommand: ["bash", "-c", "IFS= read -r -d '' t; printf '%s' \"$t\" | wtype -"]

    stdinEnabled: true
    onStarted: {
      if (secret !== "") write(secret + "\u0000")
      secret = ""
    }
    // Driven by running, not exited: a process that fails to start (no wtype
    // on PATH) never emits exited, and the queue behind it would sit -- with
    // typed text in memory -- until the next tap. pumpKeys ignores a repeat.
    onRunningChanged: if (!running) Qt.callLater(root.pumpKeys)
  }

  PanelWindow {
    id: panel

    visible: root.opened
    anchors { bottom: true; left: true; right: true }

    // The phone's see-through look: a translucent plate of the theme's
    // background over Hyprland's blur (config/hypr/looknfeel.lua), with keys
    // drawn as frosted rounded rectangles in the home screen's manner.
    color: Util.alpha(Color.background, 0.8)

    implicitHeight: root.keyHeight * 4 + root.keyGap * 5

    WlrLayershell.namespace: "omarchy-phone-keyboard"
    WlrLayershell.layer: WlrLayer.Top

    // Reserve the space rather than covering the app. A phone window is the
    // whole screen, so overlaying would hide the very field being typed into.
    exclusionMode: ExclusionMode.Auto

    // Must never hold the keyboard: the keys wtype injects would land back in
    // this surface instead of the application they are meant for.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Column {
      anchors.fill: parent
      anchors.margins: root.keyGap
      spacing: root.keyGap

      Repeater {
        model: root.currentRows

        delegate: Row {
          id: letterRow

          required property string modelData

          readonly property var keys: modelData.split("")

          width: parent.width
          height: root.keyHeight
          spacing: root.keyGap
          // Shorter rows sit centred, the way a physical keyboard staggers.
          leftPadding: (parent.width - (keys.length * keyWidth + (keys.length - 1) * root.keyGap)) / 2

          readonly property int keyWidth:
            (parent.width - 9 * root.keyGap) / 10

          Repeater {
            model: letterRow.keys

            delegate: Key {
              required property string modelData

              width: letterRow.keyWidth
              height: root.keyHeight
              readonly property string character:
                root.keyLayer === "letters" && root.shifted ? modelData.toUpperCase() : modelData

              label: character
              onActivated: root.typeText(character)
            }
          }
        }
      }

      Row {
        id: bottomRow

        // Width left for keys once the three gaps between four of them are
        // taken, so each key is a fraction of that rather than of the row.
        readonly property real usable: width - 4 * root.keyGap

        width: parent.width
        height: root.keyHeight
        spacing: root.keyGap

        Key {
          width: bottomRow.usable * 0.15
          height: root.keyHeight
          functional: true
          label: root.shifted ? "SHIFT" : "shift"
          active: root.keyLayer === "letters" && root.shifted
          enabled: root.keyLayer === "letters"
          onActivated: root.shifted = !root.shifted
        }

        Key {
          width: bottomRow.usable * 0.15
          height: root.keyHeight
          functional: true
          label: root.keyLayer === "symbols" ? "abc" : "?123"
          onActivated: root.keyLayer = root.keyLayer === "symbols" ? "letters" : "symbols"
        }

        Key {
          width: bottomRow.usable * 0.36
          height: root.keyHeight
          functional: true
          label: "space"
          onActivated: root.typeText(" ")
        }

        Key {
          width: bottomRow.usable * 0.17
          height: root.keyHeight
          functional: true
          label: "back"
          onActivated: root.typeKey("BackSpace")
        }

        Key {
          width: bottomRow.usable * 0.17
          height: root.keyHeight
          functional: true
          label: "enter"
          onActivated: root.typeKey("Return")
        }
      }
    }
  }

  component Key: Rectangle {
    id: key

    property string label: ""
    property bool active: false

    // Shift, layer, space, back and enter: drawn a step quieter than the
    // character keys, as iOS draws its function keys.
    property bool functional: false

    signal activated()

    // The home screen's corner ratio, on a key's height rather than a tile's.
    radius: Math.round(root.keyHeight * 0.22)
    color: Util.alpha(Color.foreground,
      key.active || tap.pressed ? 0.3 : (key.functional ? 0.06 : 0.14))

    // Item.enabled cascades and already blocks the tap, but a disabled key that
    // looks identical to a live one just reads as the phone ignoring you.
    opacity: enabled ? 1.0 : 0.4
    border.width: Math.max(1, Style.space(1))
    border.color: Util.alpha(Color.foreground, 0.16)

    Text {
      anchors.centerIn: parent
      text: key.label
      color: key.active ? Color.accent : Color.foreground
      font.family: Style.font.family
      // Characters at half the key's height, as iOS sets them.
      font.pixelSize: key.functional ? Style.font.bodySmall : Math.round(root.keyHeight * 0.5)
    }

    // Fires on press, not on release: a keyboard that waits for the finger to
    // lift feels broken, and repeat-by-holding needs the press edge anyway.
    MouseArea {
      id: tap
      anchors.fill: parent
      onPressed: key.activated()
    }
  }
}
