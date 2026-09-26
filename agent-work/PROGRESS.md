# Progress log

Pushed to `agent-work/` on branch `claude/nifty-hamilton-ezxf50` at least once an
hour while work is going on. Newest entry first.

## 2026-09-26 (late night): brightness and volume sliders

- **The control centre has iOS's two sliders** under its tiles: screen
  brightness and volume. Drag along one, or tap a point on it; the fill and
  the icon follow your finger.
- They move the same things the phone's keys would: the screen's backlight,
  and the speaker or headphones you are listening on. Turning the volume up
  unmutes, and a muted speaker shows as empty. Brightness stops at 5% so the
  screen never goes fully dark.
- Each reads its level when the control centre opens, and stays hidden if it
  cannot (no backlight to control, no sound device).
- Preview: `previews/13-control-centre-sliders.png`. Not yet tried on a phone.

## 2026-09-26 (night): the phone's own lock screen

- **An iOS-style lock screen.** It opens on the time and date over your
  blurred wallpaper. Swipe up (or tap) for the passcode page: "Enter
  Passcode", a dot for each digit you type, and round number keys with their
  letters under them, as on an iPhone. Enter (the key right of 0) unlocks.
  Delete and Cancel sit under the pad. After about 12 seconds untouched it
  goes back to the time (the screen itself goes dark after 5).
- **Your passcode is your Linux password.** If it is all digits, the number
  pad is all you need, like a phone PIN. If it has letters or symbols, tap
  ABC for a letter keyboard (and #+= on it for symbols). A keyboard plugged in
  or paired works on both pages.
- **Wrong passcodes**: the dots shake and "Authentication failed" shows above
  them, with a count of tries. After 10 wrong tries in a row, even the right
  passcode is refused for 2 minutes (the message looks the same), as at the
  desktop lock.
- **Everything else is Omarchy's own lock**, unchanged (fingerprint unlock
  too, where a sensor is set up). The installer builds it from the Omarchy on
  the phone and switches Omarchy's desktop lock off; if the build fails,
  Omarchy's own lock stays on instead, and the Lock tile stays hidden.
- **The Lock tile** in the control centre now uses it, and shows only while
  the phone's lock screen is the one in use.
- **The phone still never locks by itself**: not when idle, not with the power
  button, not when it suspends. That comes once this has been checked on a
  phone.
- **The keyboard-over-the-lock workaround is gone**, and with it the setting
  that let the on-screen keyboard draw above a locked screen.
- Previews: `previews/12-lock-time.png` and `previews/12-lock-passcode.png`.

**NEEDS HARDWARE: check this on the phone before relying on it.** It has not
run on a phone yet.

1. Attach a hardware keyboard first (USB-C, or Bluetooth already paired), so
   the password can be typed if the touch pad fails.
2. Run `omarchy-phone-diagnose`. It must say "lock: the phone's own".
   `omarchy-shell lock status` must show `"passwordPam":true`.
3. Swipe down from the top and tap Lock.
4. Check all five:
   - the time shows, and swiping up brings the passcode page
   - tapping number keys adds dots; Delete removes one
   - a wrong passcode shakes the dots and says so
   - the right passcode and Enter unlock
   - with the screen gone dark after a few seconds, a tap wakes it
5. Only then use it without a hardware keyboard.

**If the passcode page does not work:**

- Type the password on the hardware keyboard and press Enter.
- Without one, hold the power button to force the phone off and boot it
  again; the lock does not survive a reboot.
- Then, to go back to Omarchy's own lock (the Lock tile then hides), run:
  `mkdir -p ~/.config/omarchy-phone && touch ~/.config/omarchy-phone/no-phone-lock`
  and then `omarchy-phone-install --apply`. Delete that file and run the
  installer again to bring the phone lock back.

Restarting the shell over SSH does not help, because the lock takes a stranded
lock back on start.

## 2026-09-26 (evening): notification banners

- **Notifications now drop in as iOS-style banners** at the top of the
  screen, on the same frosted plate as the home screen's search, each with the
  app's icon on the home screen's tile shape, its name, and how long ago it
  came ("now" for new ones). Tap one to open it; swipe it left or right to
  clear it; keep a finger on one to hold it on screen. Critical ones (a battery
  alarm, say) stay until cleared and have a rim in the theme's urgent colour.
  More than half a screen of them scrolls.
- **Everything else is Omarchy's own notification service**, unchanged:
  do-not-disturb, history, how long each banner stays. The installer builds a
  copy of it from the Omarchy on the phone with only the popups swapped, and
  switches the built-in one off. If that build fails, Omarchy's own desktop
  toasts stay on instead, so notifications never go missing.
  `omarchy-phone-diagnose` says which of the two is in use.
- After an Omarchy update, run `omarchy-phone-notifications-build` (or the
  installer) again so the copy matches the new Omarchy.
- Preview: `previews/11-notification-banners.png`.

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
- **Opt-in Lock tile** (the on-screen keyboard over Omarchy's password lock):
  replaced by the phone's own lock screen, see the newer entry. The
  `lock-with-keyboard` file does nothing now and can be deleted.

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
  notifications (both added in later entries).

## Can it be flashed onto the phones asked for?

No, and nothing in this repo can change that. See `install/DEVICES.md`:

- **iPhone SE 2**: Apple's boot chain runs only kernels Apple has signed.
- **Samsung phones from 2023 on, including the Z Fold 8**: One UI 8 removed
  bootloader unlocking in every region, and there are no Linux kernel ports for
  them.

It can be flashed onto phones that already boot postmarketOS, such as the
OnePlus 6T (the reference device, see `install/BRING-UP.md`). Every layout here
fits those phones' screens.
