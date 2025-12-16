# Resource Flow & Economy System

## Overview
Victoria 3-inspired production system where locations have inputs/outputs, combined with automatic item distribution via priority heuristics and kingdom-wide resource sharing.

## Comprehensive Economic Ecosystem
The resource flow and economy system creates a living, breathing economic simulation that operates on multiple interconnected levels, from individual item transactions to kingdom-wide resource allocation strategies. Drawing inspiration from Victoria 3's sophisticated production modeling, this system treats every location as a node in a vast economic network where inputs are transformed into outputs through complex production chains that respond dynamically to supply, demand, and strategic priorities. Unlike static economy systems that simply deduct resources and provide benefits, this approach creates genuine economic relationships where the health of individual production nodes affects the entire kingdom's prosperity.

The automatic item distribution system represents a breakthrough in strategy game resource management, eliminating the tedious micromanagement that often bogs down economic gameplay while maintaining meaningful strategic choices. Through sophisticated priority heuristics, the system intelligently routes produced items to the units and locations that can best utilize them, taking into account factors like unit type compatibility, combat readiness requirements, geographic proximity, and strategic importance. A newly crafted magical sword doesn't simply enter a generic inventory pool—instead, the system evaluates all available units, considers their current equipment, combat roles, and strategic priorities, then automatically delivers the weapon to the unit where it will provide maximum tactical advantage.

The franchise mutual aid system creates a compelling framework for cooperative resource management that goes beyond simple resource pooling. When a location faces production shortages, it broadcasts aid requests across the franchise network, triggering a sophisticated negotiation system where other locations evaluate their capacity to assist based on their own surpluses, strategic priorities, and relationship factors. This creates emergent political dynamics where successful aid provision builds reputation and reciprocal obligations, while failure to assist can strain inter-location relationships and reduce future cooperation possibilities.

Perhaps most uniquely, the system integrates seamlessly with the game's core item gravity mechanics, where the physical nature of items creates constant tension between risk and reward. Magic items recovered from battlefield victories must be physically transported to bases for identification and distribution, while mundane items can be scrapped for raw materials or sold to mainland markets for gold. The ever-present threat of items sinking into the ground if not actively carried creates time pressure that transforms routine logistics into tactical challenges, where players must balance the immediate needs of combat units against the long-term benefits of proper item management.

## Core Economic Principles

### Guaranteed Baseline
- **Food Security**: Food is always free and guaranteed for all populations
- **Franchise Support**: If a location can't meet production requirements, others help
- **Development Incentive**: Helping others provides modified forecasts and reciprocal aid
- **No Starvation**: Logistics failures don't result in population loss

The guaranteed baseline philosophy ensures that economic complexity enhances rather than overwhelms the core gameplay experience. By removing survival mechanics like food scarcity and population starvation, the system allows players to focus on strategic resource optimization rather than crisis management. This design choice creates space for sophisticated economic interactions while maintaining accessibility for players who prefer tactical combat over economic micromanagement. The franchise support network transforms what could be punitive resource shortages into opportunities for cooperative gameplay and strategic alliance building.

### Production Surplus Model
- **Consumption First**: Population needs met before export consideration
- **Export Economy**: Surplus food and goods can be exported to mainland
- **Import Options**: Gold from exports can buy non-magical items from mainland
- **Local vs Import**: Magic items must be crafted locally, mundane items can be imported

## Location-Based Production

### Building Types by Terrain
- **Skeleton Areas**: Boneyards (automatic undead unit production)
- **Magical Forests**: Mushroom Golem Guardians (gemstone-enhanced defense)
- **Mining Areas**: Gemstone excavation and processing
- **Coastal Areas**: Fishing, trade ports, shipbuilding
- **Plains**: Agriculture, livestock, basic crafting
- **Mountains**: Stone quarries, metal mining, fortifications

### Production Mechanics
```
ProductionBuilding {
    inputs: list<ResourceType, Amount>
    outputs: list<ResourceType, Amount>
    efficiency: float
    worker_count: int
    automation_level: enum(manual, semi_auto, full_auto)
}
```

### Input/Output Categories
- **Raw Materials**: Stone, wood, metal ore, magical components
- **Processed Goods**: Tools, weapons, armor, refined materials
- **Food**: Grains, meat, magical foods, preserved rations
- **Magical Items**: Enchanted equipment, potions, scrolls
- **Currency**: Gold, trade goods, precious materials

## Automatic Distribution System

