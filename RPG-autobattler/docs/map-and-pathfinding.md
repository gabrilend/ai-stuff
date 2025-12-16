# Map and Pathfinding System

## Map Design

### Overall Structure
- Randomly generated network of pathways
- Inspired by dense mesh network of pipes from classic screensavers
- Substantial spacing between individual pathways
- Multiple interconnected routes between bases

### Lane Specifications
- Each lane/pipe is wide enough for ~5 units to stand side-by-side
- Additional units queue behind the front line
- Sufficient width for tactical formations and maneuvering

## Pathfinding System

### Lane Sub-Paths
- Each lane internally contains 5 parallel sub-paths
- Sub-paths arranged side-by-side across the lane width
- Each sub-path represents ~20% of the total lane width
- Units assigned to specific sub-paths maintain relative positioning

### Movement Behavior

#### Standard Movement
- Units attempt to follow their assigned sub-path when advancing
- Maintains formation structure and player-intended positioning
- Preserves tactical arrangements (e.g., melee vs ranged positioning)

#### Obstacle Avoidance
- When allies block the direct path, units move around them
- Prevents unnecessary queuing behind stopped units
- Only queue when no space available for maneuvering

#### Formation Preservation
- Units maintain relative spawning positions within their lane
- Allows strategic deployment (melee on one side, ranged on other)
- When new units arrive, they can pass around existing units to reach intended positions

## Strategic Implications

### Lane Selection
- Multiple pathways provide strategic choices
- Different routes may offer tactical advantages
- Players must consider enemy positioning and defenses

### Formation Control
- Sub-path system enables precise unit positioning
- Allows for complex tactical arrangements
- Supports combined arms tactics (melee/ranged coordination)

### Dynamic Positioning
- Units adapt to battlefield conditions while maintaining formation intent
- Balance between tactical flexibility and strategic positioning
- Prevents static, queue-based movement that limits tactical options

## Technical Implementation Notes

- 5 sub-paths per lane provide sufficient granularity for tactical control
- Movement system prioritizes formation maintenance over pure efficiency
- Pathfinding considers both individual unit goals and overall formation structure