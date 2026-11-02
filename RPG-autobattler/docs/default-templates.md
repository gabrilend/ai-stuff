# Default Unit Templates

Generated from `src/data/default_templates.lua` by `src/utils/template_documentation.lua`;
rewrite it with `./run <dir> template-docs` rather than editing it by hand.

Every template has a budget of 100 points. Point costs are first guesses (issue 058);
tuning waits until ability sets play in real matches (issue 067).

## Starter

One template per ability set: the plainest way to field each.

### Warrior

Sword and power strike; holds the line.

- **Body:** melee; **archetype:** damage
- **Points:** 58 of 100
- **Stats:** health 120, speed 60, armor 4, magic resist 0, sight 60
- **How to use it:** Put it in front. Power strike charges only with an enemy in reach, so it pays to close in.

Abilities:

1. **primary_melee_attack** (primary): 25 damage; reach 15; charges in 10 s; 10 points
2. **power_strike** (damage): 45 damage; reach 15; charges in 12.5 s; 42 points

### Archer

Bow and piercing shot; fights from range while standing still.

- **Body:** ranged; **archetype:** ranged damage
- **Points:** 71 of 100
- **Stats:** health 80, speed 45, armor 0, magic resist 0, sight 80
- **How to use it:** Keep it behind a front line; piercing shot charges only while it stands still.

Abilities:

1. **primary_ranged_attack** (primary): 20 damage, projectile; reach 30; charges in 10 s; 11 points
2. **piercing_shot** (damage): 35 damage, pierces 3, projectile; reach 40; charges in 12.5 s; 50 points

### Cleric

Heals the weakest ally and wards a group.

- **Body:** support; **archetype:** support
- **Points:** 58 of 100
- **Stats:** health 80, speed 50, armor 0, magic resist 5, sight 70
- **How to use it:** Field it with two or more allies nearby, or the ward never charges.

Abilities:

1. **primary_melee_attack** (primary): 25 damage; reach 15; charges in 10 s; 10 points
2. **minor_heal** (heal): 30 healing; reach 30; charges in 16.7 s; 18 points
3. **protective_ward** (buff): buff for 15 s; reach 30; charges in 25 s; 28 points

### Battle Mage

Meteors on clumped enemies; stirs allies to fury.

- **Body:** special; **archetype:** damage
- **Points:** 71 of 100
- **Stats:** health 100, speed 70, armor 0, magic resist 0, sight 70
- **How to use it:** Best against crowds: meteor strike waits for two enemies in reach.

Abilities:

1. **primary_ranged_attack** (primary): 20 damage, projectile; reach 30; charges in 10 s; 11 points
2. **meteor_strike** (area): 40 damage in a 35 radius; reach 45; charges in 33.3 s; 29 points; cooldown 6 s
3. **battle_fury** (buff): buff for 12 s; reach 20; charges in 25 s; 21 points

### Brute

Stuns, cripples and sunders the armor of what it hits.

- **Body:** tank; **archetype:** crowd control
- **Points:** 50 of 100
- **Stats:** health 200, speed 30, armor 5, magic resist 0, sight 50
- **How to use it:** A debuff specialist: it softens one target for everyone else to finish.

Abilities:

1. **primary_melee_attack** (primary): 25 damage; reach 15; charges in 10 s; 10 points
2. **stunning_bash** (debuff): debuff for 1.5 s; reach 15; charges in 33.3 s; 3 points
3. **crippling_blow** (debuff): debuff for 4 s; reach 15; charges in 20 s; 9 points
4. **sunder_armor** (debuff): debuff for 8 s; reach 20; charges in 20 s; 18 points

Warnings (on purpose): 3 debuff abilities besides the primary; more than 2 of one kind may leave gaps.

### Druid

Regeneration and healing circles from range.

- **Body:** support; **archetype:** support
- **Points:** 83 of 100
- **Stats:** health 60, speed 50, armor 0, magic resist 5, sight 70
- **How to use it:** Heals over time; it shines in long fights, not quick ones.

Abilities:

1. **primary_ranged_attack** (primary): 20 damage, projectile; reach 30; charges in 10 s; 11 points
2. **regeneration** (heal): 10 healing; reach 25; charges in 20 s; 26 points; cooldown 4 s
3. **healing_circle** (area): 25 healing in a 40 radius; reach 25; charges in 25 s; 26 points; cooldown 6 s
4. **focus** (buff): buff for 10 s; reach 50; charges in 33.3 s; 20 points

### Skirmisher

Poison darts and piercing shots.

- **Body:** ranged; **archetype:** ranged damage
- **Points:** 92 of 100
- **Stats:** health 80, speed 55, armor 0, magic resist 0, sight 80
- **How to use it:** Poison ticks through armor: use it against tanks.

