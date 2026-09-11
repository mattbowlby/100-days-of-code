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

## Settled — the layout model

**One window per workspace**, implemented in `config/hypr/windows.lua` as a
`window.open` handler that moves a second window on a workspace to an empty one.

It fell out of the input layer rather than taste. The alternative was a
`scrolling` layout at `column_width = 1.0`, which is a truer phone model — every
window a full-screen column — but moving between columns needs a one-finger
gesture, and per the finding above there is none. A window past the first would
have been unreachable by touch. Workspaces *are* reachable with one finger via
`workspace_swipe_touch`, so workspaces are where windows go.

Consequences to hold onto while building the shell: the app switcher is the
horizontal swipe, the app grid opens apps onto empty workspaces, and "two
windows side by side" is not a state this port has.

## Also verified

- `workspace = "empty"` resolves in the Lua dispatcher — `hl.dsp.focus({
  workspace = "empty" })` moved 2 → 3 on this machine. Same workspace-argument
  parser `hl.dsp.window.move` uses.
- `hl.dsp.window.move` takes **no window argument**. Its accepted arguments are
  `direction, x+y(+relative), workspace, into_group, out_of_group`, so it acts on
  whatever holds focus. Any handler that moves a window must first confirm the
  window it means is the focused one.
- Windows expose `address, class, initial_class, title, workspace, floating,
  fullscreen, pid, monitor, mapped` — and no geometry. Workspaces expose
  `id, name, windows` (a live count), `monitor, last_window, has_fullscreen`.
- `hl.on` validates event names and its error lists all 31 of them. The useful
  ones here: `window.open`, `window.open_early`, `window.close`, `window.active`,
  `workspace.active`, `monitor.layout_changed`, `input.keyboard.key` — that last
  one is how a compositor-side long-press could be done if logind's turns out
  not to be enough.
- `hyprctl dispatch` compiles its arguments as Lua now, so the old
  `hyprctl dispatch workspace empty` form is a syntax error. Use `hyprctl eval`.
- Handlers registered through `hyprctl eval` do **not** persist, so event
  payloads cannot be observed off-device this way. This is why
  `config/hypr/windows.lua` guards its payload instead of trusting it.
