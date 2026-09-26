pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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

  // An argv vector, never a command string. Util.execArgv exists because a
  // shell would re-tokenize this, and every character on this keyboard is
  // exactly the sort of input that breaks that -- `;`, `$`, a backtick.
  //
  // The `--` matters too: `wtype -` means "read from stdin", so typing a bare
  // hyphen without it hangs on a pipe that never closes instead of producing a
  // character.
  function typeText(text) {
    Quickshell.execDetached(["wtype", "--", text])
  }

  // Named keys go through press/release rather than as text; identifiers are
  // resolved by libxkbcommon.
  function typeKey(keyName) {
    Quickshell.execDetached(["wtype", "-P", keyName, "-p", keyName])
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
      font.pixelSize: key.functional ? Style.font.bodySmall : Style.font.title
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