Abilities:

1. **primary_ranged_attack** (primary): 20 damage, projectile; reach 30; charges in 10 s; 11 points
2. **poison_dart** (damage): 8 damage, projectile; reach 30; charges in 14.3 s; 19 points
3. **piercing_shot** (damage): 35 damage, pierces 3, projectile; reach 40; charges in 12.5 s; 50 points

### Berserker

A cleaving axe and battle fury.

- **Body:** melee; **archetype:** damage
- **Points:** 52 of 100
- **Stats:** health 170, speed 70, armor 4, magic resist 0, sight 60
- **How to use it:** The axe cleaves a second enemy: send it where enemies bunch up.

Abilities:

1. **axe_attack** (primary): 32 damage, cleaves 1 more; reach 13; charges in 12.5 s; 18 points
2. **battle_fury** (buff): buff for 12 s; reach 20; charges in 25 s; 21 points

### Crossbowman

Slow, heavy, accurate bolts.

- **Body:** ranged; **archetype:** ranged damage
- **Points:** 72 of 100
- **Stats:** health 80, speed 45, armor 0, magic resist 0, sight 80
- **How to use it:** Out-ranges the other archers; bolts pierce some armor.

Abilities:

1. **crossbow_attack** (primary): 28 damage, projectile; reach 34; charges in 14.3 s; 12 points
2. **piercing_shot** (damage): 35 damage, pierces 3, projectile; reach 40; charges in 12.5 s; 50 points

### Field Medic

Emergency heals for allies near death.

- **Body:** support; **archetype:** support
- **Points:** 71 of 100
- **Stats:** health 60, speed 50, armor 0, magic resist 5, sight 70
- **How to use it:** Its big heal waits for an ally below 30%; it saves units rather than topping them up.

Abilities:

1. **primary_melee_attack** (primary): 25 damage; reach 15; charges in 10 s; 10 points
2. **emergency_heal** (heal): 50 healing; reach 30; charges in 12.5 s; 35 points; cooldown 5 s
3. **regeneration** (heal): 10 healing; reach 25; charges in 20 s; 26 points; cooldown 4 s

### Storm Caller

Static fields that slow and burn; curses that weaken.

- **Body:** special; **archetype:** crowd control
- **Points:** 96 of 100
- **Stats:** health 100, speed 70, armor 0, magic resist 0, sight 70
- **How to use it:** Lay a field where enemies must walk; slowed enemies stay in it longer.

Abilities:

1. **primary_ranged_attack** (primary): 20 damage, projectile; reach 30; charges in 10 s; 11 points
2. **static_field** (area): 8 damage in a 30 radius, leaves a zone for 6 s; reach 40; charges in 25 s; 58 points; cooldown 8 s
3. **weakness_curse** (debuff): debuff for 8 s; reach 30; charges in 25 s; 17 points

## Advanced

Three abilities that work together.

### Heavy Knight

Armored axe-bearer that cracks armor and wards its line.

- **Body:** tank; **archetype:** tank
- **Points:** 86 of 100
- **Stats:** health 240, speed 30, armor 10, magic resist 0, sight 50
- **How to use it:** Lead with it: it takes the first blows, sunders the toughest enemy and wards those behind.

Abilities:

1. **axe_attack** (primary): 32 damage, cleaves 1 more; reach 13; charges in 12.5 s; 18 points
2. **sunder_armor** (debuff): debuff for 8 s; reach 20; charges in 20 s; 18 points
3. **protective_ward** (buff): buff for 15 s; reach 30; charges in 25 s; 28 points

### Sniper

Long sight and heavy bolts; focus shortens its cooldowns.

- **Body:** ranged; **archetype:** ranged damage
- **Points:** 96 of 100
- **Stats:** health 80, speed 45, armor 0, magic resist 0, sight 150
- **How to use it:** Give it a guard: it is slow, frail and deadly once set.

Abilities:

1. **crossbow_attack** (primary): 28 damage, projectile; reach 34; charges in 14.3 s; 12 points
2. **piercing_shot** (damage): 35 damage, pierces 3, projectile; reach 40; charges in 12.5 s; 50 points
3. **focus** (buff): buff for 10 s; reach 50; charges in 33.3 s; 20 points

### Battle Cleric

Fights in the line, saves those beside it and cleanses their debuffs.

- **Body:** support; **archetype:** hybrid
- **Points:** 62 of 100
- **Stats:** health 100, speed 50, armor 4, magic resist 5, sight 70
- **How to use it:** A healer that can stand at the front: armor and health let it stay near the wounded.

Abilities:

1. **primary_melee_attack** (primary): 25 damage; reach 15; charges in 10 s; 10 points
2. **emergency_heal** (heal): 50 healing; reach 30; charges in 12.5 s; 35 points; cooldown 5 s
3. **purifying_touch** (heal): 15 healing; reach 20; charges in 20 s; 7 points

