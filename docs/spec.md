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

**Custom colour. Owner.** The custom control is a hue ring. Every hue is on it, red included. Some cultures read red as lucky, so the choice is the user's. The user picks the hue. The app sets lightness and chroma for each appearance so the mark always measures 3:1 or more. This is why the control is not the system colour picker, which also offers white and black.

The app's own palettes and swatches still never use red. The red test covers what the app ships, not what the user picks.

**What 3:1 means.** It is a contrast ratio between a mark and the paper behind it. WCAG 2.2 sets 3:1 as the least a shape needs when it carries information, so that people with low vision can see it. Pale yellow on white paper is about 1.2:1.

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

**Contrast.** Text contrast against the worst pixel of each paper, and mark contrast as drawn, are in `docs/contrast.md`. That file is the output of `python3 tools/tokens/check_tokens.py --table`. The floor is compared unrounded and lives in `docs/tokens.json`.

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

**VoiceOver.** A day is read as date then state, for example "Tuesday 10 November. Done." State names: Done, Part done, Paused, Extra credit, To come. A day with no log and an off-schedule day are read as the date alone. "Not logged" is spoken only when Show days not logged is on. Today is read as "Today" before the date. The heat map groups by week with a summary. The scene card is one element, read as scene then palette name, for example "Lake, blue hour".

**Where the key lives.** Habit detail has a key. You has a row, "What the marks mean", that opens the marks board.

## Screens and behaviour

**Headings.** A screen heading ("Today", a habit name) is content, set in the display font, and scrolls with the page. The navigation bar is the plain system bar. It shows the system inline title once the heading has scrolled under it.

**Today rows.** A row shows a second line only when it says something about today: the count for a counted habit, or "Extra credit". Habits that are off schedule today are not listed (**Guess**).

**Logging. Guess.** A tap on a yes-or-no habit logs it. A second tap takes the log back. A tap on a counted habit adds the habit's tap amount, which defaults to 1. The count line under a counted habit's name ("3 of 8 glasses") is a button that opens the count sheet. In the sheet the user types an amount and chooses Add or Take away. Touch and hold on the control opens the same sheet. **Owner:** every number in the app can be typed, including the target and the tap amount in New habit. Arrows are never the only way to reach a number such as 15,000 steps or 25 minutes. VoiceOver gets adjustable actions named "Increase" and "Decrease" with the step as the value.

**Past days. Guess.** In the month view of Habit detail, a tap on a past day logs or edits that day through the same intent. A yes-or-no habit toggles. A counted habit opens the count sheet for that day. One line under the grid says "Tap a past day to change it." Future days cannot be logged.

**Gentle Mode.** The switch is in You. While it is on, Today shows one line that says so, with a "Turn off" button.

**Counts. Owner.** `LogEvent.delta` is any whole number, positive or negative. `Habit` has `tapAmount`, default 1. Sums still commute across devices.

**Page width. Guess.** On iPad and Mac the content is one page, 393 points wide, centred in the window. The scene card stays 350 by 118 points. Tabs become the system sidebar. A mark is never more than a page width from its habit name.

**Tags tab. Guess.** The Tags tab is shown on iPhone only. iPad and Mac cannot read NFC tags.

**Large text.** At accessibility sizes a Today row becomes one column: symbol, name, count, then the control, which grows to 76 points. The name is never cut. The three-line limit applies only at standard sizes. On Appearance, the style tiles and the scene picker become lists. The scene card does not scale.

**Watch. Guess.** The Watch shows today's habits as a list of name and control, with the count under the name for a counted habit. It has no scene card. Text is the system font. Marks are drawn in the chosen style. At large text sizes the control moves under the name.

**Narrow widths. Guess.** The scene card is centred. At 375 points wide its side margins are 12.5 points. Below 366 points (iPad Slide Over and narrow Split View) the card scales down to the width less 16 points. This is the one case where the card is not 350 by 118. The Mac window cannot be made narrower than the sidebar plus the page.

**Scene picker.** The picker lists approved scenes only. With one scene it is not shown.

**First run.** Today shows the scene card, one line of text and one button, "Add a habit".

**Shared store.** Widgets, App Intents and the Watch app need the SwiftData store in an App Group container. An `.entitlements` file is allowed for the App Group only (**Owner**). The owner has a free Apple account. Before milestone 1, a throwaway project checks that an App Group works with free signing.

## Product, from the brief

**Tabs.** Today, Progress, Tags, You. Today is the list, the check-offs and the scene card. Progress is the all-habit ledger with a heat map. Tags is the NFC walkthrough. You holds Nudges, Appearance, Gentle Mode, Vacation, Archive and Export.

**Pausing.** Vacation Mode pauses with a start and end date. Gentle Mode is armed once with one switch and pauses everything with no end date until it is turned off.

**Data model.** Three SwiftData models.

