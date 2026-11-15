# Habit spec

This file records decisions. Items marked **Guess** were made where the brief is silent and wait for the owner's yes or no. Items marked **Owner** were decided by the owner after the brief was written.

## Goal

**Owner**, 14 November 2026. The goal is a minimum usable app, milestones 1 to 3, with inclusion and accessibility built in from the first milestone and not added later.

**Principle. Owner.** Every addition must add value, earn its place, and fit the vision and the expert reviews. When two reviews disagree, this is the test.

**Principle. Owner.** Something is better than nothing. A small log, a part-done day or a count with no target is credited, never scored as a failure.

## Status

Phase 2. Milestone 1, the core loop in Pen and ink, is on `feat/core-loop`. The owner approved Lake variant A. No other scene is started. Phase 1 review findings are in `docs/reviews/phase-1.md`.

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
| Mark shape | Square | Strokes that run past the edge of a square | Round wash |
| Done | Filled square | Tight strokes over the whole square | Wash with a full-strength rim |
| Part done | Five ink lines | The same strokes over the lower half, cut on the diagonal | Three brush strokes |
| Today | Outer square outline | A hand-drawn square on Today, a hand circle in calendars | Outer brushed ring |
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
| Dot | A small dot | The habit is not scheduled that day |
| Blank | Nothing | The day has no log |
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

**Logging. Guess.**
- A tap on a yes-or-no habit's control logs it. A second tap takes the log back.
- A tap on a counted habit's control adds the habit's tap amount. It only ever adds, at any count.
- A counted row always shows its count line, "0 of 8 glasses" included, also in Gentle Mode. The line is drawn as a button and opens the count sheet. Touch and hold on the control opens the same sheet.
- The count sheet shows the total, an amount field that starts at the tap amount, and two buttons, Take away and Add. Each button applies the change and closes the sheet. Cancel closes it with no change. Take away never takes more than the total. For a day that is not today the sheet names the date.
- **Owner:** every number in the app can be typed, including the target and the tap amount in New habit. Arrows are never the only way to reach a number such as 15,000 steps or 25 minutes.
- VoiceOver gets adjustable actions named "Increase" and "Decrease" with the step as the value. System undo takes back the last log.
- One haptic confirms a log and a take-back.

**Hit areas.** The control's target is the full row height by 76 points from the trailing edge. The count line's target is 44 points high. A tap on the name or symbol logs, the same as the control. The owner decided this on 15 November 2026. Habit detail opens from the row menu. On the Watch the whole row logs.

**Past days. Guess.** In the month view of Habit detail, a tap on a past day opens a small sheet for that day. The sheet names the date and the day's state. For a yes-or-no habit it has one action, "Mark done" or "Clear". For a counted habit it is the count sheet. A past day never changes on a single tap. An off-schedule day says "Not scheduled" and still allows a log. One line under the grid says "Tap a past day to change it." The month title has previous and next controls. Future days cannot be logged.

**Gentle Mode.** The switch is in You. While it is on, Today shows one line that says so, with a "Turn off" button on its own line. After Turn off, today stays paused and the line reads "Gentle Mode ends after today." with a "Keep it on" button until the day ends.

**Appearance page.** One choice per row: a preview of the scene card and one Today row, Style, Light or dark, then two rows under Colour. "Marks" opens the accent list (Follow the scene, the eight swatches, Custom colour). "Scene colours" opens the palette list (Follow the time of day, the five palettes). The scene row appears when a second scene is approved.

**Habit detail.** The key is one row, "What the marks mean", that opens the marks board.

**Dark material. To design.** Ink is a dark paper, and each style needs a stated material on it: light ink in Pen and ink, light and coloured pencil in Pencil, opaque paint in Watercolor. In Ink the scene's lightest value sits below the heading text. The Pen and ink frame is one hairline in the rule colour in both appearances.

**Pencil, second pass done.** Done is tight strokes over the whole square, running past its edge. Part done is the same strokes over the lower half, cut on the diagonal, so the two differ by silhouette and stay apart when blurred. Strokes are drawn at full strength with small breaks, to hold 3:1. The Today control is a square of four strokes, and the hand circle is kept for today in calendars. Rules are pencil lines, the paper tooth is coarser, and the display font is lighter (weight 380, was 450). Still owed: the dark version, the marks board for this style, hand-drawn dashes for "to come", and a contrast measurement on a simulator screenshot. The control square stays dark, at 4.5:1 or more, with a thinner line.

