#!/usr/bin/env python3
"""Generate only the native macOS .icon bundle from the approved SVG layers.

  python3 assets/generate-macos-icon.py          # write Apple bundle only
  python3 assets/generate-macos-icon.py --check  # read-only reproducibility check
  python3 assets/generate-macos-icon.py --validate-compiled path/to/Assets.car

Requires Python 3; compiled inspection additionally requires Xcode assetutil.
No Icon Composer license acceptance, application install, signing, or store upload.
Use only this isolated generator for the native bundle.
Xcode/actool synthesizes the macOS mask, effects and pre-Tahoe ICNS fallback.
"""

import argparse
import copy
import json
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/logo.svg"
LAYERS = ROOT / "assets/icon-layers/macos"
BUNDLE = ROOT / "mac/Sources/SinalSync.icon"
NAMES = ("01-wads-signature.svg", "02-devices.svg", "03-transmission.svg")


def geometry(node):
    """Ignore serialization, namespaces and accessibility titles, not geometry."""
    return (node.tag.rsplit("}", 1)[-1], tuple(sorted(node.attrib.items())),
            tuple(geometry(child) for child in node
                  if child.tag.rsplit("}", 1)[-1] not in ("title", "desc")))


def validate_sources():
    source = ET.parse(SOURCE).getroot()
    shapes = [n for n in source if n.tag.rsplit("}", 1)[-1] not in ("title", "desc")]
    if len(shapes) != 9:
        raise ValueError("Canonical logo.svg structure changed; review layer separation")
    signature = copy.deepcopy(shapes[1])
    signature.attrib.pop("opacity", None)  # opacity belongs to the native layer
    expected = ([signature], shapes[2:6], shapes[6:])
    for name, children in zip(NAMES, expected):
        layer = ET.parse(LAYERS / name).getroot()
        actual = [n for n in layer if n.tag.rsplit("}", 1)[-1] not in ("title", "desc")]
        if [geometry(n) for n in actual] != [geometry(n) for n in children]:
            raise ValueError(f"{name} differs from canonical logo.svg geometry")
        if layer.get("viewBox") != "0 0 256 256":
            raise ValueError(f"Unexpected layer canvas: {name}")


def manifest():
    groups = []
    for index, (filename, title) in enumerate(zip(NAMES, ("WADS signature", "Phone and Mac", "Signal 5G and arrow"))):
        glass = index > 0
        layer = {"image-name": filename, "name": title, "glass": glass,
                 "position": {"scale": 1, "translation-in-points": [0, 0]}}
        if not glass:
            layer["opacity"] = 0.09
        group = {"name": ("01 WADS signature", "02 Devices", "03 Transmission")[index],
                 "layers": [layer], "specular": glass,
                 "shadow": {"kind": "neutral" if glass else "none",
                            "opacity": (0, 0.25, 0.2)[index]},
                 "translucency": {"enabled": glass, "value": 0.12 if glass else 0}}
        if glass:
            group["lighting"] = "combined"
        groups.append(group)
    return {"groups": groups,
            # Xcode 27 template requires an array, NOT the string "shared".
            "supported-platforms": {"squares": ["macOS"]},
            "fill-specializations": [{"value": {"solid": "srgb:0.470588,0.184314,0.603922,1.00000"}}]}


def validate_compiled(path):
    result = subprocess.run(["xcrun", "assetutil", "--info", str(path)],
                            text=True, capture_output=True, check=True)
    records = json.loads(result.stdout)
    groups = [r for r in records if r.get("AssetType") == "IconGroup"]
    required = {"SinalSync/" + g["name"] for g in manifest()["groups"]}
    if not required.issubset({g.get("Name") for g in groups}):
        raise ValueError("Compiled asset catalog is missing native icon groups")
    lit = set()
    light_groups = set()
    for group in groups:
        if group.get("Name") in required and group.get("Appearance") == "NSAppearanceNameAqua":
            light_groups.add(group["Name"])
            layers = group.get("Layers", [])
            if len(layers) != 1 or layers[0].get("AssetType") != "Vector":
                raise ValueError("Native icon group lost its vector layer")
            if layers[0].get("LayerHasLightingEffects"):
                lit.add(group["Name"])
    if light_groups != required:
        raise ValueError("Compiled catalog is missing default-appearance vector groups")
    if not {"SinalSync/02 Devices", "SinalSync/03 Transmission"}.issubset(lit):
        raise ValueError("Compiled catalog is missing native lighting effects")
    stacks = [r for r in records if r.get("AssetType") == "IconImageStack"
              and r.get("Name") == "SinalSync" and r.get("Appearance") == "NSAppearanceNameAqua"]
    if len(stacks) != 1 or stacks[0].get("LayerCount") != 4:
        raise ValueError("Compiled catalog is missing the native four-layer icon stack")
    effects = {layer.get("Name"): layer for layer in stacks[0].get("Layers", [])
               if layer.get("Appearance") == "NSAppearanceNameAqua"}
    for name in ("SinalSync/02 Devices", "SinalSync/03 Transmission"):
        fx = effects.get(name, {})
        if not fx.get("LayerHasSpecular") or not 0 < fx.get("LayerTranslucency", 0) < 1:
            raise ValueError("Compiled stack lost native specular/translucency effects")
    icons = [r for r in records if r.get("AssetType") == "Icon Image" and r.get("Name") == "SinalSync"]
    if not any(r.get("PixelWidth") == 1024 for r in icons):
        raise ValueError("Compiled catalog has no 1024px icon rendition")
    print(f"PASS: {len(required)} native vector groups, device/transmission lighting, 1024px rendition")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate without writing")
    parser.add_argument("--validate-compiled", type=Path, metavar="ASSETS_CAR")
    args = parser.parse_args()
    validate_sources()
    if args.validate_compiled:
        validate_compiled(args.validate_compiled)
        return
    expected = manifest()
    if args.check:
        if json.loads((BUNDLE / "icon.json").read_text()) != expected:
            raise ValueError("icon.json is stale; run generate-macos-icon.py")
        for name in NAMES:
            if (BUNDLE / "Assets" / name).read_bytes() != (LAYERS / name).read_bytes():
                raise ValueError(f"Bundled layer is stale: {name}")
        print("PASS: native bundle matches approved geometry, effects and source layers")
    else:
        (BUNDLE / "Assets").mkdir(parents=True, exist_ok=True)
        for name in NAMES:
            (BUNDLE / "Assets" / name).write_bytes((LAYERS / name).read_bytes())
        (BUNDLE / "icon.json").write_text(json.dumps(expected, indent=2) + "\n")
        print(f"Generated {BUNDLE.relative_to(ROOT)} (3 vector layers, native lighting)")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
