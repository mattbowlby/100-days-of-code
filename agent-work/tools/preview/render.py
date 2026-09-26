#!/usr/bin/env python3
"""Render phone plugins offscreen through stubbed Quickshell and composite them
the way Hyprland would: wallpaper, then layers in order, blurring what sits
under any namespace that has a blur layer rule."""
import json, os, re, shutil, subprocess, sys, pathlib
from PIL import Image, ImageFilter, ImageDraw

HERE = pathlib.Path(__file__).resolve().parent
# An Omarchy source tree or install: themes/, applications/icons/ and
# shell/Commons/ are read from it.
OMARCHY = pathlib.Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy"))

def preprocess(src, dst):
    if dst.exists(): shutil.rmtree(dst)
    shutil.copytree(src, dst)
    for f in dst.rglob("*.qml"):
        s = f.read_text()
        s = s.replace("WlrLayershell.namespace:", "wlrNamespace:")
        s = s.replace("WlrLayershell.layer:", "wlrLayer:")
        s = s.replace("WlrLayershell.keyboardFocus:", "wlrKeyboardFocus:")
        s = s.replace("WlrLayershell.exclusiveZone:", "exclusiveZone:")
        s = re.sub(r"^(\s*)screen: modelData", r"\1fakeScreen: modelData", s, flags=re.M)
        f.write_text(s)

def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--plugin", action="append", required=True, help="dir:File.qml[:open]")
    ap.add_argument("--w", type=int, default=360); ap.add_argument("--h", type=int, default=780)
    ap.add_argument("--scale", type=int, default=3)
    ap.add_argument("--theme", default="tokyo-night"); ap.add_argument("--wallpaper", default="")
    ap.add_argument("--blur", default="omarchy-phone-bar,omarchy-phone-home,omarchy-phone-control,omarchy-phone-keyboard")
    ap.add_argument("--out", required=True)
    ap.add_argument("--apps", default="", help="JSON list of {id,name,icon}; default: Omarchy's web-app icons")
    ap.add_argument("--actions", default="", help="JS run after load, with `plugins` array in scope")
    a = ap.parse_args()

    import tempfile
    work = pathlib.Path(os.environ.get("PREVIEW_WORK") or tempfile.mkdtemp(prefix="omarchy-phone-preview-"))
    work.mkdir(parents=True, exist_ok=True)
    # Stubs are copied per run: PreviewEnv.qml is generated into them, and two
    # runs sharing one copy would share one HOME.
    stubs = work / "stubs"
    if stubs.exists(): shutil.rmtree(stubs)
    shutil.copytree(HERE / "stubs", stubs)
    (stubs / "qs").mkdir()
    (stubs / "qs" / "Commons").symlink_to(OMARCHY / "shell" / "Commons")
    home = work / "home"; theme = home / ".local/state/omarchy/current/theme"
    theme.mkdir(parents=True, exist_ok=True)
    shutil.copy(OMARCHY / "themes" / a.theme / "colors.toml", theme / "colors.toml")
    env = {"HOME": str(home), "OMARCHY_PATH": str(OMARCHY), "PREVIEW_W": a.w, "PREVIEW_H": a.h, "TOPLEVELS": os.environ.get("TOPLEVELS", "")}
    (stubs / "Quickshell/PreviewEnv.qml").write_text(
        "pragma Singleton\nimport QtQuick\nQtObject { property var values: %s }\n" % json.dumps(env))

    loads = []
    for i, spec in enumerate(a.plugin):
        parts = spec.split(":")
        d = pathlib.Path(parts[0]).resolve(); dst = work / f"p{i}"
        preprocess(d, dst)
        loads.append({"url": (dst / parts[1]).as_uri(), "open": len(parts) > 2 and parts[2] == "open"})

    if a.apps:
        apps_json = pathlib.Path(a.apps).read_text()
    else:
        icons = OMARCHY / "applications" / "icons"
        apps_json = json.dumps([{"id": p.stem, "name": p.stem, "icon": str(p)} for p in sorted(icons.glob("*.png"))])

    shots = work / "shots"
    if shots.exists(): shutil.rmtree(shots)
    shots.mkdir()
    main_qml = work / "main.qml"
    main_qml.write_text((HERE / "main.qml.in").read_text()
        .replace("@LOADS@", json.dumps(loads)).replace("@APPS@", apps_json)
        .replace("@SHOTS@", str(shots)).replace("@W@", str(a.w)).replace("@H@", str(a.h))
        .replace("@SCALE@", str(a.scale)).replace("@ACTIONS@", a.actions))
    penv = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                QML_XHR_ALLOW_FILE_READ="1", QML_IMPORT_PATH=str(stubs),
                QT_SCALE_FACTOR=str(a.scale), HOME=str(home))
    r = subprocess.run([os.environ.get("QML", "/usr/lib/qt6/bin/qml"), str(main_qml)], env=penv, capture_output=True, text=True, timeout=120)
    log = r.stdout + r.stderr
    metas = [json.loads(l.split("SHOT ", 1)[1]) for l in log.splitlines() if "SHOT " in l]
    for l in log.splitlines():
        if "SHOT " not in l and ("Warning" in l or "Error" in l or "rror:" in l or "EXEC" in l or "qml:" in l or "TypeError" in l):
            print(l)
    if not metas:
        print(log); sys.exit(1)

    S = a.scale; W, H = a.w * S, a.h * S
    wp = pathlib.Path(a.wallpaper) if a.wallpaper else sorted((OMARCHY / "themes" / a.theme / "backgrounds").iterdir())[0]
    canvas = Image.open(wp).convert("RGBA")
    k = max(W / canvas.width, H / canvas.height)
    canvas = canvas.resize((round(canvas.width * k), round(canvas.height * k)), Image.LANCZOS)
    l0, t0 = (canvas.width - W) // 2, (canvas.height - H) // 2
    canvas = canvas.crop((l0, t0, l0 + W, t0 + H))
    blurred_ns = set(a.blur.split(","))
    for m in sorted(metas, key=lambda m: (m["layer"], m["order"])):
        if not m["visible"]: continue
        x, y, w, h = [round(v * S) for v in (m["x"], m["y"], m["w"], m["h"])]
        raw = Image.open(m["file"])
        if raw.mode == "RGB":
            # The software grab sometimes drops the alpha channel; a surface
            # whose transparent pixels came back black gets them back here.
            raw = raw.convert("RGBA")
            px = raw.getdata()
            raw.putdata([(r, g, b, 0) if (r, g, b) == (0, 0, 0) else (r, g, b, 255) for (r, g, b, _) in px])
        img = raw.convert("RGBA").resize((w, h))
        bg = Image.new("RGBA", (w, h), tuple(m["color"]))
        layer = Image.alpha_composite(bg, img)
        if m["ns"] in blurred_ns:
            # Hyprland blurs what is under the surface wherever its alpha passes
            # ignore_alpha, then draws the surface over the blur.
            region = canvas.crop((x, y, x + w, y + h)).filter(ImageFilter.GaussianBlur(10 * S))
            mask = layer.getchannel("A").point(lambda v: 255 if v > 0.05 * 255 else 0)
            canvas.paste(region, (x, y), mask)
        canvas.alpha_composite(layer, (x, y))
    canvas.convert("RGB").save(a.out)
    print("wrote", a.out, [ (m["ns"], m["visible"]) for m in metas ])

main()
