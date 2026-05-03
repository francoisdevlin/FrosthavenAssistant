# User Manual — Outline Proposal

A working sketch of what a real user manual for X-Haven Assistant could look like. Companion to bead `xhaven-chk`. Lives here so we can iterate, then attach to an upstream issue when proposing.

## What this is, and isn't

**It IS:** a guide to using the *app* — what every screen, button, and menu does; how to configure for various play styles; how to recover from mistakes; how multiplayer behaves.

**It IS NOT:** a rulebook. The actual game rules belong in Cephalofair's rulebook. Where game concepts come up (initiative, conditions, elements, etc.), we cite or briefly recap, never replicate. The rulebook is the source of truth for *what is true in the game*; the manual is the source of truth for *what is true in the app*.

## What's wrong with the README's Usage section today

The current README has a "Usage" section with ~40 unstructured bullets — a flat bag of "tap X to do Y" tips. It works as a reference if you already know what you're looking for, but:

- No conceptual structure. Tips about the AMD are scattered, tips about character widgets are scattered, networking is at the bottom.
- No progression. A new user can't read top-to-bottom and feel oriented.
- No anchor for "I'm in the middle of a round and I can't figure out X."
- Missing context entirely for: undo/redo behavior in detail, edition differences, accessibility settings, custom difficulty, what's computed vs. what's tracked.

A real manual organizes by play flow + app feature, with a reference section underneath.

## Audience

Three sketchy personas:

1. **New player, new app.** Bought the game recently, picked up the app to ease setup. Needs the conceptual scaffolding plus the "first scenario" walkthrough.
2. **Returning player, used Gloomhaven Helper before.** Looking for "how is this different / what's new / what hasn't changed."
3. **Power user.** Wants to know about networking, custom monsters, settings, edge cases.

The manual should serve all three without privileging any. Quick Start handles persona 1; reference + cross-edition section handles persona 2; advanced sections handle persona 3.

## Proposed structure

### Front matter

- **Welcome** — what the app does, what's outside scope (campaign progress, character sheets), supported editions.
- **Quick Start** — first scenario from cold install. (Reuses the existing README "Set-up Guide" + adds tap-by-tap detail.)

### Part I — Anatomy

- **The Main Screen** — the four regions: top bar (elements), main list (initiative + figures), bottom bar (round + scenario + draw + AMD), sidebar menu (`≡`). Annotated diagram.
- **Common Gestures** — tap, long-press (reorder), double-tap (zoom card), swipe, "tap outside menu to close." This is the kind of thing the README hides and that intermediate users always rediscover.
- **Icon and Symbol Glossary** — element icons, condition icons, modifier deck symbols, the meaning of standee colors and numbers.

### Part II — Setting Up

