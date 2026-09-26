# Omarchy Phone

A touch-first port of [Omarchy](https://omarchy.org) 4.x to a phone: Hyprland
for the session, Quickshell for the surface, and as little new code as the job
allows. The parent system at `/usr/share/omarchy` is the spec.

Reference target: **OnePlus 6T (fajita)**, sdm845, Arch ARM base.
Panel 1080x2340 at scale 3 — **360x780 logical**, portrait.

Not yet run on a phone. Everything here has been exercised against the desktop
Omarchy install on an x86 laptop, or rendered offscreen (`previews/`);
`NOTES.md` marks what that cannot settle. `install/DEVICES.md` says which phones
can run it at all -- in short, ones that can boot postmarketOS; no iPhone and no
current Samsung.

## The look

iOS's layout -- pages of apps, a dock, page dots, a control centre that drops
from the top -- with every app on the same frosted rounded-square tile, and
Omarchy's see-through surfaces over a blur instead of Apple's liquid glass.
It follows the active Omarchy theme, light or dark. On an unfolded foldable
(shortest side 600 logical px or more) the home screen opens as two pages side
by side once there is more than one page of apps. `previews/` has renders at each size.

## Shape

```
config/hypr/     the mobile session (Lua, not .conf)
plugins/         shell plugins, installed to ~/.config/omarchy/plugins
  phone-bar          status bar, screen-edge swipes and the control centre
                     (swipe up from the bottom, marked by a home indicator
                     over apps: home; down from the top: control centre);
                     hosts Omarchy's own widgets and panels
  phone-home         home screen and dock, under every window
  phone-keyboard     on-screen keyboard        (bar toggle)
bin/             omarchy-phone-* tools
install/         device bring-up fragments
```

Two decisions worth knowing before reading the code, both explained in
`NOTES.md`:

- **The shell is plugins, not a fork.** Quickshell registers the launched config
  root as the QML module `qs`, so a separate phone shell would resolve
  `import qs.Commons` against its own empty root and lose the entire `Ui/` kit.
  The phone bar and home screen run inside upstream's shell host instead.
  That host lets a plugin open only its own surfaces unless it is the bar, and
  hands the app list only to plugins of kind `menu`, which is why gestures and
  the control centre live in the bar and the home screen declares `menu`.
- **One window per workspace.** `hl.gesture()` enforces `fingers >= 2`, so
  Hyprland's current gesture API cannot express a one-finger phone swipe. The
  legacy `workspace_swipe_touch` can, which makes workspaces the only
  touch-reachable way between windows — so each window gets one.

## Quick start

```bash
bin/omarchy-phone-diagnose          # where does the port stand on this machine
bin/omarchy-phone-install           # dry run: what installing would do
bin/omarchy-phone-install --apply   # actually install (refuses off-device)
```

To try the shell plugins without installing the session:

```bash
cfg=~/.config/omarchy/shell.json
cp "$cfg" "$cfg.bak"                              # keep a way back
bin/omarchy-phone-plugins-link                    # link into ~/.config/omarchy/plugins
sleep 10                                          # let the hot-reload settle -- see below
jq '.bar.id = "dev.omarchyphone.bar"
    | .plugins = ((.plugins // []) | map(select((.id // "") | startswith("dev.omarchyphone.") | not))
        | . + [{id: "dev.omarchyphone.home"}, {id: "dev.omarchyphone.keyboard"}])' \
  "$cfg.bak" > "$cfg"                             # non-bar plugins load only if listed
omarchy-restart-shell

cp "$cfg.bak" "$cfg"                              # and back out
bin/omarchy-phone-plugins-link --unlink
sleep 10
omarchy-restart-shell
```

**Do not link and restart in the same breath.** Linking creates several symlinks
at once, the shell live-reloads a plugin for each, and a restart landing in the
same second crashes Quickshell — reproducibly, 5 times out of 5 here. It is an
upstream robustness bug rather than anything in this port, the shell relaunches
itself afterwards, and a real install never does it (`omarchy-phone-install`
links and then tells you to restart). `NOTES.md` has the backtrace.

`--unlink` only removes symlinks that resolve into this checkout, so a real
plugin directory of the same name is never destroyed.

## Tools

| | |
|---|---|
| `omarchy-phone-device` | resolve the device profile (`--profile`, `--field K`, `--status`) |
| `omarchy-phone-diagnose` | read-only report: device, session modules, plugins, lint, running shell |
| `omarchy-phone-install` | install the session; dry run unless `--apply` |
| `omarchy-phone-plugins-link` | link/unlink the shell plugins for development |
| `omarchy-phone-lint-qml` | qmllint with the `qs` module path and Quickshell's false positives handled |
| `omarchy-phone-cellular` | modem status/control via mmcli; the one tool with no upstream ancestor |

## Verifying

```bash
luac -p config/hypr/*.lua        # session modules
bash -n bin/omarchy-phone-*      # tools
bin/omarchy-phone-lint-qml       # QML; fails on warnings, baseline is zero
```

`qs` has no `--check` subcommand — running the shell is not a lint. `qmllint`
is installed at `/usr/lib/qt6/bin/qmllint` but is not on `PATH`;
`omarchy-phone-lint-qml` is the wrapper that makes it meaningful.
