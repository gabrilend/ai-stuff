# AI Personality & Dijkstra Mapping System

## Overview
Advanced AI system that combines spatial awareness through Dijkstra mapping with personality-driven decision making using a 4-color matrix system.

## Comprehensive System Architecture
The AI personality and Dijkstra mapping system represents one of the most sophisticated approaches to unit behavior ever implemented in a strategy game, creating artificial intelligence that feels genuinely intelligent rather than merely programmed. At its foundation lies a elegant four-color personality matrix that reduces the infinite complexity of decision-making to a manageable yet nuanced two-dimensional coordinate system. Each unit's personality is defined by X and Y coordinates ranging from -1 to 1, where the X-axis represents the spectrum from aggressive Red behavior to balanced Green approaches, while the Y-axis spans from cautious Blue strategies to creative Yellow solutions.

This personality system gains its power through integration with dual Dijkstra mapping systems that provide both spatial and conceptual awareness. The spatial Dijkstra maps function as traditional pathfinding aids, calculating optimal movement costs across the terrain, but the conceptual Dijkstra maps represent a breakthrough in AI design—abstract value maps that change based on each unit's personality matrix. A Red-personality unit's conceptual map prioritizes enemy positions and aggressive tactical locations, while a Blue-personality unit's map emphasizes defensive positions and escape routes. Green personalities seek balanced, strategically advantageous positions, while Yellow personalities are drawn to unconventional locations that might surprise opponents.

The decision-making process combines these systems through percentage-based choice generation, where every decision point creates four potential actions (one aligned with each color) and the unit's personality coordinates determine the probability of selecting each option. This creates behavior that is both predictable enough for players to understand and exploit, yet varied enough to feel genuinely dynamic. A unit at coordinates (-0.7, 0.3) will heavily favor Red aggressive solutions with a moderate Yellow creative influence, but will still occasionally select Green or Blue options, creating the kind of behavioral variation that makes AI opponents feel like thinking entities rather than deterministic state machines.

Perhaps most importantly, this system scales beautifully across the game's complexity. Individual unit decisions aggregate into squad-level behaviors, which combine into army-level strategies, all emerging naturally from the same underlying personality and mapping mechanics. The system requires no explicit programming of high-level strategies—complex behaviors like flanking maneuvers, defensive formations, and adaptive responses emerge organically from the interaction of individual units following their personality-driven decision trees while navigating their personalized conceptual maps of the battlefield.

## Personality Matrix System

### 4-Color Personality Types
- **Red (Aggressive)**: Direct confrontation, immediate action, high-risk/high-reward
- **Blue (Defensive)**: Cautious approach, defensive positioning, risk mitigation
- **Green (Balanced)**: Adaptive strategies, situational awareness, moderate risk
- **Yellow (Creative)**: Unconventional solutions, experimental tactics, innovation

These four personality archetypes were specifically chosen to create maximum strategic diversity while maintaining intuitive player understanding. Red represents the warrior's path—direct, aggressive, willing to accept casualties for decisive victory. Blue embodies the guardian's philosophy—cautious, defensive, prioritizing preservation over conquest. Green reflects the tactician's approach—adaptive, measured, seeking optimal solutions through careful analysis. Yellow captures the innovator's spirit—creative, unpredictable, finding novel approaches that conventional strategies miss. The beauty lies not in the pure archetypes, but in the infinite gradations between them, where a unit at coordinates (-0.3, 0.8) exhibits mild Red tendencies strongly influenced by Yellow creativity, creating unique behavioral signatures that players can learn to recognize and counter.

### Personality Coordinates
```
PersonalityMatrix {
    x: float (-1.0 to 1.0)  // Red(-1) to Green(1) axis
    y: float (-1.0 to 1.0)  // Blue(-1) to Yellow(1) axis
}
```

### Coordinate Mapping
- **(-1, -1)**: Pure Red-Blue (Aggressive Defense)
- **(1, -1)**: Pure Green-Blue (Cautious Balance)  
- **(-1, 1)**: Pure Red-Yellow (Aggressive Creativity)
- **(1, 1)**: Pure Green-Yellow (Creative Balance)

## Decision Making System

### Choice Probability Calculation
For any decision with 4 options (one for each color):
```
red_weight = max(0, -x) * base_weight
green_weight = max(0, x) * base_weight
blue_weight = max(0, -y) * base_weight
yellow_weight = max(0, y) * base_weight

total = red_weight + green_weight + blue_weight + yellow_weight
probability_red = red_weight / total
// ... etc for other colors
```