**Pencil, the finding that started it.** The senior designer review found that Pencil reads as Pen and ink with a marker font. Owed: done marks as visible strokes at 56 degrees with stroke ends showing, rules drawn by hand, paper tooth that shows on a phone, a lighter weight of the display font, and a Today control that is the four-stroke square, with the hand circle kept for today in calendars.

**Screens not drawn yet.** You, Progress, Tags, Vacation, the Edit form, the accent and palette lists, the hue ring, the day sheet, export and import, Archive, week and year views in place, and the Mac and Watch versions of the sheets. Each is mocked with its states at the start of the milestone that builds it (**Guess**). States owed for the drawn screens are listed in `docs/reviews/phase-1.md`.

**Counts. Owner.** `LogEvent.delta` is any whole number, positive or negative. `Habit` has `tapAmount`, default 1. Sums still commute across devices.

**Page width. Guess.** On iPad and Mac the content is one page, 393 points wide, centred in the window. The scene card stays 350 by 118 points. Tabs become the system sidebar. A mark is never more than a page width from its habit name.

**Tags.** There is no Tags tab. Tags is a row in You, shown on iPhone only, because iPad and Mac cannot read NFC tags.

**Large text.** At accessibility sizes a Today row becomes one column: symbol, name, count, then the control, which grows to 76 points. The name is never cut. The three-line limit applies only at standard sizes. On Appearance, the style tiles and the scene picker become lists. The scene card does not scale.

**Watch. Guess.** The Watch shows today's habits as a list of name and control, with the count under the name for a counted habit. It has no scene card. Text is the system font. Marks are drawn in the chosen style. At large text sizes the control moves under the name.

**Narrow widths. Guess.** The scene card is centred. At 375 points wide its side margins are 12.5 points. Below 366 points (iPad Slide Over and narrow Split View) the card scales down to the width less 16 points. This is the one case where the card is not 350 by 118. The Mac window cannot be made narrower than the sidebar plus the page.

**Scene picker.** The picker lists approved scenes only. With one scene it is not shown.

**First run.** Today shows the scene card, one line of text and one button, "Add a habit".

**Shared store.** Widgets, App Intents and the Watch app need the SwiftData store in an App Group container. An `.entitlements` file is allowed for the App Group only (**Owner**). The owner has a free Apple account. Before milestone 1, a throwaway project checks that an App Group works with free signing.

**Shared-store test.** Run on 15 November 2026 with Xcode 27.2. Free signing gave both the app and a widget extension a profile with the App Group. On an iPhone, a value written by the app in shared UserDefaults, a file and a SwiftData store was read by the widget. It works. The profiles expire after 7 days. SwiftData logs errors if `Library/Application Support` does not exist in the group container, so the app creates that folder before it opens the store.

**Identifiers. Owner**, 15 November 2026.

| | Id |
|---|---|
| App | `dev.byrnelikeburn.Habit` |
| Widget | `dev.byrnelikeburn.Habit.Widget` |
| Watch | `dev.byrnelikeburn.Habit.Watch` |
| App Group | `group.dev.byrnelikeburn.Habit` |

The signing team is not committed. It lives in `Config/Local.xcconfig`, which git ignores.

## Product, from the brief

**Tabs.** The brief had four: Today, Progress, Tags, You. There are now three, with Tags inside You. Today is the list, the check-offs and the scene card. Progress is the all-habit ledger with a heat map. Tags is the NFC walkthrough. You holds Nudges, Appearance, Gentle Mode, Vacation, Archive and Export.

**Pausing.** Vacation Mode pauses with a start and end date. Gentle Mode is armed once with one switch and pauses everything with no end date until it is turned off.

**Data model.** Three SwiftData models.

| Model | Fields |
|---|---|
| `Habit` | id, name, symbol name, kind (binary or counted), target (1 for binary), unit, schedule mask (weekday bits, 127 is daily), sort index, focus flag, Gentle Mode flag, Vacation default flag, tag nickname, nudge hour (default 9), descriptor, nudge phrase, nudge text, keep-wording flag, created, archived and deleted dates, relationships to events and pauses |
| `LogEvent` | Append-only. delta, habit, day key, source (manual, watch, widget, shortcut, siri, control), timestamp, device id |
| `Pause` | habit, start day, end day (nil is open-ended), reason (vacation, gentle, manual) |

