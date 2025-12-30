# Issue 000: Warlord Mode Design Compendium

**Phase:** None (Long-term Research)
**Type:** Design Research / Pondering Document
**Priority:** Foundational
**Status:** Living Document

---

## Purpose

This document serves as a compendium of considerations for the "Warlord Mode" concept - a hybrid gameplay mode that merges WoW's world geography with WC3's command-and-control RTS mechanics. Unlike implementation issues, this file captures ongoing research, design tensions, open questions, and evolving ideas.

**Prior Art:** `/home/ritz/notes/wow-server` - Detailed design for a focused WoW server with patrol/raid systems, gem-based progression, and communal faction gameplay. Many ideas here originated from that document.

---

## Core Concept

The WoW world map becomes a strategic overview. Players click to zoom their view to any location, arriving as a WC3-style warlord who can command allied units in that territory. The experience shifts fluidly between:

1. **Strategic Layer** - World map overview, territory control, resource flows
2. **Tactical Layer** - RTS-style unit command at specific locations
3. **Hero Layer** - Direct control of a powerful hero unit (optional)

---

## The Warlord's Perspective

### Commanding Allied Units

When a warlord zooms to a location, they see all allied units in that territory. They can:

- Issue move/attack/hold orders to any allied unit
- Coordinate multiple players' units in combined operations
- See fog of war based on collective allied vision

