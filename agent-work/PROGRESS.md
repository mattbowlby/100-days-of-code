# Progress log

Pushed to `agent-work/` on branch `claude/nifty-hamilton-ezxf50` at least once an
hour while work is going on. Newest entry first.

## 2026-09-26 (later): keyboard restyle, opt-in lock

- **Keyboard look**: see-through and frosted like the home screen, with
  rounded keys. Letters are brighter and larger than shift, ?123, space, back
  and enter, as on iOS.
- **Fix: the symbols layer never appeared.** The check read `layer` (every QML
  item's built-in layer-effects object, never `"symbols"`); it now reads
  `keyLayer`.
- **Search**: swipe down on the home screen for a search field at the top,
  with the on-screen keyboard up. Apps match as you type, each on the same
  tile as the grid: as many as fit above the keyboard, up to eight (fewer on
  a small or landscape screen). Tap a result, or press enter for the first
  one; tap outside the search panel to close it. Tap the field to bring the
  keyboard back.
- **Home indicator**: the iOS pill at the bottom edge, shown over apps only
  (not on the home screen), marking where the swipe home starts.
- **App switcher**: swipe up from the bottom edge and hold still for a moment;
  over an app, the home indicator stretches as the cue. Every open app (not
  scratchpads) is a card in a row, a still of its window under its name,
  opening on the app you were in. Tap a card to go to that app, drag it up
  about a third of its height to close it, tap outside the cards to go back. A
  quick swipe up still goes home, now on the lift, and dragging back down
  cancels. The window stills are untested: the preview cannot capture windows.
- **Keystrokes are typed in order, and never appear in a process list.** One
  queue, one wtype at a time, text passed on stdin.
- **Opt-in Lock tile.**
  - To enable it:
    `mkdir -p ~/.config/omarchy-phone && echo 1 > ~/.config/omarchy-phone/lock-with-keyboard`.
    A Lock tile then appears in the control centre. Write something into the
    file; an empty one may not be picked up.
  - It locks with Omarchy's password lock and brings the on-screen keyboard
    up over it. The keyboard goes away by itself a few seconds after
    unlocking.
  - Auto-lock, lock-on-suspend and the power button still never lock.

**NEEDS HARDWARE: check this on the phone before relying on it.** It has not
run on a phone yet.

1. Attach a hardware keyboard first (USB-C, or Bluetooth already paired), so
   the password can be typed if the test fails.
2. Run `hyprctl configerrors`. It must print no error text, because an older
   Hyprland without `above_lock` would reject the rule.
   `omarchy-shell lock status` must show `"passwordPam":true`.
3. Enable the tile (above), swipe down, and tap Lock.
4. Check all four:
   - the keyboard is drawn over the lock screen
   - tapping keys puts dots in the password field
   - enter unlocks
   - the keyboard disappears within a few seconds
5. Only then use it without a hardware keyboard.

**If the keyboard does not appear over the lock:**

- Type the password on the hardware keyboard.
- Without one, hold the power button to force the phone off and boot it
  again; the lock does not survive a reboot.
- Then run `rm ~/.config/omarchy-phone/lock-with-keyboard` to hide the tile.

Restarting the shell over SSH does not help, because Omarchy's lock takes a
stranded lock back on start.

## 2026-09-26: home screen, control centre, see-through look

**What changed:**

- **New home screen** (`plugins/phone-home`).
  - It is laid out like iOS: pages of apps, a dock, and page dots.
  - Every app sits on the same frosted rounded-square tile. Icons that come as
    circles, squares or bare logos are all drawn the same shape.
  - It follows the Omarchy theme, light or dark.
  - The dock is set from `~/.config/omarchy-phone/dock`, one app per line:
    up to four, in order. Apps that aren't installed are skipped, and saving
    the file updates the dock.
- **Unfolded foldables** (shortest side of 600 px or more) show two pages side
  by side once there is more than one page of apps; a single page sits
  centred. A phone in landscape stays one page.
- **Control centre**: swipe down from the top.
  - Tiles for network, Bluetooth, sound, battery and display, each shown only
    while its status-bar icon is (so no Bluetooth tile without an adapter).
  - Tiles for screenshot and night light.
  - All in the home screen's tile shape.
  - Everything behind it frosts over, like iOS.
- **Swipe up from the bottom** goes home. Doing it again while already home
  goes back to the first page. The app keeps running on its own workspace;
  swipe sideways to get back to it, or use the app switcher (see the newer
  entry).
- **See-through bar** over a Hyprland blur: Omarchy's look rather than Apple's
  liquid glass.
- **Fixes to the original port.**
  - Current Omarchy only lets the bar plugin open other plugins, and gives the
    app list only to "menu" plugins. As a result, the old app grid came up
    empty, and the old swipe gestures and quick-settings tiles did nothing.
  - The gestures and control centre now live in the bar, and the home screen
    declares "menu".
  - The superseded plugins (`phone-appgrid`, `phone-gestures`,
    `phone-quicksettings`) have been removed.
- **Installer, link and diagnose tools**: they clean up after the removed
  plugins, and the installer writes the starter dock file and refuses to edit
  a corrupt `shell.json`.
- **Lint script**: it no longer reports "clean" when qmllint refuses to run.
- **`install/DEVICES.md`** lists which phones can run this.

**How it was checked:**

- Every ~50-line chunk had four independent reviews: host APIs, logic and edge
  cases, comment accuracy, and design or device fit. Fixes were applied and
  then re-reviewed.
- Offscreen renders at each size are in `previews/`. They are simulations
  from a harness with Quickshell stubbed out, not screenshots of a phone.
- Hyprland and Omarchy behaviour was checked against their source code.

**The phone does not lock by itself, for now.** Omarchy's lock screen needs a
typed password, and until it is proven on a phone that the on-screen keyboard
comes up over it, nothing locks automatically:

- The power button only turns the screen off.
- The installer switches off Omarchy's 5-minute auto-lock and its
  lock-on-suspend (a closed flip cover or fold can suspend a phone).
- The screen never turns off by itself; only the power button blanks it.
- A blank screen is not locked. Hyprland still passes touches to apps while
  the screen is off, so a phone in a pocket may register taps, depending on
  whether its touch controller stays powered.

The same problem was in the original port, where the power button locked the
phone. See the next entry for the opt-in lock.

**Not yet done:**

- **Nothing has run on a real phone.** The renders come from an offscreen
  harness with Quickshell stubbed out, not from the real shell.
- **Missing iOS pieces:** a lock screen with its own keypad, and
  notifications.

## Can it be flashed onto the phones asked for?

No, and nothing in this repo can change that. See `install/DEVICES.md`:

- **iPhone SE 2**: Apple's boot chain runs only kernels Apple has signed.
- **Samsung phones from 2023 on, including the Z Fold 8**: One UI 8 removed
  bootloader unlocking in every region, and there are no Linux kernel ports for
  them.

It can be flashed onto phones that already boot postmarketOS, such as the
OnePlus 6T (the reference device, see `install/BRING-UP.md`). Every layout here
fits those phones' screens.