**Frozen shapes.** `Habit.rules` stores `[HabitRule]`, a struct of first day, target and schedule mask. SwiftData stores it as one composite attribute, so the struct's shape is frozen like any other stored type. A later per-rule value goes in a new field beside it, never inside it. `rules` is the source of truth for history, and `Habit.target` and `Habit.scheduleMask` hold the current values. Both are written only through `setRule`.

The day key is an `Int`, yyyymmdd, computed in the user's calendar with a settable day-start hour (default 04:00) and fixed at write time. Day totals are derived and cached in memory, never stored.

## Data rules

**Owner** accepted these on 14 November 2026. They came from the engineering and QA reviews. They are decided before milestone 1 because the schema is additive forever.

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
| 1 | Core loop in Pen and ink | Before it: the App Group test with free signing. Then models and data rules, Today, first run, New habit, yes-or-no and counted logging with typed numbers and the count sheet, `LogHabitIntent`, the style layer as data with Pen and ink only in Paper and Ink, the eight swatches, Light or dark, the Edit form and Archive, the control-side setting, privacy manifest. No scene card |
| 2 | History, export and import | Heat map (week, month, year), logging a past day, JSON export and import with a round-trip test |
| 3 | Pausing | `Pause` records, Vacation Mode, Gentle Mode, pausing one habit, run maths for days logged while paused, one Home Screen widget |
| | Stop and report | |
| 4 | Pencil and Watercolor | Both styles, their fonts, the style picker, the custom colour ring |
| 5 | Scenes | The scene card, the five palettes by clock, "Follow the scene" for marks, the Lake, then each other scene through the scene gate |
| 6 | Sync | Skipped until the owner says |
| 7 | Ambient | Widgets, App Intents surfaces, Watch app and complication |
| 8 | Nudges | Scheduling engine, wording tones, settings |
| 9 | Ordering | Focus, manual, by time, then learned |
| 10 | NFC | Tag writing and the Shortcuts walkthrough |
| 11 | Obsidian | Append to our own file, then the daily-note option |
| 12 | Removal | Restore, Recently Deleted, purge |
| 13 | Polish | Accessibility audit, Dynamic Type sweep, the usage data page if approved |

**Art is supplemental. Owner.** Scene art waits for milestone 5. Until then Today has no card and marks use a swatch. The default swatch is Blue (**Owner**). Whether each style gets its own drawing of a scene is decided in milestone 5.

## Usage data

**Proposed, waiting for the owner.** The brief says no analytics, no telemetry and no server. Nothing here sends data anywhere.

- **From the user's own log, on the device.** `LogEvent` already stores source, timestamp and delta. From those alone the app can show: which inputs are used (tap, widget, Watch, tag, Siri), how often a log is taken back within a minute, what time of day each habit is logged against its nudge hour, and how often the count sheet is needed. A page in You shows these to the user. They are also in the JSON export. No new event is recorded.
- **From Apple, later.** After the owner joins the Developer Program and ships through the App Store or TestFlight, App Store Connect reports crashes, hangs, launch time and energy for users who opted in at the system level. It needs no code and no SDK.
- **Not proposed.** A third-party analytics SDK or a server. Either one breaks three locked decisions and the "Data not collected" privacy label.

## Decided by deferring to the reviews

**Owner**, 14 November 2026: design, UI and UX questions follow the expert reviews.

- Milestone 1 holds the Edit form and Archive. Recently Deleted and purge stay in milestone 12. Kind is locked after the first log.
- The default tap amount is 1 when the target is 20 or less. Above that it is empty, which means a tap opens the count sheet.
- You has one setting for which side the control sits on.
- There are three tabs: Today, History, You. Tags is a row in You, on iPhone only.
- In the month view a future day shows its date alone. The faint dashed outline is kept for the week view.

## Milestone 1 screens, after the inclusion reviews

The behavioural scientist, neurodiversity and returning-user lenses reviewed `docs/mockups/png/sheet-m1.png`. The owner defers to the reviews on design, so these are adopted. All four items that were owed are now drawn.

