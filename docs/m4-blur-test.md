# Blur test of the small shapes

Run on 15 November 2026 with `python3 tools/marks/small_shapes.py`. The drawing is `docs/mockups/png/m4-small-shapes.png`.

The test is the one the accessibility and low-vision reviews set: each shape is drawn in a 12-unit cell, blurred with a Gaussian of one eighth of the mark's width, and compared in greyscale. The number is how far apart two blurred shapes are. 0 is identical and 1 is no overlap. No pass mark has been set yet.

## Pairs within a style

| Style | Size | Done and part done | Done and diamond | Paused and dot | Part done and paused | Diamond and paused |
|---|---|---|---|---|---|---|
| Pen and ink | 12 | 0.33 | 0.16 | 0.56 | 0.54 | 0.48 |
| Pen and ink | 6 | 0.33 | 0.16 | 0.70 | 0.44 | 0.28 |
| Pencil | 12 | 0.33 | 0.15 | 0.49 | 0.38 | 0.55 |
| Pencil | 6 | 0.33 | 0.15 | 0.65 | 0.39 | 0.36 |
| Watercolor, straight diamond | 12 | 0.33 | 0.06 | 0.50 | 0.46 | 0.54 |
| Watercolor, straight diamond | 6 | 0.33 | 0.06 | 0.64 | 0.37 | 0.37 |
| Watercolor, curved diamond | 12 | 0.33 | 0.11 | 0.50 | 0.46 | 0.41 |
| Watercolor, curved diamond | 6 | 0.33 | 0.11 | 0.64 | 0.37 | 0.22 |

**Finding.** Done against the diamond is the weakest pair in every style. That includes Pen and ink, whose small shapes are already in the milestone 2 design. Neither Watercolor diamond the reviews proposed separates from the disc.

## Other shapes for "logged while paused"

The lowest distance to any other state in the same style.

| Shape | Pen and ink 12 | Pen and ink 6 | Pencil 12 | Pencil 6 | Watercolor 12 | Watercolor 6 |
|---|---|---|---|---|---|---|
| The diamond as drawn | 0.16 | 0.16 | 0.15 | 0.15 | 0.06 | 0.06 |
| A four-point star with deep sides | 0.26 | 0.36 | 0.21 | 0.28 | 0.20 | 0.27 |
| The done shape with a slot through the middle | 0.15 | 0.25 | 0.16 | 0.29 | 0.22 | 0.38 |

Tried for Watercolor at 6 points and weaker than the star: a triangle (0.20), a tall capsule (0.21), two dabs (0.20), a plus (0.13), a teardrop (0.12).

## The same state across styles, at 6 points

| State | Pen and ink and Pencil | Pen and ink and Watercolor | Pencil and Watercolor |
|---|---|---|---|
| Done | 0.30 | 0.22 | 0.23 |
| Part done | 0.47 | 0.35 | 0.49 |
| Paused | 0.10 | 0.10 | 0.06 |
| Diamond | 0.19 | 0.00 | 0.19 |

**Finding.** The paused shape is nearly the same in all three styles. The straight diamond is identical in Pen and ink and Watercolor.
