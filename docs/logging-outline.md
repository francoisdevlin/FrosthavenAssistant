# Logging Framework — Outline Proposal

A working sketch of how a logging framework for X-Haven Assistant could work — accounting for the realities of mobile platforms, consumer-app constraints, and the project's specific multi-platform footprint (Android, iOS, Windows, Linux, macOS, Web). Companion to bead `xhaven-4uw`.

## Today's situation

- **No structured logging.** 14 raw `print()` calls + 8 `debugPrint()` + 15 `developer.log()`, mixed inconsistently within the same files.
- **No persistent log file.** Output goes to stdout if running via `flutter run` / IDE; vanishes in release builds for the user.
- **No way for users to send logs.** Reports like "can't connect" arrive with no diagnostic context.
- **No log levels.** "Server sends, redo index: 5" sits alongside fatal connection errors at the same priority.
- **Some `kDebugMode` guards, inconsistent.** ~7 places strip output from release; most don't.

## Constraints particular to mobile and consumer apps

This is the most important section. Logging on a phone you ship to non-technical users is *not* the same as logging on a server.

### Storage

- Mobile devices have finite, often tight disk. Phones can't accumulate gigabytes of logs.
- App sandboxes restrict where we can write — only the app docs / cache directories.
- Need **rotation**: cap at e.g. 5 MB total across N rotated files, drop oldest.
- Need **truncation policy**: how long to retain entries within the cap (24h? 7d? until next session?).
- **Web platform** has no real filesystem — `localStorage` is capped (~5-10 MB per origin), and `IndexedDB` is the realistic option for byte volume. Mobile-class trade-offs apply.

### Battery and performance

- Disk I/O burns battery. Verbose synchronous logging = real cost.
- Logging in hot paths (per-frame, per-tick) is unacceptable at default verbosity.
- Need **async write batching** — accumulate in memory, flush every N seconds or N entries.
- Flutter is single-isolate by default. Logging on the main isolate adds latency to UI work. Either run with main-isolate care or push file I/O to a worker isolate.
- **Default verbosity must be cheap.** ERROR/WARN-only baseline, INFO/DEBUG/TRACE only when needed.

### Privacy

- Player names typed into the app are technically PII. So are connected device IPs.
- App store policies (Apple, Google) restrict telemetry collection without consent.
- EU users have GDPR rights — export, deletion, right to know what's collected.
- **Solutions:**
  - **Redact at the log site.** Player names → `<character>` placeholder; IPs → `<remote_ip>`. Or capture but mark as redactable, with a redaction pass on submission.
  - **Local-only by default.** Logs sit on device. Nothing auto-uploads anywhere.
  - **User initiates submission.** A *Send Diagnostics* action that bundles + lets the user inspect + share via system share sheet.
  - **Show before send.** A scrollable preview of what would be sent — reduces surprise.

### App store and platform constraints

- iOS: app sandbox, write to `getApplicationDocumentsDirectory()`, share via `share_plus`. No arbitrary filesystem access.
- Android: scoped storage (API 30+), app-private dir is fine. Share via Android share intent.
- Desktop (Windows/Linux/macOS): broader filesystem access; could open in Finder/Explorer; less constrained.
- Web: no real disk. IndexedDB for persistence, downloadable text file for "submission."

### Crash reporting vs. logging — keep them distinct

Crash reporting and logging serve different needs:

| | Crash reporting (Sentry/Crashlytics/etc.) | Application logging |
|---|---|---|
| What it captures | Unhandled exceptions, native crashes | Anything we choose: events, state changes, errors |
| Trigger | Crash | Continuous, level-gated |
| Submission | Auto-uploaded by the SDK | User-initiated by us |
| Network dep | Yes, on first launch and crash | None |
| Privacy footprint | Significant — needs explicit consent | Local until user shares |

**Recommendation:** for an OSS community app with no server budget, **skip third-party crash reporting**. Keep everything local-only. If we want crash visibility, add `runZonedGuarded` + `FlutterError.onError` handlers that route to our own log facade and let users send the result.

### "We have no server" budget reality

This isn't a SaaS app. There's no observability backend, no Datadog, no Sentry instance to ingest logs. Anything we build has to work entirely client-local. This shapes everything:

- No auto-upload (no destination)
- No real-time dashboards (no consumer)
- The "feedback mechanism" is the user attaching a log file to a GitHub issue or email
- Adaptive verbosity is *for the next time the user reports the bug*, not for a SOC

## Library choices

Comparing the realistic options:

| Library | Pros | Cons | Verdict |
|---|---|---|---|
| `package:logging` (Dart team) | Official. Minimal. Hierarchical loggers. Trivial to subscribe and route output. | No built-in file output. No formatting helpers. Bare bones. | **Recommended** as the foundation. We add file output via a subscriber. |
| `package:logger` | Pretty terminal output with colors. Per-level filters. | Assumes a terminal — output formatting is wrong for mobile. Not designed for file persistence. | Skip. |
| `package:talker` | Flutter-focused. Has file output, in-app log viewer UI, error tracking, route observation. Modern. | Larger surface; more API to commit to. Some Flutter-specific assumptions. | **Strong alternative.** The in-app viewer alone is valuable. |
| Custom only | Total control. No dep weight. | We rebuild common functionality. | Overkill for this scope. |

**Honest take:** start with `package:logging` because it's official, minimal, and replaceable. Build a thin `Log` facade that wraps it. If we later want talker's in-app viewer, we can swap or wrap.

## Architecture sketch

```
┌─────────────────────────────────────────────────────┐
│  Call sites: Log.info("event"), Log.error(e)       │
│  Use the Log facade everywhere — never print()      │
└─────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────┐
│  Log facade (lib/services/log.dart)                 │
│  - Wraps package:logging                            │
│  - Adds source/line attribution                     │
│  - Marks PII fields for redaction                   │
└─────────────────────────────────────────────────────┘
                           ↓
        ┌──────────────────┴──────────────────┐
        ↓                                     ↓
┌──────────────────┐              ┌──────────────────────┐
│ In-memory ring   │              │ Subscribers          │
│ buffer (always   │              │ - Console (always)   │
│ at TRACE level)  │              │ - File sink          │
│ Last N entries   │              │   (when enabled)     │
└──────────────────┘              │ - Error counter      │
        ↓                         │   (drives adaptive)  │
   On error/crash:                └──────────────────────┘
   flush ring buffer to file —
   captures the lead-up history
```

### The ring buffer trick

This is the design move worth highlighting separately.

**Problem:** logging at TRACE level all the time is too expensive. Logging at ERROR level loses the context that led to the error.

**Solution:** keep an in-memory ring buffer (e.g., last 500 entries) that captures *everything* at TRACE level — but it never hits disk. Only entries at the current persistent level go to the file sink. When an ERROR fires, *flush the entire ring buffer to the file*. Now the persisted log has both the lead-up AND the error.

This solves the "I need TRACE detail when something goes wrong, but I don't want TRACE volume in normal operation" tension cleanly. Cheap in the common case, rich when needed.

## Strategic instrumentation points

Per the user's brief: high-value places to log. Targets:

| Location | Why | Level |
|---|---|---|
| `ActionHandler.action(command)` | Every state mutation. Most bugs are "after some action, X became wrong." | DEBUG |
| `ActionHandler.undo` / `redo` | Critical paths often missed in repro reports. | DEBUG |
| `Communication.send` / `receive` | Network protocol bugs are the #1 user-reported. | INFO |
| `Server.onCommand` (the index check) | Where the multi-client dedup happens. | INFO |
| `Connection` lifecycle (connect, disconnect, reconnect) | "Can't connect" is the most common ticket. | INFO |
| Asset loading failures (`GameData`) | Already prints; promote to a real WARN. | WARN |
| Any `catch (e)` block that currently swallows | Promote to ERROR. | ERROR |
| `setRoundState` transitions | Round state is involved in many reported bugs (#135, #170, etc.) | DEBUG |
| Modifier deck shuffle / reshuffle | Card-related bugs are common. | DEBUG |

## Adaptive log levels

Two distinct mechanisms, often conflated:

### A: Ring buffer (always TRACE) → flush on error

Already covered above. **Recommended baseline.** Doesn't actually change the level; just preserves history.

### B: Self-elevating level when errors spike

The user's brief: "when more errors are being detected, scale up the logging."

Implementation:
- Keep an `errorRate` rolling counter (errors per minute over last N minutes)
- If rate exceeds threshold (e.g., 5/min), raise persistent log level from WARN to DEBUG for a cooldown window (e.g., 10 minutes)
- After cooldown, drop back. If rate still elevated, stay DEBUG.

**Risks:**
- Storage pressure during sustained error scenarios
- "Logs always show DEBUG" if a chronic bug is firing
- Mitigated by the rotation cap

**Honest take:** this is genuinely useful for debugging-by-correspondence ("user sends log; we see escalation event marking start of trouble; we get DEBUG context for the actual problem"). But it adds complexity. Consider it Phase E, not Phase A.

## Structured format (for Claude consumption)

JSON Lines (`.jsonl`) — one JSON object per line. Each entry:

```jsonc
{
  "ts": "2026-05-03T18:42:11.234Z",
  "level": "ERROR",
  "source": "lib/services/network/client.dart:97",
  "event": "client.error",
  "message": "Lost connection to server",
  "tags": ["network", "client"],
  "context": {
    "remote_ip": "<remote_ip>",   // redacted
    "command_index": 11,
    "round_state": "chooseInitiative"
  },
  "error": {
    "type": "SocketException",
    "message": "Broken pipe",
    "stack": "..."
  }
}
```

Why this shape:

- One line per entry → trivial to grep, trivial to ingest
- Top-level fields are stable and predictable
- `context` is open for per-event payload
- Standard `event` strings give grep targets ("client.error", "command.dispatch", "round.transition")
- An agent ingesting these can reason structurally — "show me all command.dispatch events between two timestamps with round_state=chooseInitiative"

For the *human-readable* console output, the same logger formats differently:

```
18:42:11.234 ERROR client.dart:97 client.error: Lost connection to server (SocketException: Broken pipe)
```

## User-facing submission flow

The "Send Diagnostics" feature.

### UX outline

- Add menu item: *Settings* → *Diagnostics* → *Share Diagnostics*
- Action: bundle last N MB of log + system info (OS, app version, network mode) into a single text payload
- **Show preview first.** Scrollable view of what will be shared, with redactions applied. User can scroll, scan, then approve.
- Share via system share sheet (`share_plus` package on Flutter):
  - iOS: AirDrop / Mail / Messages / Files / etc.
  - Android: any share-receiving app
  - Desktop: save dialog
  - Web: download as text file

### What goes in the bundle

- Last ~1 MB of structured logs (jsonl)
- App version, build number
- Platform info (os, version, device model)
- Network state (server/client/standalone, anonymized peer count)
- Settings that affect behavior (theme, scaling, soft numpad, etc.)
- **Not** included: raw player names, raw IPs (redacted form OK)

### Privacy preview (mandatory)

A short, plain-language explanation shown above the preview:

> *Your diagnostics include the app's recent activity log, your settings, and your device type. Player names and IP addresses have been removed. Nothing is sent automatically; sharing is up to you.*

### Use cases

- User pastes log excerpt into a GitHub issue
- User emails to maintainer
- User shares with us (via paste into a Claude session) for triage

## Phasing

| Phase | Scope | Why first | Tier estimate |
|---|---|---|---|
| **A** | Introduce `Log` facade + `package:logging`. Console output only. Replace ~10-20% of existing print/debugPrint calls in the most-active files. | No user-visible change. Establishes the pattern. Reviewable by maintainer in one sitting. | **Tier-3** |
| **B** | In-memory ring buffer. Flush-on-error. Still console-only. | Adds the lead-up-context value without disk I/O. | Tier-3 |
| **C** | File sink behind a setting. Rotation. Add menu item but no submission flow yet. | Logs persist now. User can find them via Files app. | Tier-3 |
| **D** | Send Diagnostics flow. Preview + share. | The user-visible value-add. | Tier-3 |
| **E** | Strategic instrumentation rollout. Add high-value log statements at the targets enumerated above. | Once the framework is in, this is mostly mechanical. | Tier-2 / Tier-3 |
| **F** | Adaptive level elevation on error spike. | Optimization. Cosmetic without F. | Tier-3 |
| **G** | Structured (jsonl) format. | Aligns with agent consumption. May affect E if done in retro. | Tier-3 |

Each phase is its own PR. Don't ship them all together. **Phase A is the only one we'd PR cold-ish** (after maintainer says yes via issue) because it's a no-op for users.

## Open questions for the maintainer

The questions to put in the upstream issue when proposing:

1. Do you want a logging framework at all? (Some maintainers prefer the `print()` mishmash — "if it ain't broke...")
2. Library choice: `package:logging` or `talker` or other?
3. Phasing: are you OK with multi-PR rollout (A then B then ...), or do you want it bundled?
4. Privacy posture: are you comfortable with us bundling player names redacted (vs. excluded entirely)?
5. Default file location and rotation policy?
6. Are you open to the in-app viewer feature (talker offers this) or strictly text export?
7. Crash reporting: definitively out (per our reasoning) or do you want a third-party SDK like Sentry?
8. Maintenance commitment: who owns the log surface going forward?

## What we'd ship in a first PR (Phase A only)

If approved:

- Add `package:logging` dep
- Create `lib/services/log.dart` with a `Log` facade (debug/info/warn/error/trace methods, source attribution helper)
- Wire console subscriber in `main.dart` (level-gated by `kDebugMode`)
- Replace existing `print` and `debugPrint` calls in 2-3 high-traffic files (e.g., `client.dart`, `connection.dart`) with `Log.*` calls
- Document the pattern in `frosthaven_assistant/CLAUDE.md`

Sized to be reviewable in one sitting. Strictly no behavior change for users — this is a contributor-facing pattern introduction.

Subsequent PRs add Phases B-G one at a time, each with its own issue / discussion thread.

Following the maintainer-style rule: never cold-PR a structural change. Open the issue first with this outline, get feedback, scope Phase A as the first deliverable.