- **Adding Characters** — Add Character menu, name editing, level (and how level affects stats), starting HP edge cases (perks/items that grant +max HP — reference issue #213).
- **Setting a Scenario** — Set Scenario menu, choosing campaign + scenario number, what auto-populates (monsters, special rules, objectives), what doesn't (battle goals — see PR #250 re Buttons & Bugs).
- **Adding Monsters Manually** — Add Monsters menu, when you'd use it (custom scenarios, mid-scenario reinforcements not from a section).
- **Adding Sections** — when scenario books reveal a new section, how to add its monsters/rules.
- **Custom Difficulty** — adjusting monster level or max HP per-monster, scenario level adjustment.

### Part III — A Round, Step by Step

This is the heart. Mirrors the rulebook's round structure but focuses on app interactions.

- **Card Selection (player phase)** — what the app does and doesn't enforce. Players still pick cards physically.
- **Drawing Monster Abilities** — the Draw button, what triggers it, what the turn counter shows.
- **Setting Initiative** — tap targets (under the initiative marker), the soft numpad option, drag-and-drop banners variant, secret initiative in network play.
- **Sorting and Acting** — the main list reorders by initiative; how to read it; long-press to manually reorder.
- **During a Turn** — character widget anatomy (HP, conditions, XP, level, summons +); monster standee menus (HP, conditions, level); how to apply damage, conditions, healing.
- **Modifier Decks (AMD)** — when monsters draw, when allies draw, how the discard works, advantage/disadvantage drawing, perks for character AMDs.
- **Elements** — the top bar: tap to infuse, long-press to set waning. Visual states.
- **Ending Turn / Round** — the active banner icon, the Next Round button (and the morphing-button issue per #135 / xhaven-46c when fixed).

### Part IV — Special Scenario Mechanics

- **Objectives and Escorts** — represented as "characters" in the list; how to add them; how their HP/init are calculated.
- **Allies** — separate AMD, when they appear.
- **Timers and Reminders** — start-of-round / mid-round notes the app surfaces.
- **Spawns** — auto-add via section vs. manual.
- **Named/Boss Monsters** — how they differ from normal/elite, why they exist.
- **Standee Limits** — what happens when you hit the cap.

### Part V — Frosthaven Specifics

- **Loot Deck** — composition (auto-calculated by character count), drawing during turns, attribution, enhancement (and persistence across scenarios).
- **Sanctuary Deck** — when it appears, how it interacts.
- **Buttons & Bugs Differences** — battle goals hidden, single-character mode considerations.

### Part VI — Edition Differences

A table or per-edition section covering:

- Gloomhaven 1E
- Gloomhaven 2E
- Frosthaven
- Jaws of the Lion
- Forgotten Circles
- Crimson Scales
- Trail of Ashes
- Seeker of Xorn

For each: which mechanics the app supports, which it ignores, where edition-specific quirks live.

### Part VII — Multiplayer

- **Hosting** — start host server flow, IP detection, port choice, port forwarding caveats.
- **Joining** — connect-as-client flow, what happens on connect (server state overwrites local).
- **What's Synced** — game state. **What's not** — local settings.
- **Disconnect Behavior** — auto-reconnect, foregrounding, why mobile devices struggle as servers.
- **Conflict Resolution** — the `commandIndex` mechanism, "out-of-sync" notifications, what to do when they appear.
- **Initiative Secrecy** — the rule, the edge cases (modifying init reveals it).

### Part VIII — Mistakes, Undo, Customization

- **Undo and Redo** — sidebar menu, depth (250 levels), what they revert and what they don't (local settings unchanged).
- **What If Something's Wrong with the Data** — issue-filing pointer, the "all data is added by hand" caveat.
- **Custom House Rules** — using level adjustment, custom monster HP, secret-init vs. open, expire-conditions option.

### Part IX — Settings Reference

A *short* list since the README already enumerates many. Highlights:

- Scaling (banners, header, footer, soft numpad)
- Dark mode / Frosthaven theme
- Show reminders
- Auto-add spawns
- Auto-expire conditions
- No standees mode
- Networking settings

### Reference appendix

- **Menu Map** — every menu reachable from `≡` and what it does
- **Gestures** — exhaustive list
- **Icons** — exhaustive glossary
- **Keyboard Shortcuts** (desktop) — cross-reference upstream PR #304
- **Known Issues** — link out to the README's Known Issues, don't duplicate

### Where to Get Help

- GitHub issues (and the limited issue template)
- BoardGameGeek forum threads (where most ad-hoc Q&A actually lives)
- Maintainer email (per current README)

## Delivery shape — three options

| Option | Pros | Cons |
|---|---|---|
| **Doc-only** (markdown in `docs/manual.md` and/or rendered to GitHub Pages) | Fast to write, easy to update, no app code change, can ship in days | Not discoverable to users who never visit the GitHub repo. Most users never will. |
| **In-app help screen** (Help menu → renders bundled markdown) | Discoverable from inside the running app, where users actually are. Stays version-locked to the app. | App code work needed; markdown rendering dep; bundles ~kilobytes of text per release. Bigger Tier-3+ lift. |
| **Both** (doc as primary, app links to it) | Discoverable AND maintainable in one source | Maintains coupling between app version and doc URL — link rot risk |

Recommendation: **start doc-only.** Land the manual as `docs/manual.md`. Add the in-app link in a separate, smaller PR if the maintainer wants it. Don't try to ship both in one Tier-3 PR.

## Style notes

- **Voice:** match the README — friendly, direct, lowercase tolerant. Not formal documentation.
- **Length per section:** lean. Anything over ~3 paragraphs without a sub-heading is too long.
- **Examples over rules:** "If you set monster 3 to elite, then..." beats "When promoting monsters to elite class, the following stat substitutions occur."
- **Screenshots:** essential for the Anatomy section and Quick Start. Generate at standard 2x retina from `flutter run -d macos`. Annotate with simple arrows.
- **Cross-reference, don't duplicate:** link to rulebook sections (Worldhaven, BGG, etc.) for game concepts.

## Open questions for the maintainer

These are the questions to put in the upstream issue when proposing:

1. Is a real user manual something you'd want at all? (Some maintainers prefer "the README is the manual.")
2. Doc-only vs. in-app help vs. both?
3. Is `docs/` in this repo the right home, or would you prefer GitHub Pages, a separate repo, or the existing wiki (currently empty)?
4. Voice/style preference?
5. Are screenshots OK to commit? They're large in git.
6. Spoiler considerations? The pikdonker rulebook excludes sticker content for spoiler reasons; should the manual do similar for scenario-specific examples?
7. Maintenance commitment: are *we* committing to keep the manual updated, or are we asking the maintainer to?

## What we'd ship in a first PR (if approved)

Smallest viable scope to get value:

- Front matter (Welcome + Quick Start)
- Part I (Anatomy) with a single annotated screenshot
- Part III (A Round, Step by Step) for the core loop
- Reference appendix stubs

Roughly 1,500-3,000 words of new content + 1-2 screenshots. Sized to be reviewable by a single maintainer in one sitting. Subsequent PRs add Parts II, IV-VIII as separate small contributions.

Following the maintainer-style rule: never cold-PR a structural change. Open the issue first with this outline as the proposal, get feedback, scope a single chapter as the first deliverable.
