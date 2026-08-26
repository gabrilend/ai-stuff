# 908 -- The phase nine demo

**Phase:** 9, the sprite studio
**Blocked by:** every other issue in phase 9.
**Blocks:** nothing. The capstone.
**Documents:** [the roadmap](../../docs/015-roadmap.md)

## Current behaviour

**Done.** `./run-phase-demo 9` runs it. Seven parts.

**The paintbrush**, listed -- twelve words -- followed by six plausible
neighbours being refused, three of them with the word that was probably meant.
"idle" gets no suggestion, which is the fix the demo itself prompted: a
suggestion is only worth making when most of what was typed survives into it.

**A batch**: four categories, a hundred and twenty each, written to the RAM tier
as one SVG per sprite plus a text index. One sprite is printed layer by layer
with the grader's full breakdown, so the numbers are not a black box.

**A page you can open.** `contact-sheet.html` gathers the whole library, sorted by
category and tier, every sprite moving, with a person's ratings in green and the
machine's in grey. The deliverable is the picture, and a demo that only printed
numbers about a picture would have hidden it. The page says what it truncated
rather than quietly showing a sample.

**Both algorithms** on the same batch, side by side. The judge-then-curate pool
reports its agreement as UNMEASURABLE and its human-rated fraction as everything,
which is the asymmetry between them shown as numbers rather than asserted as
prose.

**The dial**, as the exchange from the issue actually happening. A table of what
each floor leaves under both provenance settings, then the sentence naming both
counts and the consequence, then nothing being applied. Then the offer to rate,
declined, and the studio not asking again -- and the library provably unchanged
by the refusal.

**The anchor**, shown twice: once on a library nobody has looked at, where the
answer is UNMEASURABLE and not a hundred per cent, and once on the goblins, where
a real disagreement is measured. The stand-in person deliberately does not share
the grader's taste, so the agreement rate is a number rather than a formality --
a stand-in that echoed the heuristic would report perfect agreement and prove
nothing.

**The table**: a goblin standing in the tavern, three beats of play, a re-tier
from the seat, and the world checksum printed before and after. It does not move.
Then play carries on. Both opinions are shown still sitting side by side, because
one field would have lost the machine's.

**The honesty**: what the five grading components are and what they are out of,
the four cut lines with the note that they were measured, and five open questions
by number.

Then the wrapper runs `084-calibrate` and the demo will not quietly show tiers
that have stopped meaning what they say.

### What the demo found

Two real defects, both invisible to the tests.

**The suggester offered a shape for a mistyped motion.** "idle" got "circle",
because three edits is most of a four-letter word. The rule is now that at most
half the word may change, and the description parser from phase eight was fixed
the same way.

**The grader punished the sprites that looked best.** The balance component added
vertical drift to horizontal, so a mirrored creature -- two eyes above the middle,
two ears above them -- scored three out of twelve. A face is in the upper half;
that is what a face is. It measures sideways lean only now, and the component is
called `upright` rather than `balance` because that is what it measures.

Correcting it moved three of the five tiers outside their intended share and
`084-calibrate` refused outright, which is the second drift that tool has caught.

## Intended behaviour

### What it shows

**A batch generated**, with the pool's counts per category.

**The tiers and their provenance** — how many machine, how many a person's, and
the agreement rate between them where both exist.

**The dial moved, with its cost reported first.** Raise one category's floor and
print the surviving count at both settings, before applying it. Then show the
output getting more alike, which is the variety being spent.

**Both algorithms.** Run the same batch under A and under B and print the two
resulting pools side by side. Neither counts as built until both are shown
working.

**A sprite re-tiered from a live session** — the thing that makes B a tabletop
idea rather than a gallery idea. Mid-play, through the same command door as
everything else, without stopping.

**And the honesty:** say that the machine grader is a heuristic and roughly what
it measures. Report the human-rated fraction, and say plainly if it is below the
anchor.

### The artifact itself

Write a few sprites out where somebody can open them, and say where. An SVG that
animates in a browser is the whole point of the format choice, and a demo that
only prints numbers about it has hidden the deliverable.

## Suggested implementation steps

1. Generate a batch across several categories, deterministically.
2. Print the pool summary.
3. Show the floor being raised, cost first.
4. Run both algorithms and compare.
5. Re-tier one during a running session.
6. Write sample sprites to the RAM tier and print the paths.
7. Confirm `./run-phase-demo 9`.
