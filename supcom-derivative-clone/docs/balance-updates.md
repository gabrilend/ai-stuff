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

**What a shell lands for, and when a gun fires again** (issue 206). A shot does
the shooter's `damage` times its falloff at the distance it was fired over,
rounded down, and never less than one. A gun that fires waits for the next
increment of its kind's shared reload counter, so its first shot after a
quiet spell can come early, and from then on it fires once a reload period.
No catalogue value changed. The shot queue's size, `shots_per_unit = 4` in the
rules, is a size and not a tuning: a full queue is a refusal by name.

**What a death puts back** (issue 208). Each kind's bones carry its new
catalogue field `bone_share` of its `cost_mass`, rounded down: 0.5 for every
kind to start, so a tank leaves 50 mass and a helicopter 2. The command truck
cost no mass and leaves none. `bones_per_unit = 8` in the rules is a size, not
a tuning.

**How often a truck launches its plane** (issue 210). A new rule,
`launch_seconds = 15`: the launch counter fires every fifteen seconds, and a
truck that launched waits for its next increment. A guess to be measured.

**The enforcer's sphere, appetite and upgrades** (issue 211). New catalogue
fields, zero for every kind but the enforcer:
- `sphere_radius = 3` (cells);
- `eat_radius = 2` (cells);
- `eat_share = 0.5`, half of what it eats to the treasury until a factory's
  dial says otherwise;
- three upgrade steps of 200 eaten mass each (A9's working ruling). Each step
  adds 25 to the health cap, 10 to the damage and 1 to the sphere.

These are guesses, to be measured.

**What ground pays** (issue 301). There is a new rule, `mass_per_cell = 1`:
every owned land cell pays its team one mass a tick. A team holding a quarter of
a 64-by-64 field earns about a thousand mass a tick, or ten thousand a second.
That is a starting point for the proving ground to tune against the costs in
the unit catalogue.