| Model | Fields |
|---|---|
| `Habit` | id, name, symbol name, kind (binary or counted), target (1 for binary), unit, schedule mask (weekday bits, 127 is daily), sort index, focus flag, Gentle Mode flag, Vacation default flag, tag nickname, nudge hour (default 9), descriptor, nudge phrase, nudge text, keep-wording flag, created, archived and deleted dates, relationships to events and pauses |
| `LogEvent` | Append-only. delta, habit, day key, source (manual, watch, widget, shortcut, siri, control), timestamp, device id |
| `Pause` | habit, start day, end day (nil is open-ended), reason (vacation, gentle, manual) |

The day key is an `Int`, yyyymmdd, computed in the user's calendar with a settable day-start hour (default 04:00) and fixed at write time. Day totals are derived and cached in memory, never stored.

## Data rules

All **Guess** unless marked. These came from the engineering and QA reviews. They are decided before milestone 1 because the schema is additive forever.

- Every model property is optional or has a default, relationships are optional, and nothing is marked unique. CloudKit needs this later.
- `LogEvent` has a stable id. Import skips an event whose id is already in the store.
- A yes-or-no habit is done when the day's total is 1 or more. Taking a log back writes minus the current total. A total below 0 is shown as 0.
- A typed amount is written as the delta itself, positive for Add and negative for Take away. No event stores a total.
- A log on a paused day is extra credit, whatever the count. A log on an off-schedule day is extra credit too.
- Turning Gentle Mode off sets the end day to today, so today stays paused.
- Pauses may start in the past. Overlapping pauses are treated as one.
- Changing a target or schedule applies from the day of the change. Earlier days keep the old target and schedule. `Habit` keeps a short history of (first day, target, schedule mask) for this.
- "Today" is computed from the device's current calendar, time zone and day-start hour. A day that already holds a log is drawn by its state, even if travel or a new day-start hour puts it after today.
- If the day-start hour does not exist on a daylight-saving night, the next valid time is used. The day-start hour can be set from 00:00 to 08:00.

## Rules for phase 2, from the reviews

**Drawing and memory.**
- Pencil wobble and Watercolor edges are baked into the path once, with fixed-seed noise. One cached drawing per style, state, size, accent, appearance and display scale. No filter, blur or shader runs per mark.
- The year view is one `Canvas` with one accessibility element per week.
- Paper grain ships as one 8-bit alpha tile per style, tinted with the token colour and tiled. It is not a full-screen bitmap.
- Only the current tinted scene is kept in memory. Tinting runs off the main actor.
- The two ramps are blended in gamma sRGB, as `tools/scenes/tint.py` does. `docs/tint-luts.json` holds the lookup tables for a Swift test to match.
- Scene value layers stay 8-bit PNG. A 16-level PNG bands the sky.

**Type.**
- Display-font digits are lining and tabular. In Pencil, digits in counts and stats use the slashed zero.
- Bold Text weights: Pen and ink medium to semibold and bold to heavy. Pencil 450 to 600 and 650 to 800. Watercolor 500 to 700 and 700 to 800, which needs Alegreya Sans ExtraBold in the bundle.
- Variable fonts are built from a font descriptor with explicit axis values, then scaled with the text style. `Font.custom` by family name gives the wrong weight for Shantell Sans and Fraunces.
- A habit name is never cut from the xxLarge text size upward.
- Before a font ships, it is downloaded from its upstream repository, and that file's hash and license are recorded. The mockup files came from the Google Fonts mirror.

**Words and locale.**
- Week start, weekday order and weekday letters come from the user's calendar. Day buttons are read by VoiceOver with full weekday names.
- Dates and lists use the system format styles, never a fixed pattern.
- Every count is one String Catalog entry with plural forms and positional values. The user's unit is shown as typed.
- Layout uses leading and trailing, so it mirrors in right-to-left languages. The hatch angle does not mirror.
- "Extra credit" has a translator note: not a score or grade.

**Tests.**
- The clock, calendar, time zone and locale are one injectable value in `HabitKit`. Tests and screenshots set it from fixtures.
- Tests cover: two devices tapping offline, a target or schedule change against history, a day-start change during a day, time-zone moves, daylight saving at the day-start hour, a part log on a paused day, export and import including importing twice, and layout at 320 and 375 points.
- A test walks the custom hue ring and checks every hue at 3:1 on both papers of every style.

**Release.**
- Bundle ids and the App Group id are fixed in this file before any target exists. Intents live in the app target.
- Every target has a privacy manifest. This is on the milestone 1 definition of done.
- The notification prompt appears only when the user first turns on a nudge. If it is declined, that setting shows one line with a link to Settings, and nothing appears anywhere else.
- Quiet Hours work by not scheduling. The Time Sensitive level is not used.
- In tinted and clear widget modes the system sets the colour. Marks there carry state by shape alone. A system tint of red is the user's choice and is outside the app.
- The app icon needs default, dark, clear and tinted variants.
- A free Apple account's builds stop launching after 7 days and must be rebuilt from the Mac. Export and import are the way back if the bundle or team changes.

