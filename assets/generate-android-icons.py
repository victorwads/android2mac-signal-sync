#!/usr/bin/env python3
"""Generate ONLY Android launcher resources from the approved canonical logo.svg artwork.

Usage: python3 assets/generate-android-icons.py [--check]
Requires Python 3, ImageMagick 7, and Swift/AppKit (macOS) or rsvg-convert.
Does not write macOS, shared artwork,
preview or store files. --check compares every generated resource byte-for-byte.
Adaptive layers use the approved exported 108dp safe-zone composition; legacy
PNGs use the original rounded master at 48/72/96/144/192 px.
"""
import argparse
import math
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/logo.svg"
LAYERS = ROOT / "assets/icon-layers/android"
RES = ROOT / "android/app/src/main/res"
SVG = "{http://www.w3.org/2000/svg}"
ANDROID = "{http://schemas.android.com/apk/res/android}"
ET.register_namespace("android", ANDROID[1:-1])
DENSITIES = (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
             ("xxhdpi", 144), ("xxxhdpi", 192))


def attr(name):
    return ANDROID + name


def number(value):
    return format(value, ".12g")


def transform(value):
    """Compose the uniform scale/translation subset used by approved layers."""
    scale, x, y = 1.0, 0.0, 0.0
    pattern = r"(translate|scale)\(([^)]+)\)"
    if re.sub(pattern, "", value).strip():
        raise ValueError(f"Unsupported SVG transform: {value}")
    for op, args in re.findall(pattern, value):
        values = [float(v) for v in re.split(r"[ ,]+", args.strip())]
        if op == "translate":
            x += scale * values[0]
            y += scale * (values[1] if len(values) == 2 else 0)
        else:
            if len(values) == 2 and values[0] != values[1]:
                raise ValueError("Only uniform scale is supported")
            scale *= values[0]
    return {attr("scaleX"): number(scale), attr("scaleY"): number(scale),
            attr("translateX"): number(x), attr("translateY"): number(y)}


def rect_path(el):
    x, y = float(el.get("x", 0)), float(el.get("y", 0))
    w, h = float(el.get("width")), float(el.get("height"))
    rx = min(float(el.get("rx", el.get("ry", 0))), w / 2)
    ry = min(float(el.get("ry", el.get("rx", 0))), h / 2)
    if not rx or not ry:
        return f"M{x} {y} H{x+w} V{y+h} H{x} Z"
    # SVG rect corners are elliptical arcs, not quadratic approximations.
    return (f"M{x+rx} {y} H{x+w-rx} A{rx} {ry} 0 0 1 {x+w} {y+ry} "
            f"V{y+h-ry} A{rx} {ry} 0 0 1 {x+w-rx} {y+h} "
            f"H{x+rx} A{rx} {ry} 0 0 1 {x} {y+h-ry} "
            f"V{y+ry} A{rx} {ry} 0 0 1 {x+rx} {y} Z")


def vector(source, monochrome=False):
    svg = ET.parse(source).getroot()
    if svg.get("viewBox") != "0 0 256 256":
        raise ValueError(f"Unexpected viewBox in {source}")
    root = ET.Element("vector", {attr("width"): "108dp", attr("height"): "108dp",
                                attr("viewportWidth"): "256", attr("viewportHeight"): "256"})

    def walk(el, parent, opacity=1.0):
        kind = el.tag.removeprefix(SVG)
        if kind in ("title", "desc"):
            return
        opacity *= float(el.get("opacity", 1))
        if kind == "g":
            group = ET.SubElement(parent, "group", transform(el.get("transform", "")))
            # The signature paths do not overlap, so per-path opacity faithfully
            # represents this SVG group without flattening into an opaque color.
            for child in el:
                walk(child, group, opacity)
            return
        if kind not in ("rect", "path"):
            raise ValueError(f"Unsupported SVG element: {kind}")
        if el.get("transform"):
            raise ValueError("Path transforms must be expressed by a group")
        fill, stroke = el.get("fill", "#000000"), el.get("stroke")
        if monochrome:
            fill = "none" if fill in ("none", "#782F9A") else "#FFFFFF"
            stroke = "#FFFFFF" if stroke else None
        path = {attr("pathData"): rect_path(el) if kind == "rect" else el.attrib["d"],
                attr("fillColor"): "#00000000" if fill == "none" else fill}
        fill_alpha = opacity * float(el.get("fill-opacity", 1))
        if fill != "none" and not math.isclose(fill_alpha, 1):
            path[attr("fillAlpha")] = number(fill_alpha)
        if stroke:
            path.update({attr("strokeColor"): stroke,
                         attr("strokeWidth"): el.get("stroke-width", "1"),
                         attr("strokeLineCap"): el.get("stroke-linecap", "butt"),
                         attr("strokeLineJoin"): el.get("stroke-linejoin", "miter")})
            stroke_alpha = opacity * float(el.get("stroke-opacity", 1))
            if not math.isclose(stroke_alpha, 1):
                path[attr("strokeAlpha")] = number(stroke_alpha)
        if el.get("fill-rule") == "evenodd":
            path[attr("fillType")] = "evenOdd"
        ET.SubElement(parent, "path", path)

    for element in svg:
        walk(element, root)
    ET.indent(root)
    return (ET.tostring(root, encoding="unicode") + "\n").encode()


