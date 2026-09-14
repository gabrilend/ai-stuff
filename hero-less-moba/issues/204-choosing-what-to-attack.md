# 204 — Choosing What to Attack

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 105, 201 |
| Blocks | 203, 302, 606 |
| Reads | [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) |
| Open questions | none |

## Current behavior

Ranked, cheapest test first: somebody already swinging at me, then an enemy soldier
in acquisition range, then a structure in weapon range, then nothing.

**Rule 2 now picks whoever this body can already reach, at random among them, and the
nearest one it cannot reach otherwise.** It used to take the **lowest-health** enemy
anywhere in acquisition range -- seventy-four paces for a melee body, a hundred and
thirty for an archer -- with the random choice reserved for exact health ties, which
stop occurring the moment anybody is wounded.

The document below always said *nearest*; the code said *weakest*, with a line
defending it: bodies should finish things. What that actually does is send a soldier
past the man standing in front of him to reach somebody bleeding seventy paces away,
and when two lines meet, both sides do it at once. Everybody converges on whoever is
most hurt, from every direction, and the two lines walk through each other instead of
into each other. Measured: two lines that had been sitting a hundred and seventeen
paces apart with nobody fighting closed to seven, with six bodies engaged on each
side.

It mattered less while bodies could stand inside one another and a queueing rule held
a rank together. With bodies solid and that rule gone, **targeting is what makes a
line** -- two ranks stop against each other because each body is swinging at the body
in front of it.

Ties are broken by the team's own tie stream with reservoir sampling, which advances
the stream a fixed number of times so a replay stays reproducible. A spatial grid
rebuilt each tick keeps the search from being every body asking every other.

**And rule 1 hardly ever fires**, which was not noticed until somebody watched a
fight. The tick only asks a body to choose when it has **no living target**, so a
body already swinging at somebody never re-enters the ranking at all. Rule 1
therefore only decides anything in the one tick after a target dies. A body locked
onto a wounded enemy will take a whole fight's worth of blows in the back from a
second enemy and never once look round.

## Intended behavior

Target selection, ranked, cheapest test first:

1. **Whoever this body can already reach**, chosen at random when there are several.
   A body fights whoever is in front of it, and when several are, it has no reason to
   prefer any of them — picking at random is what stops a whole rank fixating on one
   man while the soldiers beside him swing at nobody.
2. **The nearest enemy soldier within acquisition range.**
3. **An enemy structure within weapon range.**
4. **Nothing.** Keep walking.

### An enemy that has struck you is always a valid target, at any distance

**Not an override — a candidate.** Whoever hits a body for the first time joins that
body's list of things it may choose from, and it joins it *regardless of range*: the
one target in this game that does not have to be inside acquisition range to be
picked. Everything else about the choice is unchanged, so the ranking above still
decides between it and everybody else.

Two consequences, and the second is the reason it is a candidate rather than a
command:

**A body being shot from beyond its own sight walks toward the thing shooting it.**
An archer at a hundred and thirty paces is outside a melee body's seventy-four, so it
does not appear in any search that body makes. Without this rule a soldier stands and
is killed by something it is not permitted to notice. With it, the archer is on the
list, is the only thing on the list, and the soldier closes on it.

**And a body in a melee does not abandon it to chase that archer.** If something is
already inside this body's reach, rule 1 takes it and the distant assailant loses —
which is right, and is the whole reason this is not an override. Being hit from far
away makes the striker *available*, not *urgent*. A rule that forced it would turn
every ranged volley into an invitation to break formation and run at the enemy
backline, and a line that does that is not a line.

**This is not what the code does today.** Today the striker outranks everything and is
taken immediately, which is the forcing version — so a body currently *does* abandon
the enemy in front of it to go after whoever shot it last.

### The list is rebuilt, not remembered

**Every time a body needs to choose, it identifies the nearby potentials afresh.** The
proximity search runs, and the remembered strikers are added to what it found. The list
is a thing assembled at the moment of asking, not a thing accumulated and carried.

That is what makes the striker memory's shortness harmless. It holds only the few most
recent assailants and a new one pushes the oldest off, so it is fair to ask what happens
to a body that has been forgotten — and the answer is nothing, because forgetting is not
exclusion. Anything standing near this body is found by the search whether it is
remembered or not. **There is no case where a body becomes unable to target an actor
again.**