**Reaching Edit and Archive.** A tap on a habit's name logs. A swipe left on a row shows Edit and Archive. Touch and hold on the name opens a menu with Edit, Archive and Move. VoiceOver offers the same three as actions on the row. The owner decided this on 15 November 2026. The Archived list in You has "Bring back" from milestone 1. After Archive, one line with Undo shows until the next action. The menu is drawn in `sheet-m1.png`.

**Order.** Manual reorder is in milestone 1, using the system list edit mode and VoiceOver move actions. Done rows stay where they are, so a row never moves under a thumb.

**Not scheduled today.** Today ends with one collapsed row, "Not scheduled today". It opens to those habits with the same controls. A log there is extra credit. Drawn in `sheet-m1.png`.

**New habit.** The name is the only required field. Defaults are Yes or no, every day, and the first symbol. Unit and "One tap adds" sit under one "More" row in New habit and are open in Edit. A sentence under the day circles restates the choice, for example "Every day except Thursday". Day letters use two letters where initials repeat. The name placeholder models a plan with a cue: "Stretch after brushing teeth". If Add is disabled, a line says why.

**Controls that differ.** A counted control shows a small plus inside the square until the target is met, so it reads as "adds" before the tap. Drawn in `sheet-m1.png`. After a yes-or-no log is taken back, one line with Undo shows until the next action.

**Feedback.** A mark draws in as one short stroke, under 300 ms. With Reduce Motion it swaps with no animation. The count line changes on every tap. There is no all-done banner.

**Day boundary.** Between midnight and the day-start hour, Today shows "Until 04:00" under the date. The day-start setting has the caption "Logs before this time count for the day before."

**Stats.** Habit detail leads with Days done, with its start date, and for a counted habit a total in the user's unit. Longest run and Current run are behind one switch, "Show runs". "Show days not logged" is a separate switch. A run row is never hidden at zero.

**Pausing one habit.** Milestone 3 adds "Pause this habit" to the Edit form and the row menu, open-ended, with Resume in the same place. Gentle Mode is reachable from Today as well as from You. The Vacation form says the start can be in the past.

**Year view.** It starts at the habit's first month, labels months, and a tap on a month opens it.

**Words.** "Nothing set for today" replaces "Nothing is due today". The Archive caption leads with "You can bring it back at any time."

## Decided on the reviews' evidence

**Owner**, 14 November 2026: an expert review may override the brief when the change serves the user.

- A counted habit may have no target. With no target, any log draws as done. The target field starts empty in New habit. Asked for by the behavioural scientist, the neurodiversity expert and the returning user.
- A part-done day never breaks a run. Habit detail shows "Days logged" beside "Days done". Asked for by the behavioural scientist and the returning user.
- One Home Screen widget is part of milestone 3, if the App Group test passes. It gives the user a cue outside the app. Asked for by the behavioural scientist.
- The label "Extra credit" becomes "Logged while paused". Asked for by the tired daily user, the content designer and the behavioural scientist. Older sections of this file and of `docs/reviews` still say "extra credit" for the same state.

## Milestone 2 screens

Drawn in `docs/mockups/png/sheet-m2.png`, in Pen and ink. Redrawn on 15 November to the rules below. Still owed: History in month and year, History with no habits and with 30, the largest text size, and the Mac and Watch versions.

- Habit detail in month, week and year views. A future day shows its date alone. The year starts in the month the habit was added and labels its months.
- Stats: Days done, Days logged, and a total in the user's unit, with the start date. Current run and Longest run appear only when "Show runs" is on.
- A habit with no history shows one line and an "Add a past day" button.
- A past day opens a sheet that names the date. A day that was not scheduled says so and still takes a log.
- History is a ledger: one row per habit, seven days across.
- You gains "Show runs", "Show days not logged", "Export a copy" and "Import a copy".
- Import ends on a sheet that counts what was added and what was skipped. A file that cannot be read says so and changes nothing.

## Milestone 2 rules, from the reviews

Accessibility, UI and UX, and a combined behavioural and returning-user review looked at `sheet-m2.png`. These are adopted. The drawings do not show them all yet.

