# Habit spec

This file records decisions. Items marked **Guess** were made where the brief is silent and wait for the owner's yes or no.

## Status

Phase 1, design. No Swift exists. The Lake is painted in three variants and waits for approval. No other scene is started.

## Creative direction

The direction is the fold. Every scene is built on one horizon that works as a fold line, and the lower half is a softer mirror of the upper half, as a ridge is mirrored in still water. The hand is right-handed hatching at one steep angle, 56 degrees, in every style: fine ink lines in Pen and ink, visible graphite strokes in Pencil, three brush strokes in Watercolor. The swatch set runs round the colour wheel from ochre to plum with a gap where red would be. Type has open bowls and clear diagonals.

## Scene art

**Method.** Each scene is composed by hand as a list of placed shapes: ridge profiles through control points, tree tips placed one by one, ripples placed one by one. A raster painter in `tools/scenes/paint.py` lays each shape down as a wash. A wash has a ragged edge caught on paper tooth, pigment pooled at its rim, granulation in the paper valleys, uneven water inside it, and it glazes over earlier washes by multiplying. Mist lifts a band back toward paper between layers. Reflections are the land mirrored, blurred and broken by ripples. Nothing is generated at random except texture.

**Output.** One greyscale value layer per scene, 8-bit, 1.0 is bare paper. Sizes: 1050 by 354 px (3x) and 700 by 236 px (2x).

**Budget.** 300 KB per scene for both sizes together. 1.5 MB for five scenes. The Lake is 154 KB at 3x and 81 KB at 2x, 235 KB together.

**Tint.** Each palette has two ramps, top and bottom. A ramp maps pigment density to colour through five stops at density 0, 0.22, 0.50, 0.80 and 1.0: paper, light wash, mid wash, dark pigment, darkest. Stops are interpolated in OKLab. The top ramp colours the top of the card and the bottom ramp the bottom, with a smoothstep blend down the card. The app builds two 256-entry lookup tables when the palette changes, tints the value layer once, and caches the result. Nothing is tinted while scrolling.

**Ink appearance. Guess.** In Ink the card shows the same painting in low light. Lightness is compressed to 0.10 + 0.64 L in OKLab and the unpainted paper takes 35% of the light wash colour. The order of values does not change.

**One painting per scene. Guess.** The same painting is used in all three styles. Only the frame differs: a ruled double border in Pen and ink, a hand-ruled pencil border in Pencil, and a deckled edge with no line in Watercolor.

**Lake.** Three variants are in `docs/scenes/lake/`. Variant A is my pick. Its value bands are 6% bare paper, 76% light wash, 12% mid wash and 6% dark pigment.

| Variant | Composition |
|---|---|
| A, Fold | A far ridge with two summits, a slope from the right, a dark wooded point from the left, all mirrored |
| B, Headland | Open water on the left, one dark wooded headland on the right, a low far shore |
| C, Island | A low horizon, a long pale range, one wooded island and a smaller one behind it |

## Palettes

Ramp colours and accents are in `docs/tokens.json`. "True red" is defined for tests as hue within 15 degrees of 0, saturation above 0.40 and value above 0.25 in HSV. No ramp stop, accent or swatch is red by that test.

Sunset uses the Sunrise hues in the opposite order, gold at the top and coral at the bottom, with denser washes. Its mean luminance on the Lake is 0.55 against 0.71 for Sunrise.

**Clock. Guess.** The brief says fixed clock hours derived from the day-start setting. Proposed:

| Palette | From | To |
|---|---|---|
| Sunrise | 05:00 | 08:00 |
| Midday | 08:00 | 17:00 |
| Sunset | 17:00 | 20:00 |
| Blue hour | 20:00 | 22:00 |
| Night | 22:00 | 05:00 |

Any time before the day-start hour shows Night. With day start at 06:00, Sunrise runs 06:00 to 08:00. With day start at 00:00 the table is unchanged.

## Styles

Tokens are in `docs/tokens.json`. `tools/tokens/check_tokens.py` checks them.

| | Pen and ink | Pencil | Watercolor |
|---|---|---|---|
| Display font | New York | Shantell Sans (proposed) | Alegreya Sans (proposed) |
| Paper | Flat paper white | Cream with fine tooth | Bright white with cold-press dimples |
| Rules | Hairline ink | Pencil line | None |
| Mark shape | Square | Square, hand-drawn twice | Round wash |
| Solid | Filled square | Dense graphite hatching | Wash with a pooled rim |
| Hatched | Five ink lines | Five loose strokes | Three brush strokes |
| Today | Outer square outline | The day is circled by hand | Outer brushed ring |
| Scene frame | Ruled double border | Hand-ruled border | Deckled edge, no line |

Labels and controls use SF in every style.

**Text contrast**, measured against the worst pixel of each paper (the base colour with grain at full strength):

