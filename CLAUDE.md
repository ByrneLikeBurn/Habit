# Habit

Habit is a habit tracker for iOS, iPadOS, macOS and watchOS. Swift 6, SwiftUI, SwiftData. Minimum OS 26 on every platform. No accounts, no server, free forever.

This file is the project brief for every session. `docs/spec.md` records decisions as they are made.

## Words

| Word | Means |
|---|---|
| Style | The overall look: fonts, paper, how marks are drawn. Pen and ink, Pencil, Watercolor |
| Appearance | Light or dark: Paper, Ink |
| Accent | The user's chosen mark colour, or "follow palette" |
| Scene | A painted landscape in a framed card at the top of Today |
| Palette | The colour set a scene is painted in, set by time of day |

## Who decides

The owner set this on 14 November 2026. The brief began as an idea. Development follows evidence. Where an expert review disagrees with this file on design, UI or UX, and the change serves the user, the review wins. Every such change is written in `docs/decisions.md` with the review that asked for it, and is reported to the owner with two or three sentences that say what changed and why.

This does not cover privacy, what leaves the device, dependencies, the additive schema rule, or cost. Those stay with the owner. Where two reviews disagree, do not treat it as a choice between the two. First look for an option neither review considered that meets what both are protecting. Change the vantage point and widen the view: ask what each review is trying to prevent, and whether one design prevents both. Then put the options, the third one included, back to the reviews that disagreed and have them test it against each other's concern. If they land on one course, take it, record it and report it. Bring it to the owner only when no clear course comes out.

Nothing goes to the owner for review until the expert reviews have seen it. The owner set this on 15 November 2026, to cut delays and misdirection from the human step. Reports to the owner say what was decided and why, in two or three sentences each. They ask a question only when the reviews could not settle it, or when the matter is one of those listed above as the owner's. The test is that every addition adds value, earns its place, and fits the vision and the reviews.

## Invariants

These outrank every other instruction. Violating one is a bug, however good the reason sounds. If an instruction would break one, stop and tell the owner.

1. **No guilt mechanics.** No streak-loss alarms, no red chosen by the app, no "you're falling behind", no mention of a missed day unless the user opted in. Missing a day produces silence. The user may pick red as their own accent. The owner decided this on 14 November 2026.
2. **Colour carries no meaning.** Heat-map intensity is hatching density, never hue. The user's accent tints marks only, never text, never rules. Text contrast is a fixed constant the user cannot break.
3. **Pausing only ever helps.** A paused day with no log never breaks a run and never extends it. A paused day with a log extends it. The app calls such a day "Logged while paused". The streak function has unit tests that assert exactly this.
4. **Every input is optional.** NFC, widgets and the Watch are shortcuts, not dependencies. Losing a tag breaks nothing.
5. **One write path.** Every `LogEvent` is created in `LogWriter`. A user log reaches it only through `LogHabitIntent`: widget button, Shortcuts and NFC, Control Centre, Action button, Siri and in-app taps all route through it. Import reaches it only through `LogWriter.importEvents`, which writes all of a file or none. The owner approved this wording on 15 November 2026.
6. **Time of day carries no habit meaning.** Palettes follow the clock. They never react to streaks, misses, pauses, counts or completion.
7. **Scenes are calm.** No people, animals, buildings or weather. One soft horizon. Nothing moves. No true red in any palette. Scenes appear in one framed card at the top of Today and nowhere else, never behind text, rows or marks.
8. **System chrome stays system.** Tab bar, navigation bars, sheets, alerts and the keyboard are not restyled or covered.

## Locked decisions

