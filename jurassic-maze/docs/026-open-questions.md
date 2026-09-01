# Open Questions

Every question that came up while working this out, written down where it can be
found rather than quietly answered by whoever hit it first. They are not
decoration and they are not a closing section. **A task holding an unanswered
open question is in progress, not finished.**

Each says what is blocked by it and what was assumed in the meantime, so that
work could continue. An assumption is not an answer.

---

## Blocking — these change what gets built

### 1. "Swap to a different target" — the camera, or the fencer?

The sentence was: *"for the fencing guys, they should be able to swap to a
different target (same team or no? toggle checkmark) to continue the watching
experience. That same toggle should apply when they 'solve' the maze."*

It reads two ways. **The camera** swaps to a different fencer when this duel
ends, or **the fencer** swaps to a different opponent so the fight continues and
the camera does not have to move.

Both are cheap and they are not mutually exclusive. Which was meant?

*Assumed for now:* the camera, described in
[the camera](008-the-camera-and-what-it-watches.md). The fencer's re-engagement
delay is written as a knob rather than a constant, so setting it to zero produces
the other reading without a rewrite.

*Blocks:* issue 407, issue 503.

### 2. "But only when they're navigating the dungeon" — what does the "only" attach to?

The sentence was: *"The humans can ride the dinos and the dinos can use weapons.
But only when they're navigating the dungeon."*

Either **riding and weapons exist only in the delve mode** and not in the
habitat, or **a dinosaur carries its weapon while moving and puts it down to
fight**, which would be a strange rule but is a possible reading of the same
words.

*Assumed for now:* the first. See [the delve](021-the-delve.md).

*Blocks:* issue 701, issue 702.

### 3. Does "solve" mean solve?

The phrase was *"trying to solve Dungeons and Dragons monsters"* — not fight, not
kill. Taken literally it makes each monster a lock with a key, and the keys turn
out to be each other, which is the design in
[the monsters](023-the-monsters-of-the-delve.md).

Taken loosely it just means "deal with", and the monsters are enemies with
health.

The literal reading is a much more interesting mode and it is built out of what
was said rather than invented on top of it. But it is an interpretation of one
word, and it decides the whole phase.

*Assumed for now:* literal.

*Blocks:* all of phase 7.

### 4. How big is a maze, and how many things are in it?

No size was given. The reference picture is roughly a hundred and fifty cells
across and eight or so terraces tall, and it holds nothing but stone.

*Assumed for now:* 129 by 129 cells, 12 layers, which is odd-numbered so the room
lattice fits exactly, and a few hundred bodies. Every one of those is a knob in
the parameters table, so the answer changes a number rather than a design.

*Blocks:* nothing, but it decides whether the thread pool is needed at all.

### 5. Do the phases share one aquarium, or is each its own scene?

Can balls, little guys, fencers and dinosaurs all be in the maze at once, or does
each phase replace the last?

They *can* coexist — that is what the locomotion table is for — but nothing has
been said about whether they should.

*Assumed for now:* they coexist, and which kinds are present is a parameter of
the run. It costs nothing to allow and it is the more interesting default.

*Blocks:* issue 307, the phase demos.

---

## Not blocking, but wanted

### 6. Is the jungle ever in scope?

The reference picture is more than half foliage: ferns, palms, volcanoes, a sky,
and dinosaurs standing outside the maze looking in. None of it is in the plan and
none of it has a simulation behind it. It would be the single largest art
commitment in a project that currently has no art at all.

Worth it, someday? Or is the stone the whole picture?

### 7. Should the upper terraces be inset?

Stacked rectangles was the answer given, and the generator does that. But the
reference picture is a stepped pyramid — every level up is smaller than the one
below, which is what lets you see the lower terraces at all from a corner-on
angle.

The generator's centre bias approximates this. Should it be explicit instead —
each slab strictly inside the last?

### 8. Does a creature remember where it last saw something?

Sight has no memory today: lose sight, forget immediately. Remembering the last
known position is what makes a search look intelligent rather than random, and it
is one field.

### 9. When a golem breaks a wall, does it stay broken?

The delve's golem is the only thing that changes the stone. Over a long run the
maze slowly becomes a field. Does it heal? Should there be a limit? Does a
broken maze that the validator would now reject matter?

### 10. What colour is it?

The reference is grey and tan limestone with green moss in the cracks and pale
sandstone on some faces. That is the assumed palette. It is also the only
aesthetic decision in the project that has not been made deliberately.

### 11. Do the little guys have teams?

`team` is zero for a body that belongs to nobody, and the camera's `same team
only` setting reads it. But the wandering little guys of phase four have no
reason to have teams, and the fencers of phase five do. Are they the same
creature with a field set, or two creature kinds?

### 12. Is there ever sound?

Nothing has been said. The engine's audio module is currently switched off, which
is a stronger statement than leaving it on and unused — a module that is not
started cannot be quietly depended on.

---

## How to use this page

Ask one at a time. When one is answered, the answer goes into the document it
belongs to, the question is struck from this page with a line saying where the
answer went, and any issue that was blocked on it is unblocked.

A question that is answered and left here is worse than no question at all,
because it looks unanswered. A question that was answered somewhere else and
never struck from here is the same problem from the other direction.
