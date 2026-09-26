# Preview harness

This renders the phone plugins to PNG without a phone, Hyprland or Quickshell.
The images in `previews/` come from it.

It is a simulation, not a screenshot:

- **Quickshell is replaced by stubs** in `stubs/`. `PanelWindow` becomes a
  plain window, and `FileView` reads files through XHR. `Process` never runs,
  and `hyprctl` calls and plugin summons are logged as `EXEC` lines rather than
  carried out.
- **Every surface is laid out from its layer-shell anchors, margins and
  implicit size.** Surfaces are then stacked by layer over the theme's
  wallpaper.
- **Window stills and effects are stand-ins.** `ScreencopyView` is a grey
  panel labelled "window" (hidden in the switcher by the effect below),
  and `MultiEffect` (not in Qt before 6.5) is replaced by a plain `ShaderEffect`. The harness renders with Qt's software
  backend, which draws no shader effects, so anything behind one -- the app
  switcher's window stills -- comes out blank.
- **Desktop entries and windows are stand-ins too.** `DesktopEntries` has no
  entries, so app names fall back to window titles, and `ToplevelManager` has
  no windows and never an active one.
- **Blur is imitated.** Any namespace listed in `--blur` gets a Gaussian blur
  of whatever is under it, wherever the surface's alpha is above 0.05. The
  real blur is Hyprland's, set in `config/hypr/looknfeel.lua`.

## What it needs

- Qt 6's `qml` runtime and modules. On Debian or Ubuntu that is `qml-qt6`,
  `qml6-module-qtquick*` and `libqt6svg6`.
- Pillow.
- JetBrainsMono Nerd Font installed as `monospace`, for the icons.
- An Omarchy tree, found through `OMARCHY_PATH` (default `/usr/share/omarchy`).

## How to run it

```bash
OMARCHY_PATH=~/src/omarchy tools/preview/render.py \
  --plugin plugins/phone-bar:Bar.qml \
  --plugin plugins/phone-home:Home.qml \
  --plugin plugins/phone-keyboard:Keyboard.qml:open \
  --w 360 --h 780 --scale 3 --theme tokyo-night \
  --actions 'plugins[0].openControl()' \
  --out /tmp/phone.png
```

- **`--plugin`** loads a plugin root. Add `:open` to call its `open()` first.
- **`--actions`** is JavaScript run after loading, with the loaded roots in
  `plugins`.
- **`--apps`** takes a JSON list of `{id, name, icon}` to use in place of
  Omarchy's web-app icons.
- **`TOPLEVELS`**, set to a number N ≥ 1 in the environment, puts N windows in
  the Hyprland stub (0 or any non-number: one), each on its own
  workspace and titled Chromium, foot, Files, Messages, Maps, Photos in turn.
  The first is on the focused workspace, so the bar renders as it does over an
  app, with the home indicator, and the app switcher has cards. For example:
  `TOPLEVELS=3 tools/preview/render.py ... --actions 'plugins[0].openSwitcher()'`.

### Notification banners

`Banners.qml` needs the logic file its build copies in, and a notification
service to read from. `fixtures/NotificationsPreview.qml` stands in for the
service with three notifications. Build the plugin, copy it and the fixture
into one directory, and load the fixture:

```bash
bin/omarchy-phone-notifications-build
dir=$(mktemp -d) && cp -a plugins/phone-notifications/. tools/preview/fixtures/NotificationsPreview.qml "$dir"/
tools/preview/render.py --plugin plugins/phone-bar:Bar.qml \
  --plugin plugins/phone-home:Home.qml --plugin "$dir":NotificationsPreview.qml \
  --w 360 --h 780 --scale 3 --theme tokyo-night --out /tmp/banners.png
```

### Lock screen

`LockView.qml` is drawn inside a session lock, which the harness cannot make.
`fixtures/LockPreview.qml` puts it on a full-screen panel instead, over the
harness's wallpaper (written as a PNG for it, in `PREVIEW_WALLPAPER`), and
echoes typing back as the lock service would. Drive it with `--actions`:

```bash
bin/omarchy-phone-lock-build
dir=$(mktemp -d) && cp -a plugins/phone-lock/. tools/preview/fixtures/LockPreview.qml "$dir"/
tools/preview/render.py --plugin "$dir":LockPreview.qml --w 360 --h 780 --scale 3 \
  --theme tokyo-night --blur none \
  --actions 'plugins[0].view.showPasscode(); plugins[0].view.type("1")' --out /tmp/lock.png
```

The wallpaper comes out sharp: the lock blurs it with a `MultiEffect`, which
the software renderer does not draw.
