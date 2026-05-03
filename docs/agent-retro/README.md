# Agent Retros

Per-PR retros, capturing what worked and what didn't when working with Claude on this codebase. The validation muscle of Track C ([`../strategy.md`](../strategy.md)).

## Why these exist

Without a retro after each PR, "I'm getting better at agentic work" is vibes-based. Retros turn it into evidence. They also seed updates to [`../../CLAUDE.md`](../../CLAUDE.md) and to memory — the mechanism by which lessons learned in one session become defaults in the next.

## When to write one

After every PR — merged, rejected, or abandoned. Especially abandoned ones; those are the most informative.

## Format

One file per PR. Filename: `YYYY-MM-DD-<short-slug>.md`.

```markdown
# Retro — <PR title>

- **PR:** link or "fork-only branch X"
- **Tier:** 0/1/2/3/4 per the strategy doc
- **Outcome:** merged / closed / abandoned / fork-only
- **Time spent:** rough estimate
- **Lines:** +X / -Y

## What Claude did well unprompted

(One or two bullet points. Things that were the right judgment call without being told.)

## What I had to correct

(Things I had to push back on. The kind of thing that would have shipped wrong if I weren't watching.)

## What the next session should know

(One or two takeaways. These should be specific enough to act on. Vague takeaways like "communicate better" are useless. "Don't propose `late` as a fix for null-safety warnings; this codebase forbids it" is useful.)

## Any CLAUDE.md / memory updates triggered by this PR

(If a takeaway was promoted to a permanent rule, link to the commit or memory entry that captures it.)
```

## Review cadence

Every ~5 retros, skim the lot for patterns:
- Are the same corrections coming up repeatedly? → CLAUDE.md or memory needs strengthening.
- Are the same things going right? → maybe lower the supervision on those.
- Is the time-spent trend going down for similar work? → the system is working.

This skim is itself a useful artifact — write it up as `meta-YYYY-MM-DD.md` in this directory.

## Index

_(Empty. Add entries chronologically as PRs ship.)_
