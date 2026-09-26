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

Consequences to hold onto while building the shell: the horizontal swipe moves
between apps (swipe up and hold opens the app switcher), the home screen is
whatever an empty workspace shows (it sits on the Bottom layer under every
window) so launching from it opens apps onto an empty workspace, and "two
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

The plugins as built: `dev.omarchyphone.bar` (kind `bar`, and host of the edge
gestures and control centre), `dev.omarchyphone.home` (kinds `overlay` +
`menu`, `keepLoaded`), `dev.omarchyphone.keyboard` (`overlay` + `bar-widget`).
A PIN-pad phone lock is still to come. Omarchy's lock (`plugins/lock`) asks
for a typed password and keeps keyboard focus on its password field. The phone
keyboard can type into it: the layer rule `above_lock = 2` on
`omarchy-phone-keyboard` (`config/hypr/looknfeel.lua`) draws it above a session
lock and lets it take touches, and the keys wtype injects go to the focused
surface. Keystrokes go through one queue, in order, with text on stdin rather
than argv (`phone-keyboard/Keyboard.qml`): arguments are world-readable, and a
scrambled password is a failed unlock that pam_faillock counts.

The **Lock tile** runs `omarchy-system-lock`, summons the keyboard, then asks
`omarchy-shell lock isLocked` every 2 s and hides the keyboard once the lock has
been seen up and then gone (or after five checks if it never came). The tile is
**opt-in**: it shows only while `~/.config/omarchy-phone/lock-with-keyboard`
exists. It stays opt-in until seen working on a phone, because a lock whose
keyboard does not come up cannot be left short of forcing the phone off. For
the same reason the power button only blanks the panel
(`config/hypr/bindings.lua`), the installer pushes the idle lock and
screensaver out to ~23 days (the idle service's only other "off" is the
stay-awake marker, which a user could toggle back), and it masks
`omarchy-sleep-lock.service`, which locks on every suspend -- and a phone
suspends when a cover's or fold's hall sensor reports as a lid. It cannot be a
bar feature proper: `barPluginMayControl` refuses authentication services, so
the tile goes through the same command a user would run. Also still missing:
blanking the panel after idle, which upstream only does as part of locking.

One rough edge: Omarchy's lock blanks the panel 5 s after locking and after
each wake, and the keyboard above it stays touchable while the panel is dark.
A tap low on a dark screen can therefore type a stray character before it
wakes the panel; a tap higher up wakes it through the lock's own surface.

**A risk this carries:** Hyprland layer rules match on namespace only, and any
client may name its layer surface `omarchy-phone-keyboard`. An app already
running as the user could draw a fake keyboard above the lock and record the
taps -- the password. It could not take keyboard focus or unlock anything, and
such an app could equally edit `~/.config/hypr`; but it is why the rule names
exactly one namespace, and why a lock that draws its own keypad inside the
`WlSessionLockSurface` is the real fix, after which this rule goes.

### Two host rules the layout of the plugins follows

Both are newer than the first version of this port, and both broke it silently:

