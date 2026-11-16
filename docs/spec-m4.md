# Milestone 4: Pencil and Watercolor

This file holds the milestone 4 design while milestone 2 is being built. It moves into `docs/spec.md` when the milestone 2 PR is merged. Nothing here is drawn yet. The order is: written rule, then drawing, then build.

Areas touched: marks, colour, contrast and type; adding a screen (the style picker and the colour ring). Lenses: accessibility, colour vision and low vision, typographer, senior designer, product owner.

## Order

The reviews set this on 15 November 2026. Each step waits for the one before it.

1. One written material rule per style, covering Paper and Ink together.
2. The marks at every size, smallest first.
3. The Today control and the rules between rows.
4. Increase Contrast.
5. Fonts.
6. The style picker.
7. The colour ring, as the last and separate PR of the milestone.

## Scope

- Every screen from milestones 1 to 3, and the widget, in Pencil and Watercolor, in Paper and Ink.
- The style picker, the two fonts with their licences, and a marks board for each style.
- Cut from this milestone: the scene card, and the "Follow the scene" and "Scene colours" rows. They belong to milestone 5.
- The colour ring stays, as one "Custom colour" row under the swatches, hue only. It is the one route to red, which the owner asked for. Custom hues are tested on the marks in step 2, in yellow and red, because a wash and broken strokes are where 3:1 is hardest.

## Pass conditions

**Senior designer.**
1. With text hidden, each style can be named from one Today row and from one History month strip.
2. No style's small shapes match another's.
3. Within a style every state differs by silhouette, at year-cell size and blurred.
4. Ink shows the stated dark material, not the Paper drawing recoloured.
5. Watercolor has no drawn outline on any mark or ring. Pencil has no ruler-straight line and no machine dash.
6. The display font differs visibly from the SF labels at heading and row size.

**Accessibility, colour vision and low vision.**
1. Every state measures at least 3:1 as drawn, at default settings. Pencil is measured on the lightest pixel inside a stroke. Watercolor is measured on the rim, not inside the wash.
2. Wobble moves the silhouette by at most 10% of the mark's width. A break in a stroke is at most 1 point and never opens the outline.
3. Strokes are at least 1.5 points. The paused dash is at least 2 points thick and half the mark wide. The dot is at most a quarter of the mark.
4. The Watercolor rim is at least 1.5 points at full strength. The bleed stays inside the cell.
5. "Told apart" means a different silhouette in greyscale after a Gaussian blur of one eighth of the mark's width. Tested at 24, 12 and 6 points for: done and part done, done and diamond, dash and dot, to come and not logged, today with and without a mark.
6. Ink is a light material on dark paper, at the same ratios, with no glow.
7. Increase Contrast: marks in the text colour, strokes half a point heavier, a flat wash, at least 7:1.
8. "To come" is 3:1. It is fainter through dash gaps and a thinner stroke, not through opacity. This changes the words "reduced opacity" in `CLAUDE.md`, and is recorded when this file is merged.

**Colour ring.**
- Lightness is solved for each hue, appearance and style. A test sweeps 360 hues, two appearances and three styles, and the lowest result is 3.0 as drawn.
- The ring and the preview show the corrected colour, never the raw one. Yellow on Paper shows as dark ochre. Dark blue on Ink shows as light periwinkle.
- The hue has a name in text. The preview shows all seven states on both papers.
- The handle is at least 44 points, with a two-tone outline that holds 3:1 anywhere on the ring.
- VoiceOver reads it as adjustable: "Yellow, 60 degrees". Arrow keys move 1 degree and Shift moves 10. A degree can be typed.

**Style picker.** Each tile shows that style's own paper, the display font at 28 points or more with "Aa 0O 1l", and the done, part-done and paused marks at 24 points. The chosen tile has a checkmark and a 2 point border, and is spoken. Tiles stack at the largest text sizes.

**Fonts.**
1. OFL 1.1 with the licence file, or installed with the OS on every platform.
2. Covers the style's normal and Bold Text weights, up to 800. Bold Text adds at least 150 weight units.
3. Lining figures, all ten digits one width.
4. 1, l and I differ by shape, and 0 differs from O, at 17 points.
5. Western, Central European, Baltic and Turkish Latin, with dashes and curly quotes.
6. At the largest text size a 58-character habit name fits four lines with nothing clipped.
7. One habit name is enough to tell the style from New York and from SF.

## Fonts, as measured

The typographer measured the font files on 15 November 2026.

| Font | Result |
|---|---|
| Shantell Sans | Passes for Pencil. Weights 300 to 800. Needs `tnum` and `zero` on. One variable file, 1.28 MB. Set `INFM`, `BNCE` and `SPAC` to 0 |
| Playpen Sans | Fails. No tabular figures. I and l are the same stroke |
| Alegreya Sans | Passes for Watercolor with two conditions: bundle Medium, Bold and ExtraBold, and set `lnum` and `tnum` on everywhere. About 0.8 MB. I and l differ by height only, which is weak |
| Fraunces | Fails. No tabular figures, and it is a serif beside New York |
| Chalkboard SE, Optima | Not measured. No files here |

Not measured: wrapping at the largest text size, rendering at 17 points, whether Alegreya's `lnum` and `tnum` combine, and the upstream file hashes. Total cost is about 2.1 MB.

The stale rule: `docs/spec.md` gives Pencil Bold Text as 450 to 600, but the display weight is now 380. The pair is set again in step 5.

**Plain text. Proposed by the typographer, not yet settled.** One setting that swaps the display font for SF and keeps the style's marks and paper. A hand font at 17 points in a list of twelve names adds reading load for tired and dyslexic users, and some adults will find it childish.

## Step 1: the material rules. Draft, for the reviews

**Pencil.** The tool is one blunt coloured pencil. A mark is a set of parallel strokes at 56 degrees with no outline and no fill. Stroke ends show and run 1 to 2 points past the square. Nothing is ruler straight. Paper is cream with a fine tooth that shows through the strokes. Rules between rows are one pencil line drawn by hand. In Ink the paper is charcoal with the same tooth, the rules and the today square are drawn in a white pencil, and the marks are the accent as a lighter pencil. Strokes stay strokes. Nothing glows.

**Watercolor.** The tool is one round brush. A mark is one wash with no outline. The colour pools at the rim, so the rim is the darkest part and carries the 3:1. The inside is lighter and shows the paper. Paper is bright white cold-press with dimples that show inside the wash. There are no rules between rows, only space. In Ink the paper is a dark wash-stained sheet and the paint is opaque, like gouache: flat, light, with a soft edge and no rim. The today mark is a brushed ring with a visible start and end, not a hairline.

**Small shapes, 12 points and under.** A stroke or a rim cannot be drawn this small, so each style has its own silhouette for each state.

| State | Pen and ink | Pencil | Watercolor |
|---|---|---|---|
| Done | Square | A block that leans at 56 degrees | Disc at three quarters of the cell |
| Part done | Half square, cut on the diagonal | The same lean at half the width | Half disc, split top to bottom |
| Paused | Flat bar, square ends | One stroke with tapered ends, tilted a little | A round-ended dab |
| Logged while paused | Diamond | Diamond drawn in three strokes, with ragged ends | Open question below |
| Not scheduled | Dot | Dot | Dot |

**Open question for the reviews.** In Watercolor at small sizes the disc and the diamond look alike. Options: a sharp diamond that reaches the full cell while the disc stays at three quarters, or a teardrop with its point up, or something better.
