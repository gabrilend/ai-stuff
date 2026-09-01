# 025 — The Development, Replayed

Derived from `llm-transcripts/aug-31-26-through-sep-1-26.md`, whose own structure is the
record: each user request is a place the design changed its mind, which is the boundary
that matters. The preceding session's work is the base, because it was sitting
uncommitted in the tree when this one began.

| # | What was being tried | Where the boundary came from |
| --- | --- | --- |
| 1 | The formation turns after all, and flat arrows are built and switched off | the tree at the start of this session |
| 2 | The road stops being a fence, and the measurement that closed the question does not survive re-running | requests 2–4 |
| 3 | A way to *watch* the rule rather than total it up | request 5 |
| 4 | A body looks up when somebody new hits it; archers become wedges | request 6 |
| 5 | The proving ground: a rule gets its own square of ground | request 7 |
| 6 | Terror, the seed notebook, and a great deal of design captured | request 8 |
| 7 | Up means back the way it came, and the queue becomes visible | request 9 |

## What is faithful and what is not

**The code is reconstructed.** For every source file that both sessions touched, this
session's changes were reversed to produce the state the previous session left, and that
state is what commit 1 contains. There are seven such files and the reversal is exact.

**Two documents in commit 3 are not.** `scenarios/the-archers-cannot-see` and
`watch-the-arrows` were written at step 3 and edited again at step 5, and they appear in
commit 3 in their later form. Reconstructing them would mean writing out a version that
is recoverable but that nothing depends on.

**Four issue files span steps** — 214, 602, 702 and 709 were each written at one step and
added to at a later one. They appear at their first step in the form they finally took.
An issue file is a blueprint rather than a record, so a later paragraph appearing early
misrepresents when a thought arrived but never what was built.

**Nothing is rewritten.** Every commit is new and sits on top of what was already there,
so the whole run undoes with `git reset --hard 6f2ecc8a` and the tree comes back from the
copy in `/dev/shm/hero-less-moba-replay-backup`.

## Why this document exists

The commits carry the reasoning; this carries the reasoning about the commits. Where the
boundaries were drawn is the only expensive decision in a replay and it is the one that
becomes invisible the moment it is made — a history whose steps are wrong reads exactly
like a history whose steps are right.

The method is at [`skills/replay-the-development/SKILL.md`](../skills/replay-the-development/SKILL.md).
Its first instruction is to find the boundaries where the design changed its mind rather
than where files changed, and the reason that mattered here is that a single file often
carried three iterations while a single iteration often touched nine files.
