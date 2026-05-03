# Validation — What "Ready to PR" Actually Means

The CLAUDE.md says every change needs a "how to demo" step. This doc spells out what's enough, what's not, and how the bar shifts depending on where the work is going.

## The validation pyramid for this codebase

```
                      Manual play-test
                  ┌─────────────────────┐
                  │ Click through the   │
                  │ user-facing flow    │
                  │ on macOS desktop    │  ← required for UI / multi-step changes
                  └─────────────────────┘
                ┌──────────────────────────┐
                │   Targeted unit tests    │
                │   (flutter test path/x)  │
                └──────────────────────────┘   ← required for new logic
              ┌──────────────────────────────┐
              │   Full unit test suite       │
              │   (flutter test)             │   ← always
              └──────────────────────────────┘
            ┌──────────────────────────────────┐
            │   Static analysis                │
            │   (flutter analyze)              │     ← always
            └──────────────────────────────────┘
```

We climb only as high as the change requires.

## What's required for which kind of change

### Bug fix (no logic change)

E.g. fixing a typo, correcting a JSON spawn count, swapping a wrong asset reference.

- ✅ `flutter analyze` clean
- ✅ `flutter test` passes
- ❌ New unit test (usually unnecessary for data fixes; unit tests don't exercise data accuracy)
- ❌ Manual play-test (unless the fix is user-visible — then yes)

### Bug fix (logic change)

E.g. fixing the EPIPE socket exception (#244), correcting an off-by-one in initiative ordering.

- ✅ `flutter analyze` clean
- ✅ `flutter test` passes
- ✅ **Regression test** that proves the bug was present and is now gone
- ✅ Manual repro of the original bug, then verify the fix

### New feature (user-visible)

E.g. global hotkeys (#304), a new menu option, a new condition icon.

- ✅ `flutter analyze` clean
- ✅ `flutter test` passes
- ✅ Targeted unit tests for any new logic (Command classes especially)
- ✅ Manual play-test on the primary platform — click the feature, verify the visible behavior
- ✅ Brief screen recording or screenshot in the PR body if the change is visual

### Networking change

E.g. anything in `lib/services/network/`, the headless server, the protocol.

- All of the above, plus:
- ✅ Two-instance test: run a server in one window, a client in another, exercise the change
- ✅ Disconnect/reconnect cycle without stuck state

This bar is high because networking bugs are the most common user-reported ones, and the test suite barely touches this layer.

### Data file edit

E.g. correcting a scenario, updating a monster ability.

- ✅ `flutter analyze` clean (catches JSON parse failures)
- ✅ `flutter test` passes
- ✅ Load the affected scenario in the running app, verify the change appears
- ✅ Reference the rulebook source in the PR body so review is fast

## "Manual play-test" — what does that mean concretely?

For a UI change to character widgets:
1. `flutter run -d macos`
2. Add a character (Add Character menu)
3. Set scenario (Set Scenario menu, pick something simple like Frosthaven 1)
4. Exercise the changed UI
5. Undo the change. Redo. Verify the state is restored / reapplied correctly.

For a Command change:
1. As above, plus
2. Trigger the command, then click *Undo* in the side menu — verify the state actually reverts
3. *Redo* — verify it reapplies cleanly

Undo/redo is *the* hidden gotcha in this codebase. A Command that's wrong on undo will look correct on first execution and break only when the user undoes — easy to miss.

## What `flutter test` does NOT cover

Reading the `test/` directory: tests focus on Command behavior and some Resource logic. They do **not** cover:
- UI rendering or interaction
- Network communication, server-client sync, or replication
- Asset loading from `assets/data/`
- Platform-specific code (window sizing, fullscreen, hotkeys)

Lean on this when scoping your validation: a passing `flutter test` doesn't mean the user-facing flow works. For anything in those uncovered areas, manual play-test is mandatory.

## The "build_runner" gotcha

Tests use generated mock files (`*.mocks.dart`). Before running tests on a fresh checkout or after changing a mock-using class:

```bash
dart run build_runner build
```

If you skip this, tests fail with "type X is not a subtype of MockX" errors that look like test breakage but are actually missing mocks.

## The bar for upstream PRs vs. fork-only changes

| | Upstream PR | Fork-only |
|---|---|---|
| `flutter analyze` clean | ✅ | ✅ |
| `flutter test` passes | ✅ | ✅ |
| Tests for new logic | ✅ (our discipline, even if upstream doesn't require it) | Optional |
| Manual play-test | ✅ for user-visible changes | ✅ for user-visible changes |
| Documented in PR body | ✅ | n/a |

We hold ourselves to a slightly higher bar than upstream's revealed preference (see [`maintainer-style.md`](maintainer-style.md)) because Track C (validation skill) is part of why we're here. But we don't *demand* others meet our bar — that's not our job as a contributor.

## When validation fails

- **`flutter analyze` complains** — fix it. The codebase has strict `dart_code_metrics` rules and adding violations sends the wrong signal upstream.
- **`flutter test` fails** — first run `dart run build_runner build`. If still failing, your change broke something.
- **Manual play-test reveals a regression** — back out the change and rethink. Don't ship and "fix in a follow-up."