**Stats.** Order is Days logged, then the unit total, then Days done. A counted habit with no target shows the first two only. There is never a rate, a percentage or "of N days". The same stats mean the same thing in week, month and year: all time, under the label "Since 28 April 2026". The week view adds one line for the week's total, and only when the week has a log. A week with no log shows no zeros.

**Place.** Habit detail keeps one anchor date per visit. Switching between week, month and year opens the period that holds it. The period title is a button that returns to the current period. Opened from History, detail shows the same range and period, and Back reads "History".

**Days.** Any day up to today opens the day sheet, in week and month. The hit area is the whole cell, with or without a mark. Past days and today are buttons with the hint "Opens this day". Future days are not buttons. "Add a past day" is on every Habit detail state. It opens a date picker and then the day sheet. The month view can page back before the habit was added.

**Day sheet.** It names the habit and the date. At zero a count reads "Nothing logged", like a yes-or-no habit, with the amount field and Add below. "of 8 glasses" shows once the day has a log. Take away is off at zero. A day with a log has "Clear this day", which writes minus the total. After any change to a past day, the Undo line shows. The hint under the grid reads "Tap a past day to add or change a log."

**Year.** Each month is one button, 44 points high: its label and its block of weeks. A week belongs to the month that holds its Monday. The year starts at the month of the "Since" date. VoiceOver reads one element per month, for example "June 2026. 22 days done, 3 part done, 2 paused. Opens the month." At accessibility text sizes the grid becomes a list of months as text rows.

**History tab.** A whole row is one button and one VoiceOver element. A tap on a past cell opens the day sheet. A tap on the name opens Habit detail. History is not a place to log today, so the name does not log here as it does on Today. Today's cell is drawn as the thin today outline at mark size, not as the Today control. An off-schedule day shows a small dot, so a habit set for three days a week does not look half empty. Owed drawings: month and year, no habits, 30 habits, the largest text size.

**Import and export.** After a file is picked, a preview says what the file holds and what is new, with Import and Cancel. A file with nothing new ends on "Nothing new in this file". A file that is not a Habit export and a file from a newer version get separate messages. First-run Today has a second, quiet action, "Import a copy". Export and Import rows are buttons with no chevron. Owed: rules for a habit whose id exists but whose details differ, for a habit archived here and live in the file, and whether pauses and settings are in the file.

**You.** Switches are the system toggle, not restyled. One line under the two History switches says what each adds.

**Largest text size.** Week becomes seven rows. A History row puts the name above its marks. Stat rows stack label over value. Sheet buttons stack. The month keeps seven columns and caps the date numeral where two digits fit.

**Runs.** A run counts scheduled days in a row with any log. A part-done day extends it. A day whose total is zero or less after an undo counts as no log. The mark still shows whether the target was met: solid for done, hatched for part done. The help line reads "A run counts the scheduled days in a row with any log, even a small one." It sits under the "Show runs" switch. Three reviews agreed (behavioural, neurodiversity and returning user, content).

**Current run row.** With "Show runs" on, the row is always there. Its value is "12 days" in a run, "Between runs" after a gap and "No run yet" before the first log. A pause keeps the number. A zero is never shown. Longest run is hidden until it is 1 or more. Note for translators: "State label. No run is active after a gap. Restructure freely. Must not name a missed day or a zero." The three reviews split at first (hide the row, "Starts with any log", "Between runs") and all accepted this course in a second round. They would revisit it if users read "Between runs" as an unwanted reminder.

**Tab name.** The ledger tab is called "History". "Progress" implies a direction, so a quiet week reads as none. "Log" is already the app's word for an entry. The same three reviews agreed.

**Second review, 15 November.** Accessibility, UI and UX, and the tired daily user looked at the redrawn sheet. Adopted:

