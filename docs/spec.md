# Habit spec

This file records decisions. Items marked **Guess** were made where the brief is silent and wait for the owner's yes or no. Items marked **Owner** were decided by the owner after the brief was written.

## Status

Phase 1, design. No Swift exists. The owner approved Lake variant A. No other scene is started. Review findings are in `docs/reviews/phase-1.md`.

## Creative direction

The direction is the fold. Every scene is built on one horizon that works as a fold line, and the lower half is a softer mirror of the upper half, as a ridge is mirrored in still water. The hand is right-handed hatching at one steep angle, 56 degrees, in every style: fine ink lines in Pen and ink, visible graphite strokes in Pencil, three brush strokes in Watercolor. The swatch set runs round the colour wheel from ochre to plum with a gap where red would be. Type has open bowls and clear diagonals.

## Scene art

**Method.** Each scene is composed by hand as a list of placed shapes: ridge profiles through control points, tree tips placed one by one, ripples placed one by one. A raster painter in `tools/scenes/paint.py` lays each shape down as a wash. A wash has a ragged edge caught on paper tooth, pigment pooled at its rim, granulation in the paper valleys, uneven water inside it, and it glazes over earlier washes by multiplying. Mist lifts a band back toward paper between layers. Reflections are the land mirrored, blurred and broken by ripples. Nothing is generated at random except texture.

**Output.** One greyscale value layer per scene, 8-bit, 1.0 is bare paper. Sizes: 1050 by 354 px (3x) and 700 by 236 px (2x).

**Budget.** 300 KB per scene for both sizes together. 1.5 MB for five scenes. The Lake is 155 KB at 3x and about 81 KB at 2x.

**Tint.** Each palette has two ramps, top and bottom. A ramp maps pigment density to colour through five stops: paper, light wash, mid wash, dark pigment, darkest. Stop positions and colours are in `docs/tokens.json`. Stops are interpolated in OKLab. The top ramp colours the top of the card and the bottom ramp the bottom, with a smoothstep blend down the card. The app builds two 256-entry lookup tables when the palette changes, tints the value layer once, and caches the result. Nothing is tinted while scrolling.

**Ink appearance. Guess.** In Ink the card shows the same painting in low light. Lightness is compressed in OKLab and the unpainted paper takes some of the light wash colour. The numbers are in `docs/tokens.json` under `inkScene`. The order of values does not change.

**One painting per scene. Guess.** The same painting is used in all three styles. Only the frame differs: a ruled double border in Pen and ink, a hand-ruled pencil border in Pencil, and a deckled edge with no line in Watercolor.

**Lake.** Three variants are in `docs/scenes/lake/`. The owner approved variant A. After the colour-vision review the far ridge wash was made denser, because the ridge was faint against the sky at Sunrise and Midday. The composition did not change.

| Variant | Composition |
|---|---|
| A, Fold | A far ridge with two summits, a slope from the right, a dark wooded point from the left, all mirrored |
| B, Headland | Open water on the left, one dark wooded headland on the right, a low far shore |
| C, Island | A low horizon, a long pale range, one wooded island and a smaller one behind it |

## Palettes

"True red" is defined for tests as hue within 15 degrees of 0, saturation above 0.40 and value above 0.25 in HSV. No ramp stop, accent or swatch is red by that test. Every warm stop is at least 4 degrees clear of the limit.

Sunset uses the Sunrise hues in the opposite order, gold at the top and coral at the bottom, with denser washes.

**Clock. Guess.**

| Palette | From | To |
|---|---|---|
| Sunrise | 05:00 | 08:00 |
| Midday | 08:00 | 17:00 |
| Sunset | 17:00 | 20:00 |
| Blue hour | 20:00 | 22:00 |
| Night | 22:00 | 05:00 |

Any time before the day-start hour shows Night. With day start at 06:00, Sunrise runs 06:00 to 08:00. With day start at 00:00 the table is unchanged. The palette changes without animation.

## Accent

**Owner.** The user's choice of mark colour comes first. The time of day is one option among the choices, not a rule.

- Follow the palette. The default, as in the brief.
- One of eight swatches.
- Custom colour.

