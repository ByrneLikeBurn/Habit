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
5. "Told apart" is tested in greyscale after a Gaussian blur of 0.75 points, at 24, 12 and 6 points, for: done and part done, done and diamond, dash and dot, to come and not logged, today with and without a mark. At 12 points and under the pass mark is 0.25 on the distance in `docs/m4-blur-test.md`. Above 12 points the two blurred marks must differ over a patch at least 3 points across, confirmed by eye. The first wording used a blur of one eighth of the mark's width, which gave the same score at every size.
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

## Step 1: the material rules. Passed

Both reviews failed the first draft on 15 November 2026, because it could be drawn two ways in several places. They passed the second draft with four sentences rewritten. Those rewrites are in the text below. Lenses that saw the final wording: senior designer, product owner, accessibility, colour vision and low vision.

**Pencil.** The tool is one blunt coloured pencil. A mark is a set of parallel strokes at 56 degrees with no outline and no fill. Each stroke has a solid core at least 1.5 points wide. The paper's tooth erodes the edges of a stroke only, never its core. The gap between strokes is no wider than a stroke, so a done mark blurs to a solid. Stroke ends show and run 1 to 2 points past the square. Nothing is ruler straight. Paper is cream with a fine tooth. Rules between rows are one pencil line drawn by hand.

- Done: strokes over the whole square.
- Part done: the same strokes over the lower half, cut on the diagonal.
- Paused: one stroke, tilted 10 degrees.
- Logged on a paused day or a day off: a diamond filled with the same strokes, with a cut of 1.25 points across its middle.
- To come: a square of short hand-drawn dashes, in a stroke thinner than a mark stroke and never under 1.5 points, with gaps of at least 2 points.
- Not logged, when the user has turned it on: a hand-drawn empty square.
- Today: a square of four strokes around the mark, whose ends cross and overshoot each corner by 1 point.

In Ink the paper is charcoal with the same tooth. The pigment sits on the tooth, so charcoal specks show at the edges of each stroke and between strokes. The core stays solid and the stroke geometry is unchanged. Rules and the today square are drawn in a white pencil. Nothing glows.

**Watercolor.** The tool is one round brush. A mark is one wash with no outline. The colour pools at the rim. The rim darkens over 1.5 to 2 points with no inner line, and it carries the 3:1. The inside is a wash at 60% of the rim's strength or more, and is never bare paper. Paper is bright white cold-press with dimples that show inside the wash. There are no rules between rows, only space.

- Done: one round wash.
- Part done: three brush strokes at full strength throughout.
- Paused: one round-ended dab.
- Logged on a paused day or a day off: a diamond-shaped wash, with a cut of 1.25 points across its middle.
- To come: a ring of short brush dabs, thinner than the rim and never under 1.5 points, with gaps of at least 2 points.
- Not logged, when the user has turned it on: one thin closed ring at the done mark's size, in the accent, never under 1.5 points.
- Today: a brushed ring around the mark, with a visible start and end. The gap is at most 1 point.

In Ink the paper is near-black cold-press with the same dimples and no stains. The paint is opaque, like gouache: flat and light, with no rim. Its edge is uneven from the brush, not blurred, and falls off within 1 point. Contrast is measured on the flat inside.

**Small shapes, 12 points and under.** A stroke or a rim cannot be drawn this small. Each shape is flat, at full strength. To come and not logged are not drawn at 12 points and under.

| State | Pen and ink | Pencil | Watercolor |
|---|---|---|---|
| Done | Square | A block that leans at 56 degrees, at three quarters of the cell | Disc at three quarters of the cell |
| Part done | Half square, cut on the diagonal | The lower half of the leaning block, cut on the diagonal | Half disc, split top to bottom |
| Paused | Flat bar, square ends | One stroke with tapered ends, tilted 10 degrees | A round-ended dab |
| Logged on a paused day or a day off | A diamond at the full cell, split by a flat gap of 2.5 units | The same diamond, upright, with the gap tilted 10 degrees | The same diamond with barely curved sides and a flat gap |
| Not scheduled | Dot | Dot | Dot |
| Today | Square outline | A square of four strokes whose ends cross and overshoot each corner by 1 point | Brushed ring |

The dot is the same in every style. It is exempt from the rule that no style's small shapes match another's.

The paused bar is as wide as the done shape and at least 2 points thick. The accessibility review asked for the full cell. An earlier check found that a full-width bar joins the diamond beside it in a strip, so the width stays at the done shape's width and the blur test in step 2 decides.

**Step 2, small shapes: tested.** The blur test found the diamond was the weakest shape in every style, Pen and ink included. It is now a split diamond. The numbers and what was ruled out are in `docs/m4-blur-test.md`. The pass mark is 0.25 and every pair in every style is at 0.29 or more. The diamond and the paused shape are exempt from the rule that no style's small shapes match another's.