## Milestones

**Owner**, 14 November 2026.

| # | Milestone | Holds |
|---|---|---|
| 1 | Core loop in Pen and ink | Models and data rules, Today, New habit, yes-or-no and counted logging with typed numbers, `LogHabitIntent`, the style layer as data with Pen and ink only, the Lake card in five palettes, Follow the palette and the eight swatches, light or dark, privacy manifest |
| 2 | History, export and import | Heat map (week, month, year), logging a past day, JSON export and import with a round-trip test |
| 3 | Pausing | `Pause` records, Vacation Mode, Gentle Mode, extra-credit run maths |
| | Stop and report | |
| 4 | Pencil and Watercolor | Both styles, their fonts, the style picker, the custom colour ring |
| 5 | Sync | Skipped until the owner says |
| 6 | Ambient | Widgets, App Intents surfaces, Watch app and complication |
| 7 | Nudges | Scheduling engine, wording tones, settings |
| 8 | Ordering | Focus, manual, by time, then learned |
| 9 | NFC | Tag writing and the Shortcuts walkthrough |
| 10 | Obsidian | Append to our own file, then the daily-note option |
| 11 | Removal | Archive, restore, Recently Deleted, purge |
| 12 | Polish | Accessibility audit, Dynamic Type sweep |

## Usage data

**Proposed, waiting for the owner.** The brief says no analytics, no telemetry and no server. Nothing here sends data anywhere.

- **From the user's own log, on the device.** `LogEvent` already stores source, timestamp and delta. From those alone the app can show: which inputs are used (tap, widget, Watch, tag, Siri), how often a log is taken back within a minute, what time of day each habit is logged against its nudge hour, and how often the count sheet is needed. A page in You shows these to the user. They are also in the JSON export. No new event is recorded.
- **From Apple, later.** After the owner joins the Developer Program and ships through the App Store or TestFlight, App Store Connect reports crashes, hangs, launch time and energy for users who opted in at the system level. It needs no code and no SDK.
- **Not proposed.** A third-party analytics SDK or a server. Either one breaks three locked decisions and the "Data not collected" privacy label.

## Open decisions

Each needs the owner. The recommendation is mine.

| # | Decision | Recommendation | Blocks |
|---|---|---|---|
| 1 | The data rules above | Accept as written | Milestone 1 |
| 2 | The usage data page | Build it in milestone 12 from the existing log fields | Milestone 12 |
| 3 | Display fonts for Pencil and Watercolor | Shantell Sans and Alegreya Sans | Milestone 4 |
| 4 | The items marked Guess in this file | Accept as written | The milestone that first uses each |

Decided on 14 November 2026 and now written into this file and `CLAUDE.md`: whole-number deltas and typed numbers, the `.entitlements` file for the App Group, the milestone order, export in milestone 2, three review lenses per milestone, red allowed as a user's accent, and three more lenses (UI and UX, human factors, senior designer).

## Scenes, from the brief

**Rules.** The card is 350 by 118 points, short and wide, with one soft horizon. Value runs from bare paper through light and mid washes to dark pigment. A scene with one flat opacity fails. It must read in all five palettes, at half and one-third size, and in greyscale, protanopia, deuteranopia and tritanopia. The palette changes colour only, never composition. Scenes: Lake, Redwoods, Desert, Coast, Mountains. Each is shown to the owner as three variants, one scene at a time. A scene rejected twice is dropped.

**What failed before, for the Redwoods.** Straight tapered trunks in a row read as a barcode. A corridor of trunks with drooping boughs was eerie. Foliage as round dabs read as camouflage. Sticks for trunks with loose needle lines over blobs read as sickly pines with needles attached to nothing. A mix of all of these was a pastiche. Wanted: tall trunks, a canopy, a pine-needle feel, calm, not muddy, not eerie.

**What worked.** A lake in washes: ragged edges, a wet rim where a wash pools, granulation, glazing with multiply, bare paper kept as highlights, graded gradients, tapered ripples, paper-coloured mist between layers.

**Styles.** Pencil is a coloured-pencil feel: visible hatching, varying line weight, paper tooth, playful and slightly whimsical. Watercolor is transparent washes with no outline: paint is the shape, layers are transparent, water density varies inside a wash, edges bleed and pool at the rim, bare paper is the highlight. Calm never means slower or sparser. Logging stays one obvious tap. The three styles must not look alike.

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
- "The brief" is the owner's first prompt, `habit-build-prompt.md`. It is not in the repo. Its rules now live in `CLAUDE.md` and this file, with the owner's later changes applied. Where they differ from the brief, the repo is right.
- The brief's Pen and ink Paper tokens give 6.76:1 for secondary and 4.77:1 for tertiary, under the 6.8:1 and 4.8:1 floor when compared unrounded. Secondary went from 70% to 70.5% and tertiary from 60% to 60.5%.

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
