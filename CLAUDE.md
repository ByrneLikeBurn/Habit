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

## Invariants

These outrank every other instruction. Violating one is a bug, however good the reason sounds. If an instruction would break one, stop and tell the owner.

1. **No guilt mechanics.** No streak-loss alarms, no red anywhere, no "you're falling behind", no mention of a missed day unless the user opted in. Missing a day produces silence.
2. **Colour carries no meaning.** Heat-map intensity is hatching density, never hue. The user's accent tints marks only, never text, never rules. Text contrast is a fixed constant the user cannot break.
3. **Pausing only ever helps.** A paused day with no log never breaks a run and never extends it. A paused day with a log is extra credit and extends it. The streak function has unit tests that assert exactly this.
4. **Every input is optional.** NFC, widgets and the Watch are shortcuts, not dependencies. Losing a tag breaks nothing.
5. **One write path.** Every `LogEvent` is written by one App Intent, `LogHabitIntent`. Widget button, Shortcuts and NFC, Control Centre, Action button, Siri and in-app taps all route through it.
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
| Habit kinds | `.binary` and `.counted` (target and optional unit) |
| NFC | Shortcuts automations matched on tag UID. No domain, no universal links, no server |
| Journalling | Obsidian only, through the built-in `obsidian://` URI |
| Mac | Native SwiftUI, not Catalyst |
| Dependencies | None beyond Apple's frameworks. Ask before adding any |
| Time of day | Fixed clock hours derived from the user's day-start setting. No location, no CoreLocation, no network. A manual override exists |
| Scene art | Pre-rendered raster assets. One greyscale value layer per scene, tinted at runtime by palette, within the size budget in `docs/spec.md` |
| Structure | One shared Swift package `HabitKit` (models, day and pause maths, ordering, nudge scheduling, formatting) used by the app, watch, widget and intents targets |
| Schema | Additive only, forever. Never rename or retype a field. New fields are optional or defaulted, and the default lives on the stored property itself. A new schema version is needed only when the set of `@Model` types changes |
| CloudKit | The owner has not bought the Apple Developer Program. No CloudKit entitlement, container or `.entitlements` file. The Sync milestone is skipped until the owner says |

## Design rules that do not change

- Text contrast floor, every style, paper / ink: body 17.7:1 / 16.2:1, secondary 6.8:1 / 8.3:1, tertiary 4.8:1 / 5.1:1. Measured against the worst pixel of the style's paper.
- State is carried by shape, never by wash colour or intensity.
- Mark states: solid (done), hatched (part done), centred dash (paused), diamond (extra credit), blank (off schedule, or nothing logged), dashed outline at reduced opacity (to come). Today is an outline overlaid on the day's state.
- A past day with no log draws nothing. The empty outline for such a day, and the current run, appear only when the user turns on "Show days not logged". The owner decided this on 14 November 2026.
- The year view carries state by small shapes, never by opacity. The owner decided this on 14 November 2026.
- The user's accent choice comes first. Following the palette is the default option, not a rule. A custom colour is picked by hue, never red, and the app sets its lightness so marks keep 3:1.
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
- Phase 2 milestones, in order: 1 Core loop and styles. 2 History. 3 Pausing. Stop and report. 4 Sync (skipped until the owner says). 5 Ambient. 6 Nudges. 7 Ordering. 8 NFC. 9 Obsidian. 10 Removal. 11 Polish.
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

**Review lenses.** Each lens runs as a separate subagent that has not seen the working. It gets its brief, this file and the thing under review. It returns at most five findings, ranked, each with a file and line or a screen, and a concrete failure scenario. Valid findings are fixed. The rest are listed with the reason.

The first eight run after every milestone. The last five were added on 14 November 2026 to cover the roles an app team has. They run at each stop: the end of phase 1, after milestone 3, and at the end. Run lenses two or three at a time, not all at once.

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
| Release engineer | Build and release | What works with a free Apple account, App Groups and the shared store, signing, privacy manifest and required-reason APIs, when the notification prompt appears, widget tint modes, app icon variants, App Review rules |

Roles a typical app team has that this project leaves out, with the reason: backend and DevOps (there is no server), data analyst (there is no analytics), growth and marketing (the app is free and has no accounts), monetisation (there is no paywall).

**Security and privacy.**
- No network calls, permissions, entitlements or dependencies beyond what a feature needs and the owner approved.
- No analytics or log event on any user action. No user content in log output.
- Fonts must be free to redistribute or installed with the OS. Download from the official source only. Commit the license next to the font and record source URL and file hash in `docs/asset-licenses.md`.
- Textures are drawn in code or are assets with a recorded license.
- Screenshots use fixture data only.
