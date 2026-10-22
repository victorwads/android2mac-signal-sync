#!/usr/bin/env python3
"""Build local Google Play artwork; never uploads or changes any store data.

Input: approved icon-layers/master/composite.svg (no launcher safe-zone scale).
Output: final 512px PNG32 icon only. --check verifies without writing.
Requires ImageMagick 7 and Swift/AppKit (macOS) or rsvg-convert.
No drafts, feature graphics, uploads or external mutations are produced.
"""
import argparse
import hashlib
import shutil
import struct
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCE = ROOT / "assets/icon-layers/master/composite.svg"
NS = {"s": "http://www.w3.org/2000/svg"}
PURPLE = "#782F9A"
WHITE = "#FFF8FD"
ORANGE = "#FF693D"


def run(*args):
    return subprocess.check_output([str(x) for x in args], text=True).strip()


def rasterize(source, destination):
    """Native SVG renderer; MSVG silently drops the approved stroked paths."""
    if sys.platform == "darwin" and shutil.which("swift"):
        helper = destination.parent / "render.swift"
        helper.write_text("import AppKit\nlet source = CommandLine.arguments[1]\nlet target = CommandLine.arguments[2]\nguard let image = NSImage(contentsOfFile: source) else { fatalError(\"Cannot load SVG\") }\nlet bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,\n    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,\n    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!\nNSGraphicsContext.saveGraphicsState()\nNSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)\nimage.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024),\n    from: .zero, operation: .copy, fraction: 1)\nNSGraphicsContext.restoreGraphicsState()\ntry bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: target))\n", encoding="utf-8")
        run("swift", "-module-cache-path", destination.parent / "swift-cache", helper, source, destination)
    elif shutil.which("rsvg-convert"):
        run("rsvg-convert", "-w", "1024", "-h", "1024", "-o", destination, source)
    else:
        raise SystemExit("A full SVG renderer is required: Swift/AppKit or rsvg-convert")
    pixels = subprocess.check_output(["magick", str(destination), "-depth", "8", "RGBA:-"])
    white = orange = 0
    for i in range(0, len(pixels), 4):
        r, g, b, a = pixels[i:i+4]
        white += a > 240 and min(r, g, b) > 230
        orange += a > 240 and r > 230 and 60 < g < 150 and b < 100
    assert white > 1000 and orange > 1000, "Incomplete SVG rasterization"


def verify(path, size, png_color_type):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    assert (width, height) == size, (path, width, height)
    assert depth == 8 and color == png_color_type, (depth, color)
    assert run("magick", "identify", "-format", "%[colorspace]", path) == "sRGB"
    assert run("magick", "identify", "-format", "%[opaque]", path) == "True"
    assert len(data) < 1024 * 1024, (path, len(data))
    print(f"PASS {path.name}: {width}x{height}, 8-bit, PNG type {color}, opaque sRGB, {len(data)} bytes; sha256={hashlib.sha256(data).hexdigest()}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify final icon without writing")
    args = parser.parse_args()
    if not shutil.which("magick"):
        parser.error("ImageMagick 7 (magick) is required")
    source = ET.parse(SOURCE).getroot()
    base = source.find("s:rect", NS)
    assert base is not None and base.get("x") == "0" and base.get("width") == "256"
    assert base.get("fill") == PURPLE and not base.get("rx"), "Full-bleed square source required"
    curve = source.find("s:path[@id='curva-e-primeira-barra']", NS)
    assert curve is not None and curve.get("stroke-width") == "8", "Approved connected curve required"
    icon = HERE / "icon-512.png"
    with tempfile.TemporaryDirectory(prefix="signal-sync-play-icon-") as temp:
        raster = Path(temp) / "master.png"
        generated = Path(temp) / "icon-512.png"
        rasterize(SOURCE, raster)
        run("magick", raster, "-resize", "512x512", "-depth", "8", "-colorspace", "sRGB",
            "-define", "png:exclude-chunks=date,time", "PNG32:" + str(generated))
        verify(generated, (512, 512), 6)
        if args.check:
            if not icon.exists() or icon.read_bytes() != generated.read_bytes():
                raise SystemExit("Out-of-date Google Play icon; run assets/store/google-play/generate.py")
            print("PASS: final Play icon is reproducible; no files changed")
        else:
            icon.write_bytes(generated.read_bytes())
            print("Generated final icon only; no feature graphic or external mutation")
    print("Source sha256=" + hashlib.sha256(SOURCE.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