| | |
|---|---|
| Minimum OS | iOS 26, iPadOS 26, macOS 26, watchOS 26. Greenfield. Support nothing older |
| Persistence | SwiftData. CloudKit private database later. No Core Data |
| Accounts | None. No Sign in with Apple, no login screen, no backend |
| Price | Free forever. No ads, no analytics, no telemetry, no paywall surface |
| Habit kinds | `.binary` and `.counted` (optional target and optional unit). With no target, any log is done |
| NFC | Shortcuts automations matched on tag UID. No domain, no universal links, no server |
| Journalling | Obsidian only, through the built-in `obsidian://` URI |
| Mac | Native SwiftUI, not Catalyst |
| Dependencies | None beyond Apple's frameworks. Ask before adding any |
| Time of day | Fixed clock hours derived from the user's day-start setting. No location, no CoreLocation, no network. A manual override exists |
| Scene art | Pre-rendered raster assets. One greyscale value layer per scene, tinted at runtime by palette, within the size budget in `docs/spec.md` |
| Structure | One shared Swift package `HabitKit` (models, day and pause maths, ordering, nudge scheduling, formatting) used by the app, watch, widget and intents targets |
| Schema | Additive only, forever. Never rename or retype a field. New fields are optional or defaulted, and the default lives on the stored property itself. A new schema version is needed only when the set of `@Model` types changes |
| CloudKit | The owner has not bought the Apple Developer Program. No CloudKit entitlement or container. An `.entitlements` file is allowed for the App Group only. The owner corrected this on 14 November 2026. The Sync milestone is skipped until the owner says |
| Counts | `LogEvent.delta` is any whole number. A habit has a tap amount, default 1. Every number the user sets can be typed. Arrows are never the only way to reach a number |

## Design rules that do not change

- Text contrast floor, every style, paper / ink: body 17.7:1 / 16.2:1, secondary 6.8:1 / 8.3:1, tertiary 4.8:1 / 5.1:1. Measured against the worst pixel of the style's paper.
- State is carried by shape, never by wash colour or intensity.
- Mark states: solid (done), hatched (part done), centred dash (paused), diamond (logged while paused), small dot (off schedule), blank (nothing logged), dashed outline at reduced opacity (to come). Today is an outline overlaid on the day's state.
- A past day with no log draws nothing. The empty outline for such a day, and the current run, appear only when the user turns on "Show days not logged". The owner decided this on 14 November 2026.
- The year view carries state by small shapes, never by opacity. The owner decided this on 14 November 2026.
- The user's accent choice comes first. Following the palette is the default option, not a rule. A custom colour is picked by hue. Any hue is allowed, red included. The app sets its lightness so marks keep 3:1. The app's own tokens, swatches and palettes never use red.
- Scene card is 350 by 118 points. No text sits on it.
- Views read the style from the environment. A view that computes a colour or names a font is a bug. Tokens live in the style files only.
- Accessibility is v1: Dynamic Type to AX5, VoiceOver, Increase Contrast, Reduce Transparency, 44 by 44 targets.

## Working rules

**Git.**
- One change, one branch, one PR. Branch off `main`, named for what it does (`feat/…`, `fix/…`, `docs/…`). Never commit to `main` after the first commit.
- After every commit, run `git push`.
- Finish each milestone by opening the PR with `gh` and stopping there. Merge only when the owner asks in that run. Never enable auto-merge. Do not force push.
- The repo is public. Commit nothing private: no secrets, no personal data, no seed string, no fixtures with real data.

**Phases.**
- Phase 1 is design. It ends with a stop. No Swift is written in phase 1.
- Phase 2 milestones, in order, as the owner changed them on 14 November 2026: 1 Core loop in Pen and ink. 2 History, export and import. 3 Pausing and one Home Screen widget. Stop and report. 4 Pencil and Watercolor. 5 Scenes. 6 Sync (skipped until the owner says). 7 Ambient. 8 Nudges. 9 Ordering. 10 NFC. 11 Obsidian. 12 Removal. 13 Polish. Scene art is supplemental. No scene card or palette is built before milestone 5. What each holds is in `docs/spec.md`.
- After each milestone, run the reviews on the diff as separate subagents (see Review lenses), fix what is valid, and send a report.
- No scene is built that the owner has not approved.

**Scope.**
- Stay in scope. Anything noticed outside the current milestone is a line in the report, not a commit.
- A change made to test a hypothesis is reverted when the hypothesis fails.
- Describe the diff you made, and say what the brief asked for that you did not do.
- Prefer deleting code to adding a flag.
- When the brief is silent, ask. Do not invent a convention.

**Writing.** Prose (commits, reports, comments, docs) is plain and says what changed. One idea per sentence. Do not write for effect. No "worth noting", "to be clear", "the real question is", no sentence fragments for emphasis, no grading your own work with words like "successfully" or "perfect". If a sentence can be deleted without losing information, delete it.

