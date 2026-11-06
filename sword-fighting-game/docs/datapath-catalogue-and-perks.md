# Datapath: the catalogue, mods and perks

```
assets/catalogue/{weapons,unit-types,regions,perks}.lua
   + mods/<name>/ the same files, for each mod in config.mods then --mod
     (an entry with an existing name replaces it whole; a new name adds)
   ──► every entry checked against its schema (004); unknown fields,
       missing fields, wrong types and names that point nowhere stop the
       program at start-up, naming file, entry and field
   ──► catalogue

battle setup (014): every soldier made as a base swordsman (006)
   ──► each side's perks applied in the order taken (015), by effect:
       convert_units  N soldiers from the back ranks become a unit type;
                      the player only if they chose to be affected
       swap_weapon    base swordsmen take another weapon
       add_trait      riposte, harry, bushido
       add_armor      armor rating points
       thicken        thick armor: +2 points, slower walk, longer windups
       unlock_ranges  volleys at range 1, 2 or 3
       crit_chance    a further chance that any hit is critical
   ──► derived numbers refreshed once (armor, walk share, awareness)

traits are read where their rule lives:
   always_critical (011)  guard_while_advancing (008)  stabs_only (010)
   throws_from_front (012, 013)  shield (011, 013)  loose (008)
   riposte (011)  harry (012)  bushido (007)
```

The worth of each perk is measured, not guessed: the phase 6 demo fights
matched batches with and without each one.
