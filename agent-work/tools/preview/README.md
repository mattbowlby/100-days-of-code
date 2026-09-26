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
