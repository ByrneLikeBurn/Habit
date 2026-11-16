"""Meadow scene. Three hand-placed compositions. Run: python3 meadow.py <out_dir> [a b c]

Not in the brief's list of five and not approved by the owner. Variants for the scene gate only.
"""
from __future__ import annotations

import sys
import numpy as np
from paint import Painting, XN, YN, H, W, smoothstep, save_value, noise
from lake import sky, treeline
from mountains import ridge, haze

XX = XN * W
YP = YN * H


def crown_tree(p, x, base, height, spread, density, seed, above=1.0):
    """One flat-crowned tree: a thin leaning trunk and a wide, shallow canopy with an uneven underside."""
    top = base - height
    lean = 0.012 * ((seed % 5) - 2) / 2
    t = np.clip((base - YN) / max(height, 1e-6), 0, 1)
    trunk = (0.0035 * W * (1.0 - 0.45 * t)) - np.abs(XX - (x + lean * t) * W)          # signed, in pixels
    trunk = np.where((YN > top + 0.3 * height * 0.2) & (YN < base + 0.004), trunk, -9.0)
    rx, ry = spread * W, height * 0.30 * H
    cx, cy = (x + lean) * W, (top + height * 0.22) * H
    under = 1.0 + 0.5 * smoothstep(0.0, 1.0, (YP - cy) / ry)                           # flatter and wider underneath
    canopy = (1.0 - np.sqrt(((XX - cx) / (rx * under)) ** 2 + ((YP - cy) / ry) ** 2)) * ry
    m = np.maximum(p.ragged(trunk, edge=0.8, rough=1.5, fine=1.5, seed=seed) * (trunk > -4),
                   p.ragged(canopy, edge=1.6, rough=3.5, fine=2.5, tooth=1.5, seed=seed + 1) * (canopy > -7)) * above   # no stray specks: a speck in the sky reads as a bird
    p.wash(m, density, rim=0.22, rim_w=3, gran=0.075, flow=0.2, seed=seed + 2)


def swathes(p, y0, y1, n, seed, strength=0.24):
    """Light lying on grass: long, soft, slightly tilted bands of paper kept between y0 and y1."""
    rng = np.random.default_rng(seed)
    for i in range(n):
        cy = y0 + (y1 - y0) * (i + 0.5 + 0.3 * (rng.random() - 0.5)) / n
        tilt = 0.03 * (rng.random() - 0.5); cx = 0.2 + 0.6 * rng.random(); half = 0.25 + 0.3 * rng.random()
        hh = 0.020 + 0.016 * (i / max(n - 1, 1))
        band = np.exp(-((YN - (cy + tilt * (XN - 0.5))) / hh) ** 2) * np.exp(-((XN - cx) / half) ** 4)
        p.lift(strength * band * (0.6 + 0.4 * smoothstep(-1, 1, noise(seed + 7 * i, 3.0, sigma_x=60.0))))


def grass(p, pts, density, seed, fade=None, tooth=2.2):
    """A swell of grassland. Its top edge is fine and broken, like seed heads against the light."""
    prof = p.profile(pts, wobble=0.0025, wobble_sigma=9, seed=seed)
    m = p.ragged(p.below(prof), edge=1.2, rough=2.0, fine=4.0, tooth=tooth, seed=seed + 1)
    d = density if fade is None else density - fade[0] * smoothstep(fade[1], fade[2], YN)
    p.wash(m, d, rim=0.18, rim_w=3, gran=0.085, flow=0.26, flow_sigma=30, flow_aspect=6.0, seed=seed + 2)
    return prof


def variant_a() -> np.ndarray:
    """Open plain. A low horizon and a wide sky. Far pale hills, a loose line of flat-crowned trees, three swells of grass."""
    p = Painting(paper_seed=27)
    above = np.ones_like(YN)
    sky(p, above, top=0.30, reach=0.52, seed=611)
    ridge(p, [(-0.05, .60), (.14, .575), (.30, .59), (.46, .605), (.62, .585), (.80, .57), (1.05, .60)],
          0.20, above, 621, edge=2.4, fade=(0.10, 0.56, 0.66))
    haze(p, 0.635, 0.01, 0.028, 0.55, 626)
    grass(p, [(-0.05, .665), (.2, .655), (.45, .66), (.7, .668), (1.05, .655)], 0.34, 631, fade=(0.10, 0.66, 0.80))
    for i, (x, h, s) in enumerate([(.565, .155, .050), (.640, .200, .066), (.705, .130, .042), (.800, .170, .056), (.905, .105, .036)]):
        crown_tree(p, x, 0.668, h, s, 0.62 + 0.05 * (i % 2), 640 + 9 * i)
    grass(p, [(-0.05, .76), (.18, .745), (.40, .77), (.62, .80), (.84, .775), (1.05, .76)], 0.50, 661, fade=(0.14, 0.76, 0.92))
    swathes(p, 0.70, 0.86, 3, 671)
    grass(p, [(-0.05, .90), (.22, .93), (.46, .905), (.70, .885), (1.05, .915)], 0.80, 681)
    return p.finish()


