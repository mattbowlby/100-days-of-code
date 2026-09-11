# Omarchy Phone — porting notes

A touch-first port of Omarchy 4.x to a phone. The parent system is the spec: the
installed tree at `/usr/share/omarchy` is mirrored in layout, naming and idiom,
and this repo holds only what a phone genuinely needs differently.

Reference target: **OnePlus 6T (fajita)**, sdm845, Arch ARM (DanctNIX) base.
See `install/devices/fajita.conf` — the profile is the single source of panel
geometry and peripheral flags, resolved by `bin/omarchy-phone-device` and read
once per config load by `config/hypr/device.lua`.

Panel: 1080x2340 at scale 3 → **360x780 logical**, portrait, `transform = 0`.
That 360px logical width is the number most design decisions here fall out of.

## Verified against Hyprland 0.56.2

Facts established on this machine with `hyprctl getoption` and `hyprctl eval`,
not assumed. Worth keeping because several contradict what the obvious reading
of the docs would suggest.

- **`hl.gesture()` cannot express a one-finger swipe.** It enforces
  `fingers >= 2`; `hl.gesture({ fingers = 1, ... })` is rejected with
  *"value 1 is less than the minimum of 2"*. A phone swipe is one finger, so the
  current gesture API is a trackpad API as far as this port is concerned.
- **`gestures:workspace_swipe` (the master toggle) is gone**, but
  `workspace_swipe_touch`, `_distance`, `_cancel_ratio` and `_create_new` all
  still exist. Those four are therefore the only route to a touchscreen
  workspace swipe, and `config/hypr/input.lua` uses them deliberately.
- **`misc:vfr` no longer exists.** Do not add it back as a battery measure.
- **`cursor:hide_on_touch` already defaults to `true`**, so the emulated pointer
  that touch produces needs no handling. `cursor:inactive_timeout` stays at 0.
- `input:touchdevice:{enabled,output,transform}` and
  `misc:key_press_enables_dpms` all exist and accept the values used here.
- Animation styles are genuinely validated — an unknown style is rejected — so
  `style = "slide"` on the `workspaces` leaf being accepted is meaningful.

## NEEDS-HARDWARE

Nothing below can be settled on an x86 laptop. Each is an assumption, not a
claim, until it runs on the device.

1. **Does `workspace_swipe_touch` still drive a digitiser in 0.56.2?** The
   options parse, but the gesture rework landed around 0.51 and the master
   toggle was removed. If touch swipe turns out dead, the fallback is a shell-
   level gesture handler in Quickshell rather than a compositor one — and that
   changes what `config/hypr/input.lua` is for.
2. **DSI-1 is the assumed output name.** Confirm with `hyprctl monitors all`;
   if it differs, only `DEVICE_OUTPUT` in the profile changes.
3. **Scale 3 legibility.** 360x780 matches what Android reports, but Omarchy's
   shell typography is sized from `[font] base-size` in the theme's
   `shell.toml` and may need its own phone value.
4. **freedreno/Mesa GLES3 under Hyprland on sdm845** — viable in principle, not
   demonstrated here.
5. **Swipe distance of 120 logical px** (a third of the width) is a reasoned
   starting point, not a measured one.

## Open decision — the layout model

Unresolved, and it shapes the shell. On a 360px-wide surface, dwindle's split
gives two 180px columns, which is not a usable phone window. The candidates:

- **One window per workspace, dwindle inherited, switch by workspace swipe.**
  What the current input layer already supports. No window can become
  unreachable. Closest to Android. Costs: "open a second window" has to mean
  "open it on the next workspace", which is not dwindle's instinct.
- **`scrolling` layout at `column_width = 1.0`.** Each window is a full-screen
  column and the model is exactly a phone's. But column navigation needs a
  gesture, and per the finding above there is no one-finger gesture API — so a
  window past the first could be unreachable by touch. Trap unless the shell
  drives the scroll itself.

Leaning toward the first, because it cannot strand a window. Settle it before
building the app grid, which assumes one or the other.
