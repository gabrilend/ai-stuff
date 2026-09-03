# 100 — The random draw

## Current behavior

Built and tested, except for configuration and the ledger's persistence.

The module resolves paths through the filesystem and answers whether one
is genuinely beneath another; walks a corpus into a roll of candidates
while reporting anything that resolves outside it; filters a roll by what
a viewer already holds and by a per-file ceiling; and picks uniformly
from the survivors using kernel entropy. Running dry returns nothing plus
a reason, distinguishable from an error.

Twenty-two tests pass, covering each way out of the corpus that was
identified: a sibling sharing a name prefix, a climb with `..`, a symlink
whose target is outside, the root itself, a trailing slash on the root,
and a name the corpus does not contain.

That last one was a real defect, found by the test rather than by
reading. Path resolution used a flag that succeeds when only the final
component is missing, so a never-written filename inside the corpus
resolved cleanly and tested as lendable. It now requires every component
to exist.

Not yet done: steps 1 and 5 below. There is no configuration reader — the
corpus root, ceiling and ledger path are passed by the caller rather than
read from anywhere. The ledger exists only as the in-memory `held` map a
caller keeps; nothing writes it to the RAM tier, so nothing survives
between processes.

## Intended behavior

A module that answers one question — *give me a file, at random, that I
am allowed to lend* — and knows nothing about who is asking or what
becomes of the answer. It is consumed by the jail (phase 2) and by the
refill loop (phase 3), which must not be able to tell each other apart
from inside it.

It holds the corpus boundary. Every path it can return lives under one
configured root, and a draw that can be persuaded to return something
outside that root is the only defect in this project that matters.

It holds the repeat ceiling. A viewer whose only verb is delete can ask
forever; the ceiling is what makes a random sampler stop short of being a
slow complete copy. Running dry is correct behaviour and must be
reported as such, distinguishable from an error.

## The shape of the data

**A roll entry** — one candidate file:

| field | type | meaning |
|---|---|---|
| `path` | string | absolute, always under the corpus root |
| `size` | integer | bytes, as reported by stat |
| `drawn` | integer | times handed out, across all viewers |
| `last` | integer | unix seconds of most recent draw, 0 if never |

**The roll** — an array of those, built by walking the corpus root once.

**The ledger** — a map from viewer name to a set of paths that viewer has
already been given. Lives in the RAM tier so it does not survive a
reboot, because the project promises to keep no logs. Its purpose is to
answer *has this viewer seen this file*, not *what has this viewer been
reading*.

## Suggested implementation steps

1. **Read the configuration.** Corpus root, repeat ceiling, ledger path.
   Absent values are errors, not defaults — a draw with no configured
   root must refuse to run rather than guess at one.

2. **Build the roll.** Walk the corpus root, stat each regular file, and
   record it. Symbolic links are resolved and the result checked against
   the root; a link pointing outside the corpus is dropped and reported,
   because that is the boundary being probed.

3. **Assert the boundary.** A function that takes a path and answers
   whether it is genuinely underneath the corpus root, after resolution.
   Written before anything calls it, and tested against the ways out:
   `..` segments, symlinks, a root given with and without a trailing
   slash, and a path that merely shares a prefix with the root as a
   string but is a sibling directory.

4. **Filter and pick.** Given a viewer name, drop what they already hold
   and what has hit the ceiling, then choose uniformly from the
   survivors. Return the path, or nil plus a reason.

5. **Stamp the ledger.** Record the pairing before returning, so a caller
   that crashes after receiving a path does not get the same file again.

6. **Tests, run at build time.** The boundary cases from step 3; a draw
   from an empty corpus; a draw that exhausts a small corpus and reports
   running dry; the same viewer asking twice never receiving the same
   file; two viewers being able to receive the same file.

## Related

- [The draw](../docs/002-the-random-draw.md) — datapath
- [What this project is](../docs/000-what-this-project-is.md) — why this
  is phase one and the credential is not

## Open questions

- **Does the roll rebuild while running?** Walking once means files added
  later are invisible until restart, and a file deleted from the corpus
  while loaned out leaves a dangling path.
- **What is the ceiling's default?** One draw per file per viewer is
  strict; unlimited is generous. The number is the difference between a
  sampler and a slow full copy.
- **Should the ledger survive a restart?** It does not today, so a restart
  lets every viewer see everything again. Moving it to disk would hold
  the ceiling across restarts and would mean re-reading the no-logs
  promise.

## Status

In progress. Steps 2, 3, 4 and 6 are done. Steps 1 and 5 remain, and the
three open questions above are unanswered.
