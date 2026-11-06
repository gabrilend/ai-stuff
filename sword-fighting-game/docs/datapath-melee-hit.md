# Datapath: a sword blow

From where the sword rests to what the blow does.

```
mouse motion ──► u (−1..1) on the U ──► side: left | bend | right
left click   ──► swing kind: bend → stab, an arm → slash
space        ──► overhead (side "above")
                    │
          windup (committed: only a hit stops it)
                    │
          strike moment ──► momentum =
                    body:    speed toward the target × body weight
                  + pattern: flow from the last swing's side to this one
                             (opposite side: flow bonus; slash → stab: bend
                             bonus; same side: none; forgotten after a while)
                  + overhead bonus for an overhead
                    │
          resolution, in order (011):
            reach    alive, within weapon reach + kind reach + body, in front
            parry    target guarding, standing, not open, not from behind:
                     roll parry chance (stamina curve, bushido flatter)
                     + shield bonuses ──► success: both spend stamina,
                     attacker staggers, riposte answers with a quick stab
            flank    attacker more than 90° off the target's facing
            critical first cause that holds: momentum ≥ threshold, flank,
                     always-critical trait, chance roll (always drawn)
            damage   weapon damage × kind × (critical multiplier) × armor share
            effect   health falls, target staggers, its windup is lost;
                     at zero it falls and frees its cell
                    │
          recovery (an overhead leaves its swinger open: no parry)
```

Every number named here is a knob in src/001-config.def.lua (sections
sword, swings, hits, stamina) or a field of the weapon's catalogue entry.
The values in force can be read from the configuration; the effect of a
change is measured with `./run-many-battles`.
