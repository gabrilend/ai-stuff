# Issue 015 - Implement Building and Construction System

## Current Behavior
The building system is defined but completely unimplemented in `src/unit.h`:
```c
typedef struct Building {
    char* name;
    int type;
    // TODO: Define building system
} Building;
```
This structure exists but has no functionality, no building types defined, no construction mechanics, and no integration with character or economic systems.

## Intended Behavior
Implement a comprehensive building and construction system that enables:
- Different building types with specific functions and benefits
- Construction mechanics requiring resources, time, and skills
- Building ownership and management by characters
- Economic integration with resource production and consumption
- Building upgrades and maintenance systems
- Integration with character progression and settlement development

## Suggested Implementation Steps

### Phase 3A: Core Building System Design
1. **Define Building Types and Properties**
   ```c
   typedef enum BuildingType {
       BUILDING_HOUSE_SMALL,      // Basic residential
       BUILDING_HOUSE_LARGE,      // Upgraded residential
       BUILDING_SHOP,             // Commercial building
       BUILDING_FORGE,            // Crafting facility
       BUILDING_LIBRARY,          // Knowledge and research
       BUILDING_TEMPLE,           // Religious building
       BUILDING_GUARD_TOWER,      // Defensive structure
       BUILDING_FARM,             // Food production
       BUILDING_MINE,             // Resource extraction
       BUILDING_TAVERN,           // Social gathering place
       BUILDING_WAREHOUSE,        // Storage facility
       BUILDING_COUNT
   } BuildingType;
   
   typedef struct BuildingProperties {
       char* name;                    // Display name
       char* description;             // Detailed description
       int construction_time_days;    // Time to build
       int max_occupants;            // How many people can live/work here
       int defense_value;            // Defensive bonus
       int comfort_rating;           // Quality of life bonus
       float upkeep_cost_per_day;    // Daily maintenance cost
       bool provides_income;         // Can generate revenue
       float income_per_day;         // Daily income if applicable
       bool requires_staffing;       // Needs workers to function
       int min_staff_required;       // Minimum workers needed
   } BuildingProperties;
   ```

2. **Implement Building Construction Requirements**
   ```c
   typedef struct ConstructionRequirement {
       int resource_type;            // WOOD, STONE, METAL, etc.
       int quantity_required;        // Amount needed
       bool is_consumed;            // True if used up in construction
   } ConstructionRequirement;
   
   typedef struct SkillRequirement {
       int skill_type;              // CARPENTRY, MASONRY, etc.
       int minimum_level;           // Required skill level
       int workers_needed;          // Number of skilled workers
   } SkillRequirement;
   
   typedef struct BuildingBlueprint {
       BuildingType building_type;
       ConstructionRequirement* materials;
       int material_count;
       SkillRequirement* skills;
       int skill_count;
       int base_cost;               // Gold cost for tools/hiring
       int size_requirement;        // Land area needed
   } BuildingBlueprint;
   ```

### Phase 3B: Building State and Management
3. **Implement Building State System**
   ```c
   typedef enum BuildingState {
       BUILDING_PLANNED,            // Blueprint exists, construction not started
       BUILDING_UNDER_CONSTRUCTION, // Currently being built
       BUILDING_COMPLETE,           // Fully constructed and functional
       BUILDING_DAMAGED,            // Damaged but still usable
       BUILDING_RUINED,            // Too damaged to use
       BUILDING_ABANDONED          // No longer maintained
   } BuildingState;
   
   typedef struct Building {
       char* name;                  // Custom name given by owner
       BuildingType type;
       BuildingState state;
       char* owner_id;             // Character who owns this building
       int construction_progress;   // 0-100% complete
       int condition;              // 0-100% condition
       float accumulated_upkeep;   // Unpaid maintenance costs
       time_t construction_start;   // When building started
       time_t last_maintenance;    // Last upkeep payment
       
       // Location and placement
       int x_coordinate;
       int y_coordinate;
       int facing_direction;       // 0-7 for 8 directions
       
       // Functionality
       char** current_occupants;   // IDs of characters living/working here
       int occupant_count;
       Item** stored_items;        // Building inventory
       int stored_item_count;
       float current_funds;        // Money generated/stored
       
       // Upgrades and modifications
       char** installed_upgrades;  // List of building improvements
       int upgrade_count;
   } Building;
   ```

4. **Create Building Management Functions**
   ```c
   Building* create_building_blueprint(BuildingType type, int x, int y);
   bool start_construction(Building* building, Unit* character);
   bool advance_construction(Building* building, int work_days);
   bool complete_construction(Building* building);
   bool pay_upkeep(Building* building, float amount);
   bool assign_occupant(Building* building, const char* character_id);
   bool remove_occupant(Building* building, const char* character_id);
   ```

