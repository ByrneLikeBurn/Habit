"""Mountains scene. Three hand-placed compositions. Run: python3 mountains.py <out_dir> [a b c]

Not approved by the owner. These are variants for the scene gate. Nothing here ships until one is approved.
"""
from __future__ import annotations

import sys
import numpy as np
from paint import Painting, XN, YN, H, W, smoothstep, save_value, noise
from lake import treeline, sky, water, ripples


def ridge(p, pts, density, above, seed, edge=2.0, rim=0.28, gran=0.068, wobble=0.005, sigma=18, fade=None):
    prof = p.profile(pts, wobble=wobble, wobble_sigma=sigma, seed=seed)
    m = p.ragged(p.below(prof), edge=edge, rough=4, fine=2.5, seed=seed + 1) * above
    d = density if fade is None else density - fade[0] * smoothstep(fade[1], fade[2], YN)
    p.wash(m, d, rim=rim, rim_w=5, gran=gran, flow=0.18, seed=seed + 2)
    return prof, m


def snow(p, prof, m, depth, seed, lit=1.0):
    """Bare paper kept on the side of each summit that faces the light, broken by rock ribs at uneven spacing. No outline."""
    from scipy import ndimage as ndi
    rng = np.random.default_rng(seed)
    t = ndi.gaussian_filter1d(rng.standard_normal(W), 26.0); t /= t.std()
    reach = depth * np.clip(0.9 + 0.35 * t, 0.45, 1.5)                          # the snow line wanders slowly: no scallops
    yy = np.arange(H)[:, None] * np.ones((1, W))
    below = yy - prof[None, :]                                                 # pixels under the ridge
    cap = smoothstep(7.0, -7.0, below - (reach * H)[None, :]) * m
    slope = ndi.gaussian_filter1d(np.gradient(prof), 16.0)
    face = smoothstep(0.03, -0.12, slope)[None, :]                             # 1 where the ridge climbs to the right: the face toward the light
    u = np.arange(W)[None, :] + 0.9 * below                                    # ribs run down and to the left, along the fall of the slope
    n = ndi.gaussian_filter1d(rng.standard_normal(3 * W), 7.0); n /= n.std()
    ribs = smoothstep(0.55, 1.05, n[np.clip(u.astype(int) + W, 0, 3 * W - 1)])
    p.lift(0.86 * cap * face * (1.0 - 0.9 * ribs))


