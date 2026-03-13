# AI Bot Behavior

## Weapon-Based Behavior Patterns

Each weapon type creates bots with unique behavior:

### Example: Lightning Gun (Sniper)
- Maintains maximum distance from target
- Selects farthest visible target
- Ignores other enemies (focus fire)
- Stays stationary while firing
- Repositions only when losing line of sight

### Example: Flak Cannon (Brawler)
- Moves close to enemies
- Aggressive engagement
- Dodges left and right to avoid projectiles
- Targets nearest enemy
- Uses terrain for cover approach

### General Principles
- Each weapon should have distinct tactical behavior
- Behaviors should match weapon's optimal range and usage
- Bots should "feel" different from each other

## Pathfinding and Movement

### Route Memory System
Each bot maintains:
- List of previously taken waypoint paths
- Resets on death

### Path Selection Algorithm
1. Bot reaches waypoint junction
2. Randomly selects from available paths
3. Excludes previously-taken paths from selection
4. If all paths taken, reset memory and choose freely

### Benefits
- Natural spreading across map
- Reduces looping behavior
- Prevents congestion at chokepoints
- Creates organic unit distribution

## Objective Behavior

### Proximity-Based Engagement
- Bots check for nearby objectives
- Engage with objectives if:
  - Within detection range
  - No higher-priority target exists
  - Objective is appropriate for current behavior

### Objective Priority
Implementation decision pending:
- Option A: Always prioritize combat over objectives
- Option B: Always prioritize objectives over combat
- Option C: Weapon-dependent priority (some bots focus objectives, others focus combat)

## Combat Behavior

### Target Selection
Varies by weapon type (see weapon-based behavior patterns above)

### Engagement Range
- Determined by weapon type
- Bots should respect optimal range for their weapon
- Repositioning when out of effective range

### Dodging and Evasion
- Weapon-dependent complexity
- Close-range bots: Active dodging
- Long-range bots: Minimal movement
- Medium-range bots: Positional adjustment

## Future Enhancements

### Advanced Tactics
- Coordinated pushes
- Unit formations
- Focus-fire priority targets
- Retreat and regroup behaviors

### Player Commands
Not in MVP, but potential for:
- Rally points
- Attack/Defend orders
- Hold position commands
- Focus target designation
