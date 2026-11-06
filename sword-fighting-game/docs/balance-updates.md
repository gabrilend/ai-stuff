# Balance updates

Append-only. Every change to a default in src/001-config.def.lua is written
here: the knob, the value before and after, and why. For the numbers a change
produced, run `./run-many-battles` before and after rather than trusting a
figure copied here.

## 2026-11-06 — first numbers

All of src/001-config.def.lua was set from the vision's wording where it
gives one (half a second to move the lock, one in four to trip on a guarded
sidestep, half speed through an ally, range 3) and by judgement elsewhere.

## 2026-11-06 — hits.critical_momentum 0.9 → 0.75

Headless smoke battles showed criticals on about one hit in a hundred, nearly
all from overheads. The vision says extra damage "usually means you got
momentum on your side", so momentum should be the ordinary road to a
critical: at 0.75 a slash from the side opposite the last one (flow 0.6)
becomes critical with a modest step into the target, while a repeated side
or a stab never is on its own.
