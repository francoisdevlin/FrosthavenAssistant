# Architecture

A deeper dive than [`../frosthaven_assistant/CLAUDE.md`](../frosthaven_assistant/CLAUDE.md). That file orients an agent for tactical work; this one captures the WHY.

> **Status:** initial pass based on code survey. Refined as we work in different areas.

## The shape of the app

A single-window Flutter app that mirrors the physical state of a Gloomhaven/Frosthaven game session: which monsters are on the board, their health and conditions, the modifier deck, current initiative, scenario rules. It's a **stateful UI over a heavily-shared mutable game state**, with two complications that drive the design:

1. **Undo/redo across arbitrary actions.** Any state-affecting action can be undone, including network-synced ones.
2. **Multi-device sync.** The same state can be authoritative on one device and replicated on N others over LAN.

Both are solved by the same mechanism: every state change is a `Command`.

## The Command pattern is load-bearing

`lib/Resource/commands/` contains 70+ command classes. Each one:
- Knows how to `execute()`, `undo()`, and `describe()` itself
- Holds the data needed to do both (e.g. `ChangeHealthCommand` holds the figure ID and the delta)
- Can be serialized to flow over the network

Commands are dispatched through `GameState.action(command)`. This is the single mutation path. Direct mutation of state classes is prevented by a `_StateModifier` capability token — only `Command` objects can pass it, so the type system enforces the discipline.

The `ActionHandler` (`lib/Resource/action_handler.dart`) owns:
- A 250-deep history of commands paired with `GameSaveState` snapshots
- The undo/redo cursor
- Network broadcast on execute (when hosting) and replication on receive (when client)

This is why it's so important to never mutate state outside a command: anything done outside the command pipeline is invisible to undo and to peers.

## State exposed via ValueNotifier, consumed via ValueListenableBuilder

`GameState` and friends expose `ValueListenable<T>` getters. UI widgets bind via `ValueListenableBuilder<T>`, so a single `notifyListeners()` after a mutation triggers exactly the rebuild scope it should.

The codebase has 92+ ValueNotifier instances. This is more than typical — each conceptually-separate piece of state gets its own notifier so a change in one (e.g. round number) doesn't redraw something unrelated (e.g. the modifier deck).

**Why this rather than Provider, Riverpod, or Bloc?** This codebase is older than the popularity of those, and `ValueNotifier` ships with Flutter. The trade-off: more boilerplate, but no third-party state-management dependency.

## Service Locator (GetIt) for cross-cutting singletons

`lib/services/service_locator.dart` registers 7 lazy singletons:

| Service | Role |
|---|---|
| `GameData` | Loads campaign/scenario/monster JSON from `assets/data/` |
| `Settings` | User preferences (28 ValueNotifiers, persisted via `shared_preferences`) |
| `GameState` | The central mutable game state (split into 10+ part files) |
| `Communication` | Application-level networking layer |
| `Network` | OS-level networking (sockets, info) |
| `Connection` | Connection lifecycle management |
| `Client` | Client-mode connection state |

Code accesses these via `getIt<ClassName>()`. This pattern is straightforward but means most of the app reaches global singletons — cleanly testing a unit that touches `GameState` or `Settings` requires mocking the GetIt registration.

## The networking model

Found in `lib/services/network/`:

- **Server mode** — one device hosts. It runs a TCP listener on port 4567 (configurable). Clients connect.
- **Client mode** — connects to a server's IP:port. Server's state overwrites client's local state on connection.
- **Sync mechanism** — commands are broadcast on execute. Clients apply received commands. If a client tries to execute locally while out of sync, the server's state wins and the client's change is discarded.

The headless server (`frosthaven_assistant_server/`) reuses the same `Communication` protocol but without the Flutter UI — it's a Dart command-line app that holds game state and brokers between connected clients. Useful when no one's device can reliably stay in foreground.

## Game data is read-only JSON, loaded once

`assets/data/` holds:
- `editions/` — campaign-specific monster, scenario, and ability data
- `rooms/` — room layout definitions
- 28 JSON files total, ~68 MB of associated images

`GameData` parses these into `Model` classes (`lib/Model/`) at startup. The Model classes are immutable and used as read-only references throughout the app. This is the "schema" boundary: data shape is fixed at JSON authoring time, and the `room-data-converter/` sibling project produces these JSONs.

When we modify a campaign, scenario, or monster, we're either:
- Editing a JSON in `assets/data/` directly (small fixes, e.g. spawn counts)
- Adding a new entity that didn't exist (rare)
- Re-running `room-data-converter/` (broader changes)

## Model vs. State

Subtle but important distinction:

| | `lib/Model/` | `lib/Resource/state/` |
|---|---|---|
| Mutability | Immutable | Mutable (via commands) |
| Loaded from | JSON assets | Created at runtime per game |
| Lifetime | Process | Per scenario |
| Examples | `Campaign`, `Scenario`, `MonsterAbility`, `Room` | `GameState`, `MonsterInstance`, `CharacterState`, `ModifierDeck` |

Model objects describe what *exists in the rules*. State objects describe what's happening in *this game session right now*.

## The `_currentList` pattern

`GameState._currentList` is the active turn order — characters and monsters interleaved, sorted by initiative. It's a `BuiltList<ListItemData>` (immutable view over a private mutable list). This list is the source of truth for "who acts next" and is one of the most-touched pieces of state. Most "add monster", "remove character", "reorder" commands ultimately mutate this.

## Layout layer

`lib/Layout/` contains 75+ widget files organized into:
- `CharacterWidget/` — character row UI
- `menus/` — modal dialogs (39 files; settings, scenario picker, AMD viewer, etc.)
- `components/` — reusable UI bits
- Top-level widgets for the main screen scaffold

A few notable widgets:
- `main_list.dart` — the primary scrollable initiative list
- `bottom_bar.dart` — round/scenario/draw controls
- `top_bar.dart` — element infusions
- `global_hotkeys.dart` — desktop keyboard shortcuts (added in upstream PR #304)

## Where the design starts to creak

Honest assessment, useful for picking refactor targets later:

- **`GameState` has too much surface.** Split into 10+ part files; that's organization, not decomposition.
- **`getIt` is reached into from deep widgets**, not just at composition roots. Coupling.
- **Logging is print/debugPrint/developer.log, no abstraction.** [Documented separately.] No way for a user to send us logs.
- **No structured error handling.** `catch (e)` blocks often `print(e.toString())` and continue. Some have `if (kDebugMode)` guards, some don't.
- **Tests don't exercise the network or UI in any depth.** `test/` mirrors `lib/` in places, but coverage is uneven.

These are observations, not items to fix today. Each could be a Tier-3 or Tier-4 effort once trust is established.

## Reading order for a new agent

If you're new to this codebase and need to make a change in app code, a useful reading order:

1. `lib/main.dart` — what gets initialized
2. `lib/services/service_locator.dart` — what's globally available
3. `lib/Resource/state/game_state.dart` — the central state
4. One existing command in `lib/Resource/commands/` similar to your task — to see the pattern
5. The widget(s) you're touching, working out from `main_list.dart` if it's UI

The CLAUDE.md in `frosthaven_assistant/` covers the conventions; this doc covers the why.