- A day the habit is not scheduled shows a small dot in week, month, year and History. It was blank in month, "Off" in week and a dot in History. The dot is in "What the marks mean".
- Dates a user can tap are drawn in secondary text. Future dates are tertiary and are not buttons.
- A History row puts the name above seven equal cells, each 44 points. Today is marked once in the header and by a thin outline in the cell. VoiceOver reads the row as one element with one action per day, for example "Open Tuesday 10 November". Cells take keyboard focus.
- In the year view a month button is at least 44 points wide.
- "Since" and the first month of the year view use the earlier of the day the habit was added and its first log. The previous-year arrow is on when that falls in an earlier year.
- The week view puts the date beside the weekday, so the only number under a mark is the count.
- Day sheet: Add and Mark done write, close the sheet and show the Undo line. "Take away" and "Clear this day" are text buttons under Add. Take away cannot go below zero. A yes-or-no day that is done shows "Done" and "Clear this day".
- The Undo line sits above the tab bar and covers nothing. It is announced ("Cleared 7 November. Undo available"). It stays until the next action, for everyone, as milestone 1 built it.
- Import: a habit whose id is here with different details keeps this device's version. The preview says how many differ (**Guess**, to be checked by the engineering and QA reviews).
- "Add a past day", the period arrows, the period title and text buttons have a 44 point hit area.
- The year grid has an `AXChartDescriptor`.

Not adopted: filling the past-day amount with what is left to the target. A past-day fix is as often small as full, and the field already takes any typed number.

**Reaching Habit detail from Today.** The row menu and the swipe actions gain "Details", beside Edit and Archive. VoiceOver gets the same action. The word is not "History", because that is now the tab (**Guess**, for the content review at the milestone 2 build). A name tap on Today still logs.

**A log on a day off.** It draws the diamond and reads "Logged on a day off", as milestone 1 built it. The day sheet for such a day shows that after a log.

**Export.** The owner deferred to the reviews on 15 November 2026, and the security, engineering and QA reviews approve it on these conditions.

- The file is made only when the user taps "Export a copy" and goes only to the system share sheet. The app makes no network call.
- Plain JSON. The header holds the format name, one whole-number version, the app build, the export time and a count per record type.
- It holds habits, logs and pauses. It holds no settings and no device id. On import each log gets the fixed device value "imported".
- `Pause` gets a stable id, so import can skip a pause that is already here.
- The file name is "Habit export" and the date. No habit name and no device name.
- The export screen says: "This copy is not encrypted. Anyone who has it can read your habits."
- The temporary file is written to the app's own temporary folder with complete file protection, deleted when the share sheet closes, and swept at launch.
- Import checks the whole file, then writes all of it or none of it. It refuses a file over the size and count limits, a newer version, an unknown kind, a bad day key, an amount over the typed-number cap, and a log whose habit is missing. Unknown keys are ignored. An older version imports with defaults. The limits are set at the build (**Guess**).
- A habit archived here stays archived when the file has it live. Its logs still import. It counts in the preview's "differ" number.
- Parse errors never log file content. Test files are made up.
- Round-trip test: export, import into an empty store and export again gives the same file apart from the export time. Day totals and runs match, across pauses. A second import adds nothing. Negative and zero amounts survive. Day keys do not change under another time zone or day-start hour. A cut-off file and a newer file write nothing.

**Import and the one write path.** The engineering, QA and security reviews agree. Import does not call the intent once per log, because each call saves on its own and a failure part way would leave half a file written. Import gets one named function in `LogWriter`, `importEvents`, which checks every log, inserts them all and saves once. It shares the amount cap, the habit check and the day-key check with live logging. It keeps each log's id, day key, timestamp and source, and sets the device value to "imported". It never alters a value: one bad log refuses the whole file. It gives no haptic and no Undo line, and reloads widgets once at the end. The source check gains a pattern so only the import file may call it. The owner approved the new wording of invariant 5 on 15 November 2026, and it is in `CLAUDE.md`.

**Password on export. Later, not in the MVP.** The reviews agree it should exist, off by default, in milestone 13 or sooner if testing asks for it. One switch on the export screen, "Protect with a password". The password is typed once and shown, with a hide button. The field is marked as a new password so the system password manager may offer to save it. The owner agreed to that on 15 November 2026: a saved password may sync through iCloud Keychain, because it is the user's own Apple account and not a server run for this app. The app never stores, reads back or logs the password and calls no keychain API. There is no hint and no recovery. The screen keeps the line "Habit cannot recover this password. Save it somewhere you will find it later." and does not promise a save offer. The file name ends in "-protected". Built with Apple's frameworks only: PBKDF2 for the key, AES-GCM for the file, a fresh salt and nonce each time. To check on a device: whether the system offers to save a password with no account or domain.

