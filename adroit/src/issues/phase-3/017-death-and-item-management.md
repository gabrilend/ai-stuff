# Issue 017 - Implement Character Death and Item Management

## Current Behavior
The main game loop in `src/main.c` line 318 has a TODO comment:
```c
// TODO: Handle unit death, drop items, etc.
```
Currently, there is no implementation for:
- Character death detection and handling
- Item dropping when characters die
- Death consequences and recovery mechanics
- Inventory management during death
- Resurrection or respawn systems
- Items left behind in the world

## Intended Behavior
Implement a comprehensive death and item management system that handles:
- Character death detection with multiple death conditions
- Automatic item dropping and inventory management
- Death consequences affecting character progression
- Options for character recovery (resurrection, respawn, etc.)
- Items persistence in the world after character death
- Death-related adventure events and narrative integration

## Suggested Implementation Steps

### Phase 3A: Death Detection and State Management
1. **Define Death Conditions and Types**
   ```c
   typedef enum DeathCause {
       DEATH_HIT_POINTS,          // HP reduced to 0 or below
       DEATH_ABILITY_DRAIN,       // Critical ability score reduced to 0
       DEATH_POISON,              // Poison or disease
       DEATH_MAGIC,               // Magical death effect
       DEATH_ENVIRONMENTAL,       // Drowning, falling, etc.
       DEATH_AGE,                 // Natural death from old age
       DEATH_EXECUTION,           // Intentional killing
       DEATH_ACCIDENT,            // Accidental death
       DEATH_UNKNOWN              // Unclear cause
   } DeathCause;
   
   typedef enum DeathSeverity {
       DEATH_UNCONSCIOUS,         // Temporarily down, can recover
       DEATH_DYING,               // Making death saves, critical condition
       DEATH_DEAD,                // Dead but potentially resurrectable
       DEATH_DESTROYED,           // Permanently dead, no resurrection
       DEATH_MISSING              // Missing/presumed dead
   } DeathSeverity;
   
   typedef struct DeathState {
       bool is_dead;
       DeathCause cause;
       DeathSeverity severity;
       time_t time_of_death;
       char* death_location;
       char* death_circumstances;
       int death_saves_made;      // For dying condition
       int death_saves_failed;    // For dying condition
       bool stabilized;           // No longer making death saves
   } DeathState;
   ```

2. **Implement Death Detection Functions**
   ```c
   bool check_character_death(Unit* character, DeathCause* cause);
   void apply_death_state(Unit* character, DeathCause cause, DeathSeverity severity);
   bool is_character_dead(const Unit* character);
   bool is_character_dying(const Unit* character);
   bool can_character_be_stabilized(const Unit* character);
   void process_death_saves(Unit* character);
   ```

3. **Add Death State to Character Structure**
   ```c
   // Add to Unit structure in unit.h
   typedef struct Unit {
       // ... existing fields ...
       DeathState* death_state;   // NULL if alive, populated if dead/dying
       bool has_died_before;      // Track if character has been dead
       int total_deaths;          // Number of times died
       char** death_history;      // Log of all death events
   } Unit;
   ```

### Phase 3B: Item Dropping and Management
4. **Implement Item Dropping System**
   ```c
   typedef struct ItemDrop {
       Item* item;                // The dropped item
       int quantity;              // Amount dropped
       float x_position;          // World coordinates where dropped
       float y_position;
       time_t drop_time;          // When item was dropped
       char* drop_reason;         // "character death", "intentional drop"
       bool is_recoverable;       // Can be picked up again
       float decay_rate;          // How fast item degrades/disappears
   } ItemDrop;
   
   typedef struct DroppedItemList {
       ItemDrop** items;
       int item_count;
       int max_items;
       char* location_name;       // Where these items are located
   } DroppedItemList;
   
   DroppedItemList* drop_all_character_items(Unit* character, const char* location);
   DroppedItemList* drop_specific_items(Unit* character, int* gear_indices, int count);
   bool add_dropped_item(DroppedItemList* list, Item* item, int quantity, 
                        float x, float y, const char* reason);
   void process_item_decay(DroppedItemList* list, float time_elapsed);
   ```

5. **Create Inventory Management During Death**
   ```c
   typedef struct DeathInventoryOptions {
       bool drop_all_items;           // Drop everything on death
       bool drop_only_equipped;       // Keep items in backpack
       bool drop_valuable_items;      // Drop items above certain value
       float value_threshold;         // Minimum value to drop
       bool keep_bound_items;         // Keep soul-bound/no-drop items
       bool drop_at_random_locations; // Scatter items vs. drop in pile
       float scatter_radius;          // How far to scatter items
   } DeathInventoryOptions;
   
   void configure_death_inventory_rules(DeathInventoryOptions* options);
   DroppedItemList* process_death_inventory(Unit* character, 
                                           const DeathInventoryOptions* options,
                                           const char* death_location);
   ```

### Phase 3C: Death Consequences and Recovery
6. **Implement Death Consequences System**
   ```c
   typedef struct DeathConsequences {
       int experience_loss;           // XP penalty for dying
       int stat_drain;               // Temporary ability score penalties
       int hp_penalty;               // Reduced max HP temporarily
       float skill_penalty;          // Skill check penalties
       int recovery_time_hours;      // Time needed to fully recover
       bool needs_restoration;       // Requires magical healing
       char* special_effects;        // Other death-related effects
   } DeathConsequences;
   
   DeathConsequences calculate_death_penalties(const Unit* character, DeathCause cause);
   void apply_death_consequences(Unit* character, const DeathConsequences* consequences);
   void reduce_death_penalties_over_time(Unit* character, float hours_elapsed);
   bool remove_death_consequences(Unit* character); // Full recovery
   ```