def haze(p, y0, tilt, height, strength, seed):
    """Mist that lies along a valley: its line tilts and wanders, its depth varies, and it thins out in places."""
    n = noise(seed, 3.0, sigma_x=120.0); n = n[H // 2][None, :] if n.ndim == 2 else n
    w = noise(seed + 1, 3.0, sigma_x=80.0); w = w[H // 3][None, :]
    yc = y0 + tilt * (XN - 0.5) + 0.018 * n
    hh = height * (1.0 + 0.45 * w)
    thin = smoothstep(-1.2, 0.4, noise(seed + 2, 3.0, sigma_x=150.0)[H // 4][None, :])
    p.lift(strength * np.exp(-((YN - yc) / np.maximum(hh, 0.02)) ** 2) * (0.35 + 0.65 * thin))


def variant_a() -> np.ndarray:
    """Massif. One broad snow peak right of centre, a lower shoulder to the left, mist in the valley, a dark wooded spur."""
    p = Painting(paper_seed=17)
    yh = 0.66
    above = np.ones_like(YN)
    sky(p, above, top=0.32, reach=0.50, seed=311)

    prof, m = ridge(p, [(-0.05, .43), (.10, .40), (.22, .33), (.30, .355), (.40, .30), (.50, .21), (.585, .115),
                        (.63, .135), (.70, .10), (.77, .19), (.86, .27), (.95, .25), (1.05, .30)],
                    0.40, above, 321, wobble=0.007, sigma=12, fade=(0.26, 0.20, yh))
    snow(p, prof, m, 0.085, 325)
    p.mist(yh - 0.14, 0.07, 0.70, seed=326)

    ridge(p, [(-0.05, .50), (.12, .47), (.26, .52), (.40, .56), (.55, .53), (.70, .49), (.84, .52), (1.05, .47)],
          0.42, above, 331, fade=(0.20, 0.48, yh + 0.05))
    p.mist(yh - 0.03, 0.04, 0.55, seed=336)

    ridge(p, [(-0.05, .66), (.15, .64), (.34, .67), (.52, .71), (.70, .68), (.88, .63), (1.05, .60)],
          0.52, above, 341, fade=(0.16, 0.64, 0.86))
    near = p.profile([(-0.05, .60), (.06, .63), (.16, .69), (.26, .76), (.36, .84), (.46, .93), (.56, 1.02), (1.05, 1.2)],
                     wobble=0.003, wobble_sigma=10, seed=351)
    near = treeline(near, [(.030, .040, .0120), (.105, .046, .0140), (.185, .034, .0120)],
                    canopy=0.024, seed=5)                    # one wood with an uneven top and a few low tips: tall thin tips read as towers
    m = p.ragged(p.below(near), edge=1.3, rough=3, fine=3, tooth=1.6, seed=352)
    p.wash(m, 0.84, rim=0.25, rim_w=4, gran=0.080, flow=0.22, seed=353)
    return p.finish()


def variant_b() -> np.ndarray:
    """Ranges. Five ridges, one behind the other, pale to dark, with mist lying between them. No snow."""
    p = Painting(paper_seed=18)
    above = np.ones_like(YN)
    sky(p, above, top=0.26, reach=0.30, seed=411)
    rows = [
        ([(-0.05, .34), (.12, .30), (.24, .22), (.33, .26), (.46, .31), (.60, .23), (.70, .16), (.745, .125), (.80, .20), (.88, .27), (1.05, .33)], 0.24, .30),
        ([(-0.05, .40), (.10, .43), (.25, .38), (.40, .33), (.52, .39), (.68, .43), (.84, .36), (1.05, .40)], 0.32, .42),
        ([(-0.05, .56), (.14, .50), (.28, .46), (.42, .52), (.58, .57), (.74, .52), (.90, .47), (1.05, .50)], 0.42, .55),
        ([(-0.05, .62), (.18, .66), (.36, .70), (.52, .66), (.66, .61), (.82, .65), (1.05, .72)], 0.56, .70),
        ([(-0.05, .86), (.16, .80), (.32, .77), (.50, .82), (.70, .88), (.86, .84), (1.05, .80)], 0.80, .88),
    ]
    for i, (pts, d, base) in enumerate(rows):
        prof, m = ridge(p, pts, d, above, 421 + 20 * i, edge=2.4 - 0.25 * i, gran=0.060 + 0.005 * i, sigma=22 - 3 * i,
                        fade=(d * 0.55, base - 0.06, base + 0.10))
        if i == 0:                                             # one small cap of bare paper on the far summit, on the side toward the light
            yy = np.arange(H)[:, None] * np.ones((1, W))
            cap = smoothstep(0.05 * H, 0.008 * H, yy - prof[None, :]) * m * np.exp(-((XN - 0.722) / 0.044) ** 2) * smoothstep(0.75, 0.73, XN)
            p.lift(0.92 * cap)
        if i < 4: haze(p, base + (0.05, 0.07, 0.045, 0.065)[i], (0.03, -0.04, 0.05, -0.025)[i], (0.034, 0.048, 0.032, 0.040)[i], 0.58 - 0.09 * i, 430 + 20 * i)
    return p.finish()


def variant_c() -> np.ndarray:
    """Tarn. The fold: two steep snow peaks and a dark scree slope, mirrored in a small still water."""
    p = Painting(paper_seed=19)
    yw = 0.60
    above = smoothstep(yw + 0.004, yw - 0.004, YN)
    sky(p, above, top=0.30, reach=0.50, seed=511)
    land0 = p.T.copy()

    prof, m = ridge(p, [(-0.05, .40), (.08, .36), (.18, .25), (.25, .15), (.30, .19), (.38, .30), (.47, .36), (.56, .29),
                        (.64, .17), (.69, .12), (.75, .20), (.84, .31), (.94, .37), (1.05, .40)],
                    0.40, above, 521, wobble=0.008, sigma=10, fade=(0.22, 0.24, yw))
    snow(p, prof, m, 0.075, 525)
    p.mist(yw - 0.06, 0.05, 0.62, seed=526)

    ridge(p, [(-0.05, .52), (.14, .50), (.30, .53), (.46, .56), (.62, .54), (.80, .55), (1.05, .51)],
          0.44, above, 531, fade=(0.16, 0.50, yw))
    scree = p.profile([(-0.05, yw + .30), (.52, yw + .10), (.60, yw + .01), (.68, .56), (.78, .50), (.88, .43),
                       (.97, .385), (1.05, .36)], wobble=0.004, wobble_sigma=10, seed=541)
    scree = treeline(scree, [(.750, .040, .0080), (.822, .052, .0095), (.900, .040, .0085), (.962, .056, .0100)],
                     canopy=0.022, seed=6)
    m = p.ragged(p.below(scree), edge=1.3, rough=3, fine=3, tooth=1.6, seed=542) * above
    p.wash(m, 0.84, rim=0.25, rim_w=4, gran=0.080, flow=0.22, seed=543)

    land = p.T / np.maximum(land0, 1e-6)
    water(p, yw, land, near=0.24, far=0.04, seed=551, squash=0.84)
    ripples(p,
        lights=[(.24, .655, .10, .0050, .55), (.60, .650, .12, .0048, .55), (.40, .720, .12, .0066, .55),
                (.78, .740, .09, .0070, .50), (.22, .810, .12, .0088, .50), (.58, .860, .15, .0100, .50)],
        darks=[(.48, .780, .09, .0066, .22), (.80, .850, .10, .0085, .26), (.30, .920, .14, .0105, .28)])
    return p.finish()


VARIANTS = {"a": variant_a, "b": variant_b, "c": variant_c}

if __name__ == "__main__":
    out = sys.argv[1]
    for k in sys.argv[2:] or list(VARIANTS):
        save_value(VARIANTS[k](), f"{out}/mountains-{k}-value.png"); print("painted", k)