**Custom colour. Guess, and a disagreement with a plain colour picker.** The system colour picker lets the user pick red, white or black. Red breaks invariant 1. White and black break the 3:1 rule for marks. The custom control is a hue ring with the red arc left out. The user picks the hue. The app sets lightness and chroma for each appearance so the mark always measures 3:1 or more.

The palette also has a manual override: the user can pin one of the five palettes.

## Styles

Tokens are in `docs/tokens.json`. `tools/tokens/check_tokens.py` checks them. `tools/scenes/tint.py` reads the palettes from the same file.

| | Pen and ink | Pencil | Watercolor |
|---|---|---|---|
| Display font | New York | Shantell Sans (proposed) | Alegreya Sans (proposed) |
| Paper | Flat paper white | Cream with fine tooth | Bright white with cold-press dimples |
| Rules | Hairline ink | Pencil line | None |
| Mark shape | Square | Square of four strokes that overshoot their corners | Round wash |
| Done | Filled square | Dense graphite hatching | Wash with a full-strength rim |
| Part done | Five ink lines | Five loose strokes | Three brush strokes |
| Today | Outer square outline | The day is circled by hand | Outer brushed ring |
| Scene frame | Ruled double border | Hand-ruled border | Deckled edge, no line |

Labels and controls use SF in every style. System controls take the text colour as their tint, because the accent may tint marks only (**Guess**). The Appearance control offers System, Paper and Ink (**Guess**).

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

**Mark colours**, measured as drawn: at the opacity the style draws the edge that carries state, over that style's worst paper pixel.

| Mark colour | Hex | Lowest ratio as drawn | Where |
|---|---|---|---|
| swatch ochre | `#A47C1E` | 3.32:1 | watercolor/paper |
| swatch moss | `#6E8B2E` | 3.37:1 | watercolor/paper |
| swatch leaf | `#3E8A45` | 3.68:1 | watercolor/paper |
| swatch teal | `#2A8A86` | 3.58:1 | watercolor/paper |
| swatch blue | `#4C78C8` | 3.74:1 | watercolor/paper |
| swatch indigo | `#6A6AD0` | 3.93:1 | watercolor/paper |
| swatch plum | `#9A5DB0` | 3.94:1 | watercolor/paper |
| swatch graphite | `#6F6B66` | 3.47:1 | watercolor/ink |
| accent sunrise | `#A8802A` | 3.16:1 | watercolor/paper |
| accent midday | `#3F8554` | 3.84:1 | watercolor/paper |
| accent sunset | `#B26A2C` | 3.64:1 | watercolor/paper |
| accent bluehour | `#5B72C4` | 3.87:1 | watercolor/paper |
| accent night | `#6B6FB8` | 3.91:1 | watercolor/paper |

## Marks

One drawing has one meaning.

| State | Drawing | When |
|---|---|---|
| Done | Solid | The target was met |
| Part done | Hatched | A counted habit has some logs and is under target |
| Paused | Centred dash | The day is paused and has no log |
| Extra credit | Diamond, as large as a done mark | The day is paused and has a log |
| Blank | Nothing | The day is off schedule, or it has no log |
| To come | Dashed outline, faint | The day is in the future and scheduled |
| Not logged | Empty outline | A past scheduled day with no log, and only when Show days not logged is on |

**Today** is an outline in the text colour around the day's mark. On the Today screen every control has it, so the control is visible in every state, including paused. A today with nothing logged is the outline alone.

**Days not logged. Owner.** By default a past day with no log draws nothing, and Habit detail shows Days done, Longest run and Extra credit. One switch in You, "Show days not logged", turns on the empty outline for those days and adds Current run to Habit detail. This replaces the brief's default of drawing a missed day as an empty outline.

**Year view. Owner.** Cells are too small to hatch. Each state is a small shape: a full square for done, a half square cut on the diagonal for part done, a short bar for paused, a diamond for extra credit, nothing otherwise. Today has an outline. In Watercolor the square is a disc and the half square is a half disc. This replaces the brief's four opacity steps, which carried state by intensity.