**Reports.** First line is the result. Then the definition-of-done list with honest pass or fail, anything guessed, anything noticed that is wrong or stale, the decisions log, and anything the brief asked for that was not done.

**Command approvals.** Before any command that needs approval, say in one plain sentence what it does and whether it is reversible. Flag `rm`, `sudo`, `git reset --hard`, force pushes and anything outside the project folder.

**Definition of done.** Walk this list in each milestone report and mark each line honestly.

- Builds for macOS, `generic/platform=iOS Simulator` and watchOS with no errors and no new warnings
- `swift test` in `HabitKit` and the app tests pass, including tests added
- Streak tests assert invariant 3 directly: paused with no log neither breaks nor extends; paused with a log extends
- A test asserts no style token, swatch or palette colour is red
- Contrast test: every text token on the worst pixel of each style's paper, both appearances, meets the floor
- Palette selection by clock is tested at every boundary, with the day-start hour at 0 and at 6
- A test asserts an unknown stored style, scene or palette falls back to Pen and ink, Lake and auto
- Export and import round-trip test passes
- An automated check fails if `Color("` or `.custom(` appears outside the style files
- Screenshots of every screen, style and appearance saved with paths listed, deterministic (pinned simulator, fixture store, frozen clock, animations off)
- Each screen checked at AX5 and with Increase Contrast
- Scrolling Today with 30 fixture habits does not redraw grain per frame. Say how it was checked
- Scene assets: total size listed, within budget. Each scene checked at full, half and one-third size, in all five palettes, under the four colour-vision filters
- No scene was built that the owner had not approved
- No new dependencies. `docs/asset-licenses.md` lists every font and texture
- Every target has a privacy manifest
- The reviews ran as separate subagents and their findings are in the report

**Review lenses.** Each lens runs as a separate subagent that has not seen the working. It gets its brief, this file and the thing under review. It returns at most five findings, ranked, each with a file and line or a screen, and a concrete failure scenario. Valid findings are fixed. The rest are listed with the reason.

After each milestone three lenses run: senior software engineer, QA engineer and tired daily user. Accessibility is added when the diff changes the UI. Security and privacy is added when the diff adds a permission, a file or a dependency. All twenty run at each stop: the end of phase 1, after milestone 3, and at the end. Run lenses two or three at a time, not all at once. The owner set this on 14 November 2026.

