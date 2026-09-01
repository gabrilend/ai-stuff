# Open Questions

Every question that came up while working this out, written down where it can be
found rather than quietly answered by whoever hit it first. They are not
decoration and they are not a closing section. **A task holding an unanswered
open question is in progress, not finished.**

Each says what is blocked by it and what was assumed in the meantime, so that
work could continue. An assumption is not an answer.

---

## Blocking — these change what gets built

### ~~1. "Swap to a different target" — the camera, or the fencer?~~ — answered

**The fencer.** A released fencer re-engages immediately and the fight rolls on;
a corridor becomes a running brawl and the camera never has to move to keep
watching one.

`disengage_seconds` is zero by default. Above zero it is the other behaviour — a
series of separate duels with the camera going looking between them — and both
have tests, so the knob stays. See
[fencing](017-fencing.md) and
[issue 503](../issues/completed/503-a-duel-has-to-end.md).

### 2. "But only when they're navigating the dungeon" — what does the "only" attach to?

The sentence was: *"The humans can ride the dinos and the dinos can use weapons.
But only when they're navigating the dungeon."*

Either **riding and weapons exist only in the delve mode** and not in the
habitat, or **a dinosaur carries its weapon while moving and puts it down to
fight**, which would be a strange rule but is a possible reading of the same
words.

*Assumed for now:* the first, and it is built that way. See
[the delve](021-the-delve.md).

*Blocks:* nothing structural. Weapons are not built at all yet, so the second
reading would be a change to a row rather than to a design.

### ~~3. Does "solve" mean solve?~~ — answered

**Loosely.** The monsters are enemies with health, and a party fights them
directly. The cycle between the three of them becomes a **damage-type chart**
rather than the point of the mode: fire ruins a vine and does nothing to stone, a
stone fist ruins a wooden machine, and being held still is a thing that happens
to a golem rather than the only thing that can.

The creatures stay exactly as they are. What changes is that the party is
equipped — humans carry weapons, and dinosaurs carry them too while navigating
the dungeon — and the "arranging the meeting" machinery is not wanted.

See [the delve](021-the-delve.md) and
[the monsters](023-the-monsters-of-the-delve.md), both rewritten to this reading.

### 4. How big is a maze, and how many things are in it?

No size was given. The reference picture is roughly a hundred and fifty cells
across and eight or so terraces tall, and it holds nothing but stone.

*Assumed for now:* 129 by 129 cells and 32 layers, which is as tall as a column
can be. Populations are per scene and run from 90 dinosaurs to 1400 walkers.

*Answered in part by measurement:* the thread pool is **not** needed. Fourteen
hundred bodies cost about three and a half milliseconds a tick, which is a fifth
of a frame — and the largest speed-up in the project by far was not parallelism
but raising LuaJIT's trace cache limits, which was worth eleven times.

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

### ~~6. Is the jungle ever in scope?~~ — answered

**No. The stone is the whole picture.** Nothing outside the maze: no foliage, no
volcanoes, no sky beyond a flat colour, and no creatures standing outside looking
in. It would be the largest art commitment in a project that has no art at all,
and none of it has a simulation behind it.

Recorded in [drawing a pile of stones](007-drawing-a-pile-of-stones.md), which
previously listed it as undecided.

### 6b. Should there be more plazas, or fewer?

Not in the original list, and it turned into a real question. The generator
clears about a dozen open courts among the corridors, because a body wider than
one cell has nowhere at all to stand without them.

They also decide how much of the maze a dinosaur can use: the courts are mostly
not connected to each other, so a maze has eight or fourteen separate
**enclosures** and a dinosaur lives in one of them for its whole life. Nobody
designed that and it is the best thing in phase 6. More plazas means fewer, larger
enclosures and a habitat that feels less like a zoo; fewer means more of a maze
and less of a habitat.

### 7. Should the upper terraces be inset?

Stacked rectangles was the answer given, and the generator does that. But the
reference picture is a stepped pyramid — every level up is smaller than the one
below, which is what lets you see the lower terraces at all from a corner-on
angle.

The generator's centre bias approximates this. Should it be explicit instead —
each slab strictly inside the last?

### 7b. Should a golem's damage heal?

Related to question 9 below and now real rather than hypothetical: golems break
about forty blocks a minute and the maze visibly opens up behind them. Over a long
run it becomes a field.

### 8. Does a creature remember where it last saw something?

Sight has no memory today: lose sight, forget immediately. Remembering the last
known position is what makes a search look intelligent rather than random, and it
is one field.

### 9. When a golem breaks a wall, does it stay broken?

The delve's golem is the only thing that changes the stone. Over a long run the
maze slowly becomes a field. Does it heal? Should there be a limit? Does a
broken maze that the validator would now reject matter?

### ~~10. What colour is it?~~ — answered

**Keep the limestone.** Grey-tan stone with green moss in the walked places, as
the reference picture has it. The three-tone shading and the per-cell mottle do
the work of making the geometry legible; the hue is close to incidental, and it
reads well at every zoom.

Every colour in the project is in `041-the-palette.lua` and nothing else names
one, so re-lighting the whole thing is still one file if that changes.

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
