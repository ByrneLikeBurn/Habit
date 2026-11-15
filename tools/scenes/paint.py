"""Raster wash painter for Habit scene art.

A scene is a list of hand-placed shapes. Each shape is laid down as a wash on a
transmittance layer T (1.0 is bare paper, 0.0 is the darkest pigment). Washes
glaze by multiplying. The output is one greyscale value layer per scene.

Offline tool. It is not part of the app and the app does not depend on it.
Needs numpy, scipy and Pillow.
"""
from __future__ import annotations

import numpy as np
from scipy import ndimage as ndi
from scipy.interpolate import PchipInterpolator
from PIL import Image

# Card is 350 x 118 pt. The master is painted at 3x with 2x supersampling.
PT_W, PT_H = 350, 118
SCALE = 3
SS = 2
W, H = PT_W * SCALE * SS, PT_H * SCALE * SS  # 2100 x 708 working pixels


def _rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def noise(seed: int, sigma: float, shape=(H, W), sigma_x: float | None = None) -> np.ndarray:
    """Smooth noise with unit standard deviation. sigma is in working pixels."""
    n = _rng(seed).standard_normal(shape)
    sx = sigma if sigma_x is None else sigma_x
    n = ndi.gaussian_filter(n, (sigma, sx), mode="reflect")
    return n / (n.std() + 1e-9)


def fbm(seed: int, sigma: float, octaves: int = 3, gain: float = 0.5, **kw) -> np.ndarray:
    out = np.zeros((H, W))
    amp, total = 1.0, 0.0
    for i in range(octaves):
        out += amp * noise(seed + 101 * i, sigma / (2 ** i), **kw)
        total += amp
        amp *= gain
    return out / total


def smoothstep(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a + 1e-9), 0, 1)
    return t * t * (3 - 2 * t)


YY, XX = np.mgrid[0:H, 0:W].astype(np.float64)
XN, YN = XX / W, YY / H  # normalised coordinates, 0..1


class Paper:
    """Cold-press paper height field. Pigment settles in the valleys."""

    def __init__(self, seed: int = 7):
        tooth = 0.70 * noise(seed, 2.6) + 0.22 * noise(seed + 1, 5.0) + 0.15 * noise(seed + 2, 1.2)
        self.height = tooth / tooth.std()
        self.valley = np.clip(-self.height, -2.0, 2.0)


