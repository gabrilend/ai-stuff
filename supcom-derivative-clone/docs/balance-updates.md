# Balance Updates

An append-only ledger of knobs turned and levers pulled, with the reason for each.
Issue files are for building things; this is for tuning the numbers in the
catalogue tables under `assets/` once they exist. Every entry says what changed,
from what, to what, and why.

Nothing has been tuned, because nothing has run. The vision's starting numbers —
four shells for a tank, three for a gun, one for a truck, six and four for an
enforcer; ten-to-one costs for land, the reverse for air, equal for sea; heal
intervals of a few seconds per kind — go into the catalogue as its first values,
and the first entry here will be the first time one of them moves.

The first table to exist is `assets/034-the-rules.lua`, which holds the rules
that are not a unit's. Its first values are the working rulings of the open
questions, not tunings: ten ticks a second (B4), and a claim that completes
after three increments of a one-second counter within two cells (B6).
