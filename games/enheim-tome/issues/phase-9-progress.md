# Phase 9 — The Scene

The narrative half. Axis interactions become a record; the record becomes words
that decide nothing back.

**Twelve issues written, none complete. Nothing has been built.**

| Issue | State |
| --- | --- |
| [901 — an interaction is one axis across the actors](901-an-interaction-is-one-axis-across-the-actors.md) | not started |
| [902 — a scene record](902-a-scene-record.md) | not started |
| [903 — what changed is computed first](903-what-changed-is-computed-first.md) | not started |
| [904 — a scene exists only where something changed](904-a-scene-exists-only-where-something-changed.md) | not started |
| [905 — history is append-only](905-history-is-append-only.md) | not started |
| [906 — a fact is public or private](906-a-fact-is-public-or-private.md) | **blocked** — open question 23 |
| [907 — the narrator is a viewer](907-the-narrator-is-a-viewer.md) | not started — open question 20 |
| [908 — the narrator thinks, then narrates](908-the-narrator-thinks-then-narrates.md) | not started |
| [909 — the narration phase cannot see the private facts](909-the-narration-phase-cannot-see-the-private-facts.md) | not started — open question 24 |
| [910 — naming is the one place words touch the world](910-naming-is-the-one-place-words-touch-the-world.md) | not started |
| [911 — a narration lands in the text pane](911-a-narration-lands-in-the-text-pane.md) | not started — open question 21 |
| [912 — a missing narrator fails loudly](912-a-missing-narrator-fails-loudly.md) | not started — open question 20 |

The design is [the scene](../docs/010-the-scene.md).

## What this phase is for

[Phase 8](phase-8-progress.md) produces numbers — shares, thresholds, blends,
sparks. On their own they are a simulation nobody can read. This phase is the half
that makes the city legible, and it exists as its own phase rather than as the tail
of phase 8 because of a rule the project has held since the beginning:

> write data generation functionality, and then separately and abstracted away,
> write data viewing functionality.

The scaffold generates. The scene views. Putting them in one phase would invite
exactly the bleed the rule exists to prevent.

## The decision this phase rests on

**The words are a view, and they render nothing back.** An axis moves because the
share of one over N+1 says it moved, never because a sentence said somebody was
persuaded.

Three properties come from that, and they are the reason it is worth being strict
about:

- a bad narration is a bad paragraph, not a corrupted city
- the same scene narrated twice leaves the city identical, so it can be re-run,
  run with a different model, or read as a record with no narrator at all
- the whole thing runs **headless**, for a thousand days, with nothing attached —
  which is what makes depending on a language model safe here

The one exception is sharp and must not spread: **naming a minted axis is
generation, not viewing.** A new name entering the vocabulary is a real change,
because an axis is also a filter and will be hatched across the map from then on.
Naming and describing are two jobs done by the same thing, and the code must keep
them apart.

## The interaction table, and the one nobody designed

An interaction is one axis across everyone present, typed five ways: **shared**,
**strained**, **offered**, **withheld**, **asserted**.

*Withheld* is the one worth keeping. An open actor carries something and every
other carrier is absent — so nobody takes it, not because they refused but because
being receptive is the same as being unable to hand things out. That falls
straight out of *the closed gives, the open receives* and was not put there.

## What bounds the work

**A scene exists only where something changed.** A gathering that moves no axis and
strikes no spark gets no record and no words. Cheap to test, since the scaffold has
already computed what changed by the time the question is asked.

Most hours in most blocks will produce nothing, which is not a shortfall — it is
what an ordinary day is, and the vision insists on ordinary.

## The two phases, which settled the biggest question here

The narrator sees **everything** — all of it, everyone's history, public and
private alike — and then says far less than it knows.

| Phase | Sees | Produces |
| --- | --- | --- |
| **thinking** | every fact there is | what this scene is about |
| **narration** | public facts, plus private ones the reader knows | the words |

That refuses a choice the question had assumed was forced. A narrator restricted to
permitted facts writes ignorant prose; one given everything leaks. Two phases give
the thing people actually do: **you know something, you do not say it, and knowing
it changes how you say everything else.**

And it settled the filter question on the way past. *Public plus known* is exactly
what a filter's person half selects, so **one rule gates the map and the tome
together** and the two halves of the screen cannot come to disagree about what you
are allowed to know.

## Blocked on

| # | Question |
| --- | --- |
| 19 | What is a "thing"? The vision said person, place, thing; this project has no objects. |
| 20 | When does the narrator run — at play time over a network, or ahead of time in batches? |
| 21 | How long is a narration, in a pane 420 pixels wide? |
| 23 | What makes a fact public or private, and how is a private one learned? |
| 24 | How is the discretion boundary enforced rather than requested? |

23 is what stands between the public/private rule and being implementable —
everything above it is decided, and it alone is not.

24 is the one worth being stubborn about. If the thinking and narration phases
share a context, the private facts are still in front of the model while it writes,
and the rule has become a **request**. This project treats a fallback as a warning
and a warning as an error, and a discretion boundary enforced by asking nicely is
exactly that kind of quiet failure. The narration phase should run against a
context that never held the private facts at all.
