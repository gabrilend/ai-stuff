<!-- made by scripts/build-info-pages from the comments in 007-stamina.lua; change the comments and rebuild, not this page -->
# 007-stamina


How much the body has left. Stamina runs from 1 (fresh) to 0 (spent);
fatigue is 1 minus stamina. Actions spend it, rest restores it, and the
parry chance and the two trip rules are read from it here, as pure
functions of a soldier record and the configuration, so the documentation's
fatigue slider can show exactly what the game does.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.spend` | `s, amount` | A cost larger than what is left takes stamina to zero, never below. |
| `M.restore` | `s, config, dt, moving` | Called once per tick after everything else. Swinging, guarding and dodging spend rather than restore; standing still restores fastest. |
| `M.parry_chance` | `stamina, config, bushido` | Nearly certain when fresh, falling with fatigue along a curve, and never below the floor. Bushido flattens the curve, for armies without the armor to rely on. |
| `M.backstep_trips` | `s, config` | Backstepping while fatigued trips, always. |
| `M.sidestep_trips` | `s, config, stream` | Sidestepping while guarding trips one time in four; never otherwise. The roll is only drawn while guarding, so unguarded sidesteps do not move the movement stream at all. |
| `M.trip` | `s, config, battle` | Down she goes: no movement, swing or guard until she gets up. |
