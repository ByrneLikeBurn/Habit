"""Writes docs/tint-luts.json: the tint lookup tables for every palette and appearance.

The Swift tint is tested against this file. If the two differ, the scene card no longer
matches the approved art. Run: python3 tools/scenes/export_luts.py
"""
import json
import pathlib

import numpy as np

import tint as T

out = {"note": "256 sRGB colours per ramp, index 0 is bare paper and 255 is the darkest pigment. Written by tools/scenes/export_luts.py.",
       "verticalBlend": "smoothstep of y from 0 at the top edge to 1 at the bottom edge", "luts": {}}
for pal in T.PALETTES:
    for app in ("paper", "ink"):
        top, bottom = T.luts(pal, app)
        hexes = lambda lut: ["#%02X%02X%02X" % tuple(int(v) for v in np.clip(c * 255 + 0.5, 0, 255)) for c in lut]
        out["luts"][f"{pal}/{app}"] = {"top": hexes(top), "bottom": hexes(bottom)}
path = pathlib.Path(__file__).resolve().parents[2] / "docs" / "tint-luts.json"
path.write_text(json.dumps(out, separators=(",", ":")) + "\n")
print(path, path.stat().st_size)
