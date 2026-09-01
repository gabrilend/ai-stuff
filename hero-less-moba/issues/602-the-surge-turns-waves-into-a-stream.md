# 602 — The Surge Turns Waves Into a Stream

| | |
| --- | --- |
| Phase | 6 — The Surge and the Challenge |
| Blocked by | 207, 601 |
| Blocks | 603, 605, 607 |
| Reads | [the siege-surge](../docs/014-the-siege-surge.md) |
| Open questions | B2 — surge length and stream rate |

## Current behavior

A surge is a stream: one body per lane per team on one shared timer, so bodies come
in threes. Towers stop replacing guards and are unkillable for the duration, and the
chest cannot grow — which falls out rather than being enforced, since a stream body
belongs to no wave and "wiped" is a statement about a group.

It is the one thing in the game that walks out in a line.

## Intended behavior

During a siege-surge both bases emit **one body per lane on a very short
interval** — a trickle from each of the three mouths, continuously, instead of a
batch every several seconds. Where normal play sends a handful of soldiers down
each lane every several seconds, a surge sends one down each lane every fraction
of a second.

The spawner reads row 2 of the phase table. Same function, different interval and
count — if a branch is needed, the phase table is the wrong shape and should be
fixed rather than worked around.

### Everyone the surge sends out has exactly one hit point

**The bodies the surge emits**, not every body standing on the field. A hero somebody
bought three minutes ago is unchanged; the stream is made of paper.

Not a reduction and not a multiplier — the number is one. Anything that lands is enough.

And they are not being thrown away. **They are testing arrangements of technology**, and
a body comes home the moment it has been subjected to a hit, having found out what it
went to find out. Whether the arrangement worked is not a question the body has to
answer, because it would not be coming back if it had not.

It is what gives the stream its shape. A trickle of bodies that each need six blows to
put down is a queue; a trickle of bodies that leave the moment anything touches them is
a front that moves. **A surge should look like weather, not like a siege.**

It also sits exactly beside what the surge already does to stone. Towers cannot be lost,
cannot be reinforced, and carry nothing for the duration, so a team's investment is
inert — and now the bodies it is pouring out are worth nothing either. What is left is
the **arrangement**: where the bodies are and which way they are pointing, which
[the open questions](../docs/020-open-questions.md) already identify as the only thing a
surge actually takes from a team. Everything a player *bought* is untouched and idle at
the same time.

### Terror, and the number that sends a body home

A body carries **terror** as well as health. Certain attacks — *fear*, *despair*,
*ruin* — deal terror where an ordinary blow deals damage. It is spent in the same
currency and it goes in a different column.

> **A body retreats when terror plus health falls below zero.**

Plus, and below zero, and both words are load-bearing.

**Terror is measured against what a body has left, not against what it started with.**
Nothing is compared to a maximum and there is no second threshold to tune. The same
mouthful of despair that a fresh body shrugs off will break one that has been fought
down, because the sum is smaller — and a body that has just been healed is braver than
it was a second ago, without a healer having to be given a morale ability. The two
columns are one pool with two ways of being emptied.

**And terror never kills.** Health at zero is a body that has been destroyed; terror
past the same line is a body that has left. Which of the two happens is decided by
which column did the emptying, and both are read off one comparison.

That is also why a surge body with one hit point and no terror is not merely fragile in
a new way. It is at one, so the first blow takes it below zero — and *below zero is what
retreating means*. **The stream is not being killed. It is being sent home**, one body
at a time, by anything that touches it.

### And then they run home, and home is a real place

A body past that line **runs — at running speed**, which nothing else in this game ever
uses, and **avoiding allies and foes alike** on the way. Not falling back to its own
line and not rejoining a formation: leaving, across whatever ground is between it and
where it is going, going round everything.

Where it is going depends on what it is:

| | Runs to |
| --- | --- |
| a guard | its own **guardhouse** |
| a wave body | a **guardhouse in a neighbouring lane** |
| a hero | the **home library** |

**Guardhouses do not exist yet.** They are named here for the first time and nothing in
the project has one, so they are a prerequisite for this rather than a detail of it.

The middle row is the interesting one. A wave body does not run back the way it came —
it runs *sideways*, to somebody else's lane, which means a broken push in one lane
arrives as reinforcement in the next. A surge does not simply consume what both sides
send into it; it stirs their armies between lanes.

This is the same gear [212](212-a-beaten-body-gets-one-roll.md) reserved and has
never had an occasion to use, and it is the same avoidance
[214](214-going-round-what-is-in-the-way.md) is being built for — pointed at every
body rather than at friendly ones only, because a body running for home has no
interest in fighting anything it passes.

What that produces is a surge with a **return current**. Bodies pour out of both
bases, meet, mostly die, and the survivors stream back the way they came through the
ones still coming out. A lane during a surge is two opposed flows and a scatter of
individuals crossing them, which is a thing to look at rather than a thing to count.

### Guards join the stream

While a surge runs, **towers spawn no guards.** That production is redirected to
the base and emerges as ordinary stream bodies.

Mechanically it is a redirect of the existing guard timer, not a new spawner: the
tower's timer still fires, but the body appears at the library node facing
outward with no leash instead of at the tower node with one. The defence walks
out to meet the fight instead of waiting at home for it.

