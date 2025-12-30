# Issue 004: Warlord Interface Design

**Phase:** None (Long-term Research)
**Type:** Design Research
**Priority:** High
**Parent:** 000-warlord-mode-design-compendium.md

---

## Purpose

Deep exploration of the warlord command interface - how players zoom between strategic and tactical views, issue orders, and coordinate with other warlords.

---

## The Three Layers

### Strategic Layer (World Map)

```
View:
- Full Azeroth map (or focused region)
- Territory control overlay
- Resource flow indicators
- Active battle markers
- Caravan routes

Interactions:
- Click territory to zoom in
- Hover for territory info
- See faction-wide alerts
- Monitor multiple fronts
```

### Tactical Layer (Territory View)

```
View:
- WC3-style RTS perspective
- Individual units visible
- Terrain details
- Structures and resources
- Fog of war based on vision

Interactions:
- Select and command units
- Issue move/attack/hold orders
- Coordinate with allies
- Direct patrol/raid operations
```

### Hero Layer (Direct Control)

```
View:
- Third-person or isometric
- Focused on single hero
- Personal UI elements
- Ability bar

Interactions:
- WASD or click-to-move
- Ability usage
- Inventory management
- Can zoom out to tactical
```

---

## Zoom Transitions

### World → Territory

```
Trigger: Click on territory in world map

Transition:
1. Camera begins descent
2. Cloud/fog effect during zoom
3. Territory loads in background
4. Warlord "presence" spawns at center
5. Tactical UI appears
6. Ready for commands

Duration: ~1 second
```

### Territory → World

```
Trigger: Press designated key or click world map button

Transition:
1. Camera begins ascent
2. Tactical UI fades
3. Territory shrinks to map marker
4. World map UI appears
5. Warlord presence persists (orders continue)

Duration: ~0.5 seconds
```

### Tactical → Hero

```
Trigger: Select hero unit, press "possess" key

Transition:
1. Camera snaps to hero
2. Perspective shifts to hero-centered
3. Hero UI appears
4. Tactical commands still available (hotkey)

Duration: instant
```

### Hero → Tactical

```
Trigger: Press "release" key or designated hotkey

Transition:
1. Camera zooms out
2. Hero deselected (or remains selected)
3. Full tactical view restored
4. Hero continues last order

Duration: instant
```

---

## Command Authority

### Single Warlord

```
When alone in territory:
- Full command authority
- All allied units respond
- Orders execute immediately
- No conflicts
```

### Multiple Warlords

```
Problem: Two warlords, same unit, different orders

Possible solutions:

Option A: Last Order Wins
- Most recent order takes priority
- Simple, but frustrating
- Warlords can override each other

Option B: Owner Priority
- Unit owner's orders take precedence
- Other warlords can suggest, not command
- Requires ownership tracking

Option C: Rank System
- Higher rank warlord takes priority
- Rank earned through contribution/prestige
- Creates hierarchy

Option D: Voting/Consensus
- Conflicting orders create vote prompt
- Quick resolution (5 seconds)
- Timeout defaults to senior warlord

Recommendation: Hybrid
- Owner priority for personal units
- Rank priority for faction NPCs
- Clear visual indicator of command authority
```

### Supreme Commander Role

```
For large operations:
- One warlord designated supreme
- Full authority over all units in region
- Other warlords become advisors
- Duration-limited (one battle/operation)

Designation:
- Volunteered by faction vote
- Or highest rank present
- Or designated by faction leadership
```

---

## The Warlord Presence

### Abstract Representation

```
Warlord in territory is not a unit:
- No physical body to attack
- Represents "attention" not person
- Can be in multiple territories? (TBD)
- Fog of war based on collective vision
```

### Alternative: Warlord Unit

```
Warlord has physical presence:
- Can be attacked, killed
- Death = forced zoom out
- Respawn delay
- Creates assassination gameplay

Trade-off:
- More immersive
- But warlords become cautious
- May hide instead of command
```

