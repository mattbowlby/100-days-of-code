# Progress log

Pushed to `agent-work/` on branch `claude/nifty-hamilton-ezxf50` at least once an
hour while work is going on. Newest entry first.

## 2026-09-26: home screen, control centre, see-through look

**What changed:**

- **New home screen** (`plugins/phone-home`).
  - It is laid out like iOS: pages of apps, a dock, and page dots.
  - Every app sits on the same frosted rounded-square tile. Icons that come as
    circles, squares or bare logos are all drawn the same shape.
  - It follows the Omarchy theme, light or dark.
  - The dock is set from `~/.config/omarchy-phone/dock`, one app per line.
- **Unfolded foldables** (shortest side of 600 px or more) show two pages side
  by side. A phone in landscape stays one page.
- **Control centre**: swipe down from the top.
  - Tiles for Wi-Fi, Bluetooth, sound, battery, display, screenshot,
    night light and stay-awake, all in the home screen's tile shape.
  - Everything behind it frosts over, like iOS.
- **Swipe up from the bottom** goes home. Doing it again while already home
  goes back to the first page.
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
  plugins, write the starter dock file, and refuse to edit a corrupt
  `shell.json`.
- **Lint script**: it no longer reports "clean" when qmllint refuses to run.
- **`install/DEVICES.md`** lists which phones can run this.

**How it was checked:**

- Every ~50-line chunk had four independent reviews: host APIs, logic and edge
  cases, comment accuracy, and design or device fit. Fixes were applied and
  then re-reviewed.
- Offscreen renders at each size are in `previews/`.
- Hyprland and Omarchy behaviour was checked against their source code.

**The phone is never locked, for now.** Omarchy's lock screen needs a typed
password, and the on-screen keyboard can't appear over it, so a locked phone
could not be unlocked. Until there is a phone lock with a PIN pad (next on the
list):

- The power button only turns the screen off.
- There is no Lock tile.
- The installer switches off Omarchy's 5-minute auto-lock, and its
  lock-on-suspend (a closed flip cover or fold can suspend a phone).

The same problem was in the original port, where the power button locked the
phone.

**Not yet done:**

- **Nothing has run on a real phone.** The renders come from an offscreen
  harness with Quickshell stubbed out, not from the real shell.
- **Missing iOS pieces:** app switcher, lock screen, notifications, and search.

## Can it be flashed onto the phones asked for?

No, and nothing in this repo can change that. See `install/DEVICES.md`:

- **iPhone SE 2**: Apple's boot chain runs only kernels Apple has signed.
- **Samsung phones from 2023 on, including the Z Fold 8**: One UI 8 removed
  bootloader unlocking in every region, and there are no Linux kernel ports for
  them.

It can be flashed onto phones that already boot postmarketOS, such as the
OnePlus 6T (the reference device, see `install/BRING-UP.md`). Every layout here
fits those phones' screens.
