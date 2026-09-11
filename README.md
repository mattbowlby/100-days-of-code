# Omarchy Phone

A touch-first port of [Omarchy](https://omarchy.org) 4.x to a phone: Hyprland
for the session, Quickshell for the surface, and as little new code as the job
allows. The parent system at `/usr/share/omarchy` is the spec.

Reference target: **OnePlus 6T (fajita)**, sdm845, Arch ARM base.
Panel 1080x2340 at scale 3 — **360x780 logical**, portrait.

Not yet run on a phone. Everything here has been exercised against the desktop
Omarchy install on an x86 laptop; `NOTES.md` marks what that cannot settle.

## Shape

```
config/hypr/     the mobile session (Lua, not .conf)
plugins/         shell plugins, installed to ~/.config/omarchy/plugins
bin/             omarchy-phone-* tools
install/         device bring-up fragments
```

Two decisions worth knowing before reading the code, both explained in
`NOTES.md`:

- **The shell is plugins, not a fork.** Quickshell registers the launched config
  root as the QML module `qs`, so a separate phone shell would resolve
  `import qs.Commons` against its own empty root and lose the entire `Ui/` kit.
  The phone bar and app grid run inside upstream's shell host instead.
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
bin/omarchy-phone-plugins-link                   # link into ~/.config/omarchy/plugins
jq '.bar.id = "dev.omarchyphone.bar"' ~/.config/omarchy/shell.json | sponge ...
omarchy-restart-shell
bin/omarchy-phone-plugins-link --unlink          # and back out
```

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
