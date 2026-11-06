<!-- made by scripts/build-info-pages from the comments in 010-swings.lua; change the comments and rebuild, not this page -->
# 010-swings


One attack from start to finish. A swing has a windup (committed: only a
hit can stop it), one strike moment (resolved by 011-hit-resolution.lua),
and a recovery. The kinds are rows in a table, so a weapon that wants a new
kind of swing adds a row rather than a branch.

Momentum is fixed at the strike: how fast the body was carrying itself at
the target, plus how the swing flows from the one before it.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.start` | `battle, s, request` | request: "swing", "overhead" or "riposte". Returns the swing, or false when the soldier cannot swing now. |
| `M.momentum` | `battle, s, swing` | Body part: speed toward the target times the body-weight knob. Pattern part: the flow bonus from the last swing's side to this one's, forgotten if the last swing was too long ago. The overhead always carries its own. |
| `M.advance` | `battle, s, dt` | Moves a swing on by one tick. Returns true on the tick it strikes. After an overhead strikes, its swinger is open (unparryable) for the recovery. |
| `M.progress` | `swing` | For drawing: phase "windup" or "recovery" and how far through it, 0..1. |

## Tables of rows

| Name | What it is |
| --- | --- |
| `KIND_SIDE` | The side each kind comes from, when it does not depend on the U. |
| `FLOW` | How a swing flows from the last one: the previous side, then this side, names the momentum bonus earned. Opposite sides flow; the same side again stalls (no row); a stab after a slash flows a little. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `allowed` | `weapon, kind` | (no comment in the source) |
| `choose_kind` | `battle, s, request` | An overhead request is an overhead if the weapon makes them; anything else swings from wherever the sword sits on the U. A weapon or a soldier that only stabs turns every swing into a stab. |
