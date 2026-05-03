# FrosthavenAssistant — Agent Instructions

This repository hosts a personal fork of X-Haven Assistant, a Flutter combat helper for Gloomhaven, Frosthaven, and related campaigns.

## Repository Layout

This is a multi-package repo. Each subproject has its own purpose:

- **`frosthaven_assistant/`** — Main Flutter app (Android, iOS, Windows, Linux, macOS, Web). See [`frosthaven_assistant/CLAUDE.md`](frosthaven_assistant/CLAUDE.md) for architecture (Command pattern + ValueNotifier, GetIt service locator, `dart_code_metrics` rules, testing with mockito + build_runner).
- **`frosthaven_assistant_server/`** — Headless Dart server (Dockerized, port 4567) that hosts shared game state for multi-device play. Local path dependency of the main app.
- **`room-data-converter/`** — Dart tool that produces room and scenario JSON for each campaign (`Frosthaven.json`, `Gloomhaven.json`, `Crimson Scales.json`, etc.). Output is consumed by the main app's `assets/data/`.
- **`showoff/`** — Screenshots used in the README and release material. Not code.

When in doubt about which subproject owns a change, check whether it touches game UI (`frosthaven_assistant/`), networking protocol (both app and server), or game data shape (`room-data-converter/` produces, app consumes).

## Development Workflow (MANDATORY)

All non-trivial work MUST follow this order. Do not skip steps or reorder.

1. **Update usage docs** — Update or create docs (README, CLAUDE.md, inline doc comments) that describe what you're building BEFORE you build it. If your change adds a new command class, widget, network message, or concept, document it first.

2. **Update data/messaging schema** — If your change touches the network protocol, JSON data shapes in `assets/data/`, or the public shape of a Model class, update those definitions next. Schema-shaped changes go in before any code that uses them.

3. **Write tests** — Write failing tests that describe the expected behavior. Tests go in BEFORE the implementation. New Command classes especially — test `execute()`, `undo()`, and `describe()` round-trip behavior up front.

4. **Write code** — Now implement, making the tests pass.

5. **How to demo** — Every feature, task, or fix must include instructions for verifying it. This could be a `flutter test` invocation, a manual click-path in `flutter run`, a curl against the server, or a screenshot diff. If there's no way to demo it, the work isn't done.

   Examples:
   - `flutter test test/command/add_monster_command_test.dart` — new test should pass
   - `flutter run -d macos`, open *Set Scenario* menu, select Frosthaven scenario 23 — new objective row should appear
   - `docker run -p 4567:4567 frosthaven-server && curl localhost:4567/health` — should return ok

This order ensures: docs stay current, schemas are intentional (not accidental), tests define behavior (not just verify it), and code is the last thing written.

**Commit after each step.** Do not accumulate uncommitted work. If a session ends mid-task, only uncommitted work is lost. Commit early, commit often:
- Commit after updating docs
- Commit after updating schema/data shapes
- Commit after writing tests (even if they fail)
- Commit after writing code (tests should pass)

Use clear commit prefixes: `docs:`, `schema:`, `test:`, `feat:`, `fix:`, `refactor:`.

### Bug fix exception

Bug fixes that correct behavior to match existing documentation do NOT need new docs. They still require:
- A **regression test** that proves the bug is fixed
- All tests passing

A regression test counts as the demo for a bug fix.

## Task Scope

Keep individual tasks small and shippable.

A well-scoped task:
- Has ONE primary deliverable
- Can be completed in 15-30 minutes
- Has clear acceptance criteria
- Has a single "how to demo" instruction

If a task feels like more than 3-4 commits, split it before starting. "Add X, update Y, and fix Z" is three tasks, not one.

## Code Conventions (cross-cutting)

- **Dart/Flutter** — Lints from `dart_code_metrics` are strict. Run `flutter analyze` before committing. Avoid `dynamic`, `late`, and `!` (non-null assertions).
- **State changes** — In the main app, NEVER mutate state directly. All mutations go through `Command` objects. See [`frosthaven_assistant/CLAUDE.md`](frosthaven_assistant/CLAUDE.md) for the full pattern.
- **Immutability** — Models use `built_collection`. Don't expose mutable internals.
- **Magic numbers** — Recent direction is to extract to a `values` file. Follow suit when touching UI.

## Upstream and Branch Policy

This is a personal fork of `Tarmslitaren/FrosthavenAssistant`. Goals: contribute fixes/features back upstream where appropriate, and maintain personal quality-of-life improvements that may not be upstream-suitable. See [`docs/strategy.md`](docs/strategy.md) for the full plan and rationale.

### Remotes

```
origin    = git@github.com:francoisdevlin/FrosthavenAssistant.git   (the fork)
upstream  = https://github.com/Tarmslitaren/FrosthavenAssistant.git (Tarmslitaren's repo)
```

### Branches

| Branch | Purpose | Pushed to upstream? |
|---|---|---|
| `main` | Mirror of `upstream/main`. Never commit directly here. Used as the base for upstream PRs. | n/a |
| `fork-main` | Daily working branch. Contains everything in `main` PLUS this `CLAUDE.md`, the `docs/` tree, agent scaffolding, and any personal QoL features that aren't upstream-bound. | **Never.** Fork-only. |
| `feat/*`, `fix/*`, `docs/*`, `refactor/*` | Topic branches. Cut from `main` if the work is destined for upstream; cut from `fork-main` if it's fork-only. | PR'd to upstream if cut from `main`. |

### Rules

1. **`fork-main` never gets PR'd to upstream.** It carries this CLAUDE.md and `docs/` — internal scaffolding that has no business in upstream.
2. **Upstream-bound work cuts from `main`**, not `fork-main`. This keeps the PR diff free of agent/docs noise.
3. **Keep `main` synced with upstream.** Periodically run `git fetch upstream && git merge --ff-only upstream/main` (or rebase) so PR branches stay clean.
4. **When a fix is both useful to your group AND upstream-suitable**, do it as an upstream PR from `main`-based branch first. Once merged upstream, `fork-main` picks it up naturally on the next sync.

### Working with the maintainer

Tarmslitaren reviews PRs personally. Build trust progressively (see strategy doc). Tier 1 = trivial/obvious fixes. Don't open structural-refactor PRs cold — propose them via issue first.

### AI-assistance disclosure (standing rule)

Disclose Claude assistance on:
- The first comment in any new upstream issue thread we open or join
- The body of every upstream PR we submit

The form: a short, neutral footer (under a horizontal rule) noting that the comment/PR was drafted with Claude assistance and reviewed by the human contributor. Avoid both extremes — don't downplay the workflow, don't overstate it. Be specific about what was AI-assisted (analysis, drafting) and that a human reviewed before posting.

The maintainer maintains a `claude_refactor` branch, so AI-assisted contributions are within his comfort zone. Disclosure matches transparency for transparency. If a future maintainer is hostile to AI assistance, the disclosure surfaces that cheaply, before we sink work into a PR that won't merge.

Sample footer (adapt as needed):

> ---
>
> *Disclosure: I work with Claude as a coding assistant — this was drafted with its help and reviewed by me before posting. Will flag the same on any potential PRs going forward.*
