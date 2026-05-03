# Maintainer Style — Tarmslitaren

Observations from the last 20 merged PRs upstream (#241 through #304, Dec 2024 – Apr 2026). Updated as we accumulate data.

## The single biggest insight

**Zero formal reviews on any of the 20 PRs.** Every PR shows `reviews: 0`. Tarmslitaren does not review-and-comment in the GitHub UI — he reads the diff himself and either merges, asks in a single inline comment, or sits on it. There is no PR template, no CODEOWNERS, no contributor guide.

**Implication:** silence after submission is normal. A merge with no comments is the typical "approved" signal. We won't get LGTM-style review feedback to learn from. Track-C retros become more important because the upstream signal is binary.

## PR size

All 20 PRs are small:

| PR | Lines | Type |
|---|---:|---|
| #304 (largest) | +334/-18 | New feature (global hotkeys) |
| #280 | +64/-42 | Docs |
| #241 | +46/-28 | Scenario data |
| ...most others | <30 lines | Tiny |
| #294, #254, #250 | 1-2 lines | Scenario data fixes |

**Median PR is 10-30 lines.** No PR in the sample touches more than ~15 files. No structural refactors, no architecture changes. The maintainer's revealed preference: small, surgical changes.

## Categories of merged work

| Category | Count | Examples |
|---|---:|---|
| Scenario / monster data fixes | 5 | #294, #248, #254, #250, #241 |
| CI / Docker / workflow | 7 | #262, #263, #266, #280, #281, #296, #255, #256 |
| App features / fixes | 6 | #304 (hotkeys), #285, #270, #272, #269, #244 |
| Tooling (FVM, .gitignore) | 1 | #268 |

**Scenario data fixes are the lowest-friction PR category.** They're tiny, obviously correct (point at the rulebook), and reference a specific scenario number. This is the prototype for a Tier-1 contribution.

## Title style

No enforced convention. Examples in the sample:

- `Global hotkeys` — bare descriptive
- `fix workflow build` — lowercase, casual
- `fix: Update spawn numbers for scenario 46` — conventional-commits-flavored
- `[Bugfix]: Remove server ip text limit` — bracketed tag
- `[workflow] add 'linux build' step to check compilation errors` — bracketed area
- `Issue in scenario 93B that spawns Vermling Scout from GH instead of FH` — verbose plain English
- `Tolerate \`EPIPE\` socket exceptions` — Title Case + backticks

**Match the affected area's vernacular and you'll be fine.** Do not impose a strict convention.

## PR body style

Highly variable:
- ~25% of PRs have empty bodies (#296, #281, #241)
- ~50% have 1-3 sentences linking an issue
- ~25% have detailed motivation, tables, or test notes (#304, #244, #266)

**The minimum viable body**: "Fixes #X. <one-sentence summary of approach>." Most accepted PRs do at least this.

**Recommended for our PRs**: 2-4 sentences with motivation + issue link + how to verify. Slightly above the median. Punches above casual without over-engineering.

## Issue references

Common pattern. Many PRs mention `#X`, `Closes #X`, `Fixes #X`, or `Refer to issue X`. Roughly 12/20 PRs in the sample cite at least one issue.

**Implication:** before opening a PR, check the issue tracker. If our fix matches an open issue, reference it. If not, the PR can stand alone.

## Issue-before-PR question

Strategy doc had this open question. Answer from the data:

**Direct PRs are normal and accepted.** The common pattern is "PR cites an existing issue I or someone else filed." The PR is not preceded by an explicit comment thread. Open issues already accumulate user reports; contributors then attach a PR to one.

**Exception (inferred):** for non-trivial structural changes (CI overhauls, dependency adoption, architecture shifts), the data is thin but #262 ("based off #232") and the FVM PR (#268) suggest some prior conversation. **For Tier-4 work, propose via issue first to confirm appetite.**

## Commit style

- Lowercase, single-line headlines
- Typos and grammar slips preserved ("syncronization", "appropiate")
- Conventional-commits prefixes optional, used by some contributors not others
- Multiple commits per PR is fine — no squash-required signal
- Bundling related fixes in one PR is accepted (#248 covered two issues)

## Test expectations

**Tests are not required.** None of the 20 PRs in the sample reference adding or running tests in their description. The scenario data fixes have no tests. The hotkey feature PR (#304, +334 lines) has no test mention. The EPIPE fix (#244) describes a manual repro but not a regression test.

**Implication:** upstream's bar is "looks right, doesn't break the build." Our internal bar (per [`../CLAUDE.md`](../CLAUDE.md)) is higher — we still write tests for our own work because Track C demands validation. But we shouldn't act surprised when test-less PRs land, and we shouldn't lecture upstream contributors about it in our PRs.

## Repeat contributors

| Contributor | PRs in sample | Type |
|---|---:|---|
| `treac` | 5 | Mix: bug fixes, workflow, FVM tooling |
| `murrant` | 4 | All Docker/CI |
| Others (chubby1968, hatal175, LeVeiLLeuR74, etc.) | 1-2 each | Single contributions |

Repeat contributors land more substantial / infra-touching changes (`treac` did the FVM adoption, `murrant` did the entire Docker pipeline). One-time contributors did small data fixes or single-issue PRs.

**Implication:** the trust ladder is real. Don't try to land the equivalent of `murrant`'s Docker overhaul as a first PR.

## Practical playbook for our first PR

Based on this data, the ideal Tier-1 PR looks like:

1. **A scenario data fix** matching an open issue, OR a 1-3 line bug fix, OR a regression test for an existing fix.
2. **Title:** descriptive plain English. Don't agonize.
3. **Body:** 2-4 sentences. "Fixes #X. [Why this is wrong] [What I changed] [How I verified]." Optionally a screenshot.
4. **Cite the open issue** if one exists.
5. **Tests optional** for upstream, but write one anyway if the change has logic (Track C discipline).
6. **One commit is fine, multiple is fine**, just don't include unrelated changes.
7. **Cut from `main`** (which mirrors `upstream/main`), not `fork-main`.

## Lessons from rejected PRs

Three informative closed-but-unmerged PRs:

### #292 — "Data: correct Boneshaper perk rolling card target" (rejected)

Tiny PR (+2/-2) referencing an open issue. Tarmslitaren replied:

> 'self' is wrong, it should be target Boneshaper (remember, that Boneshaper's summons will also use her deck)

**Lesson:** Tarmslitaren knows the rules deeply. Data fixes need to be **rule-correct**, not just "looks plausible." When fixing scenario/card/monster data, **cite the rulebook source** in the PR body so the maintainer can verify quickly without doing the lookup himself. A wrong fix to a real bug burns trust as much as any other kind of mistake.

### #238 — "Fix gloomhaven hazardous terrain calculation" (rejected, friendly)

Bug fix referencing issue #99. Tarmslitaren replied:

> fixed with alternate solution. Thanks for contributing!

**Lesson:** Even correct PRs can get superseded by the maintainer's own implementation. This is a *soft* rejection — relationship intact, code redone. Don't take it personally; it's a sign he was already thinking about the bug. **Mitigation:** if it's a non-obvious approach, mention the alternatives you considered in the PR body. Lets him see your reasoning and choose, rather than discarding and rewriting.

### #124 — "Scenario 27 and specials conditions" (silently closed)

Large PR (+716/-20). **No body. No comments. No interaction. Just closed.**

**Lesson:** Large PRs without context die in silence. The maintainer doesn't have the bandwidth to reverse-engineer intent from a 700-line diff. **Never open a large PR cold** — propose via issue first, or open small focused PRs that build up to the larger goal. This is direct evidence for the strategy doc's Tier-4 rule.

### Synthesis

- **Tier 1-2 rule:** if it's a data/rule fix, cite the source. Don't make the maintainer do the lookup.
- **Tier 3 rule:** if your approach has alternatives, name them in the PR body so he can pick.
- **Tier 4 rule:** never cold-open. The empty-body, no-comment closure of #124 is what happens.

## What we still don't know

- His response time. (Sample shows merges happening but not how long they sat.)
- Whether he prefers PRs targeted at a specific milestone/release.
- His tone in active conflict — the rejections we've seen are short and polite, but we haven't seen what happens when a contributor pushes back.

These are good follow-ups for future Tier-0 deepening.
