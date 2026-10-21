#!/usr/bin/env python3
"""Generate native app icons from logo.svg. Requires Python 3 and ImageMagick 7."""
import json
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
SVG = ASSETS / "logo.svg"
NS = {"s": "http://www.w3.org/2000/svg"}

def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)

def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text + "\n", encoding="utf-8")

def main():
    if not shutil.which("magick"):
        raise SystemExit("Install ImageMagick first: brew install imagemagick")
    tree = ET.parse(SVG)
    color = tree.find("s:rect[@id='background']", NS).attrib["fill"]
    symbol = tree.find("s:g[@id='symbol']", NS)
    catalog = ROOT / "mac/Sources/Assets.xcassets"
    appicon = catalog / "AppIcon.appiconset"
    appicon.mkdir(parents=True, exist_ok=True)
    write(catalog / "Contents.json", json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))
    images = []
    with tempfile.TemporaryDirectory(prefix="signal-sync-icons-") as temp:
        master = Path(temp) / "master.png"
        run("magick", "-background", "none", SVG, "-resize", "1024x1024", master)
        shutil.copyfile(master, ASSETS / "logo-preview.png")
        for size in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                filename = f"icon_{size}x{size}@{scale}x.png"
                run("magick", master, "-resize", f"{size * scale}x{size * scale}", appicon / filename)
                images.append({"idiom": "mac", "size": f"{size}x{size}", "scale": f"{scale}x", "filename": filename})
        res = ROOT / "android/app/src/main/res"
        for density, size in (("mdpi",48), ("hdpi",72), ("xhdpi",96), ("xxhdpi",144), ("xxxhdpi",192)):
            target = res / f"mipmap-{density}" / "signal_launcher.png"
            target.parent.mkdir(parents=True, exist_ok=True)
            run("magick", master, "-resize", f"{size}x{size}", target)
    write(appicon / "Contents.json", json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2))
    # The foreground fits inside the adaptive icon's central safe zone.
    paths = []
    for path in symbol:
        rule = ' android:fillType="evenOdd"' if path.get("fill-rule") == "evenodd" else ""
        paths.append(f'    <path android:fillColor="#FFFFFFFF"{rule} android:pathData="{path.attrib["d"]}" />')
    vector = '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">\n  <group android:scaleX="0.075" android:scaleY="0.075" android:translateX="15.6" android:translateY="15.6">\n' + "\n".join(paths) + '\n  </group>\n</vector>'
    write(res / "drawable/signal_launcher_foreground.xml", vector)
    write(res / "drawable/signal_launcher_background.xml", f'<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><solid android:color="{color}" /></shape>')
    adaptive = '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n  <background android:drawable="@drawable/signal_launcher_background" />\n  <foreground android:drawable="@drawable/signal_launcher_foreground" />\n</adaptive-icon>'
    write(res / "mipmap-anydpi-v26/signal_launcher.xml", adaptive)
    write(res / "mipmap-anydpi-v33/signal_launcher.xml", adaptive.replace('</adaptive-icon>', '  <monochrome android:drawable="@drawable/signal_launcher_foreground" />\n</adaptive-icon>'))
    print("Generated macOS AppIcon, Android legacy/adaptive/themed icons and assets/logo-preview.png")

if __name__ == "__main__":
    main()