| Lens | Team role | Brief |
|---|---|---|
| Accessibility expert | Accessibility specialist | WCAG 2.2 AA, Dynamic Type to AX5, VoiceOver, Increase Contrast, Reduce Transparency, Differentiate Without Colour, 3:1 non-text contrast, 44x44 targets, custom-font scaling and legibility |
| Security and privacy expert | Security and privacy engineer | Provenance and licensing of fonts and textures, network calls, permissions, logging, anything that leaves the device |
| Apple industrial designer | Visual and platform designer | Fit with iOS 26 and macOS 26 and the HIG, system chrome untouched, hierarchy and restraint, decoration never carries meaning, both appearances, iPhone, iPad and Mac layouts |
| Senior software engineer | Tech lead | Single source of tokens, schema and sync safety, tests that can fail, screenshot determinism, scroll performance, scope creep, dead code |
| Typographer | Type designer | Font pairing and hierarchy, numeral clarity (1 and l, 0 and O), long names wrapping, weight range for Bold Text, glyph coverage, license |
| Color vision and low vision | Accessibility specialist | Protanopia, deuteranopia, tritanopia and greyscale views of every scene and palette, mark legibility beside the scene card, AX5 layout, whether any palette reads as a warning |
| Performance and app size | Performance engineer | Scene asset size and decode cost, memory on palette change, scroll cost on Today, launch time, runtime tinting cost, caching |
| Tired daily user | User research | Someone on a low-energy day who glances once. Is logging still one obvious tap? Any visual noise? Any state harder to read at a glance? Anything that feels like effort, judgment or guilt? |
| Product owner | Product manager | Does the work match the brief and nothing more? Does each milestone leave something a user can use? Is every open question written down with an owner? What should be cut? |
| First-day user | User research, onboarding | Someone who has never seen the app. Empty states, the first habit, whether each mark can be understood without a key, whether every gesture has a visible alternative, where they would get stuck |
| Content designer | UX writer, localisation | Every string: plain, short, free of guilt and grading. Plurals, dates and numbers by locale, week start, text 40% longer in translation, right-to-left layout, VoiceOver wording |
| QA engineer | Test engineer | Day start, midnight, daylight saving, time-zone travel, counted habits and undo, logging a past day, pause edges, export and import, the smallest and largest devices, what the tests do not cover |
| UI and UX designer | Interaction designer | Task flows from start to finish, every state of every screen (empty, partial, full, error), navigation, feedback after each action, recovery from a mistake, consistency of controls across screens |
| Human factors | Human interface and human factors | Glance time, reach and thumb zones, target size and spacing, slips and mistaken taps, memory load, mode errors, how many decisions a task takes, use while tired, walking or one-handed |
| Senior designer | Design lead | Whether the product holds together as one thing: hierarchy, rhythm, restraint, what to remove, whether the three styles are distinct and each complete, whether every screen earns its place |
| Behavioural scientist | Behaviour change research | Does the design help a habit form: a clear cue, low friction, a small reward at the moment of logging. Whether runs, counts and extra credit motivate or pressure. Fit for people with ADHD or low executive function |
| Neurodiversity expert | Neurodiversity-affirming clinician | Autistic, ADHD and AuDHD users. Executive function load, time blindness, demand avoidance, all-or-nothing thinking, sensory load of texture and colour, shame after a gap, whether pausing and flexible targets are easy to reach, whether the wording treats the user as capable |
| Returning user | User research | Someone who opens the app after three weeks away, and someone on day 200. Is the first screen free of judgment? Is it easy to start again, drop a habit, or change a target? Does a long history stay readable? |
| Illustrator | Art director for scenes | Each scene as a painting: composition, value structure, edges, whether it reads as the place, whether it is calm, and the brief's list of what failed before. Runs at every scene gate as well as at stops |
| Release engineer | Build and release | What works with a free Apple account, App Groups and the shared store, signing, privacy manifest and required-reason APIs, when the notification prompt appears, widget tint modes, app icon variants, App Review rules |

Roles a typical app team has that this project leaves out, with the reason: backend and DevOps (there is no server), data analyst (there is no analytics), growth and marketing (the app is free and has no accounts), monetisation (there is no paywall).

**Accessibility.** This is v1, not polish.
- Dynamic Type to AX5 on every screen. Layouts reflow, nothing clips.
- Custom fonts scale with the text style. A fixed-size custom font is a bug. Bold Text uses a heavier weight.
- VoiceOver on the heat map groups by week with a summary and an `AXChartDescriptor`. Never 365 focusable cells.
- Increase Contrast maps to heavier ink. In Watercolor it also turns washes and grain off. Reduce Transparency removes grain.
- 44 by 44 minimum targets. Full Keyboard Access and complete menu-bar commands on Mac.
- Differentiate Without Colour needs no special handling and must stay that way.
- A mark measures at least 3:1 against the paper behind it, as drawn. 3:1 is the WCAG 2.2 minimum for a shape that carries information.
- The scene card is decorative. It has one accessibility label that names scene and palette. It must not crowd the first habit row at AX5.

**Architecture.**
- Styles are data. Adding a style changes nothing outside the style files and the picker.
- `HabitApp`'s `ModelContainer` is always built through a migration plan, never a bare `Schema`.
- Font names that do not resolve fail silently. A test checks that each font resolves on each platform.
- Paper grain is rendered once per size and reused. No live blur or shader effects redrawn while scrolling.

**Security and privacy.**
- No network calls, permissions, entitlements or dependencies beyond what a feature needs and the owner approved.
- No analytics or log event on any user action. No user content in log output.
- Fonts must be free to redistribute or installed with the OS. Download from the official source only. Commit the license next to the font and record source URL and file hash in `docs/asset-licenses.md`.
- Textures are drawn in code or are assets with a recorded license.
- Screenshots use fixture data only.