class Painting:
    def __init__(self, paper_seed: int = 7):
        self.T = np.ones((H, W))
        self.paper = Paper(paper_seed)
        self._seed = 1000

    def _next(self) -> int:
        self._seed += 17
        return self._seed

    # ---- shapes -------------------------------------------------------------

    def profile(self, pts, wobble: float = 0.0, wobble_sigma: float = 40.0, seed: int | None = None) -> np.ndarray:
        """Height profile y(x) through hand-placed control points (normalised). Returns working pixels."""
        xs, ys = zip(*pts)
        f = PchipInterpolator(xs, ys, extrapolate=False)
        xq = np.clip(np.arange(W) / W, xs[0], xs[-1])  # hold the end values outside the points
        y = f(xq) * H
        if wobble:
            n = _rng(seed or self._next()).standard_normal(W)
            n = ndi.gaussian_filter1d(n, wobble_sigma, mode="reflect")
            y = y + wobble * H * n / (n.std() + 1e-9)
        return y

    def below(self, prof: np.ndarray) -> np.ndarray:
        """Signed field, positive below the profile (inside a landform)."""
        return YY - prof[None, :]

    def ragged(self, field: np.ndarray, edge: float = 1.5, rough: float = 5.0, fine: float = 2.0,
               tooth: float = 1.2, seed: int | None = None) -> np.ndarray:
        """Turn a signed field into a coverage mask with a ragged, paper-caught edge."""
        s = seed or self._next()
        f = field + rough * noise(s, 14.0) + fine * noise(s + 1, 3.5) + tooth * self.paper.height
        return smoothstep(-edge, edge, f)

    # ---- paint --------------------------------------------------------------

    def wash(self, mask: np.ndarray, density, rim: float = 0.3, rim_w: float = 5.0,
             gran: float = 0.07, flow: float = 0.18, flow_sigma: float = 70.0, flow_aspect: float = 1.8,
             bloom: float = 0.0, seed: int | None = None) -> None:
        """Lay one wash. density is a scalar or a field. Glazes by multiply."""
        s = seed or self._next()
        d = np.broadcast_to(np.asarray(density, dtype=np.float64), (H, W)).copy()
        # water density varies inside the wash
        if flow:
            d *= 1.0 + flow * fbm(s, flow_sigma, octaves=3, sigma_x=flow_sigma * flow_aspect)
        # backruns: a few soft blooms where water pushed pigment outward
        if bloom:
            b = noise(s + 5, 55.0)
            ring = np.exp(-((b - 0.9) / 0.16) ** 2) - 0.8 * smoothstep(0.9, 1.6, b)
            d *= 1.0 + bloom * ring
        # pigment pools at the wet rim
        if rim:
            inside = ndi.distance_transform_edt(mask > 0.5)
            d *= 1.0 + rim * np.exp(-inside / rim_w) * (0.7 + 0.3 * noise(s + 9, 25.0))
        # granulation: pigment settles into paper valleys, more where paint is dense
        if gran:
            d *= 1.0 + gran * self.paper.valley
        a = np.clip(d * mask, 0.0, 0.97)
        self.T *= 1.0 - a

    def lift(self, alpha: np.ndarray) -> None:
        """Move toward bare paper. Used for mist and for light kept on water."""
        a = np.clip(alpha, 0.0, 1.0)
        self.T = self.T + (1.0 - self.T) * a

    def mist(self, y: float, height: float, strength: float, seed: int | None = None, x_fade=None) -> None:
        """Paper-coloured mist: a soft horizontal band lifted back toward paper."""
        s = seed or self._next()
        band = np.exp(-((YN - y) / height) ** 2)
        drift = 0.75 + 0.25 * noise(s, 30.0, sigma_x=260.0)
        a = strength * band * drift
        if x_fade is not None:
            a = a * x_fade
        self.lift(a)

    def stroke(self, cx: float, cy: float, half_len: float, thick: float, density: float,
               lift: bool = False, wobble: float = 0.0, seed: int | None = None) -> None:
        """One horizontal brush stroke that tapers to both ends. Used for ripples."""
        s = seed or self._next()
        u = (XN - cx) / half_len
        body = np.clip(1.0 - u * u, 0.0, 1.0)
        t = thick * (0.15 + 0.85 * body)  # thickness tapers
        yc = cy
        if wobble:
            yc = cy + wobble * np.sin((XN - cx) * 38.0 + (s % 7))
        m = np.exp(-(((YN - yc) / (t + 1e-6)) ** 2)) * (body ** 0.6) * (np.abs(u) < 1)
        # dry brush: the stroke skips on paper peaks toward its ends
        skip = smoothstep(-1.2, 0.4, self.paper.valley + 2.2 * body - 0.6)
        m = m * skip
        if lift:
            self.lift(density * m)
        else:
            self.T *= 1.0 - np.clip(density * m, 0, 0.97)

    # ---- reflection ---------------------------------------------------------

    def reflect(self, land_T: np.ndarray, waterline: float, squash: float = 0.9, strength: float = 0.7,
                blur_y: float = 5.0, shake: float = 6.0, fade: float = 0.5, seed: int | None = None) -> None:
        """Mirror the land below the waterline as a softer, broken glaze."""
        s = seed or self._next()
        yw = waterline * H
        src_y = yw - (YY - yw) / squash
        # ripples shift the reflection sideways, more as it nears the viewer
        depth = np.clip((YY - yw) / (H - yw), 0, 1)
        rows = noise(s, 2.2, sigma_x=90.0)
        src_x = XX + shake * (0.25 + depth) * rows
        dens = 1.0 - land_T
        dens = ndi.gaussian_filter(dens, (blur_y, 1.5))
        r = ndi.map_coordinates(dens, [src_y, src_x], order=1, mode="constant", cval=0.0)
        r *= (YY > yw) * strength * (1.0 - fade * depth)
        r *= 1.0 + 0.06 * self.paper.valley
        self.T *= 1.0 - np.clip(r, 0, 0.95)

    # ---- output -------------------------------------------------------------

    def finish(self, paper_tooth: float = 0.012) -> np.ndarray:
        """Return the value layer at 3x (1050 x 354), 0..1, 1 is bare paper."""
        T = self.T * (1.0 - paper_tooth * np.clip(self.paper.valley, 0, 2))
        img = Image.fromarray(np.clip(T, 0, 1).astype(np.float32), mode="F")
        img = img.resize((W // SS, H // SS), Image.LANCZOS)
        return np.clip(np.asarray(img).astype(np.float64), 0, 1)


def save_value(value: np.ndarray, path: str) -> None:
    Image.fromarray((np.clip(value, 0, 1) * 255 + 0.5).astype(np.uint8), mode="L").save(path, optimize=True)
