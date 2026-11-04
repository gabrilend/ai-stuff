<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10.
     Current design of choice generation, roll tables, offers and holding.
     Updated by phase 7 issues. -->

# Datapath: from seed to a level-up offer

## Data

| Structure | Fields |
|---|---|
| choice | `id` (string), `category` (string: power — a unit kind, building or ability; enhancement — strengthens one power; inspiration — a one-time boost), `stats` (table of stat name → number), `value` (number: the budget spent, the same for every choice of a tier), `price` (resource counts), `requires_unlock` (string unlock id, or the word `none`), `enhances` (power id, for enhancements) |
| unlock | `id` (string), `aether_price` (number) — a magical prerequisite that opens a family of powers |
| roll table | list of entries |
| roll table entry | `name` (string), `roll_chance` (number 0–1: how likely this entry comes up at all), `values` (list of pairs: choice id, selection weight number) |
| offer | `side` (seat or foe id), `level` (integer), `choices` (list of choice ids, the same count for every side) |
| tray slot | `choice_id` (string), `waiting_for` (power id the enhancement needs, or the word `none`) |
| power slots | per owned power: list of slotted enhancement ids (each raises that power's stats by its value) |

## Steps

```
 seed ─▶ choice generator: for each choice, spend the tier's value budget
         across stats by seeded random proportions ─▶ catalog of choices
      ─▶ table generator: group choices into entries, give each entry a
         roll chance and each value a selection weight ─▶ roll tables
 front decided ─▶ both sides level up ─▶ for each side, in parallel:
      repeat: walk the table; each entry rolls its chance; if it comes up,
              pick one value by the selection weights; until the offer has N
      ─▶ compare total value across sides; re-roll the worst outlier until
         all sides are within the parity margin
 ─▶ side takes, prices, or holds each choice
 ─▶ enhancements whose power is not owned wait in the tray; when the power
    is acquired, each one slots into it and strengthens it
    (City of Heroes' slotting, by way of the Symbeline notes)
```

Two-step rolling, in one picture: the table is a list of lottery drums. Each
drum first decides whether it turns at all this time (its roll chance). If it
turns, a ball comes out, and some balls are more common than others (the
selection weights).
