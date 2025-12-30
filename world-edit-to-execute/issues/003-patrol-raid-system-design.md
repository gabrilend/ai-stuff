# Issue 003: Patrol and Raid System Design

**Phase:** None (Long-term Research)
**Type:** Design Research
**Priority:** High
**Parent:** 000-warlord-mode-design-compendium.md

---

## Purpose

Deep exploration of the automated patrol and player-directed raid systems. This document focuses on AI behavior, trigger conditions, and strategic implications.

---

## Patrols: Automated Defense

### Trigger Conditions

```
Patrol departs when hub has:
- Minimum soldier count (e.g., 10)
- Minimum equipment per soldier
- Patrol not already active from this hub

Patrol frequency:
- Check conditions every N minutes
- If met, patrol assembles and departs
- If patrol returns, reset timer
```

### Patrol Composition

```
Based on available resources:

Heavy patrol (lots of equipment):
- Fewer soldiers, better armed
- Slow, powerful, hard to kill
- Covers less ground

Light patrol (lots of soldiers):
- More soldiers, basic arms
- Fast, wide coverage
- Vulnerable to ambush

Mixed patrol (balanced):
- Moderate numbers and gear
- Standard capability
- Most common outcome
```

### Patrol Behavior

```
Movement pattern:
1. Depart hub in random direction
2. Spiral outward through friendly territory
3. Check for enemies at each waypoint
4. If enemies found: engage
5. If victorious: loot and continue
6. If damaged: return home
7. After X waypoints: return home regardless

Vision range:
- Detect enemies within patrol vision
- Larger patrols have more vision (more eyes)
- Stealth units may evade detection
```

### Patrol Combat

```
When patrol engages:
- AI controls patrol units
- Uses standard combat system
- Parry/hit rhythm applies
- Abilities used semi-randomly

Outcome:
- Victory: collect loot, continue or return
- Defeat: units lost, equipment drops
- Retreat: patrol limps home with survivors
```

### Return and Restock

```
Patrol returns with:
- Surviving soldiers
- Collected loot (enemy equipment)
- Enemy intel (scouting info)

Loot deposited:
- Equipment goes to hub stockpile
- Feeds next patrol or raid
- May trigger threshold for caravan
```

---

## Raids: Targeted Offense

### Trigger Conditions

```
Raid becomes available when:
- Sufficient soldiers (higher than patrol)
- Sufficient equipment (higher than patrol)
- Warlord designates target
- No raid currently active from hub
```

### Target Designation

```
Warlord specifies:
- Target location (enemy hub, resource node, caravan)
- Raid type (capture, destroy, steal)
- Troop allocation (how many soldiers)

System calculates:
- Estimated success chance
- Expected losses
- Travel time
- Return time
```

### Raid Composition

```
Raids are larger than patrols:

Assault raid (capture territory):
- Maximum soldiers
- Heavy equipment
- Siege capabilities
- Slowest, most powerful

Strike raid (destroy/disrupt):
- Medium soldiers
- Mixed equipment
- Speed priority
- Hit and run

Steal raid (capture resources):
- Minimum soldiers
- Light equipment
- Maximum speed
- Caravan interception
```

### Raid Behavior

```
Movement:
1. March directly toward target
2. May engage enemies en route (optional)
3. Arrive at target
4. Execute raid type objectives
5. If successful: occupy or return
6. If failed: retreat with survivors

En route options:
- Engage all (aggressive, slow, risky)
- Engage none (stealthy, fast, may be intercepted)
- Engage threats (balanced, AI judgment)
```

### Raid Outcomes

```
Capture raid success:
- Territory changes faction control
- Hub becomes operational for new faction
- Defenders killed or flee
- Raid becomes garrison

Capture raid failure:
- Raid repelled
- Soldiers lost
- Equipment scattered (some recoverable)
- Target hub alerted

Destroy raid success:
- Target structures damaged/destroyed
- Production halted temporarily
- Demoralization effect on defenders

Steal raid success:
- Resources captured
- Caravan equivalent created
- Raid returns home with loot
```

