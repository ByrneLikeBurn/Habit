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

## Outcome

Settled on 15 November 2026 by the accessibility, low-vision and senior designer reviews, after two rounds.

**Pass mark: 0.25.** At 0.16 a blurred pair looks the same and at 0.33 it looks distinct. The mark sits between those two. It is a calibration, not a measure of sight, and is confirmed by eye at real size.

**"Logged while paused" becomes a split diamond.** It is a diamond at the full cell with a gap of 2.5 units across its middle. The designer wanted to keep the diamond, so the word and the large mark stay true. The accessibility review wanted a slot, because it was the only idea that passed. A diamond with a gap does both.

| Style | Shape | Lowest distance to any other state |
|---|---|---|
| Pen and ink | Straight diamond, flat gap | 0.38 |
| Pencil | Straight diamond, gap tilted 10 degrees | 0.32 |
| Watercolor | Diamond with barely curved sides, flat gap | 0.29 |

What the tests ruled out:
- A gap of 2 units fails in Watercolor (0.24). A gap of 3 units passes, but the halves start to read as two marks: the blur keeps 43% of peak darkness in the gap, against 52% at 2.5 units.
- A Pencil diamond that leans fails against the leaning block (0.16 to 0.22). The Pencil diamond stays upright, and this state is exempt from the rule that no style's small shapes match another's. Done and part done carry the style.
- A Watercolor diamond with straight sides fails (0.23). Deeply curved sides blur to two faint blobs.

**In a year grid the two halves stay together.** With done cells above and below, the blur keeps 38% to 44% of peak darkness inside the mark and 7% to 13% between it and its neighbours.

**The paused shape is exempt** from the cross-style rule, like the dot. A dash is a dash in any material.

## The diamond at full size

Settled on 16 November 2026, after two rounds. Drawn in `docs/mockups/png/m4-diamond-cut.png`.

**One rule for every size: a diamond with a cut across its middle.** Up to 12 points the cut is a fifth of the mark's width, which is the 2.5-unit gap above. Above 12 points the cut is 1.25 points, so a large diamond is one diamond with a hairline through it, not two triangles.

The three reviews first split. Accessibility and low vision wanted the gap at every size, so a user who learns the mark large knows it small. The senior designer and product owner wanted the large diamond left solid, because a wide gap puts two arrows inside a tap control. The first-day user said they would not connect a solid large diamond to a split small one, and proposed the hairline. Both other reviews accepted it.

**The test was wrong for large marks, and is corrected.** The first blur grew with the mark, so every size scored the same and a sharp large diamond failed. Sight blurs by a fixed amount, not by a share of the mark. Condition 5 now reads: the blur is 0.75 points at every size. The 0.25 pass mark applies at 12 points and under. Above that, two blurred marks must differ over a patch at least 3 points across, confirmed by eye in greyscale.

With the corrected blur and the rule above, lowest distance to any other state:

| Size | Pen and ink | Pencil | Watercolor |
|---|---|---|---|
| 6 points | 0.38 | 0.32 | 0.29 |
| 24 points, cut of 1.25 points | 0.25 | 0.36 | 0.15 |

Watercolor at 24 points is the weak one. The disc against the diamond is checked by eye first when the Watercolor marks are drawn.

**The key.** "Logged on a paused day or a day off". The diamond is used for both, so the cut is part of the diamond and does not mean paused.

**This changes one drawing in milestones 1 and 2.** The full-size diamond gains the hairline cut.
