# Game Mechanics

## Resource System

### Adrenaline
- Maximum capacity: 100
- Generation rate: 1 per second (passive)
- Spawn cost: 10 per unit
- Bonus sources: Adrenaline pill pickups (+1 per pill when picked up by allied units)

### Player Health
- Maximum capacity: 200
- Loss conditions:
  - Unit death: -10 health per unit
- Gain conditions:
  - Allied unit picks up health vial: +1 health
  - Allied unit picks up health pack (25hp): +5 health

Note: Health pickups heal the unit AND transfer partial health to player

### Unit Health and Armor
- Units have their own health pools
- Health pickups heal units directly
- Armor pickups protect only the unit (do not transfer to player)
- Units do not consume their own adrenaline

## Spawn System

### Spawning Process
1. Player selects a spawn point (highlighted when looked at)
2. Player left-clicks to spawn
3. Current equipped weapon is discarded and removed from game
4. AI bot spawns at the location with that weapon
5. Player receives a new random weapon (weighted random)

### Weapon Cycling
- Player has 4 guns in inventory at any time
- Weighted random ensures all weapons cycle before repeats
- Example: If 8 weapon types exist, player must spawn all 8 before seeing first weapon again

### Spawn Locations

#### Onslaught Maps
- Nodes serve as spawn points
- Standard Onslaught capture mechanics may apply

#### Team Deathmatch Maps
- AI waypoints serve as spawn points
- Availability determined by proximity:
  - Green orb: Close to allies, far from foes (available)
  - Red orb: Close to foes (unavailable)
  - Gray orb: Neutral, unclaimed

## Win/Loss Conditions

Depends on map mode:
- Onslaught: Control all nodes or primary objective
- Team Deathmatch: Score-based or elimination-based
- Custom: Map-specific objectives

## Player Death
When player health reaches 0:
- Player dies
- All spawned units may despawn (implementation decision pending)
- Respawn mechanics TBD
