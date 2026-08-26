# 603 -- Driven and ordered

**Phase:** 6, control is a dial
**Blocked by:** [601](601-a-scope-is-a-record.md)
**Blocks:** [607](607-the-phase-six-demo.md)
**Documents:** [who controls what](../docs/008-who-controls-what.md)
**Open questions:** [6.4](../docs/016-open-questions.md) — a party of four.

## Current behaviour

Every viewer drives one body with keys. `sim_drive` and `sim_order_move` both
exist and nothing chooses between them.

## Intended behaviour

A scope's `style` says which interface a viewer gets, and which verbs the gauntlet
accepts from it.

| Style | Interface | Verbs |
| --- | --- | --- |
| `DRIVEN` | Keys. You **are** that body; forward is where it is facing. | `DRIVE`, `ORDER_FACE`, `ORDER_STOP` |
| `ORDERED` | Select and order, the way a strategy game does. | `ORDER_MOVE`, `ORDER_FACE`, `ORDER_STOP` |

`DRIVE` from an `ORDERED` scope is refused — in words, naming the style, because
somebody whose keys do nothing needs to know it is a category error rather than a
broken keyboard.

### It is genuinely a separate axis

A GM can drive one goblin with the keys. A player with a party of four gets the
strategy-game interface for their four. Style and membership do not constrain each
other, and the moment they do the dial has collapsed back into a list of roles.

### The party question this exposes

The vision says a player controls "up to an entire party at once, but generally
not more". Four bodies driven simultaneously with one keyboard is not possible.
Four given orders is the strategy interface. **One driven and three following is a
third thing** that is common in games and appears in no document here.

Build the two styles. Leave [6.4](../docs/016-open-questions.md) open, because the
third thing is a design decision and not a missing function.

## Suggested implementation steps

1. Add the style gate to the gauntlet, between membership and the ruleset.
2. Add a refusal reason and its sentence.
3. Tell the view which style it has, in `OP_HELLO`, so it can present the right
   interface rather than guessing from what gets refused.
4. Write the companion `.info.md`.
5. Test each verb against each style, asserting the reason rather than the failure.
