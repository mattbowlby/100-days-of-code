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

## Settled — the shell is plugins, not a fork

The phone shell is **a set of Omarchy shell plugins**, installed into
`~/.config/omarchy/plugins/`. It is not a second Quickshell config.

Why, concretely. Quickshell registers the launched config root as the QML module
`qs`, so every `import qs.Commons` / `import qs.Ui` resolves against *that* root.
A separate phone shell at its own path would therefore get no `Commons` and no
`Ui` — the whole component kit and every theme token would have to be forked or
symlinked. Meanwhile upstream's `shell.qml` is a 1031-line plugin host that
already does config loading, plugin discovery and bar selection, and its
`services/PluginRegistry.qml` scans `~/.config/omarchy/plugins` alongside the
bundled ones. `shell.qml` picks the active bar by id from shell config and loads
it through `entryPointUrl(manifest, "bar")`.

So the bar is a designed replacement point, and a plugin's QML imports
`qs.Commons` and `qs.Ui` normally — upstream's own `plugins/lock/LockView.qml`
does exactly that. The port gets the host, the kit and the theming for free, and
"extend upstream, don't fork it" stops being an aspiration.

Manifest contract (`schemaVersion: 1`): `id`, `name`, `version`, `author`,
`description`, `kinds[]`, `entryPoints{kind: relative path}`, plus optional
`keepLoaded` and `barWidget.defaultSection`. Entry points must be relative and
inside the plugin directory — PluginRegistry rejects the manifest otherwise.
The kinds in use upstream: `bar`, `bar-widget`, `service`, `overlay`, `panel`,
`menu`.

Planned plugins, in build order: `omarchy.phone.bar` (kind `bar`), then the app
grid and on-screen keyboard as `overlay`s built out from `Ui/KeyboardPanel.qml`,
then a phone `lock`.

## Verifying QML

`qmllint` **is** installed — `/usr/lib/qt6/bin/qmllint`, from `qt6-declarative`,
just not on `PATH`. `bin/omarchy-phone-lint-qml` wraps it with the two things
needed to make it useful:

- a temp directory holding a single `qs` symlink to `$OMARCHY_PATH/shell`, since
  QML resolves module `qs.Commons` as `<import path>/qs/Commons/` and only
  Quickshell knows to register the config root as `qs` at runtime;
- `--missing-property` and `--uncreatable-type` disabled, because `Style`'s
  nested tokens are runtime-built QtObjects and Quickshell's `PanelWindow` is
  engine-instantiated. Both are wrong here, not merely noisy.

Under exactly those settings upstream's `Ui/Button.qml`, `Ui/Panel.qml` and
`Commons/Style.qml` report **zero** warnings, and a genuine typo is still caught
as unqualified access. So a warning on phone QML means something.

Note: **`qs` has no `--check` subcommand.** Its subcommands are `log`, `list`,
`kill`, `ipc`, `msg`. Parsing QML by running the shell is not a lint; use the
script above.

## Plugin ids: the `omarchy.` namespace is reserved

`omarchy.phone.bar` was **rejected at runtime**, and nothing static would have
caught it:

```
PluginRegistry: plugin omarchy.phone.bar rejected:
  id is reserved for first-party Omarchy plugins
```

PluginRegistry drops any third-party manifest whose id starts with the literal
`omarchy.` — the whole namespace belongs to built-ins, including bar widgets
registered outside the manifest system. The port uses **`dev.omarchyphone.*`**.

The rest of the id rule: non-empty, no `/`, no `..`, not starting with `/`.
`Util.canonicalWidgetId` is the identity function, so an id is compared exactly
as written. Third-party plugins on this machine use reverse-DNS
(`io.github.<user>.<name>`), which is the convention to follow.

The fallback worked as designed: with the bar rejected, `activeBarId` reverted to
`omarchy.bar` and the desktop bar rendered. A broken phone bar cannot leave a
session without one.

## The bar has actually run

Not just linted. Linked into `~/.config/omarchy/plugins`, selected with
`bar.id`, and restarted: the layer surface mapped as `omarchy-phone-bar` at
`0 0 1536x26` (its height is `Style.bar.sizeHorizontal`, default 26), and a
`grim` capture showed `18:58` on the left and `+45%` on the right in theme
colours — clock, battery percentage and charging prefix all live. Shell log was
clean of QML errors.

`bin/omarchy-phone-plugins-link` does the linking, and `--unlink` only removes
symlinks that resolve back into this checkout, so a real plugin directory of the
same name is never destroyed.

