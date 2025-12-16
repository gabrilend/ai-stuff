# Gameplay Mechanics

## Resource System

### Gold Generation
- Players receive gold over time at a steady rate
- Gold is used to purchase and deploy units
- No other resource types in the core game

## Combat System

### Battle Flow
1. Units advance down their assigned lanes
2. When opposing teams meet, combat begins
3. Units push enemies back until reaching their base
4. Combat continues until one side is eliminated or retreats

### Base Defense System
- **Main Base**: ~5 average units worth of health + automatic turret
- **Defense Shields**: 3 shields, each with ~5 average units worth of health
- **Shield Mechanics**: When a shield is destroyed, all enemy units are removed from the map
- **Reset Mechanism**: After shield destruction, enemies must advance again from their starting positions

This system prevents extreme snowball effects where accumulated surviving units become unstoppable.

## Unit Deployment

### Lane Selection
- Players choose which lane to send units down
- Strategic choice affects unit positioning and engagement timing

### Formation Control
- Units maintain relative spawning positions within lanes
- Melee and ranged units can be positioned strategically
- Example: Spawn melee on one side, ranged on the other for tactical advantage

## Unit Behavior

### Melee Units
- Move directly into melee range with nearest enemy
- Engage in combat until defeated or enemy is eliminated
- Generate mana when in range of enemies (moving or stationary)

### Ranged Units
- Maintain safe distance by backing up when enemies approach
- Cannot contribute to combat while moving backward
- Must stand still to fight effectively
- Generate mana only when standing still (combat or waiting)

### Universal Behaviors
- Units attempt to maintain their relative lane position when not fighting
- Units move around stopped allies rather than queuing behind them (when space permits)
- All units have primary abilities that generate mana continuously