def rasterize(source, destination):
    """Use a full SVG renderer: ImageMagick MSVG drops strokes in this artwork."""
    if sys.platform == "darwin":
        helper = destination.parent / "render.swift"
        helper.write_text('''import AppKit
let source = CommandLine.arguments[1]
let target = CommandLine.arguments[2]
guard let image = NSImage(contentsOfFile: source) else { fatalError("Cannot load SVG") }
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
image.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024),
    from: .zero, operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: target))
''', encoding="utf-8")
        subprocess.run(["swift", "-module-cache-path", str(destination.parent / "swift-cache"),
                        str(helper), str(source), str(destination)], check=True)
    elif shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", "-w", "1024", "-h", "1024", "-o",
                        str(destination), str(source)], check=True)
    else:
        raise SystemExit("A full SVG renderer is required: Swift/AppKit on macOS or rsvg-convert")
    # Catch incomplete SVG rendering (e.g. MSVG silently omitting every stroke).
    pixels = subprocess.check_output(["magick", str(destination), "-depth", "8", "RGBA:-"])
    white = orange = 0
    for i in range(0, len(pixels), 4):
        r, g, b, a = pixels[i:i+4]
        white += a > 240 and min(r, g, b) > 230
        orange += a > 240 and r > 230 and 60 < g < 150 and b < 100
    if white < 1000 or orange < 1000:
        raise ValueError("Incomplete SVG rasterization: missing white/orange foreground")


def generate(destination):
    def put(relative, content):
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)

    for kind in ("background", "foreground", "monochrome"):
        layer = "foreground" if kind == "monochrome" else kind
        put(f"drawable/signal_launcher_{kind}.xml",
            vector(LAYERS / f"{layer}.svg", kind == "monochrome"))
    for api in (26, 33):
        mono = ('  <monochrome android:drawable="@drawable/signal_launcher_monochrome" />\n'
                if api == 33 else "")
        put(f"mipmap-anydpi-v{api}/signal_launcher.xml", (
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '  <background android:drawable="@drawable/signal_launcher_background" />\n'
            '  <foreground android:drawable="@drawable/signal_launcher_foreground" />\n'
            + mono + '</adaptive-icon>\n').encode())
    master = destination / "legacy-master.png"
    rasterize(SOURCE, master)
    for density, size in DENSITIES:
        target = destination / f"mipmap-{density}/signal_launcher.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["magick", str(master),
                        "-resize", f"{size}x{size}", "-strip", "-define",
                        "png:exclude-chunks=date,time", "PNG32:" + str(target)], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if resources are out of date")
    args = parser.parse_args()
    if not shutil.which("magick"):
        parser.error("ImageMagick 7 is required (brew install imagemagick)")
    with tempfile.TemporaryDirectory(prefix="signal-sync-android-icons-") as temp:
        generated = Path(temp)
        generate(generated)
        files = sorted([*(generated / "drawable").glob("*.xml"),
                        *(generated / "mipmap-anydpi-v26").glob("*.xml"),
                        *(generated / "mipmap-anydpi-v33").glob("*.xml"),
                        *(generated / f"mipmap-{density}" / "signal_launcher.png"
                          for density, _ in DENSITIES)])
        changed = []
        for path in files:
            target = RES / path.relative_to(generated)
            if not target.exists() or path.read_bytes() != target.read_bytes():
                changed.append(str(target.relative_to(ROOT)))
                if not args.check:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(path, target)
        if args.check and changed:
            raise SystemExit("Out-of-date Android icons:\n" + "\n".join(changed))
        print(f"{'Verified' if args.check else 'Generated'} {len(files)} Android resources; "
              f"{len(changed)} {'out of date' if args.check else 'changed'}. No other platform touched.")


if __name__ == "__main__":
    main()