## Specialist

One trick, done well.

### Assassin

Quick dagger, poison and a crippling blow.

- **Body:** special; **archetype:** damage
- **Points:** 53 of 100
- **Stats:** health 100, speed 85, armor 0, magic resist 0, sight 70
- **How to use it:** Fast enough to reach the back line; crippled targets can't run.

Abilities:

1. **dagger_attack** (primary): 18 damage; reach 12; charges in 7.1 s; 12 points
2. **poison_dart** (damage): 8 damage, projectile; reach 30; charges in 14.3 s; 19 points
3. **crippling_blow** (debuff): debuff for 4 s; reach 15; charges in 20 s; 9 points

### Frost Mage

Slows everything: a slowing field, and a crippling blow up close.

- **Body:** special; **archetype:** crowd control
- **Points:** 88 of 100
- **Stats:** health 100, speed 70, armor 0, magic resist 0, sight 70
- **How to use it:** Hold the enemy where your archers can reach them.

Abilities:

1. **primary_ranged_attack** (primary): 20 damage, projectile; reach 30; charges in 10 s; 11 points
2. **static_field** (area): 8 damage in a 30 radius, leaves a zone for 6 s; reach 40; charges in 25 s; 58 points; cooldown 8 s
3. **crippling_blow** (debuff): debuff for 4 s; reach 15; charges in 20 s; 9 points

### Spearman

Long reach; the spear runs through to the enemy behind.

- **Body:** melee; **archetype:** damage
- **Points:** 53 of 100
- **Stats:** health 180, speed 70, armor 10, magic resist 4, sight 60
- **How to use it:** Strikes from second rank: put it just behind another melee unit.

Abilities:

1. **spear_attack** (primary): 22 damage, cleaves 1 more; reach 20; charges in 10 s; 15 points
2. **crippling_blow** (debuff): debuff for 4 s; reach 15; charges in 20 s; 9 points

## Experimental

Stats pushed to an edge on purpose. These draw warnings by design.

### Glass Cannon

Huge blows, almost no health.

- **Body:** ranged; **archetype:** glass cannon
- **Points:** 62 of 100
- **Stats:** health 50, speed 45, armor 0, magic resist 0, sight 80
- **How to use it:** Hits hardest of all for its points, and dies to anything that reaches it.

Abilities:

1. **javelin_attack** (primary): 30 damage, projectile; reach 20; charges in 12.5 s; 10 points
2. **power_strike** (damage): 45 damage; reach 15; charges in 12.5 s; 42 points

Warnings (on purpose): health 50 is very low (usual range 60-300).

### Fortress

Nearly unkillable, nearly harmless.

- **Body:** tank; **archetype:** tank
- **Points:** 95 of 100
- **Stats:** health 380, speed 30, armor 24, magic resist 0, sight 50
- **How to use it:** Blocks a lane for a long time; something else must do the killing.

Abilities:

1. **primary_melee_attack** (primary): 25 damage; reach 15; charges in 10 s; 10 points
2. **protective_ward** (buff): buff for 15 s; reach 30; charges in 25 s; 28 points

Warnings (on purpose): armor 24 is very high (usual range 0-20); health 380 is very high (usual range 60-300).

### Scout

The fastest unit with the longest sight.

- **Body:** special; **archetype:** speed
- **Points:** 55 of 100
- **Stats:** health 100, speed 120, armor 0, magic resist 0, sight 170
- **How to use it:** Gets anywhere first; good for harassing, weak in a straight fight.

Abilities:

1. **sling_attack** (primary): 16 damage, projectile; reach 24; charges in 7.7 s; 10 points
2. **focus** (buff): buff for 10 s; reach 50; charges in 33.3 s; 20 points

Warnings (on purpose): detection_range 170 is very high (usual range 40-150); speed 120 is very high (usual range 20-100).

## Showcase

Everything at once: four abilities on one unit.

### Versatile Fighter

A little of everything: a hard hit, a slow and a rallying buff.

- **Body:** melee; **archetype:** hybrid
- **Points:** 82 of 100
- **Stats:** health 120, speed 60, armor 0, magic resist 0, sight 60
- **How to use it:** Shows every part of a template at once; a sound pick when unsure.

Abilities:

1. **primary_melee_attack** (primary): 25 damage; reach 15; charges in 10 s; 10 points
2. **power_strike** (damage): 45 damage; reach 15; charges in 12.5 s; 42 points
3. **crippling_blow** (debuff): debuff for 4 s; reach 15; charges in 20 s; 9 points
4. **battle_fury** (buff): buff for 12 s; reach 20; charges in 25 s; 21 points