### Recommendation

```
Hybrid approach:
- Warlord presence is abstract by default
- Can "manifest" as hero unit (optional)
- Manifestation grants bonuses but adds risk
- Different playstyles supported
```

---

## UI Elements

### World Map UI

```
┌─────────────────────────────────────────┐
│ [Faction Banner]        [Time] [Day/Night] │
├─────────────────────────────────────────┤
│                                         │
│           AZEROTH MAP                   │
│                                         │
│    [Territory markers with status]      │
│    [Caravan routes]                     │
│    [Active battle indicators]           │
│                                         │
├─────────────────────────────────────────┤
│ [Alert Queue] [Resource Summary] [Menu] │
└─────────────────────────────────────────┘
```

### Tactical UI

```
┌─────────────────────────────────────────┐
│ [Resources]              [Time] [Mini-map]│
├─────────────────────────────────────────┤
│                                         │
│           TERRITORY VIEW                │
│                                         │
│    [Units, terrain, fog of war]         │
│                                         │
├───────┬─────────────────────────────────┤
│ Mini- │ [Selected Unit Info]  [Commands]│
│  map  │ [HP/Status bars]      [Abilities]│
└───────┴─────────────────────────────────┘
```

### Hero UI

```
┌─────────────────────────────────────────┐
│ [Hero Portrait] [HP/Mana]    [Buffs/Debuffs]│
├─────────────────────────────────────────┤
│                                         │
│           HERO VIEW                     │
│                                         │
│    [Third-person or isometric]          │
│                                         │
├─────────────────────────────────────────┤
│ [1][2][3][4][5][6]  [Inventory] [Map Toggle]│
└─────────────────────────────────────────┘
```

---

## Alerts and Notifications

### Territory Alerts

```
Types:
- Attack warning (enemies spotted)
- Raid incoming (large force detected)
- Territory lost (faction control changed)
- Caravan raided (resources lost)
- Patrol returned (loot delivered)

Display:
- Flash on world map
- Sound effect
- Queue in alert panel
- Click to zoom to location
```

### Cross-Territory Awareness

```
Warlord in Territory A can see:
- World map as minimap overlay
- Flashing indicators for alerts
- Summary of other territories' status
- Quick-jump buttons to hot spots
```

### Request for Aid

```
Warlords can request help:
- Send ping to faction
- Specify need (reinforcements, resources)
- Other warlords see request
- Can choose to zoom in and assist
```

---

## Hotkeys and Commands

### Default Bindings

```
World Map:
- M: Toggle world map view
- Click: Zoom to territory
- Scroll: Zoom map in/out

Tactical:
- Space: Center on selection
- Tab: Cycle through units
- Ctrl+Click: Queue orders
- A: Attack-move
- S: Stop
- H: Hold position

Hero:
- P: Possess selected hero
- R: Release to tactical
- 1-6: Abilities
- I: Inventory
```

### Command Wheel

```
Right-click and hold for radial menu:
- Move (default)
- Attack
- Hold Position
- Patrol
- Follow
- Special (context-sensitive)
```

---

## Multi-Monitor Support

### Dual Monitor Dream

```
Monitor 1: Tactical view (active)
Monitor 2: World map (persistent)

Benefits:
- Always-visible strategic overview
- Instant awareness of alerts
- No view switching needed
- True commander experience
```

### Single Monitor Alternative

```
Picture-in-picture:
- World map as corner overlay
- Adjustable size/opacity
- Click to zoom (switch views)
- Alerts highlighted on overlay
```

---

## Open Questions

1. Can warlords be in multiple territories simultaneously?
2. How do we handle warlord disconnect mid-battle?
3. Should there be a "spectator" mode for observation only?
4. Can enemy warlords see each other's presence?
5. What happens to orders when warlord zooms out?

---

## Revision History

| Date | Change |
|------|--------|
| 2025-12-30 | Initial document |