### Phase 3C: Economic and Resource Integration
5. **Implement Resource System for Construction**
   ```c
   typedef enum ResourceType {
       RESOURCE_WOOD,
       RESOURCE_STONE,
       RESOURCE_METAL,
       RESOURCE_CLOTH,
       RESOURCE_GLASS,
       RESOURCE_LABOR,
       RESOURCE_COUNT
   } ResourceType;
   
   typedef struct ResourceStorage {
       ResourceType type;
       int quantity;
       float quality_modifier;     // 0.5-2.0 quality affects construction
       char* source_location;      // Where resource came from
   } ResourceStorage;
   
   bool check_construction_resources(const BuildingBlueprint* blueprint,
                                   const ResourceStorage* available,
                                   int available_count);
   bool consume_construction_resources(Building* building,
                                     ResourceStorage* available,
                                     int* available_count);
   ```

6. **Create Building Economy Functions**
   ```c
   float calculate_daily_income(const Building* building);
   float calculate_daily_upkeep(const Building* building);
   bool process_building_economics(Building* building);
   void update_all_buildings_economy(Building** buildings, int building_count);
   ```

### Phase 3D: Building Upgrades and Progression
7. **Implement Building Upgrade System**
   ```c
   typedef struct BuildingUpgrade {
       char* name;                 // "Reinforced Walls", "Better Equipment"
       char* description;
       int cost;
       ConstructionRequirement* materials;
       int material_count;
       float income_bonus;         // Multiplier for income generation
       float defense_bonus;        // Additional defense value
       float efficiency_bonus;     // Reduces upkeep costs
       bool requires_skill;        // Needs specific skill to install
       int required_skill_level;
   } BuildingUpgrade;
   
   bool can_install_upgrade(const Building* building, 
                           const BuildingUpgrade* upgrade,
                           const Unit* character);
   bool install_upgrade(Building* building, 
                       const BuildingUpgrade* upgrade,
                       Unit* character);
   ```

8. **Create Building Progression System**
   - Implement building level advancement
   - Add building efficiency improvements over time
   - Create building specialization paths
   - Add building network effects (multiple buildings working together)

### Phase 3E: Settlement and Town Integration
9. **Implement Settlement System**
   ```c
   typedef struct Settlement {
       char* name;
       Building** buildings;
       int building_count;
       int max_buildings;
       char* mayor_id;            // Character governing the settlement
       int population;
       float prosperity_rating;   // 0-100 based on building types/condition
       float defense_rating;      // Total defensive capability
       float culture_rating;      // Social and cultural development
   } Settlement;
   
   Settlement* create_settlement(const char* name, int max_buildings);
   bool add_building_to_settlement(Settlement* settlement, Building* building);
   void update_settlement_ratings(Settlement* settlement);
   float calculate_settlement_prosperity(const Settlement* settlement);
   ```

10. **Add Building Interaction Systems**
    - Character-building interactions (living, working, visiting)
    - Building-to-building relationships and dependencies
    - Settlement-wide events affecting all buildings
    - Trade routes between settlements

### Phase 3F: Integration and User Interface
11. **Integrate with Character System**
    - Add building-related skills to character progression
    - Create building ownership and management UI
    - Add building-based character income and expenses
    - Implement building-based character benefits (comfort, safety, etc.)

12. **Create Building Persistence and Save System**
    - Extend JSON serialization for building data
    - Add building database management
    - Create building import/export for progress-ii integration
    - Implement building state persistence across game sessions

## Dependencies
- Resource and inventory management system
- Character skill system for construction requirements
- Economic system for costs and income
- Time and calendar system for construction duration
- UI framework for building management interfaces
- Coordinate system for building placement

## Verification Criteria
- Buildings can be planned, constructed, and completed successfully
- Construction requires appropriate resources and skills
- Building economy (income/upkeep) functions correctly
- Building condition degrades without maintenance
- Settlement prosperity reflects building quality and types
- Building data persists correctly in save files
- UI allows full building management functionality

## Estimated Complexity
**High** - This is a comprehensive system involving:
- Complex data structures and state management
- Economic modeling and balance calculations
- Resource management and constraint satisfaction
- Time-based progression and maintenance
- Integration with multiple existing systems
- User interface and visualization components

## Related Issues
- Issue 012: Character traits (may affect building preferences/efficiency)
- Issue 010: Lua integration (scripted building behaviors)
- Issue 008: Progress-ii integration (settlement data exchange)
- Future: Map and world generation system
- Future: Trade and commerce mechanics
- Future: Settlement politics and governance

## Notes
This system provides long-term goals and progression for characters beyond just combat and adventure. Start with basic building types and expand complexity gradually. Consider balance carefully - buildings should provide meaningful benefits without trivializing other game systems. The settlement aspect can grow into a full city-building game component.