Those bodies are dealt to like every other stream body — a share of everything
the team owns, split across the bodies spawning that instant — rather than
carrying the tower's upgrades the way a guard does in any other phase. Issue 603
owns the deal itself.

**Towers shoot at bare catalogue values for the duration.** No upgrade applies to
a tower while a surge runs, so entering the phase sweeps every standing guard
back to baseline and leaving it sweeps them forward again — the ordinary
clear-then-re-stamp from issue 303, fired by a phase change rather than by a
placement. Combined with towers being invulnerable and producing no replacements,
a surge is the one stretch where a team's stone is inert: it cannot be lost, it
cannot be reinforced, and it is not carrying anything.

### Why the stream

Discrete waves give a lane a rhythm: a push, a lull, a push. Both teams learn the
rhythm and play to it, and by the middle of a match the lanes have settled into a
standing pattern. A continuous stream deletes the lull. There is no between-waves
moment to reposition in, no window where a lane is briefly empty, and nothing to
time anything against, because there is no spawn clock any more.

The frontline stops being a place where two waves meet and becomes a place where
two **rates** meet.

### Wave records still exist, and never complete

The stream creates a wave record per lane per interval as before — it is just a
much smaller, much more frequent batch. That keeps the wipe detection from issue
208 working unchanged with no special case.

But note the consequence and do not treat it as a bug: with one body per record,
a "wave" is wiped the moment that body dies, which would pay an upgrade for every
single kill. **It must not.** A surge earns nothing. The phase table's row 2 says
the chest does not grow, and the draw routine reads it. The cleanest expression
is to give the wave record a `pays` flag set from the phase at creation, so the
wipe detector stays ignorant of phases entirely.

## Suggested implementation steps

1. Fill in row 2 of the phase table with the stream's interval and count.
2. Add the `pays` flag to the wave record, set from the phase at creation, and
   check it in the draw routine rather than in the wipe detector.
3. Redirect the guard timer to the base spawn while the phase is 2.
4. Check the body-count ceiling. A continuous stream in three lanes from both
   bases is the peak load the simulation will ever see, and it decides the
   soldier store's capacity.
5. Write a test that a surge pays no upgrades at all, despite producing hundreds
   of single-body wave records that all "complete."
6. Watch one in the terminal viewer. The stream should look visibly different
   from waves at a glance; if it does not, the rate is wrong.
7. Set every living body's health to one when the surge begins, and decide what
   happens to the number when it ends — see S1 below, which has to be answered
   before this can be written at all.
8. Give a surviving body somewhere to go: home, at running speed, avoiding every
   body rather than only friendly ones. This wants
   [214](214-going-round-what-is-in-the-way.md) built first, since it is that
   avoidance with the friend-or-foe test removed.
9. Watch it in [the proving ground](111-the-proving-ground.md) before watching it
   in a match: two files of bodies walking into each other on a short straight
   lane, everybody dying to one blow, and the survivors turning round. The return
   current either reads or it does not, and it is a picture rather than a number.

## Related documents and tools

- [The siege-surge](../docs/014-the-siege-surge.md)
- [Waves, and when one is finished](../docs/005-waves-and-when-one-is-finished.md)

## Still open

**B2 — how long does a surge last, and how fast is the stream relative to the
wave rate?** Awaiting evidence rather than undecided: it is found by watching one
run, not by argument. Together those two decide the peak body count, which is the
number the soldier store's fixed capacity is sized against (E3), and which
decides whether the thread pool is worth having at all.

**S1 — what does terror do to *dying*? — NEEDS A DECISION, and it blocks the rest.**

A body dies at zero health today. Under the new rule a body **retreats** when health
plus terror is below zero — and an ordinary blow taking a body from three health to
minus four has put it below zero without a grain of terror involved. So as written,
ordinary damage sends bodies home and nothing ever dies.

Three ways out, and the third reads best:

1. Ordinary damage cannot push health below zero; only terror can make the sum
   negative. Clean, and it makes terror the *only* route to a retreat.
2. Retreating and dying are separate tests: dead at zero health, retreating at a
   negative sum. Then a body carrying terror never gets to use it, because it dies
   first.
3. **Below zero means *beaten*, and [212](212-a-beaten-body-gets-one-roll.md) already
   owns what beaten means.** That issue says a beaten body rolls once: fail and it runs
   and lives, pass and it stays, lands one single blow, and dies. What has never been
   defined there is what *being beaten* is — and "terror plus health below zero" is
   exactly that definition. They are two halves of one rule, written months apart, and
   neither half has ever had the other.

If it is the third, a surge body does not roll. It is already going home, which is what
being made of paper is for.

*Answered, and folded into the body of this issue: "everyone has one hit point" means
everyone the surge **sends out**, not everyone standing on the field. And the trigger
for running home is the sum above, not surviving a blow — with one hit point there is
no surviving a blow, which is what made the old wording impossible.*
**S3 — does a running body still count?** A body streaming home is on the field,
taking up room, blocking lines of sight, and being counted in push depth. Whether it
should be is a real question: a surge whose lanes fill with bodies going the wrong
way may read as a mess rather than as a current.