7. **Create Resurrection and Recovery Systems**
   ```c
   typedef enum RecoveryMethod {
       RECOVERY_NATURAL,          // Wait for natural recovery
       RECOVERY_MAGICAL,          // Magical resurrection spell
       RECOVERY_DIVINE,           // Divine intervention
       RECOVERY_TECHNOLOGICAL,    // Advanced technology
       RECOVERY_REINCARNATION,    // Return as different form
       RECOVERY_RESPAWN           // Game mechanic respawn
   } RecoveryMethod;
   
   typedef struct RecoveryOptions {
       RecoveryMethod method;
       int cost;                  // Gold or resource cost
       int time_required;         // Time for recovery process
       float success_chance;     // Probability of successful recovery
       bool preserves_items;     // Whether items are recovered too
       bool preserves_experience; // Whether XP is preserved
       char* requirements;       // Special requirements for this method
   } RecoveryOptions;
   
   RecoveryOptions* get_available_recovery_methods(const Unit* character);
   bool attempt_character_recovery(Unit* character, RecoveryMethod method);
   void display_recovery_options(const RecoveryOptions* options, int count);
   ```

### Phase 3D: World Item Persistence
8. **Implement World Item Management**
   ```c
   typedef struct WorldItemManager {
       DroppedItemList** locations;  // Items at different locations
       int location_count;
       char** location_names;        // Names of all locations with items
       time_t last_cleanup;          // Last time old items were removed
   } WorldItemManager;
   
   WorldItemManager* create_world_item_manager(void);
   void add_location_items(WorldItemManager* manager, const char* location_name,
                          DroppedItemList* items);
   DroppedItemList* get_location_items(WorldItemManager* manager, const char* location);
   void cleanup_old_items(WorldItemManager* manager);
   bool transfer_item_to_character(WorldItemManager* manager, const char* location,
                                  int item_index, Unit* character);
   ```

9. **Add Item Recovery and Looting**
   ```c
   typedef struct LootingOptions {
       bool allow_own_item_recovery;     // Can recover your own dropped items
       bool allow_others_item_looting;   // Can take items dropped by others
       float looting_time_per_item;      // Time required to loot each item
       bool requires_line_of_sight;      // Must see items to loot them
       float maximum_looting_distance;   // How close must be to loot
   } LootingOptions;
   
   bool can_loot_item(const Unit* character, const ItemDrop* item, 
                     const LootingOptions* options);
   bool loot_dropped_item(Unit* character, DroppedItemList* location_items, 
                         int item_index, const LootingOptions* options);
   void display_available_items(const DroppedItemList* items, 
                               const Unit* character, const LootingOptions* options);
   ```

### Phase 3E: Adventure and Narrative Integration
10. **Create Death Event System**
    ```c
    typedef struct DeathEvent {
        char* event_description;      // Narrative description of death
        char* last_words;            // Character's final words
        char** witnesses;            // Who saw the death
        int witness_count;
        bool was_heroic;             // Heroic vs. mundane death
        char* legacy_effects;        // How death affects world/story
    } DeathEvent;
    
    DeathEvent* create_death_event(const Unit* character, DeathCause cause,
                                  const char* circumstances);
    void record_death_in_history(const DeathEvent* event);
    void notify_death_to_related_characters(const DeathEvent* event);
    ```

11. **Add Memorial and Legacy Systems**
    ```c
    typedef struct CharacterMemorial {
        char* character_name;
        char* memorial_text;         // Epitaph or memorial description
        time_t death_date;
        char* death_location;
        Item** memorial_items;       // Items left as memorial
        int memorial_item_count;
        bool is_public_memorial;     // Visible to other players/characters
    } CharacterMemorial;
    
    CharacterMemorial* create_character_memorial(const Unit* character, 
                                               const DeathEvent* death_event);
    void place_memorial_at_location(const CharacterMemorial* memorial, 
                                   const char* location_name);
    void display_memorial(const CharacterMemorial* memorial);
    ```

### Phase 3F: Integration and User Interface
12. **Add Death UI and Notifications**
    ```c
    void display_death_notification(const Unit* character, const DeathEvent* event);
    void show_death_consequences(const Unit* character, const DeathConsequences* consequences);
    void display_recovery_interface(Unit* character);
    bool confirm_character_recovery(const Unit* character, RecoveryMethod method);
    void show_dropped_items_summary(const DroppedItemList* items);
    ```

## Dependencies
- Time system for tracking death duration and item decay
- Location/world system for item placement and recovery
- Event system for death notifications and consequences
- UI framework for death-related interfaces
- Save/load system for persistent dropped items and death state

## Verification Criteria
- Character death is properly detected for all death conditions
- Items are correctly dropped and placed in world locations
- Death consequences apply appropriate penalties and recovery time
- Recovery methods work with correct costs and success rates
- Dropped items persist across game sessions and decay appropriately
- Item looting and recovery functions correctly with proper restrictions
- Death events are properly recorded and memorialized
- UI provides clear information about death state and options

## Estimated Complexity
**Medium-High** - Involves:
- Complex state management for death and recovery
- World item persistence and management systems
- Mathematical modeling for consequences and recovery
- Integration with multiple game systems (inventory, time, location)
- User interface for death-related interactions
- Narrative and event generation systems

## Related Issues
- Issue 014: Equipment assignment bug (affects item dropping)
- Issue 013: Weapon system (affects what items are dropped)
- Issue 015: Building system (may affect death consequences)
- Issue 008: Progress-ii integration (death events in adventures)
- Future: Combat system implementation
- Future: Save/load system for world state

## Notes
Death should be meaningful but not overly punitive. Focus on creating interesting consequences rather than just frustration. Consider different game modes (hardcore vs. casual) with different death penalties. The item management aspect should encourage strategic thinking about risk vs. reward in dangerous situations.