| Style | Appearance | Text | Ratio | Floor |
|---|---|---|---|---|
| penAndInk | paper | body | 17.7:1 | 17.7:1 |
| penAndInk | paper | secondary | 6.8:1 | 6.8:1 |
| penAndInk | paper | tertiary | 4.8:1 | 4.8:1 |
| penAndInk | ink | body | 16.3:1 | 16.2:1 |
| penAndInk | ink | secondary | 8.3:1 | 8.3:1 |
| penAndInk | ink | tertiary | 5.2:1 | 5.1:1 |
| pencil | paper | body | 17.9:1 | 17.7:1 |
| pencil | paper | secondary | 7.8:1 | 6.8:1 |
| pencil | paper | tertiary | 5.4:1 | 4.8:1 |
| pencil | ink | body | 16.7:1 | 16.2:1 |
| pencil | ink | secondary | 8.6:1 | 8.3:1 |
| pencil | ink | tertiary | 5.2:1 | 5.1:1 |
| watercolor | paper | body | 18.1:1 | 17.7:1 |
| watercolor | paper | secondary | 7.7:1 | 6.8:1 |
| watercolor | paper | tertiary | 5.4:1 | 4.8:1 |
| watercolor | ink | body | 16.6:1 | 16.2:1 |
| watercolor | ink | secondary | 8.5:1 | 8.3:1 |
| watercolor | ink | tertiary | 5.3:1 | 5.1:1 |

| Mark colour | Hex | Lowest ratio on any paper |

**Mark colours**, lowest contrast against any paper of any style:

|---|---|---|
| swatch ochre | `#A47C1E` | 3.5:1 |
| swatch moss | `#6E8B2E` | 3.6:1 |
| swatch leaf | `#3E8A45` | 3.9:1 |
| swatch teal | `#2A8A86` | 3.8:1 |
| swatch blue | `#4C78C8` | 4.0:1 |
| swatch indigo | `#6A6AD0` | 4.1:1 |
| swatch plum | `#9A5DB0` | 4.1:1 |
| swatch graphite | `#6F6B66` | 3.5:1 |
| accent sunrise | `#A8802A` | 3.3:1 |
| accent midday | `#3F8554` | 4.1:1 |
| accent sunset | `#B26A2C` | 3.8:1 |
| accent bluehour | `#5B72C4` | 4.1:1 |
| accent night | `#6B6FB8` | 4.1:1 |
ok

**Marks.** The seven states and the today outline are drawn in `docs/mockups.html` and shown per style on the marks board. On the Today screen a habit with nothing logged shows the outline alone, drawn in the text colour, so it never looks like a missed day.

**System controls. Guess.** System controls take the text colour as their tint, because the accent may tint marks only.

**Appearance options. Guess.** The Appearance control offers System, Paper and Ink.

## Fonts proposed

| Style | Font | License | Source |
|---|---|---|---|
| Watercolor | Alegreya Sans (pick) | SIL OFL 1.1 | github.com/huertatipografica/Alegreya-Sans |
| Watercolor | Fraunces | SIL OFL 1.1 | github.com/undercasetype/Fraunces |
| Watercolor | Optima | Installed with iOS and macOS | The OS |
| Pencil | Shantell Sans (pick) | SIL OFL 1.1 | github.com/arrowtype/shantell-sans |
| Pencil | Playpen Sans | SIL OFL 1.1 | github.com/TypeTogether/Playpen-Sans |
| Pencil | Chalkboard SE | Installed with iOS and macOS | The OS |

Whether Optima and Chalkboard SE resolve on watchOS is not checked. It is a phase 2 test.

## Accessibility notes for phase 2

- The scene card is one accessibility element labelled with scene and palette, for example "Lake, midday". No text sits on it.
- Mark state names for VoiceOver: Done, Part done, Not logged, Paused, Extra credit, Off schedule, Ahead.

## Noticed in the brief

- The Pen and ink tokens for Ink give 16.15:1 for body and 5.04:1 for tertiary by the WCAG formula. The floor in the brief is 16.2:1 and 5.1:1. I changed the Ink text from `#F2EEE5` to `#F3EFE6` and tertiary from 52% to 53% so the floor holds. The other choice is to keep the tokens and lower the floor.
- `gh repo create` is not available in the session that ran phase 1. The owner created the repo by hand.

## Decisions log

- Scene method: a raster wash painter with hand-placed shapes. Rejected procedural SVG, which the brief rules out.
- Paper grain in the first painter pass was too coarse and read as static. Made the tooth finer and cut granulation to about a third.
- Tree tips, first pass: wide triangles, read as a row of teeth. Rejected.
- Tree tips, second pass: bulging sides, read as towers on the island variant. Rejected, because scenes have no buildings.
- Tree tips, third pass: one wood mass with an uneven canopy and a few straight-sided, notched tips of different heights. Kept.
- Island variant: the tallest tips were lowered so the island reads as a wood.
- Waterline: an unpainted band read as a ruled white line. Replaced with a broken line of lifted paper.
- Ink appearance tint: plain dimming turned bare paper grey. The paper now takes some of the light wash colour.
- Watercolor paused mark: a line has no height, so the wash filter dropped it. Drawn as a rounded bar.
- Preview sheets are JPEG and mockup PNGs use a 256-colour palette, to keep the public repo small.
