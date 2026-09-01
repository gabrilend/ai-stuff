# The Camera And What It Watches

The angle never changes. What changes is where the camera is looking, how close
it is, and — the part with the most machinery behind it — **what it has decided
is worth looking at**.

## The camera itself

Four numbers, and nothing else.

| Field | Type | Meaning |
| --- | --- | --- |
| `pan_x`, `pan_y` | doubles, pixels | added to every projected point |
| `scale` | double | multiplies `half_width`, `half_height` and `layer_pixels` together, so zooming never distorts the projection |
| `subject` | body id, or zero | who is being followed, or nobody |

Zoom multiplies all three projection constants by one number on purpose. Scaling
the cell size and the layer height independently would change the apparent angle
of the world as you zoom, which reads as the maze subtly leaning.

Panning is by drag and by the arrow keys. Zooming is by the wheel, **centred on
the pointer** rather than on the middle of the window — inverting the projection
at the pointer before and after the scale change and adding the difference to the
pan. Zooming toward the middle when the thing you are interested in is at the
edge means chasing it back to the middle after every notch.

## The director

The camera does not choose what to watch. A separate thing does, and it is worth
keeping separate because "where is the camera" and "who is interesting" are two
questions that change at completely different rates.

The director holds a **subject** and a **verdict** about that subject, and every
tick it asks one question: *is this still worth watching?* When the answer is no,
it picks something else.

### The three ways of watching

| Mode | What the camera does |
| --- | --- |
| **free** | nothing. The person is driving. |
| **follow** | the pan tracks the subject's projected position, eased rather than snapped, so the maze slides instead of jumping |
| **stakeout** | the camera goes to where the subject is, and then *stops*. It holds that spot and watches whatever wanders through for `dwell_seconds`, then the director picks again. |

Stakeout exists because following is not always the better shot. A camera welded
to a body in a corridor shows a wall going past. A camera parked at a junction
shows the maze working.

### The settings

All of these are adjustable while the program is running, from the panel bound to
a key. Adjusting them never touches the simulation.

| Setting | Kind | What it does |
| --- | --- | --- |
| `swap now` | a key | immediately abandon the subject and pick a new one at random |
| `on swap, follow` | toggle | whether a newly picked subject is followed or staked out. Off means stakeout. |
| `dwell_seconds` | slider, 1 to 60 | how long a stakeout holds before picking again |
| `auto swap` | toggle | whether the director swaps by itself when the subject stops being interesting, or waits to be told |
| `same team only` | toggle | when swapping away from a body that belongs to a side, prefer another body on that same side |
| `stay with the loser` | toggle | when a duel ends, whether to keep watching the body that lost or move on |

`same team only` is the setting that makes a session about a faction rather than
about a maze. With it on, the camera swaps from one fencer of a colour to
another fencer of that colour, and you end up following an army. With it off, the
camera goes wherever the action is and the sides stop meaning anything to you.

### When a subject stops being interesting

The director's verdict, in the order it is checked:

1. The subject no longer exists — it left the aquarium or was killed.
2. The subject's duel ended. See [fencing](017-fencing.md).
3. The subject arrived wherever it had decided to go — the aquarium's version of
   "solved the maze". A body in an aquarium sets itself errands and completes
   them; completing one is the moment the story it was telling finished.
4. The subject has been idle longer than `boredom_seconds`.
5. Nothing above, and the stakeout's `dwell_seconds` elapsed.

Only when `auto swap` is on does a verdict cause a swap. With it off the verdict
is still computed and still shown in the panel, so that pressing `swap now` is an
informed choice rather than a dice roll — the panel says *this one is done* and
you decide.

### Picking the next one

From the `camera` stream, and **only** from the `camera` stream. That stream is
never read by the simulation, and the simulation is never read for randomness by
the director. This is the single rule that keeps a session reproducible while
somebody is mashing the swap key: the maze does not care that you are watching.

The candidate set is every body currently in the world, filtered by `same team
only` if it is on, and weighted so that bodies doing something — in a duel,
falling, being chased — are more likely to be picked than bodies standing still.
The weighting draws one number; it does not sort, because sorting every body
every swap is work proportional to the population for a choice that only needs to
be plausible.

## Following, drawn

A followed body gets a marker: a thin ring on the surface beneath it, drawn
before the body and after the column, so it sits on the stone rather than
floating. Without a marker, a camera locked to one of forty identical little guys
looks exactly like a camera that is not locked to anything.

## The question that was underneath this, and its answer

The phrasing was that the fencers *"should be able to swap to a different target
... to continue the watching experience"*, and it read two ways — the camera
swapping to a different fencer, or the fencer swapping to a different opponent.

**It was the fencer.** A released fencer re-engages immediately and the fight
rolls on, so the camera does not have to move to keep watching one. The camera's
verdict list still has "its duel ended" at the top of it, because a duel that
ends with somebody dead still ends.

## Related documents and tools

- [The isometric projection](006-the-isometric-projection.md) — the pan and scale go in here
- [Randomness comes from named streams](005-randomness-comes-from-named-streams.md) — why the camera has its own
- [Fencing](017-fencing.md) — where a duel ends and a verdict comes from