### Priority Heuristics
1. **Unit Type Matching**: Equipment goes to compatible unit classes
2. **Combat Readiness**: Combat units get priority for weapons/armor
3. **Efficiency Optimization**: Items go where they provide most benefit
4. **Geographic Proximity**: Closer units get preference for heavy items
5. **Strategic Value**: Important units/locations get premium equipment

### Distribution Algorithm
```
DistributionManager {
    item_pool: list<Item>
    unit_priorities: map<Unit, Priority>
    compatibility_matrix: map<ItemType, list<UnitClass>>
    transport_costs: map<Location, Location, Cost>
}

function distribute_items() {
    for item in item_pool {
        candidates = find_compatible_units(item)
        scored_candidates = calculate_priority_scores(candidates, item)
        selected_unit = select_highest_priority(scored_candidates)
        assign_item(item, selected_unit)
    }
}
```

### Equipment Learning System
- **Usage Tracking**: Monitor which items work well with which unit types
- **Effectiveness Metrics**: Track combat performance with different equipment
- **Synergy Discovery**: Learn about item combinations that work well together
- **Location Bonuses**: Similar buildings provide bonus modifiers to each other

## Resource Flow Network

### Inter-Location Transport
- **Shipping Routes**: Established paths between locations
- **Transport Capacity**: Limited by available transport units/infrastructure
- **Transport Costs**: Distance, danger, and cargo type affect transport costs
- **Priority Routing**: Critical resources get faster transport

### Franchise Mutual Aid
```
MutualAidSystem {
    shortage_alerts: list<ResourceShortage>
    surplus_offers: list<ResourceSurplus>
    aid_commitments: map<Location, Location, ResourcePromise>
    reputation_scores: map<Location, float>
}
```

### Aid Negotiation
1. **Shortage Detection**: Location identifies resource deficit
2. **Aid Request**: Broadcast request to franchise network
3. **Offer Evaluation**: Potential helpers assess capacity to assist
4. **Commitment Agreement**: Formal aid commitment with delivery timeline
5. **Reputation Update**: Successful aid improves faction standing

## Advanced Economic Features

### Investment System
- **Building Upgrades**: Invest gold/resources to improve production efficiency
- **Infrastructure**: Roads, ports, storage facilities improve transport
- **Technology**: Research to unlock new building types and production methods
- **Specialization**: Locations can focus on specific production chains

### Market Dynamics
- **Supply/Demand**: Prices fluctuate based on regional availability
- **Trade Routes**: Profitable routes between locations with different specialties
- **Mainland Trade**: Export surplus for gold, import unavailable goods
- **Embargo Effects**: Political conflicts can disrupt trade routes

### Magical Economics
- **Gemstone Cycle**: Mine gems → craft magical items → recover gems from battle → repeat
- **Magical Food**: Special crops that provide unit bonuses
- **Enchantment Services**: Magical enhancement of mundane items
- **Alchemy**: Transform base materials into valuable magical components

## Worker & Population Management

### Labor Allocation
- **Worker Assignment**: Citizens allocated to different production buildings
- **Skill Development**: Workers become more efficient with experience
- **Population Growth**: Successful locations attract more inhabitants
- **Migration**: Workers can move between locations based on opportunities

### Special Roles
- **Item Holders**: Dedicated workers required to store magical items
- **Transport Crews**: Workers assigned to move goods between locations
- **Researchers**: Population dedicated to technological advancement
- **Military**: Population serving in defense and expansion roles

## Economic Victory Conditions

### Prosperity Metrics
- **Production Efficiency**: How well locations meet their potential output
- **Trade Volume**: Amount of inter-location and mainland commerce
- **Innovation Rate**: Speed of technological and magical advancement
- **Population Happiness**: Citizen satisfaction with economic conditions

### Economic Warfare
- **Resource Denial**: Cutting off enemy supply lines
- **Trade Disruption**: Attacking merchant convoys and trade routes
- **Economic Espionage**: Stealing production secrets and technologies
- **Magical Item Recovery**: Recovering valuable items from battlefield losses

## Integration with Combat System

### Equipment Impact
- **Combat Bonuses**: Better equipment improves unit combat effectiveness
- **Durability**: Items can be damaged or destroyed in combat
- **Battlefield Recovery**: Victorious forces can salvage enemy equipment
- **Repair Systems**: Damaged equipment can be repaired at appropriate facilities

### War Economy
- **Production Conversion**: Peacetime buildings can be converted for war production
- **Resource Prioritization**: Military needs can override civilian distribution
- **Emergency Measures**: Crisis situations trigger special economic protocols
- **Victory Spoils**: Conquered locations provide access to their production capacity