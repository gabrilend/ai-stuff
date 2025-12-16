# Unit System

## Unit Templates

### Design System
- Players create custom unit templates between games
- All templates must use the same amount of design points
- Ensures approximate balance between different unit designs
- Natural synergies emerge through strategic combinations

### Template Components
- Unit type (melee or ranged)
- Health and damage statistics
- Ability loadout (1-4 abilities)
- Cost and deployment characteristics

## Ability System

### Ability Count
- Each unit has between 1-4 abilities (minimum 1)
- Primary ability (always present)
- Secondary abilities (0-3 additional)

### Mana System
- Each ability has its own mana bar
- Mana fills over time until maximum capacity
- Ability triggers automatically when mana is full and valid targets exist
- Mana bar stays at maximum if no valid targets available

### Mana Generation Rules

#### Primary Abilities
- Generate mana continuously for all unit types
- Always active regardless of unit state

#### Secondary Abilities
- **Ranged Units**: Generate mana only when standing still
  - During combat engagement
  - While waiting to advance (blocked by allies/enemies)
- **Melee Units**: Generate mana when in range of enemies
  - Whether moving toward enemies or stationary
  - Must be within engagement range

### Efficient Mana Usage

#### Damage Abilities
- If target has less health than ability damage, only proportional mana is consumed
- Prevents mana waste on overkill damage
- Allows for more efficient resource utilization

#### Healing Abilities
- If ally is nearly at full health, only enough mana to top them off is used
- Prevents waste of healing mana
- Optimizes support unit effectiveness

## Strategic Considerations

### Unit Type Selection
- **Melee**: High durability, close combat, consistent mana generation in fights
- **Ranged**: Distance advantage, positioning flexibility, conditional mana generation

### Ability Synergies
- Players must balance primary vs secondary abilities
- Consider mana generation conditions when designing templates
- Create synergistic combinations for tactical advantages

### Deployment Strategy
- Unit template choice affects lane effectiveness
- Formation positioning enhances template strengths
- Resource allocation between different template types