**Words.** "No history yet" becomes "Nothing logged so far" and shows only for a habit with no logs ever.

**Fixture faults found.** The year strip started at May while the stats said 28 April. The month with runs on showed a run of 2 where the marks give 3.

## Milestone 3 screens

Drawn in `docs/mockups/png/sheet-m3.png`, in Pen and ink. Three reviews saw the first draft on 15 November 2026: neurodiversity with behavioural and returning user, accessibility, and UI and UX with QA. They disagreed on how a pause ends and settled on one rule in a second round. These rules replace the earlier Gentle Mode and Vacation paragraphs where they differ.

**Names.** "Gentle Mode" is the name of the whole feature. It appears as the section header in You and in the help page, with the pause symbol, and nowhere else. Under it are two rows named for what they do, each with one line of description: "Pause everything. Until you turn it off." and "Pause for dates. Choose a first and last day. Dates can be in the past." "Vacation" is gone, because someone ill is not on vacation and will not look there. A single habit has "Pause this habit". The pause symbol also marks the Today button and the widget header. Note for translators on the header: "Feature name. Translate as a concept (rest, easy days). Do not translate 'Mode' literally." The owner asked to keep the name. The content review wanted action labels and the neurodiversity review wanted the name kept as permission to rest. Both accepted this course.

**Reaching it.** Today has a quiet text button under its last row, "Pause everything". It asks for no confirmation. You has the same switch and a "Pause for dates" row. The row menu and Edit have "Pause this habit".

**One ending rule.** Ending any pause sets its last day to today. Today stays paused and the habit starts again tomorrow. The button reads "Resume tomorrow". After it, Today reads "Resumes tomorrow." with "Keep paused". A pause whose first day is today is removed whole, and its button reads "Undo pause", so a slip leaves no trace and today's logs draw as normal marks. After a tap on "Pause everything", that button becomes "Undo pause" in place, and the line at the top of Today shows the same.

**Words.** Today reads "Everything is paused." or "Paused until 27 November." The helper is "Paused days leave your runs as they are. You can still log." It replaces "never counts against you", which implied that other days do. In Edit a paused habit reads "It starts again tomorrow. You can still log today."

**Rows while paused.** A counted row shows "0 glasses", then "3 glasses" after a log, with no target. The control shows the dash until the first log. This changes the rule that a counted row always shows "0 of 8".

**Pause for dates.** The row opens a list of dated pauses, coming and earlier, and "Pause everything" pauses that have ended. Each can be opened and changed. Save is off until the last day is set and is not before the first. A pause that has started offers "Resume tomorrow". One that has not started offers "Remove". The form says how many logged days will change mark, and how many days gain or lose a pause.

**Storage.** "Pause everything" and "Pause for dates" are each one `Pause` record with no habit. A day is paused if any pause covers it. A habit added during a pause is paused too. "Pause everything" outranks dates in the line on Today. The "today" in the form is the habit day, built from the day-start hour.

**Edit.** Archive sits in its own section, away from Pause, to prevent a slip.

**Widget.** Small and medium. Rows keep Today's order. The whole row is the button, 44 points high, and logs through `LogHabitIntent`. Text uses text styles, and a row is dropped before text shrinks. The header reads "Paused" during a pause. VoiceOver reads one element per row: "Drink water, 3 of 8 glasses, button, adds 1", "Read, logged while paused", "Walk outside, paused, button". Marks draw from the store only, never ahead of a write, so a tap on a locked device changes nothing until it is unlocked. The timeline has an entry at each day start and each pause edge. The intent carries the day the widget showed and the state it wanted. On a mismatch it reloads and writes nothing. In tinted and clear modes marks are full opacity and marked accentable, with no row rules.

**Still owed.** The largest text size for the Today lines and the widget, clear mode, the Mac and Watch versions, and tests for travel across a pause edge.

## Open decisions

Each needs the owner. The recommendation is mine.

| # | Decision | Recommendation | Blocks |
|---|---|---|---|
| 3 | The usage data page | Build it in milestone 13 from the existing log fields | Milestone 13 |
| 4 | Display fonts for Pencil and Watercolor | Decide after the Pencil design pass | Milestone 4 |
| 5 | The items marked Guess in this file | Accept as written | The milestone that first uses each |

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
