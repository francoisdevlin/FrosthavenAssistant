# Project Strategy

The why behind work in this fork. This document captures goals, multi-track approach, and operating principles. It evolves as we learn.

## Three goals

| Goal | Horizon | Success looks like |
|---|---|---|
| **A. Make the app better for game night** | Months → years | Our group hits fewer rough edges; quality-of-life features land |
| **B. Build trust with the upstream maintainer** | Months | PRs merge with light review; Tarmslitaren sees us as a reliable contributor |
| **C. Sharpen agent design + validation skills** | Ongoing | We can predict when an agent will produce a mergeable PR vs. when it'll embarrass us |

These reinforce each other:
- **B gates A**: trusted contributors can land more, faster.
- **C is the engine**: it's what makes A and B sustainable instead of one-off heroics.
- **A is the motivation**: real users (us, at game night) keep us honest about what "better" means.

## Fork vs. upstream — the split that makes everything else possible

Two distinct kinds of work, and they must never get tangled:

| Kind | Branch base | Visible to upstream? |
|---|---|---|
| `CLAUDE.md`, `docs/`, agent scaffolding, dev tooling | `fork-main` | **No.** Fork-only. |
| Bug fixes, features, refactors that benefit everyone | `main` (mirrors upstream) | **Yes.** PR'd. |
| Personal QoL features our group wants, but upstream may reject | `fork-main` | **No.** Lives on the fork. |

Branch policy is documented in detail in [`../CLAUDE.md`](../CLAUDE.md). The most important rule: upstream-bound work cuts from `main`, never from `fork-main`. Otherwise PR diffs leak internal scaffolding.

## Track A — Real improvements

Sources of work, in priority order:

1. **Things that bug us at game night.** Highest-signal — we are the user. Capture as we hit them, file under `docs/wishlist.md` (TBD).
2. **Open upstream issues that match our irritation.** Best of both worlds: aligned with upstream's roadmap AND our needs.
3. **Tractable upstream issues from triage.** Tier-1 fixes (typos, lint warnings, regression tests) for trust-building.

We avoid:
- **Speculative refactors.** Tempting, but expensive in trust capital.
- **Anything platform-hardware-specific** (Adreno flickering, Wifi IPv6) until we have a reproduction environment.
- **Large new features.** A feature flag in a Flutter combat helper has nowhere to hide.

## Track B — Maintainer relationship

The trust-building ladder:

| Tier | What | Goal |
|---|---|---|
| 0 | Lurk. Read the last 20 merged PRs. Note style, size, conventions, what gets rejected. | Calibrate before contributing. |
| 1 | Trivially correct: typo fix, regression test for an already-fixed bug, lint warning. | Positive first impression. |
| 2 | Small bug fix matching an open issue. Reference issue, follow style, include test. | Establish pattern. |
| 3 | Bigger fix or small feature. Only after two Tier-2s have merged cleanly. | Demonstrate reliability. |
| 4 | Structural improvement (e.g. logging facade). Propose via issue first — never PR cold. | Earn structural trust. |

**Validation per tier:** Did the PR merge? What feedback came back? Did it match our predictions? Each merge is data — capture in `docs/agent-retro/` (TBD).

**Don't skip tiers.** A Tier-4 PR sent before any Tier-1 has merged signals a contributor who hasn't done the homework. That's how trust gets burned, not built.

## Track C — Agent design & validation

The whole reason this fork has a `CLAUDE.md` and `docs/` tree: agentic work needs persistent context, structured workflow, and feedback loops.

Operating principles:

1. **Documentation-driven workflow** — see [`../CLAUDE.md`](../CLAUDE.md). Docs → schema → tests → code → demo. Commit after each step.
2. **Validation isn't `flutter test`.** This codebase has limited test coverage of UI and networking. Real validation = manual play-test before claiming a PR is ready. Plan for that explicitly in the demo step.
3. **Retro after every PR.** Three lines, every time:
   - What did Claude do well unprompted?
   - What did I have to correct?
   - What should the next session know? (→ memory or CLAUDE.md update)
4. **Memory captures the maintainer's preferences as we learn them.** Once we see two reviews of the same flavor, write it down.

Without (3) and (4), we'll feel like we're improving but won't be able to point to *how*. The retro loop is the validation muscle.

## Risks to watch

- **Logging-facade temptation.** It's the right idea long-term but a terrible Tier-1 PR. Save for Tier 4. Propose via issue first.
- **Pushing `CLAUDE.md` to upstream by accident.** Branch hygiene matters. Always check `git log upstream/main..HEAD` before opening a PR.
- **Fork drift.** Rebase `main` on `upstream/main` weekly so PR branches stay clean.
- **Over-investing in scaffolding.** This doc, CLAUDE.md, etc. are means, not ends. If they aren't speeding up real shipping, trim them.

## Open questions

These are things we haven't decided yet:

- Does Tarmslitaren prefer issues opened *before* PRs, or PRs opened directly? (Tier 0 will answer this.)
- What's the test bar for an upstream PR? Just `flutter test` clean, or evidence of manual play-test too? (Will learn from review feedback.)
- Should QoL-only features (fork-only) live on `fork-main` directly, or as named long-lived branches off `fork-main`? (Defer until we have one.)

## Companion docs (planned)

- `docs/wishlist.md` — game-night irritations as we encounter them
- `docs/agent-retro/` — per-PR retros
- `docs/maintainer-style.md` — observations from Tier-0 lurking and subsequent reviews
- `docs/validation.md` — what "ready to PR" actually means for this codebase
