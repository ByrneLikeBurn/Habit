"""Experiment, 16 November 2026: does a scene read as watercolour with two pigments and wet edges?

    python3 wet.py <out.jpg>

The owner said the scenes read as monochrome drawings. Three things are tried here on Redwoods A, with no floating foliage:
1. Two pigments. A second small layer says where the earth pigment goes (trunks, floor) and where the leaf pigment goes.
2. Wet into wet. Far shapes lose their edges and pigments bleed into each other where they meet.
3. Less stipple. The even grain reads as print, not paint.
Nothing here is in the app's method yet. The scene art decision in CLAUDE.md is one value layer. Changing it is the owner's.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
import redwoods
from tint import ramp_lut, hex_rgb, tint, to_image, PALETTES, PAPER, NIGHT_PAPER

EARTH = {"midday": ["#EBCBA8", "#C98F60", "#8A5230", "#40230F"], "sunrise": ["#F0C9A0", "#D39A62", "#8E5A34", "#452711"],
         "night": ["#B5A6B8", "#86708A", "#54405C", "#281E33"]}


def paint():
    trees = [(.300, .08, 1.0, 0), (.372, .14, 1.2, 0), (.455, .06, .9, 0), (.535, .16, 1.1, 0), (.628, .10, 1.0, 0), (.700, .20, 1.2, 0), (.770, .07, .9, 0),
             (.238, .42, 1.0, .004), (.418, .52, 1.15, -.003), (.585, .36, .9, .003), (.672, .60, 1.0, -.004), (.805, .46, 1.1, .002),
             (.085, 1.0, 1.15, .010), (.930, .86, 1.0, -.008)]
    far = [(x, .685 + .012 * (i % 3), .07, 6) for i, x in enumerate(np.linspace(.20, .84, 11))]
    mid = [(.20, .82, .13, 8), (.31, .78, .11, 7), (.47, .85, .14, 8), (.56, .79, .11, 7), (.63, .87, .14, 8), (.76, .82, .13, 8), (.86, .79, .11, 7)]
    near = [(.17, .955, .21, 9), (.31, .965, .19, 9), (.45, .945, .22, 10), (.60, .965, .20, 9), (.74, .95, .22, 10), (.88, .965, .20, 9), (1.0, .95, .19, 8)]
    v = redwoods.grove(57, trees, far, mid, near, [], [])
    small = lambda a: np.asarray(Image.fromarray(a.astype(np.float32), mode="F").resize((v.shape[1], v.shape[0]), Image.LANCZOS)).astype(float)
    return v, np.clip(small(redwoods.MIX), 0, 1), np.clip(small(redwoods.SOFT), 0, 1)


def wet(v, mix, soft):
    v = ndi.gaussian_filter(v, 0.8)                                            # less stipple
    s = 0.9 * ndi.gaussian_filter(soft, 4.0) ** 1.2
    v = v * (1 - s) + ndi.gaussian_filter(v, 3.2) * s                          # far shapes were painted into wet paper
    return v, ndi.gaussian_filter(mix, 5.0)                                    # pigments bleed where they meet


def colour(v, mix, palette):
    pp = NIGHT_PAPER if palette == "night" else PAPER
    la, lb = ramp_lut(PALETTES[palette][0], pp), ramp_lut(EARTH[palette], pp)
    idx = np.clip(((1.0 - v) * 255 + 0.5).astype(int), 0, 255)
    return la[idx] * (1 - mix[..., None]) + lb[idx] * mix[..., None]


if __name__ == "__main__":
    v, mix, soft = paint()
    vw, mw = wet(v, mix, soft)
    cells = [to_image(tint(v, "midday")), to_image(colour(vw, mw, "midday")), to_image(colour(vw, mw, "sunrise")), to_image(colour(vw, mw, "night"))]
    pad = 14; w, h = cells[0].size
    sheet = Image.new("RGB", (w + 2 * pad, (h + pad) * len(cells) + pad), (250, 248, 244))
    for i, c in enumerate(cells): sheet.paste(c, (pad, pad + i * (h + pad)))
    sheet.save(sys.argv[1], quality=90); print(sheet.size)
    for i, c in enumerate(cells[:2]): c.resize((350, 118), Image.LANCZOS).save(f"/tmp/blind/card-3{i + 1}-midday.png")
