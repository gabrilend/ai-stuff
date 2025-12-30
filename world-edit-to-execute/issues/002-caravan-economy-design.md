# Issue 002: Caravan Economy Design

**Phase:** None (Long-term Research)
**Type:** Design Research
**Priority:** High
**Parent:** 000-warlord-mode-design-compendium.md

---

## Purpose

Deep exploration of the resource distribution system via caravans. This document focuses on the mathematics, edge cases, and emergent economic behaviors.

---

## The 5% Rule

### Core Mechanic

```
Caravan Arrival (receiving):
- For each connected hub in range
- Receive 5% of that hub's resources
- That hub loses 5% of its resources

Caravan Departure (sending):
- Sum the 5% threshold from all faction hubs
- Must meet threshold for ALL held resources
- Send that amount, retain remainder
```

### Mathematical Properties

```
With even distribution:
- Resources flow toward deficit areas
- Surplus areas export more
- System tends toward equilibrium

With uneven distribution:
- Rare resources "stick" where they land
- Hubs specialize over time
- Trade routes become strategic
```

---

## Threshold Calculation

### Faction-Wide Thresholds

```
Faction totals determine what 5% means:

Example - Horde Resources:
- Wood: 1000 total → threshold 50
- Iron: 500 total → threshold 25
- Crystals: 100 total → threshold 5

Hub must have ALL thresholds to send:
- Has 60 Wood, 30 Iron, 3 Crystals
- Wood: ✓ (60 ≥ 50)
- Iron: ✓ (30 ≥ 25)
- Crystals: ✗ (3 < 5)
- Result: Caravan HELD
```

### Rounding Rules

```
Always round UP for thresholds:
- 5% of 17 = 0.85 → threshold = 1
- Ensures even tiny amounts eventually move
- Prevents permanent stuck resources
```

---

## Caravan Mechanics

### Travel Time

```
Caravans are not instant:
- Travel time based on distance
- Route follows roads/paths
- Dangerous territory = longer route

Example times:
- Adjacent hubs: 5 minutes
- Cross-zone: 15 minutes
- Cross-continent: 1 hour
```

### Vulnerability

```
Caravans can be raided:
- Visible on world map while traveling
- Protected by escort NPCs
- Resources captured go to raiders

Escort strength based on:
- Value of cargo (more = stronger)
- Faction military strength
- Available soldiers at origin
```

### Interception Gameplay

```
Raider perspective:
1. Scout enemy trade routes
2. Identify high-value caravans
3. Assemble warband
4. Intercept at chokepoint
5. Defeat escort, capture goods

Defender perspective:
1. Monitor caravan departures
2. Assign player escorts (optional)
3. Vary routes to avoid predictability
4. Fortify chokepoints
```

---

## Hub Specialization

### Emergent Behavior

```
Over time, hubs accumulate what they receive:

Hub A produces: Copper, Grain
Hub A receives: Iron (from Hub B), Herbs (from Hub C)

Hub A accumulates:
- Lots of Copper, Grain (produced locally)
- Some Iron, Herbs (received via caravan)
- Trace amounts of rare resources

If Hub A is efficient at processing Iron:
- Iron "sticks" less (gets used)
- Copper/Grain "stick" more (surplus)
- Hub A becomes known for metalwork
```

### Strategic Implications

```
Control hubs based on specialty:
- Copper hub → essential for engineering
- Crystal hub → essential for magic items
- Grain hub → essential for feeding armies

Losing a specialized hub = faction-wide impact
```

---

## Economic States

### Healthy Economy

```
Indicators:
- Regular caravan flow
- All hubs meet thresholds
- Surplus in most resources
- Crafting unrestricted

Player experience:
- Contribute anywhere, impact everywhere
- Professions feel meaningful
- New players can help immediately
```

### Stressed Economy

```
Indicators:
- Some resources scarce
- Caravans delayed (threshold not met)
- Prioritization decisions required
- Crafting limited by materials

Player experience:
- Gathering becomes critical
- Scouts search for new deposits
- Warlords pushed to capture territories
```

### Wartime Economy

```
Indicators:
- Resources consumed immediately
- No surplus, no reserves
- Caravans raided frequently
- Production can't keep up

Player experience:
- Every contribution matters desperately
- Adventurer rewards increased
- Defensive play encouraged
- Territory loss = catastrophic
```

---

## Trade Routes

### Automatic Routing

```
Caravans automatically route:
1. Find all connected hubs
2. Calculate shortest safe path
3. If no safe path, wait or risk dangerous route

Connected means:
- Within trading range (configurable)
- Path exists through controlled territory
- Not blocked by enemy occupation
```

### Route Manipulation

```
Strategic options:
- Capture territory to create shortcuts
- Cut enemy routes by holding chokepoints
- Build roads/paths to reduce travel time
- Fortify vulnerable route segments
```

### Isolated Hubs

```
If hub loses all connections:
- No caravans in or out
- Resources accumulate locally
- Cannot contribute to faction
- Urgent priority to reconnect

Siege tactic:
- Surround hub without capturing
- Let them accumulate resources
- Capture when stockpile is rich
```

---

## Quartermaster Interface

### Player View

```
Quartermaster shows:
┌─────────────────────────────────────┐
│ FACTION RESOURCES                   │
├─────────────────────────────────────┤
│ Wood:    1,247 (threshold: 62)      │
│ Iron:      483 (threshold: 24)      │
│ Crystal:    89 (threshold: 5)       │
│ Food:     892 (threshold: 45)       │
├─────────────────────────────────────┤
│ THIS HUB                            │
├─────────────────────────────────────┤
│ Wood:       78 ✓ ready              │
│ Iron:       31 ✓ ready              │
│ Crystal:     3 ✗ need 2 more        │
│ Food:       52 ✓ ready              │
├─────────────────────────────────────┤
│ CARAVAN STATUS: Waiting on Crystal  │
│ Next departure: when threshold met  │
└─────────────────────────────────────┘
```

### Strategic Information

```
Quartermaster also reveals:
- Incoming caravans (ETA, cargo)
- Outgoing caravans (destination, cargo)
- Recent raids (losses)
- Production rates (local gathering)

This information may be valuable to enemies...
Spies in opposing faction could report it
```

---

## Edge Cases

### New Hub Captured

```
When faction captures new territory:
- Hub starts with 0 resources
- Must wait for caravans to arrive
- Or players must transport manually
- Vulnerable period until established
```

### Resource Depletion

```
If resource completely exhausted faction-wide:
- Threshold becomes 0
- Any amount qualifies for sending
- Rapid distribution of scraps
- Signals critical shortage
```

### Caravan Spam Prevention

```
Minimum caravan interval:
- Hub can only send one caravan per X minutes
- Prevents rapid small shipments
- Encourages accumulation

Bundling:
- Wait until meaningful cargo
- One big caravan vs many small
- Easier to escort, easier to raid
```

---

## Open Questions

1. Can players manually move resources (inventory carry)?
2. Should caravans be visible to enemy faction?
3. What happens to resources in destroyed caravans?
4. Can neutral hubs (goblin ports) act as intermediaries?
5. Should there be a "market" where factions can trade?

---

## Revision History

| Date | Change |
|------|--------|
| 2025-12-30 | Initial document |
