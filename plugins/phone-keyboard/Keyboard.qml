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

  readonly property var letterRows: [
    "qwertyuiop",
    "asdfghjkl",
    "zxcvbnm"
  ]

  function open(payloadJson) {
    shifted = false
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
    color: Color.menu.background

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
        model: root.letterRows

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
              label: root.shifted ? modelData.toUpperCase() : modelData
              onActivated: root.typeText(root.shifted ? modelData.toUpperCase() : modelData)
            }
          }
        }
      }

      Row {
        id: bottomRow

        // Width left for keys once the three gaps between four of them are
        // taken, so each key is a fraction of that rather than of the row.
        readonly property real usable: width - 3 * root.keyGap

        width: parent.width
        height: root.keyHeight
        spacing: root.keyGap

        Key {
          width: bottomRow.usable * 0.18
          height: root.keyHeight
          label: root.shifted ? "SHIFT" : "shift"
          active: root.shifted
          onActivated: root.shifted = !root.shifted
        }

        Key {
          width: bottomRow.usable * 0.46
          height: root.keyHeight
          label: "space"
          onActivated: root.typeText(" ")
        }

        Key {
          width: bottomRow.usable * 0.18
          height: root.keyHeight
          label: "back"
          onActivated: root.typeKey("BackSpace")
        }

        Key {
          width: bottomRow.usable * 0.18
          height: root.keyHeight
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

    signal activated()

    radius: Style.cornerRadius
    color: key.active || tap.pressed ? Color.menu.selectedBackground : Color.menu.background
    border.width: Math.max(1, Style.space(1))
    border.color: Color.menu.border

    Text {
      anchors.centerIn: parent
      text: key.label
      color: key.active ? Color.menu.selectedText : Color.menu.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
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