**Open Question:** How do we handle command authority when multiple warlords are present?
- Shared command (anyone can order any unit)?
- Owner priority (unit owner's orders override)?
- Delegation system (owner grants command to specific warlords)?

### Hero Selection

Players may choose to embody a powerful hero unit for direct guidance. This is appropriate for:

- Difficult boss encounters
- Raid formations
- Dungeon party coordination
- Warbands raiding enemy territory

**Consideration:** When controlling a hero, are you still a warlord? Or does your perspective narrow to that hero's immediate surroundings? Perhaps a toggle between "hero view" and "commander view"?

---

## The Anti-Quest Philosophy

### No Quests

Traditional quests are replaced entirely. No NPCs with exclamation marks. No "kill 10 boars" hand-holding.

### Auto-Generated Dailies

Instead, dailies emerge organically from territory control:

```
[Territory: Westfall]
[Controlled by: Alliance]
[Control Duration: 3 days]

Auto-Generated Objectives:
- Maintain garrison above 50 units
- Harvest 200 grain (local resource)
- Repel any Horde incursions
- Keep trade routes open to Stormwind

Rewards scale with control duration.
```

The longer you hold territory, the better the rewards - but also the more attractive it becomes as a target.

**Design Tension:** How to prevent stagnation? If one faction dominates, what motivates continued play?

Possible solutions:
- Diminishing returns on long-held territory
- "Corruption" or "unrest" mechanics that spawn internal threats
- Resource depletion over time, forcing expansion
- Seasonal resets of certain regions

---

## Resource Geography

### Why Copper in Newbie Valleys?

Nobody knows why resources spawn where they do. It's a mystery of the world. But the distribution creates natural gameplay:

```
Resource Distribution (Example):

Elwynn Forest     - Copper, Timber, Grain
Westfall          - Grain, Wool, Iron (trace)
Duskwood          - Timber, Herbs, Shadow Essence
Stranglethorn     - Exotic Timber, Gold, Gems
Burning Steppes   - Iron, Coal, Adamantium
Silithus          - Crystals, Chitin, Ancient Artifacts
```

**Principle:** Every resource is needed. Copper isn't "low level" - it's a specific material with specific uses. The newbie valley produces it because that's where the copper is, not because it's "appropriate" for new players.

### Resource Hierarchy (Not Power Hierarchy)

```
Common:     Copper, Timber, Grain, Wool
Uncommon:   Iron, Herbs, Coal, Leather
Rare:       Gold, Gems, Exotic Timber, Shadow Essence
Epic:       Adamantium, Crystals, Ancient Artifacts, Dragon Scale
Legendary:  ???, ???, ???

Each tier isn't "better" - it's "different application."
Copper is still needed for advanced engineering.
Grain is still needed to feed armies.
```

---

## The Caravan Economy

### Core Mechanic

Resources flow between faction hubs via caravans. This creates:

1. **Passive distribution** - Surplus spreads, scarcity concentrates
2. **Vulnerability** - Caravans can be raided
3. **Strategic depth** - Controlling trade routes matters

### The 5% Rule

When a caravan arrives at a hub:
```
For each connected hub in trading range:
    Receive: 5% of that hub's resources
    That hub loses: 5% of its resources
```

When a caravan departs from a hub:
```
Sum the 5% qualification from all connected hubs
Send: That total in resources
```

### Worked Example

```
Faction: Horde
Total Faction Resources:
- Wood: 1000 units
- Crystals: 250 units
- Iron: 500 units

Hub A (Orgrimmar) qualifies to send when it has:
- Wood: 50 (5% of 1000)
- Crystals: 13 (5% of 250, rounded up)
- Iron: 25 (5% of 500)

If Orgrimmar has 60 Wood, 15 Crystals, 30 Iron:
→ Caravan departs with: 50 Wood, 13 Crystals, 25 Iron
→ Orgrimmar retains: 10 Wood, 2 Crystals, 5 Iron
```

### Rare Resource Accumulation

A hub won't send caravans until it meets the threshold for ALL resources it holds:

```
Hub B (Thunder Bluff) has:
- Leather: 100 (threshold: 25) ✓
- Exotic Herbs: 2 (threshold: 5) ✗

Caravan HELD - waiting for 3 more Exotic Herbs
```

This creates interesting dynamics:
- Rare resources "stick" in places that receive them
- Hubs become specialized over time
- Strategic value in holding rare-resource territories

### Healthy vs Wartime Economy

**Healthy Economy:**
```
- Resources distributed evenly
- All hubs productive
- Anyone can contribute anywhere
- Caravans flow regularly
- Surplus enables experimentation
```

**Wartime Economy:**
```
- Resources consumed as fast as produced
- Deficit in critical materials
- Incentives shift:
  → Adventurers rewarded for gathering
  → Scouts valued for finding deposits
  → Warlords pushed to claim resource territories
```

**Design Consideration:** The game should naturally oscillate between these states. Peace breeds complacency, which enables aggression, which creates war, which depletes resources, which forces peace/recovery.

---

## Patrols and Raids (From Prior Design)

### Defensive Patrols

Automated NPC groups that rotate around faction territory searching for enemies:

```
Patrol Behavior:
1. Depart from hub when supplies/equipment sufficient
2. Spiral outward through friendly territory
3. Engage any enemies encountered
4. If survive, return with loot for next patrol
5. Cycle repeats automatically
```

This creates passive territorial defense without player micromanagement.

### Offensive Raids

Targeted maneuvers into enemy territory, less automatic than patrols:

```
Raid Behavior:
1. Require threshold of equipment + soldiers
2. Directed at designated target location
3. If successful, establish camp as new quest hub
4. New hub unlocks content (vendors, daily objectives)
5. Hub vulnerable to counter-raids
```

**Strategic Layer:** The quartermaster shows what resources the faction has. When thresholds are met, things happen automatically. The composition of the next raid depends on what's been stockpiled - heavy on weapons means armored assault, heavy on food means larger force.

### Timing

```
Orcs raid during the day   → Brave and strong
Night Elves raid at night  → Ultravision, stealth

Server time compressed: 1 day = ~2 hours IRL
Raids approximately once per hour
```

This creates predictable windows for offense/defense preparation.

---

## Combat System (From Prior Design)

### Rhythmic Parry Mechanic

```
Base parry chance: 95%
Each parry: -5% parry chance
Each hit taken: parry chance goes halfway back to 95%

Attack speed standardized: 2.00 seconds
```

This creates a melee tempo - you parry, parry, parry, then get hit, recover, repeat. Combat becomes rhythmic rather than button-mashing.

### Next-Swing Abilities

Most abilities modify your next weapon swing rather than being instant:

```
Examples:
- Next strike deals 130% damage
- Next strike hits 2 additional targets for 20%
- Next strike has 100% hit but increases their parry by 10%
- Next strike doubles cast speed on your next spell
- Next strike grants 1.50s attack cooldown (tempo break)
```

This keeps combat predictable and readable for RTS-style observation.

---

## Gem-Based Progression (From Prior Design)

### No Gear Treadmill

Everyone wears faction uniform (army has uniforms). Progression comes from gem customization, not better armor drops.

```
Equipment: Standard faction gear with sockets
Progression: Gems inserted into sockets
Customization: Build defines playstyle, not power level
```

### Gem Examples (Combat)

```
Defensive:
- Every 5 seconds, gain 10 HP damage shield
- Gain 4 HP per 5 seconds
- Increase baseline parry by 5%

Offensive:
- Every 3 hits deal 12 extra fire damage
- Deal 5 fire damage on each melee attack
- Reduce opponent's parry by extra 1% per hit

Utility:
- 30% move speed for 5s when hit below 30% HP
- Increase move + attack speed by 5%
- Every 16 seconds deal 40 cold damage to random nearby enemy
```

### Legendary Item Ideas

```
Berserker's Tempo (Weapon)
- On successful hit: Attack speed increased by 10%
- On target parry/dodge: Attack speed halved
- Stacks up to 5 times (max +50% speed)
```

**Interaction with Parry System:**

Remember the parry flow:
```
Parry (successful defense): Defender loses 5% parry chance
Hit (successful attack):    Defender recovers halfway to 95%
```

So when you HIT someone:
- You gain attack speed (tempo builds)
- But they recover parry (harder to hit next time)
- They "learned" from that blow - maximum attention in mortal combat

When they PARRY you:
- You lose attack speed (momentum broken)
- Their parry drops 5% (spent defensive effort)
- You "learned" how to better get through their defenses

**Design implications:**

```
Guaranteed-hit abilities:
- GOOD: Maintains your tempo streak
- COST: Gives enemy parry recovery
- USE: When you notice momentum building, force hits to keep it

Heals:
- Now have offensive value
- Healing a low-parry ally = restoring their defense ceiling
- "Removing from the bottom of the percentage"

The dance:
- Berserker builds speed with each hit
- But each hit makes the NEXT hit harder
- Eventually they parry, momentum shatters
- Both fighters learn, reset, begin again
```

**Tactical implications:**

```
Warlord perspective:
- Watch for units with "hot" attack speed
- Know when berserker is due to bounce off

Hero perspective:
- Press when momentum is building
- Guaranteed-hits to extend streaks
- Know when to back off after a parry

Team play:
- Healers restore defensive ceilings
- Support strips parry so berserker can start fresh
- Rotation of attackers to exploit low-parry windows
```

### Gem Examples (Crafting)

```
Production:
- Every 3rd weapon crafted has random lightning enchant
- Every 7th lightning enchant creates random yellow gem
- Weapons you forge deal extra 5 damage
- Armor you create has extra 25 armor

Support:
- Summoned elementals cost 1 fewer gemstone (min 1)
- Every 3rd elemental has extra support drone
- Conjure extra strawberry each cast
- Gain extra inventory slot
```

---

## Class Design (From Prior Design)

### Four Classes, Two Per Faction

```
Horde:
- Grunt (warrior, gathering-focused)
- Shaman (caster, production-focused)

Alliance:
- Huntress (warrior, gathering-focused)
- Druid (caster, production-focused)
```

### Elemental Themes

```
Horde magic: Storm, Earth, Fire
Night Elf magic: Leaf, Cold, Star
```

### Caster Combat

Offensive spells use "target ground" with thin cone attacks:

```
mage         targeting     spell fires
 #     X        O      →   #-----X      O
     enemy    reticle       (hits first enemy in cone)
```

Support abilities are auras - passive or untargeted active effects.

---

## Quartermaster Economy (From Prior Design)

### Resource Exchange Table

```
Food → Soldiers (recruiting)
Food → Gold (caravan export)

Gold → Mercenaries (Quilboar / Furbolg)
Gold → Ores (caravan import)

Equipment → Armed soldiers ("activated" warriors)
Equipment → Sold for gold

Ores → Forged into equipment
Ores → Prospected into gemstones

Gemstones → Cut into gems
Gemstones → Crushed into arcane dust
Gemstones → Contain elemental souls (summoned soldiers)

Arcane Dust → Enchantments
Arcane Dust → Conjure berries (food)

Misc trade goods → Sold for gold (quest rewards)
```

### Communal Storage

**Critical Philosophy:** Gold is stored with the faction, not the player.

```
Player contributes copper ore
→ Faction gains copper ore

Player does not:
- Have personal bank
- Hoard resources
- Profit individually

Player feels:
- Part of cohesive whole
- Cog in a machine
- Contributor to something larger
```

This is the core lesson the design wants to teach.

---

## Quest Hub Capture (From Prior Design)

### Raid Success Creates Content

When a raid captures an enemy location, it becomes a quest hub:

```
Captured Location: Wailing Caverns entrance

New Daily Objectives:
- "Murlocs south have a clam farm. Harvest pearls."
  → Complete: Unlocks pearl vendor for ALL players
  → Vendor has limited stock until someone farms more

- "Scout reports kodo migration east."
  → Complete: Unlocks leather supply for faction

- "Cave system here has tin golems."
  → Complete: Unlocks mining node access
```

**Dynamic Content:** What's available depends on what players do. Want more pearls? Someone has to kill murlocs.

### Cave Bosses

Mines and caves contain material golems (copper, tin, iron based on region):

```
Golem Properties:
- Tough as raid boss
- Rewards profession materials
- Only drops basic ores (not gems)
- Creates destination for coordinated groups
```

---

## The Grunt's Life

### Playing as a Basic Unit

Not everyone plays as a warlord or hero. Some players embody basic units:

- **Grunts/Footmen** - Combat role, follow orders, defend territory
- **Peons/Peasants** - Profession role, gather/craft, build structures

### Profession Gameplay Loop

```
As a Peasant in Elwynn:

1. Gather copper ore from the mine
2. Smelt into copper bars at the forge
3. Craft copper fittings for construction
4. Contribute to hub's resource pool
5. When hub qualifies, your work spreads faction-wide

No XP. No levels. Just contribution.
Get bored? Walk to another territory.
```

### The "Enough Materials" Gate

If a location hasn't gathered enough materials:
- Construction projects stall
- Military production slows
- Adventurers can't be equipped

This creates organic demand for profession players. "We need more iron in Westfall" isn't a quest - it's a reality that affects everyone.

---

## Territory Conflict

### Raid Mechanics

Warbands can raid enemy territory for real rewards:

```
Raid on Alliance-held Westfall:

Objectives:
- Burn grain stores (reduce food supply)
- Capture caravan (steal resources in transit)
- Kill garrison units (weaken defenses)
- Claim territory (if garrison eliminated)

Rewards:
- Captured resources go to raiders
- Successful raids weaken enemy economy
- Territory capture changes resource flow
```

### Defense Incentives

Defenders get:
- Reinforcement requests to allied warlords
- Bonus rewards for successful defense
- Fortification bonuses for prepared positions

---

## Open Questions

### Command & Control

1. How do multiple warlords coordinate without conflicting orders?
2. Should there be a "supreme commander" role for large operations?
3. How do we handle AFK warlords whose units are in danger?

### Economy Balance

1. What prevents one faction from permanently dominating?
2. How do we handle new players joining a losing faction?
3. Should there be "neutral" territories that neither faction can hold?

### Progression

1. Without levels, how do players feel a sense of growth?
2. Are heroes permanently more powerful, or situationally strong?
3. How do we reward long-term players without making them unbeatable?

### Technical

1. How many units can be rendered in a territory?
2. How do we handle latency for real-time RTS commands?
3. Can the WoW map data be accurately translated to RTS terrain?

---

## Design Principles (Emerging)

1. **Geography is destiny** - Where resources are matters. Territory matters.

2. **No artificial progression** - Power comes from coordination, not grinding.

3. **Everything has weight** - Copper matters. Grain matters. Every contribution counts.

4. **Organic objectives** - The game state creates goals, not quest designers.

5. **Scale fluidity** - Zoom from world map to individual unit seamlessly.

6. **Economic warfare** - Starving the enemy is as valid as fighting them.

7. **Role diversity** - Heroes, warlords, grunts, peasants - all needed, all valid.

---

## Related Considerations

### Dual-Interface Philosophy

This design aligns with the project's consideration-matching methodology. The WoW world provides geography and lore, while WC3 mechanics provide gameplay. Neither is subordinate - they combine into something new.

See: `docs/considerations/dual-interface-philosophy.md`

### Map Data Translation

The WoW map must be parseable into RTS-compatible terrain. Zones become territories. Geography affects movement and combat.

See: `issues/105-parse-war3map-w3e.md` (terrain parsing applicable here)

---

## The Prestige System (From Prior Design)

### Level Cap and Specialization

```
Starting level: 10
Level cap: 20
Progression: Specialization, not raw power

Best abilities at level 20 (incentive to level)
But lower levels still functional (can contribute)
```

### Prestige: Become a Guard

Instead of "retiring" a character, you can prestige them:

```
Prestige Effect:
- Character becomes permanent faction guard NPC
- Guards Crossroads (Horde) or Astranaar (Alliance)
- Forms elite cadre of player-created defenders
- Guards can die (then they're gone forever)
```

**Emotional Investment:** That guard you see was someone's character. The defense matters because players built it.

---

## Revision History

| Date | Change |
|------|--------|
| 2025-12-30 | Initial document creation |
| 2025-12-30 | Incorporated prior design from `/home/ritz/notes/wow-server` |
| 2025-12-30 | Added Berserker's Tempo legendary item with parry interaction analysis |
| 2025-12-30 | Added Vision/Fog of War, Zoom Interface, and Audio Design sections |
| 2025-12-30 | Created companion issue files (001-005) |

---

## Vision and Fog of War

### Multi-Scale Vision

How does fog of war work across the three layers?

```
Strategic Layer (World Map):
- See territories your faction controls
- See approximate enemy presence (many/few/none)
- No unit-level detail
- Updated periodically, not real-time

Tactical Layer (Territory View):
- Fog based on collective allied unit vision
- Real-time updates
- Can see enemy units in vision range
- Buildings provide persistent vision

Hero Layer (Direct Control):
- Your hero's personal vision range
- May have abilities that extend/share vision
- Stealth detection if applicable
```

### Scout Units

Dedicated vision-providers:

```
Scout Properties:
- High move speed, low combat power
- Extended vision range
- May have stealth detection
- Valuable for patrol interception warning

Strategic use:
- Place scouts at chokepoints
- Warn of incoming raids
- Track enemy caravan routes
```

---

## The Zoom Interface

### Click-to-Zoom Mechanic

From world map to tactical view:

```
1. Player views world map
2. Clicks on territory (e.g., Westfall)
3. Camera zooms into that territory
4. Transition: ~1 second smooth zoom
5. Arrive as warlord with command authority
```

### Transition States

```
World Map → Territory:
- Zoom through clouds/fog effect
- Load territory detail during transition
- Spawn warlord "presence" at territory center

Territory → World Map:
- Zoom out through same effect
- Orders persist (units continue executing)
- Can monitor multiple territories by flipping

Territory → Hero Control:
- Select hero unit
- "Possess" - camera snaps to hero
- Orders still available but perspective narrowed
```

### Multi-Territory Awareness

```
Warlord can:
- Have world map as minimap overlay
- See ping alerts from other territories
- Quick-jump to allied requests for help
- Split attention across active fronts
```

---

## Audio Design Considerations

### Rhythmic Combat Feedback

The 2.0s attack tempo should be audible:

```
Audio cues:
- Weapon swing: distinct sound at each attack
- Parry: metallic clang (successful defense)
- Hit: impact sound (flesh/armor depending on target)
- Tempo change: audio pitch shift when attack speed changes

Berserker's Tempo specifically:
- Rising pitch/intensity with each successful hit
- Discordant "clunk" on parry (momentum break)
- Players learn to "hear" the combat state
```

### Strategic Layer Audio

```
World map sounds:
- Distant drums for active battles
- Caravan bells for trade activity
- Warning horns for territory under attack
- Faction fanfare for territory capture
```

---

## Notes for Future Pondering

- What about sea control? Ships? Naval caravans?
- Flying units and air superiority - how does this affect terrain control?
- Dungeon instances - are they "territories" you can control?
- Player housing - personal base within faction territory?
- Mercenary system - hire neutral units for temporary help?
- Espionage - scouts, spies, information warfare?
- Weather/seasons affecting resource production?
- Ancient threats - dragons, old gods - as world events that force faction cooperation?
- Voice communication integration - warlords calling out orders?
- Spectator mode - watch battles without command authority?
- Replay system - review major battles for learning?

This document will grow. Questions are as valuable as answers.

---

## Companion Issue Files

This compendium is supported by focused research documents:

| Issue | Focus Area |
|-------|------------|
| 001-combat-system-design.md | Parry rhythm, tempo, legendary items |
| 002-caravan-economy-design.md | 5% rule, thresholds, trade routes |
| 003-patrol-raid-system-design.md | Automated defense, targeted offense |
| 004-warlord-interface-design.md | Zoom mechanic, command authority |
| 005-class-gem-system-design.md | Progression, specialization, crafting |