---

## Day/Night Cycle

### Faction Timing

```
Orcs raid during day:
- "Brave and strong"
- Maximum visibility
- No stealth bonuses
- Honorable combat

Night Elves raid during night:
- Ultravision advantage
- Stealth bonuses
- Reduced enemy vision
- Ambush opportunities
```

### Compressed Time

```
Server time:
- 1 server day = ~2 hours IRL
- Day/night each = ~1 hour
- Raid window approximately once per hour

Implications:
- Players can experience full cycles in one session
- Predictable windows for offense/defense
- Can plan around faction raid times
```

### Twilight Periods

```
Dawn and dusk:
- 5-10 minute transition periods
- Neither faction has advantage
- Both patrols may be active
- Increased encounter chance
```

---

## Quest Hub Creation

### Successful Raid → Quest Hub

```
When raid captures location:
1. Raid soldiers become garrison
2. Temporary structures erected
3. Quest hub activated
4. Daily objectives generated
5. Vendors/NPCs spawned

Hub provides:
- Forward operating base
- Resource gathering point
- Player spawn location
- Faction presence in area
```

### Daily Objective Generation

```
Objectives based on surroundings:

"Murlocs south have clam farm"
→ Kill murlocs → unlock pearl vendor

"Scout reports kodo migration"
→ Hunt kodos → unlock leather supply

"Cave system has tin golems"
→ Clear cave → unlock mining node

Completion:
- Unlocks content for ALL players
- Limited stock until refilled
- Creates organic activity loops
```

### Hub Vulnerability

```
New hubs are fragile:
- Low garrison (raid survivors)
- Basic fortifications
- Limited supplies
- Counter-raid likely

Reinforcement:
- Send additional soldiers
- Transport supplies
- Build fortifications
- Establish patrols from new hub
```

---

## Player Interaction

### Warlord Role

```
Warlords can:
- Designate raid targets
- Adjust patrol priorities
- Redirect active patrols
- Reinforce active raids
- Order retreats

Warlords cannot:
- Control individual patrol units
- Guarantee outcomes
- Override other warlords (conflict resolution TBD)
```

### Grunt/Peasant Role

```
Players as units can:
- Volunteer for patrol duty
- Join raid parties
- Scout ahead of patrols
- Reinforce active engagements

Benefits:
- Better loot (was there, gets share)
- Reputation/prestige
- Influence over outcomes
- Direct combat experience
```

### Hero Role

```
Heroes can:
- Lead patrols (improved AI)
- Spearhead raids (bonus to success)
- Turn tide of battle
- Execute special objectives

Risks:
- Heroes can die
- Death = respawn delay, prestige loss
- Heroic death defending hub = prestige gain
```

---

## AI Behavior

### Patrol AI

```
Priority list:
1. Avoid suicide (retreat if outmatched)
2. Engage enemies of opportunity
3. Complete patrol route
4. Return with loot

Combat AI:
- Focus weakest enemy (efficiency)
- Use abilities semi-randomly
- Retreat at 30% strength
- Protect wounded allies
```

### Raid AI

```
Priority list:
1. Reach target
2. Complete objective
3. Minimize losses
4. Return home

Combat AI:
- Focus objective targets (buildings, leaders)
- Ignore distractions unless threatened
- Commit fully (no early retreat)
- Fight to last if objective near complete
```

### Garrison AI

```
Priority list:
1. Defend hub
2. Protect resources
3. Alert allies
4. Delay enemies until reinforcements

Combat AI:
- Hold defensive positions
- Focus attackers on structures
- Retreat to inner defenses if outer falls
- Never abandon hub
```

---

## Open Questions

1. How do warlords resolve conflicting orders?
2. Can patrols from different hubs coordinate?
3. What happens to patrol during server downtime?
4. Can raids be cancelled mid-march?
5. How do heroes affect patrol/raid success rates?

---

## Revision History

| Date | Change |
|------|--------|
| 2025-12-30 | Initial document |