**Increase Contrast.** Marks are drawn in the text colour and strokes are half a point heavier. In Watercolor the wash inside a mark is drawn flat, and paper washes and grain are off. **Reduce Transparency** turns paper grain off in every style.

**Month view.** Each day shows its date under the mark. An off-schedule day shows the date alone.

**VoiceOver.** A day is read as date then state, for example "Tuesday 10 November. Done." State names: Done, Part done, Paused, Extra credit, Nothing logged, Off schedule, To come. Today is read as "Today" before the date. The heat map groups by week with a summary.

## Screens and behaviour

**Headings.** A screen heading ("Today", a habit name) is content, set in the display font, and scrolls with the page. The navigation bar is the plain system bar. It shows the system inline title once the heading has scrolled under it.

**Today rows.** A row shows a second line only when it says something about today: the count for a counted habit, or "Extra credit". Habits that are off schedule today are not listed (**Guess**).

**Logging. Guess.** A tap on a yes-or-no habit logs it. A second tap takes the log back. A tap on a counted habit adds the habit's tap amount, which defaults to 1. Touch and hold opens a sheet with minus, plus and a number that can be typed. The same actions are offered to VoiceOver as adjustable actions and in a context menu, so nothing depends on touch and hold.

**Past days. Guess.** In the month view of Habit detail, a tap on a past day logs or edits that day through the same intent. Future days cannot be logged.

**Proposed change to the brief, waiting for the owner.** The brief says `LogEvent.delta` is +1 or -1. A habit with a target of 6,000 steps would need thousands of events. The proposal is that `delta` is any whole number, positive or negative. Sums still commute across devices. `Habit` gains `tapAmount`, default 1. The schema is additive forever, so this is decided before milestone 1.

**Page width. Guess.** On iPad and Mac the content is one page, 393 points wide, centred in the window. The scene card stays 350 by 118 points. Tabs become the system sidebar. A mark is never more than a page width from its habit name.

**Tags tab. Guess.** The Tags tab is shown on iPhone only. iPad and Mac cannot read NFC tags.

**Large text.** At accessibility sizes a Today row becomes one column: symbol, name, count, then the control, which grows to 76 points. The name is never cut. The three-line limit applies only at standard sizes. On Appearance, the style tiles and the scene picker become lists. The scene card does not scale.

**Watch. Guess.** The Watch shows today's habits as a list of name and control. It has no scene card. Text is the system font. Marks are drawn in the chosen style.

**First run.** Today shows the scene card, one line of text and one button, "Add a habit".

**Shared store. To check in milestone 1.** Widgets, App Intents and the Watch app need the SwiftData store in an App Group container. The owner has a free Apple account. Milestone 1 checks that an App Group works with free signing, because milestone 5 depends on it.

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

## Noticed in the brief

- The Pen and ink tokens for Ink give 16.15:1 for body and 5.04:1 for tertiary by the WCAG formula. The floor in the brief is 16.2:1 and 5.1:1. The Ink text was changed from `#F2EEE5` to `#F3EFE6` and tertiary from 52% to 53% so the floor holds. The other choice is to keep the tokens and lower the floor.
- `gh repo create` is not available in the session that ran phase 1. The owner created the repo by hand.
- The brief's year view (opacity steps) and its default drawing of a missed day conflicted with invariants 2 and 1. The owner resolved both. See Marks.
- `CLAUDE.md` does not hold the brief's product, design, accessibility and architecture sections. A phase 2 session needs the brief pasted again, or the brief committed to the repo.

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
- First marks used colour to tell "today, nothing logged" from "not logged". Four reviews rejected it. Replaced with the today outline on every Today control.
- Watercolor marks were drawn at 46% to 90% opacity and measured under 3:1. The edge that carries state is now drawn at 95% and the checker measures marks as drawn.
- Year view opacity steps replaced with small shapes.
- Radio buttons on Appearance replaced with checkmark rows, which is the iOS pattern.
- Sunset coral stops moved from 16 to 19 degrees of hue to 22 to 24 degrees, for margin against the red test.
- Sunrise and Midday light wash stops made deeper, and the Lake's far ridge wash made denser.
- Palettes were defined in both `tint.py` and `tokens.json`. `tint.py` now reads `tokens.json`.
