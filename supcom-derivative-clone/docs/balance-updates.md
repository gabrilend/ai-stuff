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

The second table is `assets/040-unit-catalogue.lua` (issue 202), one row per
kind. Its first values are the vision's starting numbers above, with a tank
shell worth 25: a helicopter takes two shells and a frigate eight (B2's working
ruling), and costs run ten-to-one mass for land, the reverse for air, and equal
for the sea and for the anti-air gun, which is priced as land and air at once.

**The claim radius moved from the rules to the catalogue** (issue 202). It was
`claim_radius = 2` in `assets/034-the-rules.lua` for every unit; it is now each
kind's `claim_radius`: two for the tank, the anti-air gun, the frigate and the
command truck, four for the enforcer (B6's working ruling), and zero for the
helicopter, because a plane claims no ground. No value a match used changed;
the enforcer's four and the plane's zero are new.
