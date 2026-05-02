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

## Upstream

Origin is `francoisdevlin/FrosthavenAssistant` (a fork). Upstream is `Tarmslitaren/FrosthavenAssistant`. When fixing a bug that exists upstream, consider whether the fix should also be offered upstream as a PR.
