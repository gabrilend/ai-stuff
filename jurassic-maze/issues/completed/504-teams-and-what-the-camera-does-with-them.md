# 504 — Teams, And What The Camera Does With Them

| | |
| --- | --- |
| Phase | 5 — The Fencing |
| Blocked by | 407, 503 |
| Blocks | nothing |
| Reads | [fencing](../../docs/017-fencing.md), [the camera](../../docs/008-the-camera-and-what-it-watches.md) |
| Open questions | 11 (do the little guys have teams). Question 1 is answered: the fencers swap, not the camera. |

## Current behavior

`team` is drawn at spawn from the kind's `team_count`, rather than alternated, so
a run does not depend on the order the aquarium happened to top itself up.

The director weights a body in a duel far above everything else when choosing
what to watch, and "its duel ended" sits at the top of its verdict list beneath
only the subject being gone. A fencer standing still with a sword out is
explicitly *not* an idle body, so the boredom rules do not apply to it.

**"Stay with the loser" needed its meaning pinned down.** Damage taken is
accumulated on the duel rather than derived from health afterwards, because after
a stalemate both walk away and the record of who lost is gone with it. When the
loser *died* there is nobody to stay with and the camera moves whatever the
setting says — which is not a compromise, it is what the words mean once one of
the two is not there.

A side is drawn as a tint on the body rather than as a separate sprite, so a
third side is a colour. The fencer's own colour is nearly white so that the tint
is what you see rather than a shift you have to look for.

The palette's rule that an unnamed creature comes out **magenta** is what caught
the fencer having been added to the creature table and not to the palette. A
colour nobody chose is the fastest way to see that.

## Intended behavior

`team` is a small integer; zero means unaffiliated. Two fencers duel when their
teams differ and neither is zero.

The director's **`same team only`** toggle reads the same field. With it on, the
camera swaps from one fencer of a colour to another of that colour and a session
becomes about following an army. With it off, the camera goes wherever the action
is and the sides stop mattering to the person watching.

That coupling — a combat field deciding a camera behaviour — is recorded here
because it is obvious while writing it and baffling six months later. A change to
how teams are assigned changes what the camera does.

Also here: **`stay with the loser`**, the toggle for what the camera does when a
duel ends. Following the winner is the obvious choice and it is usually the wrong
one — the winner walks off and the loser is the one something just happened to.

Teams are drawn in the palette as a tint on the body, not as a separate sprite,
so adding a third team is a colour.

## Suggested implementation steps

1. Assign teams at spawn from the creature kind's row, so a kind can be
   unaffiliated, single-team, or split.
2. Wire `same team only` into the director's candidate filter.
3. Wire `stay with the loser` into the duel-ended verdict.
4. Draw the team tint.
5. Test: with `same team only` on, a thousand swaps never select a body of a
   different team from the one it left, except when none is available — and that
   exception is counted rather than silent.

## Related documents and tools

- [Fencing](../../docs/017-fencing.md)
- [The camera and what it watches](../../docs/008-the-camera-and-what-it-watches.md)

## Still open

Open question 11: whether the wandering little guys of phase four and the fencers
of phase five are one creature kind with a field set, or two kinds. Assumed two
kinds, because a kind is a row and rows are cheap.