- **A plugin may summon, hide or toggle only itself -- unless it is the bar.**
  The scoped shell each third-party plugin gets checks `pluginOwnsTarget`, and
  the only exception is `barPluginMayControl` (shell.qml), for plugins of kind
  `bar`. A gesture service or a quick-settings overlay that opens other
  plugins' surfaces gets `false` back and nothing happens. So the edge
  gestures and the control centre are part of the bar.
  The shell's IPC is not scoped this way: `IpcHandler { target: "shell" }`'s
  `summon`/`hide`/`toggle` go straight to `shell.summon`/`hide`/`toggle`, so any process of the
  user's -- a plugin included, via `Quickshell.execDetached(["omarchy-shell",
  "shell", "summon", id])` -- can open another plugin. The home screen brings
  up the keyboard for search this way, as the keyboard's bar widget already
  does. The plugin must still be enabled, and each call starts a process. A
  later host change could close this.
- **Only plugins of kind `menu` get an app library.** `createScopedPluginShell`
  sets `appLibrary` to null for everything else, so an overlay launcher lists
  nothing. The home screen declares `["overlay", "menu"]`: the host loads it as
  an overlay (overlay wins over menu in `computePanelEntries`) and hands it the
  library.

- **A built-in can be replaced by a clone of it.** A third-party manifest
  with `omarchy.clonedFrom: "<built-in id>"` gets the built-in's host
  capabilities (`stampHostCapabilities` in `PluginRegistry.qml`), and
  `resolveEnabledId` routes every call for the built-in's id -- the bar's
  do-not-disturb toggle, `omarchy-shell` IPC -- to the clone while it is
  enabled. The built-in itself still loads unless it is in shell.json's
  `disabledPlugins[]`. This is how `omarchy plugin clone` works, and how the
  notification banners replace Omarchy's toasts: `plugins/phone-notifications`
  is Omarchy's notifications plugin, copied from the installed Omarchy at
  install time with only its popup windows swapped for `Banners.qml`. Copied
  rather than kept in this repo so the service always matches the shell it
  runs in; the build refuses, and the installer leaves Omarchy's own toasts
  on, if a later Service.qml is not laid out as expected. Plugins get no
  other way at the notification list: the first-party service API exposes only
  `doNotDisturb` and `setDoNotDisturb`.

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

## The `bar` protocol

A hosted bar widget is handed a `bar` object and reads members off it. Upstream
never writes this contract down — it is whatever `plugins/bar/Bar.qml` happens
to expose — so here it is, measured across `plugins/panels/*/Panel.qml`,
`plugins/*/BarWidget.qml` and `Ui/*.qml`:

| Member | Kind | Phone bar's answer |
|---|---|---|
| `foreground`, `barForeground` | color | `Color.bar.text` |
| `background` | color | `Color.bar.background` |
| `urgent` | color | `Color.bar.active` |
| `fontFamily` | string | `Style.font.family` |
| `vertical` | bool | `false` — a portrait bar is horizontal |
| `barSize`, `position` | int/string | the bar's own |
| `x` | real | **not declared** — the root is an `Item`, and `QQuickItem.x` is final |
| `foregroundAnimationEnabled` | bool | `false` |
| `activePopout` | var | real, with `requestPopout`/`releasePopout` |
| `centerHoverRevealSuppressed` | bool | writable — clock and weather *set* it |
| `clickTargets` | var | `[]` |
| `shell` | var | injected by the host |
| `showTooltip`, `hideTooltip` | func | no-ops |
| `switchPanelFrom` | func | no-op — pointer affordance, no phone equivalent |
| `moduleWidgets` | func | `[]` |
| `targetWindow`, `targetBelongsToWindow` | func | via the `QsWindow` attached property |
| `run` | func | `Util.execDetached` |

Three things this cost, each found only by running it:

1. **A null `bar` is not safe.** `Ui/BarWidget.qml` and `Ui/WidgetButton.qml`
   guard every read (`bar ? bar.x : fallback`), but plugin widgets do not —
   `network/Panel.qml` dereferences `bar.foreground` straight.
2. **The guards ask whether a bar is set, not what it can do.**
   `WidgetButton` tests `if (root.bar)` and then calls `bar.showTooltip(...)`,
   so injecting a partial bar converts a null-bar TypeError into a
   not-a-function TypeError. Every function above must exist even when inert.
3. **Inject twice.** Widget bindings evaluate before `onLoaded`, so a live
   plugin reload can show them a null bar for a frame — 228 TypeErrors in one
   observed reload. Upstream's `ModuleSlot.injectProps` is called immediately
   and again under `Qt.callLater`; do the same.

When re-measuring, exclude `Style.bar.*` (they are Style tokens, not members)
and *include* `root.bar.*` forms — missing the latter is what hid
`showTooltip` the first time.

## The CLI rung is mostly reuse

The scope ladder assumed a set of `omarchy-phone-*` equivalents for brightness,
audio, power profile and cellular. Most of that turned out to be unnecessary:

- **Brightness already works.** `omarchy-brightness-display` counts `DSI-` among
  its internal panels (`monitor_is_internal()` matches `^(eDP|LVDS|DSI)-`) and
  drives `brightnessctl` against whatever `omarchy-hw-display` reports. That
  helper picks the first entry in `/sys/class/backlight` and only then refines
  through an x86-flavoured candidate list (gmux, amdgpu, intel, acpi), so a
  phone panel lands on the fallback and works. `OMARCHY_BACKLIGHT_PATH` is the
  override if a device ever exposes more than one backlight.
- **Audio and power profiles** are PipeWire and powerprofilesctl underneath;
  nothing in them is x86-specific.
- **Cellular has no ancestor at all.** Nothing in `/usr/share/omarchy` mentions
  `mmcli` or ModemManager, which makes `bin/omarchy-phone-cellular` the one
  genuinely new CLI tool the port needs.

Two things learned writing it, neither of which needed a modem:

`mmcli --output-keyvalue` pads its key column with spaces, so matching a key
with a `$` anchor silently fails — the field still carries trailing whitespace.
Trim the key before matching. Only `modem.generic.state` and the `/Modem/N`
path format are actually documented; the full paths for signal quality,
operator and access technology are not and have moved between releases, so the
tool matches distinctive key *suffixes* instead of whole keys.

Both were caught by feeding synthetic `mmcli` output to the parser and then by
putting a stub `mmcli` on PATH — the whole modem path is exercised on a machine
with no modem, including "searching with signal 0", which must stay 0 rather
than becoming null.

## Theming is nearly free, with one open question

Colour works unchanged. All 22 themes under `/usr/share/omarchy/themes/` supply
their palette the ordinary way, `Color` resolves it, and the phone bar and app
grid read `Color.bar.*` / `Color.menu.*` / `Color.background` like any other
consumer. Nothing in the port needs a theme of its own.

The open question is sizing. `Style` takes typography, spacing and bar
dimensions from `shell.toml` in the active theme — `[font] base-size` as the rem
root, `[spacing] scale`, `[bar] size-horizontal` — and **not one of the 22 themes
ships a `shell.toml`**. Every theme therefore runs on `Style`'s built-in
defaults: base-size 12, bar 26.

Whether those are right for a phone cannot be answered here. At scale 3 on a
360px logical width, 12px text occupies about 3.3% of the width against 0.8% on
this laptop, so it is *relatively* four times larger already, which is roughly
what a phone wants. That is an argument for leaving it alone until it can be
looked at on the device, not a measurement.

If it does need tuning, the lever is a `shell.toml` in the active theme
(`~/.local/state/omarchy/current/theme/shell.toml`, which `Color.loadShell`
parses and hands to `Style`). Per-theme is an awkward place for a device-wide
setting, so that is a design problem to solve when there is evidence it needs
solving — forking 22 themes to change one number would be the wrong answer.

## The on-screen keyboard is greenfield, and cannot auto-raise

`Ui/KeyboardPanel.qml` is **not** an on-screen keyboard, despite the name. Its
own header says it: a layer-shell popup card for panels summoned *by* the
keyboard (SUPER+CTRL+W and friends), built on PanelWindow with a brief
`WlrKeyboardFocus.Exclusive` prime. The port's earlier notes and both agent
files claimed the OSK would extend it. They were wrong, and are fixed.

Quickshell has no virtual-keyboard or input-method type either.
`Quickshell.Wayland` exposes layer shell, `WlSessionLock` /
`WlSessionLockSurface`, screencopy, idle notify/inhibit, toplevel management and
a shortcuts inhibitor — nothing for text input. So `plugins/phone-keyboard`
injects keys out of process with **`wtype(1)`**, which implements
`zwp_virtual_keyboard_v1`:

- Characters go to `wtype -` on **stdin**, never in argv: arguments are
  readable by every user, and on the lock screen the text is the password. A
  constant `bash -c` script reads up to a NUL and pipes it on (`wtype -` types
  at EOF); the text is written to its stdin and never interpolated, so no
  character on the keyboard -- `;`, `$`, a backtick -- is ever parsed. wtype
  decodes with the inherited locale, so non-ASCII keys would need a UTF-8
  `LANG`; every key today is ASCII.
- `wtype -P KEY -p KEY` for named keys (libxkbcommon identifiers — `BackSpace`,
  `Return`), and `-M`/`-m` for modifiers. Key names are constants, so argv is
  fine there.
- One process at a time, from one queue: detached processes per tap can land
  out of order.

The surface must carry `WlrKeyboardFocus.None`, or the keys wtype injects land
back in the keyboard instead of the application.

**The consequence worth planning around:** with no input-method protocol, the
shell cannot know that a text field was focused, so the keyboard cannot raise
itself. Summoning stays explicit — a gesture or a button — until Quickshell
grows `text-input-v3`/`input-method-v2`, or the port carries its own small
input-method client. That is a real architectural limit, not a to-do.

`WlSessionLock` / `WlSessionLockSurface` being present is the good news in the
same breath: the lock screen rung has a proper API waiting for it.

## Checking an icon glyph without touching the running shell

Bar icons are private-use codepoints, and a wrong one renders as tofu that only
shows up by looking at it. Swapping someone's bar to find out is rude; render it
offline instead:

```bash
python3 -c 'import sys; sys.stdout.write(chr(0xf11c))' > /tmp/g.txt
pango-view --font="JetBrainsMono Nerd Font 64" --background=white \
  --foreground=black -q -o /tmp/g.png /tmp/g.txt
```

Which font matters. Two are in play and they are not interchangeable:

- **`omarchy.ttf`** (`/usr/share/fonts/omarchy/`) covers only **e900-e907**,
  eight glyphs. `\ue900` is the menu icon. There is no keyboard in it — reaching
  for `fontFamily: "omarchy"` with an arbitrary codepoint gets tofu.
- **`monospace`**, which is what the bar actually uses, resolves here to
  **JetBrainsMono Nerd Font** covering `f000-f385` and `f0001-f1af0`. That is
  where upstream's `\uf053`, `\uf023` and friends come from, used with no
  `fontFamily` override at all.

Verified this way: `f11c` is a keyboard, `f023` a lock, `f0e4` a gauge.

## Bar widgets whose panels are summoned through the bar

A second, separate protocol from the `bar` one above, and missing it makes a
whole category of upstream feature silently unreachable.

`shell.summon()` checks `isBarWidgetPanelPlugin(id)`: a plugin whose kinds
include `bar-widget` and **no** loader kind (panel/overlay/menu) is not routed to
the panel loader at all. It is handed to `shell.bar` instead. That covers
`omarchy.audio`, `omarchy.network`, `omarchy.bluetooth`, `omarchy.power`,
`omarchy.monitor`, `omarchy.weather` and the rest of `plugins/panels/*`.

So a replacement bar must implement four functions or every one of those panels
answers "no live bar widget for" and cannot be opened:

| Function | Contract |
|---|---|
| `summonBarWidget(id)` | find the loaded widget item, call `item.open()`, return whether it worked |
| `hideBarWidget(id)` | same, `item.close()` |
| `isBarWidgetOpen(id)` | `item.opened === true` |
| `panelWidgetIdAt(section, index)` | id of the *index*-th widget in a section, 1-based |

Which means the bar has to keep an id → loaded-item map. The phone bar registers
in the widget Loader's `onLoaded` and drops the entry in
`Component.onDestruction`.

Verified by summoning `omarchy.network` and `omarchy.power` through the phone
bar: each opened a panel surface (namespace `omarchy-keyboard-panel`, since
`Ui/KeyboardPanel.qml` is what those popups are built on) and closed again on a
second toggle, with no warnings.

A plugin that declares a loader kind *as well as* `bar-widget` is exempt and
stays with the panel loader — which is why `phone-keyboard` can be both an
overlay and a bar widget without its toggle being rerouted.

## Never link plugins and restart the shell in the same breath

Development testing crashed Quickshell **five times** before the pattern was
spotted. Every crash has the identical signature in the journal:

```
DEBUG qml: Local plugin changed, reloading: phone-bar
DEBUG qml: Local plugin changed, reloading: phone-appgrid   (etc.)
INFO: Exiting due to IPC request.
ERROR: Quickshell has crashed under pid NNNNN
```

`omarchy-phone-plugins-link` creates N symlinks at once, and the shell's plugin
file-watcher fires a live reload for each. Calling `omarchy-restart-shell`
immediately after puts an engine teardown in the same second as those reloads.
The backtrace is the collision: `QQuickRepeater::setModel` → `regenerate` →
incubate a delegate → `QQmlComponent::create` → a `__dynamic_cast` inside
Quickshell's own code → SIGSEGV, all of it triggered from a QML signal handler
partway through object creation.

Three things worth separating:

- **It is not the port's QML.** QML should not be able to segfault the engine at
  all, and the faulting frame is Quickshell's, casting an object that is being
  destroyed underneath it. This is an upstream robustness bug.
- **It is the test procedure that provokes it**, and a real install never does
  this: plugins are laid down once and the session starts afterwards.
  `omarchy-phone-install` is already correct — it links and then tells you to
  restart rather than doing both.
- **Nothing was lost.** Quickshell caught each one and relaunched itself
  ("Quickshell has been restarted"), so the desktop recovered on its own; the
  only trace was a crash notification.

So when testing by hand: link, let the reload settle, *then* restart — or
restart first and link after. Not both at once.

