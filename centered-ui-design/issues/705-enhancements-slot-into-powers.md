# 705 — Enhancements slot into powers

**Phase:** 7 — Growing outward
**Blocked by:** 704
**Blocks**: 706, 708
**Related documents:** docs/datapath-choices.md (tray slot, power slots),
docs/core-terms.md (enhancement, inspiration, tray),
/mnt/mtwo/notes/symbeline-superheros ("slot enhancements and dole out
inspirations")

## Current Behavior

A choice not taken at the level-up is lost.

## Intended Behavior

The model is City of Heroes' enhancement slotting, by way of the Symbeline
notes:

- Choices come in three kinds: **powers** (a unit kind, building or ability),
  **enhancements** (each strengthens one named power), and **inspirations**
  (one-time boosts doled out to a stand).
- Any offered choice can be held instead of taken. Held choices wait in the
  **tray**, shown on dials.
- An enhancement for a power the side already owns slots in when taken. An
  enhancement for a power the side does not own yet waits in the tray; when
  that power is acquired (bought, unlocked with aether, or offered and
  taken), every waiting enhancement for it slots in and strengthens it.
- Inspirations are doled out by telling a stand: map click on the stand, then
  the inspire button (the oldest held inspiration is used).

## Suggested Implementation Steps

1. Tray list per side; slot list per owned power.
2. Slotting rule run whenever a power is acquired.
3. Inspire verb in the order dispatch table.
4. Tests: three enhancements held for an unowned power all slot in the tick
   it is acquired; an inspiration is used once.

## Open questions

- Is this the system you meant, and is there a Symbeline document that
  specifies it more closely? (Open question 4.)