def variant_b() -> np.ndarray:
    """Slope. One long gentle slope from upper left to lower right, a dark hedge of wood behind it, one tree on the brow."""
    p = Painting(paper_seed=28)
    above = np.ones_like(YN)
    sky(p, above, top=0.28, reach=0.50, seed=711)
    ridge(p, [(-0.05, .52), (.2, .50), (.42, .535), (.62, .56), (.82, .545), (1.05, .53)], 0.22, above, 721, edge=2.4,
          fade=(0.10, 0.50, 0.62))
    haze(p, 0.60, -0.02, 0.03, 0.5, 726)
    wood = p.profile([(-0.05, .47), (.08, .485), (.20, .52), (.32, .57), (.42, .625), (.50, .69), (1.05, 1.1)],
                     wobble=0.003, wobble_sigma=10, seed=731)
    wood = treeline(wood, [(.03, .05, .0060), (.075, .03, .0045), (.13, .045, .0056), (.19, .028, .0042)], canopy=0.02, seed=7)
    m = p.ragged(p.below(wood), edge=1.4, rough=3, fine=3, tooth=1.6, seed=732)
    p.wash(m, 0.66, rim=0.25, rim_w=4, gran=0.08, flow=0.22, seed=733)
    grass(p, [(-0.05, .56), (.15, .585), (.35, .64), (.55, .70), (.75, .745), (1.05, .78)], 0.40, 741, fade=(0.12, 0.60, 0.84))
    crown_tree(p, .665, 0.735, .26, .085, 0.70, 751)
    swathes(p, 0.70, 0.84, 2, 761, strength=0.22)
    grass(p, [(-0.05, .80), (.25, .84), (.5, .88), (.75, .90), (1.05, .93)], 0.74, 771)
    return p.finish()


def variant_c() -> np.ndarray:
    """Tall grass. A high horizon. The viewer stands in the meadow: swells of grass fill the card, with a small copse far off."""
    p = Painting(paper_seed=29)
    above = np.ones_like(YN)
    sky(p, above, top=0.24, reach=0.34, seed=811)
    ridge(p, [(-0.05, .36), (.2, .345), (.45, .37), (.7, .35), (1.05, .365)], 0.18, above, 821, edge=2.4, fade=(0.08, 0.34, 0.44))
    haze(p, 0.405, 0.015, 0.026, 0.5, 826)
    grass(p, [(-0.05, .43), (.25, .42), (.5, .435), (.78, .425), (1.05, .43)], 0.28, 831, fade=(0.08, 0.43, 0.56))
    for i, (x, h, s) in enumerate([(.185, .085, .030), (.235, .115, .040), (.290, .075, .026)]):
        crown_tree(p, x, 0.432, h, s, 0.56, 840 + 9 * i)
    grass(p, [(-0.05, .56), (.2, .54), (.42, .575), (.66, .60), (.86, .57), (1.05, .555)], 0.40, 851, fade=(0.10, 0.56, 0.70))
    swathes(p, 0.47, 0.54, 1, 856, strength=0.22)
    grass(p, [(-0.05, .70), (.2, .73), (.45, .705), (.7, .68), (1.05, .715)], 0.54, 861, fade=(0.12, 0.70, 0.84))
    swathes(p, 0.62, 0.68, 1, 866, strength=0.22)
    grass(p, [(-0.05, .87), (.24, .845), (.5, .88), (.76, .90), (1.05, .86)], 0.82, 871, tooth=3.0)
    swathes(p, 0.775, 0.83, 1, 876, strength=0.22)
    return p.finish()


VARIANTS = {"a": variant_a, "b": variant_b, "c": variant_c}

if __name__ == "__main__":
    out = sys.argv[1]
    for k in sys.argv[2:] or list(VARIANTS):
        save_value(VARIANTS[k](), f"{out}/meadow-{k}-value.png"); print("painted", k)