The memory is doing one job only, and it is worth stating narrowly: it carries the
enemies that are *out of reach of the search* — the archer at a hundred and thirty paces
that a melee body's seventy-four will never sweep up. Anything inside the sweep needs no
memory. So a striker that falls off the end of the list has lost exactly one privilege:
being chased when it is too far away to see. If it is anywhere near, it is a candidate
like everybody else.

Structures rank **below** soldiers deliberately. A soldier that walks past a
defended tower to chew on the tower is a soldier that dies for free, and a
frontline made of those never moves — which is the exact failure this whole game
exists to fix.

### What makes a body look up

The ranking above decides *what* to hit. This decides *when it is asked* — and
without it the first rule is nearly dead, because a body with a living target is
never asked at all.

**A body looks up when it is struck by an enemy that has not struck it before.**
Not when it is struck — a body in a melee is struck constantly, and re-deciding on
every blow is the crowd-of-bodies-re-deciding-every-tick failure that the
only-if-you-have-nothing rule exists to prevent. The event is a *new* assailant,
which is the moment something has changed about the fight this body is in.

So each body remembers **the few enemies that have most recently hit it**, and an
attacker already in that memory passes without comment. A body being worked over by
the same three enemies settles down and keeps swinging; a body that picks up a
fourth from a direction nobody was covering looks round once.

The memory is **small and forgetful on purpose** — a handful of slots, oldest
overwritten. Remembering every enemy that ever hit it would mean a body that has
been through two fights never looks up again, which is the opposite failure and a
harder one to see. Forgetting also does something real: an enemy that hit you,
left, and came back **is** worth another look.

Each remembered attacker is held with its **generation**, because slots are
recycled. Without the stamp, a body would remember "id 57" and then ignore an
entirely different soldier that was later born into slot 57 — which is the same
class of bug the target's generation check exists to prevent, one step removed.

**It overrides the blocked-shot patience.** A body that had no line a moment ago and
is waiting a few ticks before looking again should not spend that wait being hit by
somebody new. Being struck is exactly the event that makes the wait wrong.

The look-up is a **flag set during the attacker sweep and read on the next tick**,
which is the same one-tick lag rule 1 already runs on — the sweep is where every
attacker-and-victim pair is already being visited, so noticing a new one there is
free rather than a second pass.

Exact ties are broken by the `tie` random stream, not by the lower slot index.
Two identical soldiers facing two identical enemies at identical distances should
not both pick the leftmost one every single time; that produces a frontline that
focuses in lockstep and looks mechanical. The stream is separate from every other
so that changing tie-breaking never perturbs the upgrade draw sequence.

The nearest-enemy search must not be a scan of every soldier on the map for every
soldier on the map. Soldiers are on lanes, and everything a soldier can reach is
within a short stretch of its own lane's path. **Bucket soldiers by lane and by
milestone**, and search two buckets. The search is then bounded by how many
bodies are in a few paces of lane, which is small and does not grow with match
length.

## Suggested implementation steps

1. Add `attacked_by` to the soldier record, written in the attack pass and read
   here. It is the cheapest good answer available.
2. Build the lane-and-milestone buckets once per tick, in the spawn pass, as a
   counting sort into a preallocated array. Not a hash table; hash iteration
   order is not stable and would break determinism.
3. Write the retarget pass over the buckets, sliced for the thread pool. It reads
   the world and writes only each soldier's own target fields.
4. Check the target's generation before every use. A recycled id must never
   silently address a stranger.
5. Write a test with two soldiers at equal distance from a third and assert the
   choice is stable for a given seed and varies across seeds.
6. Write a test that a soldier with a defended tower and an enemy soldier both in
   range picks the soldier.
7. Add the recent-attacker memory to the soldier record: a fixed handful of slots,
   each holding an attacker's id and the generation it had when it struck. Cleared
   when a body is born, like every other field.
8. In the attacker sweep, where every attacker-and-victim pair is already visited,
   compare the striker against the victim's memory. Absent means write it into the
   oldest slot and raise the victim's look-up flag.
9. In the retarget pass, treat a raised flag as a reason to choose even when the
   body has a living target. Clear it in the choosing, and let it skip the
   blocked-shot patience.
10. Write a test that a body already fighting one enemy switches its attention when
    a second enemy that has never hit it starts hitting it — and, in the same test,
    that a third blow from an enemy already in the memory does **not** make it look
    up, because the second half is the one that keeps this from being a body that
    re-decides every tick.

## Related documents and tools

- [A unit and what it carries](../docs/004-a-unit-and-what-it-carries.md)
- The `tie` stream from issue 105
