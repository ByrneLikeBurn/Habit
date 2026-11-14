"""Palettes and runtime tint, mirrored here so scenes can be checked before any Swift exists.

A value layer is tinted by two ramps. Each ramp maps pigment density (0 is bare
paper, 1 is the darkest pigment) to a colour. The top ramp colours the top of
the card and the bottom ramp colours the bottom, with a smooth vertical blend.
The app will build the same two 256-entry lookup tables once per palette change.
"""
from __future__ import annotations

import numpy as np
from PIL import Image

STOPS = (0.0, 0.22, 0.50, 0.80, 1.0)  # paper, light wash, mid wash, dark pigment, darkest

PAPER = "#FBFAF6"

# name: (top ramp, bottom ramp). Each ramp is light, mid, dark, darkest. Paper is prepended.
PALETTES = {
    "sunrise": (("#F6D3BE", "#E9A27F", "#A56A49", "#573A2C"),      # soft coral
                ("#F8E3B2", "#E5BA60", "#987230", "#523F1F")),     # into gold
    "midday": (("#D5E6D0", "#84B383", "#2F6B4B", "#0D2E20"),
               ("#DDE8C4", "#97B66B", "#44702F", "#162F0E")),
    "sunset": (("#F0C17C", "#D58C3A", "#85501F", "#3F2510"),       # gold, denser
               ("#EDAB8C", "#D27C55", "#864A2D", "#40241A")),      # into coral, denser
    "bluehour": (("#CCDBF1", "#7195D1", "#2D4D90", "#13224B"),     # blue
                 ("#DAD1EE", "#9B85CC", "#543C85", "#271A49")),    # into purple
    "night": (("#959ABF", "#5C6294", "#2E325F", "#141631"),
              ("#9A97C2", "#625F98", "#332F62", "#171433")),
}
NIGHT_PAPER = "#C6C9DF"  # at night the bare paper itself is dim


def hex_rgb(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64) / 255.0


def srgb_to_lin(c):
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


_M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
                [0.2119034982, 0.6806995451, 0.1073969566],
                [0.0883024619, 0.2817188376, 0.6299787005]])
_M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
                [1.9779984951, -2.4285922050, 0.4505937099],
                [0.0259040371, 0.7827717662, -0.8086757660]])


def to_oklab(rgb):
    lms = srgb_to_lin(rgb) @ _M1.T
    return np.cbrt(lms) @ _M2.T


def from_oklab(lab):
    lms = (lab @ np.linalg.inv(_M2).T) ** 3
    return lin_to_srgb(lms @ np.linalg.inv(_M1).T)


def _mix(a, b, t: float) -> np.ndarray:
    a = hex_rgb(a) if isinstance(a, str) else a
    b = hex_rgb(b) if isinstance(b, str) else b
    return from_oklab(to_oklab(a) * (1 - t) + to_oklab(b) * t)


def ramp_lut(colors, paper) -> np.ndarray:
    """256-entry lookup from density to sRGB, interpolated in OKLab."""
    cols = [hex_rgb(c) if isinstance(c, str) else c for c in (paper, *colors)]
    labs = np.array([to_oklab(c) for c in cols])
    d = np.linspace(0, 1, 256)
    lab = np.stack([np.interp(d, STOPS, labs[:, i]) for i in range(3)], axis=1)
    return from_oklab(lab)


def dim_for_ink(rgb: np.ndarray) -> np.ndarray:
    """Ink appearance: the same painting seen in low light. Order of values is kept."""
    lab = to_oklab(rgb)
    lab[..., 0] = 0.10 + 0.64 * lab[..., 0]
    return from_oklab(lab)


def luts(palette: str, appearance: str = "paper", paper: str = PAPER):
    top, bottom = PALETTES[palette]
    pp = NIGHT_PAPER if palette == "night" else paper
    if appearance == "ink":
        # the unpainted paper takes the light wash colour, so the glow is coloured light and not grey
        pt = _mix(pp, top[0], 0.35); pb = _mix(pp, bottom[0], 0.35)
        return dim_for_ink(ramp_lut(top, pt)), dim_for_ink(ramp_lut(bottom, pb))
    return ramp_lut(top, pp), ramp_lut(bottom, pp)


def tint(value: np.ndarray, palette: str, appearance: str = "paper", paper: str = PAPER) -> np.ndarray:
    """value: HxW in 0..1, 1 is bare paper. Returns HxWx3 sRGB in 0..1."""
    lt, lb = luts(palette, appearance, paper)
    idx = np.clip(((1.0 - value) * 255 + 0.5).astype(int), 0, 255)
    h = value.shape[0]
    t = np.linspace(0, 1, h)[:, None, None]
    t = t * t * (3 - 2 * t)
    return lt[idx] * (1 - t) + lb[idx] * t


# Colour-vision simulation, Machado, Oliveira and Fernandes 2009, severity 1.0, applied in linear RGB.
CVD = {
    "protanopia": np.array([[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]),
    "deuteranopia": np.array([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]),
    "tritanopia": np.array([[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]),
}


def simulate(rgb: np.ndarray, kind: str) -> np.ndarray:
    if kind == "greyscale":
        y = srgb_to_lin(rgb) @ np.array([0.2126, 0.7152, 0.0722])
        g = lin_to_srgb(y)
        return np.stack([g, g, g], axis=-1)
    return lin_to_srgb(srgb_to_lin(rgb) @ CVD[kind].T)


def to_image(rgb: np.ndarray) -> Image.Image:
    return Image.fromarray((np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8), mode="RGB")


def load_value(path: str) -> np.ndarray:
    return np.asarray(Image.open(path).convert("L")).astype(np.float64) / 255.0


def luminance(rgb) -> float:
    return float(srgb_to_lin(np.asarray(rgb)) @ np.array([0.2126, 0.7152, 0.0722]))


def contrast(a, b) -> float:
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)