**This reaches milestone 2.** Pen and ink's small diamond is in the year view and the History month strip, which are being built now. The product owner set it as a gate on the milestone 2 merge: the small diamond is drawn split before that PR merges.

**Step 2, full-size marks: reviewed, 16 November.** Drawn by `tools/marks/full_marks.py` in `docs/mockups/png/m4-marks.png`: every state at 24 points, in Paper and Ink, sharp and blurred by 0.75 points. The numbers are in `docs/m4-marks.md`.

- Accessibility, colour vision and low vision: passed in the second round. As drawn, Pencil is 3.97 on Paper and 6.21 on Ink, and Watercolor is 3.74 on Paper and 4.30 on Ink.
- Senior designer: three of five findings fixed in the second round. Four drawing fixes followed. On a third look the designer passed the Watercolor today ring and the "not logged" ring, and found two still open: the Pencil "not logged" square read as ruled, and a dark diagonal ran through a done mark on Ink. Both were changed again on 16 November: the square's sides bow by more than a point, and the charcoal specks on Ink are sparser so they do not line up between strokes. The designer sees them with the step 3 drawing.
- Not adopted: "the cut in the Pencil diamond on Ink is drawn as a light line". The pixels in the cut are bare paper. It was a misreading of the frame.
- What the reviews changed from the first drawing: Pencil strokes touch, so a done mark blurs to a solid and the cut is the only line in the diamond. Pencil on Ink is a lighter pencil of the same hue with charcoal specks outside the solid core. The Watercolor rim is 1.5 to 2.6 points wide, wider where colour pools, and grades into the wash over 3 points. To come is drawn at 2 points.
- Yellow, raw, is about 1.5:1 on the light papers. It is shaded to a dark ochre at 3.0. Thin marks in shaded yellow are measured in the colour ring PR.

Not yet drawn: Increase Contrast, and the marks inside the app's screens.

## Step 3: the Today control and the lines between rows. Passed in words

Both reviews failed the first draft on 16 November 2026 and passed the second with one rewrite each, on the same point: the sizes. Those are in the text below. Lenses that saw the final wording: senior designer, product owner, accessibility, colour vision and low vision. Nothing is drawn yet for this step.

**Pencil.** The control on a Today row is the today square: four pencil strokes whose ends cross and overshoot each corner by 1 point, in the text colour, 1.5 points wide. An empty control is the square alone. A logged control holds the mark at 24 points. The square is sized to keep 3 points clear of the mark, stroke ends included, which makes it about 37 points across, and it stays inside the 44 point target. The line between rows is one pencil stroke in the rule colour, 1 point wide, bowed by at most 1 point over its length. It starts and ends 2 to 4 points short of the margins. The inset and the bow are fixed for each habit and never change when the row is drawn again. The line carries no information.

**Watercolor.** The control is the today ring: one brushed ring in the text colour, 1.5 to 3 points wide, about 36 points across, inside a 44 point target. It starts at 1 o'clock and runs clockwise, and its gap of 1 point at most sits in the same place on every row. A gap that moved would read as progress. An empty control is the ring alone. A logged control holds the mark at 24 points, with 3 points clear between the mark and the ring. There are no lines between rows. The space between rows scales with the text size: it is one line of the habit name's text, and never less than twice the gap between lines inside a name. Under Increase Contrast one straight line, 1 point wide, in the text colour, appears between rows.

**A counted control has no plus.** Under its target it shows the part-done mark alone. At zero it is empty. The count is in text beside the name. Both reviews found that a plus hides the part-done state, as it did on the widget, and in Pencil on Ink a white plus over light blue strokes is about 2.7:1.

**Both.** The control keeps its place on the side the user chose. The square or ring never changes with the state. In Ink the square is a white pencil and the ring is opaque light paint. At the largest text sizes the control stays 44 points and the mark stays its size, as in Pen and ink. The control is one button. VoiceOver speaks the habit name, the state in words and the count. The focus ring for Switch Control and the keyboard follows the 44 point target, not the drawn strokes.

**Open, and it reaches the first version.** Pen and ink still draws a plus in a counted control. The same finding applies there. It goes to the human factors and first-day user lenses, who asked for the plus, before Pen and ink changes.

**Plain text is not a setting.** The product owner would not add a flag. It becomes a gate in step 5: twelve habit names at 17 points are shown to the tired user and neurodiversity lenses. If the hand font fails, habit names use SF in that style, and only headings keep the display font.

**To remove from `docs/spec.md` when this file merges.** The line that says Pencil uses a hand circle in calendars. A circle would match Watercolor's ring.