### Decision Types
1. **Combat Decisions**: Attack patterns, target selection, retreat conditions
2. **Movement Decisions**: Path selection, formation choice, positioning
3. **Resource Decisions**: Allocation priorities, risk tolerance, investment strategies
4. **Social Decisions**: Ally cooperation, negotiation strategies, trust levels

## Dijkstra Mapping System

### Spatial Dijkstra Map
- **Purpose**: Understanding physical distance and accessibility
- **Generation**: Calculate movement cost to all reachable positions
- **Update Frequency**: Recalculated when terrain or obstacles change
- **Uses**: Pathfinding, escape route planning, tactical positioning

### Conceptual Dijkstra Map
- **Purpose**: Understanding strategic value and threats
- **Personality Influence**: Different personalities value different concepts
- **Dynamic Weighting**: Values change based on personality and situation
- **Abstract Goals**: Safety, resources, allies, enemies, objectives

## Conceptual Map Generation

### Red Personality Concepts
- **High Value**: Enemy units, chokepoints, aggressive positions
- **Low Value**: Safe areas, defensive positions, retreat routes
- **Modifiers**: Combat effectiveness, damage potential, threat level

### Blue Personality Concepts  
- **High Value**: Safe positions, defensive structures, escape routes
- **Low Value**: Exposed positions, aggressive stances, risk areas
- **Modifiers**: Safety rating, defensive value, ally proximity

### Green Personality Concepts
- **High Value**: Strategic positions, resource nodes, balanced locations
- **Low Value**: Extreme positions (too aggressive or too passive)
- **Modifiers**: Flexibility, adaptability, situational advantage

### Yellow Personality Concepts
- **High Value**: Unusual positions, experimental opportunities, creative solutions
- **Low Value**: Conventional positions, predictable strategies
- **Modifiers**: Innovation potential, surprise factor, unique advantages

## Implementation Architecture

### Data Structures
```
DijkstraMap {
    grid: array<array<float>>
    center_points: list<Position>
    max_value: float
    calculation_type: enum(spatial, conceptual)
}

AIUnit {
    personality: PersonalityMatrix
    spatial_map: DijkstraMap
    conceptual_maps: map<string, DijkstraMap>
    current_goal: string
    decision_history: list<Decision>
}
```

### Map Update Cycle
1. **Spatial Map Update**: Recalculate physical distances and obstacles
2. **Conceptual Map Generation**: Create personality-weighted value maps
3. **Goal Evaluation**: Determine current priorities based on situation
4. **Decision Generation**: Create 4 options (one per color) for current goal
5. **Probability Selection**: Choose option based on personality matrix
6. **Action Execution**: Perform selected action and update world state

## Personality-Driven Behaviors

### Combat Behavior
- **Red**: Rush to closest enemy, high damage attacks, ignore defense
- **Blue**: Maintain safe distance, prioritize defense, retreat when threatened
- **Green**: Assess situation, balanced attack/defense, adapt to enemy strategy
- **Yellow**: Unexpected tactics, unusual positioning, creative ability usage

### Resource Management
- **Red**: Spend immediately for military advantage
- **Blue**: Save resources, invest in defense, maintain reserves
- **Green**: Balanced investment, adapt spending to current needs
- **Yellow**: Experimental investments, try new combinations, innovation

### Social Interaction
- **Red**: Direct confrontation, aggressive negotiation, dominance displays
- **Blue**: Cautious alliances, defensive pacts, trust verification
- **Green**: Balanced relationships, situational cooperation, pragmatic deals
- **Yellow**: Unusual alliances, creative diplomacy, surprise partnerships

## Learning and Adaptation

### Experience Tracking
- **Decision Outcomes**: Track success/failure of personality-driven choices
- **Situation Recognition**: Learn which personality traits work in which contexts
- **Adaptation Range**: Slight personality drift based on experience
- **Memory Decay**: Older experiences have less influence over time

### Emergent Behaviors
- **Personality Extremes**: Units at matrix edges have more predictable behavior
- **Balanced Units**: Central matrix units are harder to predict but more adaptable
- **Situational Pressure**: Extreme situations can temporarily shift personality
- **Group Dynamics**: Multiple units can influence each other's decisions

## Performance Considerations

### Optimization Strategies
- **Map Caching**: Reuse Dijkstra calculations when environment unchanged
- **Update Prioritization**: More important units get more frequent updates
- **Distance Culling**: Only calculate maps within reasonable range
- **Async Processing**: Background calculation of non-critical maps

### Memory Management
- **Map Resolution**: Balance accuracy vs memory usage
- **History Pruning**: Remove old decisions to limit memory growth
- **Shared Calculations**: Common spatial maps shared between units
- **Lazy Evaluation**: Only calculate conceptual maps when needed