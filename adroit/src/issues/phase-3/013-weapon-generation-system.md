# Issue 013 - Implement Weapon Generation System

## Current Behavior
The weapon system is currently incomplete with several missing components:
- `src/starting_weapon_tables.h` contains only placeholder comments: "TODO: Implement weapon tables similar to equipment tables"
- `src/main.c` line 232 has comment: "/* TODO: Implement weapon generation */"
- Characters are generated with equipment but no starting weapons
- Equipment system exists but weapons are treated as generic items without weapon-specific properties

## Intended Behavior
Implement a comprehensive weapon generation system that provides:
- Weapon-specific item types with combat properties
- Probability tables for weapon generation by class/background
- Weapon quality levels (Poor, Common, Fine, Masterwork, Magic)
- Weapon material types affecting stats (Iron, Steel, Mithril, etc.)
- Weapon enchantments and special properties
- Integration with existing equipment and character generation systems
- Class-appropriate starting weapon allocation

## Suggested Implementation Steps

### Phase 3A: Core Weapon Data Structures
1. **Extend Item System for Weapons**
   ```c
   typedef enum WeaponType {
       WEAPON_SWORD_SHORT,
       WEAPON_SWORD_LONG,
       WEAPON_AXE_HAND,
       WEAPON_AXE_BATTLE,
       WEAPON_DAGGER,
       WEAPON_MACE,
       WEAPON_BOW_SHORT,
       WEAPON_BOW_LONG,
       WEAPON_CROSSBOW,
       WEAPON_STAFF,
       WEAPON_SPEAR,
       WEAPON_COUNT
   } WeaponType;
   
   typedef struct WeaponProperties {
       int damage_dice_count;    // Number of damage dice
       int damage_dice_type;     // Size of damage dice (d4, d6, d8, etc.)
       int damage_bonus;         // Flat damage bonus
       int attack_bonus;         // Attack roll bonus
       int critical_range;       // Critical hit range (20, 19-20, etc.)
       int critical_multiplier;  // Critical hit damage multiplier
       float reach;             // Weapon reach in feet
       float weight;            // Weight in pounds
       int hands_required;       // 1 or 2 handed weapon
       bool is_ranged;          // True for bows, crossbows, etc.
       int ammunition_type;      // ARROW, BOLT, STONE, etc.
       char** weapon_properties; // Finesse, Light, Heavy, etc.
       int property_count;
   } WeaponProperties;
   ```

2. **Create Weapon Quality System**
   ```c
   typedef enum WeaponQuality {
       QUALITY_BROKEN = -2,     // -2 to attack/damage
       QUALITY_POOR = -1,       // -1 to attack/damage  
       QUALITY_COMMON = 0,      // Standard weapon
       QUALITY_FINE = 1,        // +1 to attack/damage
       QUALITY_MASTERWORK = 2,  // +2 to attack/damage
       QUALITY_MAGIC = 3        // Magic properties
   } WeaponQuality;
   
   typedef struct WeaponMaterial {
       char* name;              // "Iron", "Steel", "Mithril"
       float weight_modifier;   // Multiplier for weapon weight
       int hardness_bonus;      // Durability bonus
       int damage_modifier;     // Damage bonus/penalty
       int cost_multiplier;     // Cost multiplier
       bool is_magical;         // Requires magic to create
   } WeaponMaterial;
   ```

### Phase 3B: Weapon Generation Tables
3. **Create Starting Weapon Tables**
   - Implement `src/starting_weapon_tables.h` with probability tables
   - Define weapon distributions by character class/background
   - Add regional and cultural weapon preferences
   - Create wealth-based weapon quality distributions

   ```c
   typedef struct WeaponTableEntry {
       WeaponType weapon_type;
       WeaponQuality quality;
       int material_type;
       int probability_weight;   // For weighted random selection
       int min_wealth_level;     // Minimum wealth to access
       char** required_skills;   // Required proficiencies
   } WeaponTableEntry;
   
   typedef struct WeaponTable {
       char* table_name;         // "Fighter Starting", "Noble Starting"
       WeaponTableEntry* entries;
       int entry_count;
       int total_weight;         // Sum of all probability weights
   } WeaponTable;
   ```

4. **Implement Weapon Generation Functions**
   ```c
   Weapon* generate_starting_weapon(const Unit* character);
   Weapon* generate_random_weapon(WeaponQuality min_quality, WeaponQuality max_quality);
   Weapon* generate_weapon_by_type(WeaponType type, WeaponQuality quality);
   WeaponTable* get_weapon_table_for_class(int character_class);
   WeaponType select_weapon_from_table(const WeaponTable* table, int wealth_level);
   ```

### Phase 3C: Weapon Enhancement System
5. **Implement Weapon Enchantments**
   ```c
   typedef struct WeaponEnchantment {
       char* name;               // "Flaming", "Keen", "Vampiric"
       char* description;        // Full description of effect
       int enchantment_bonus;    // Magical bonus to attack/damage
       int special_damage_dice;  // Extra damage dice (for flaming, etc.)
       int special_damage_type;  // Fire, Cold, Lightning, etc.
       char** special_properties; // Special combat effects
       int property_count;
       int rarity;              // How rare this enchantment is
       bool requires_attunement; // D&D 5e style attunement
   } WeaponEnchantment;
   
   typedef struct Weapon {
       Item base_item;          // Inherit from base Item structure
       WeaponType weapon_type;
       WeaponProperties properties;
       WeaponQuality quality;
       WeaponMaterial* material;
       WeaponEnchantment** enchantments;
       int enchantment_count;
       int durability_current;   // Current condition
       int durability_max;       // Maximum durability
       bool is_identified;       // Magic items may be unidentified
   } Weapon;
   ```

6. **Create Magic Weapon Generation**
   - Implement magical weapon generation with rarity tables
   - Add combination rules for multiple enchantments
   - Create artifact and legendary weapon templates
   - Add cursed weapon generation

### Phase 3D: Integration with Character System
7. **Update Character Generation to Include Weapons**
   - Modify `src/main.c` to call weapon generation after stats
   - Integrate weapon generation with equipment generation
   - Add class proficiency checking for weapon assignment
   - Handle two-handed weapons and weapon + shield combinations

8. **Enhance Equipment Management**
   - Update gear array to distinguish weapons from other equipment
   - Add weapon slot management (main hand, off hand)
   - Implement weapon switching and readying mechanics
   - Add encumbrance calculations including weapon weight

### Phase 3E: Combat Integration and Display
9. **Create Weapon Combat Mechanics**
   ```c
   int calculate_weapon_damage(const Weapon* weapon, bool is_critical);
   int calculate_attack_bonus(const Weapon* weapon, const Unit* wielder);
   bool weapon_can_critical(const Weapon* weapon, int attack_roll);
   int get_weapon_reach(const Weapon* weapon);
   bool weapon_requires_ammunition(const Weapon* weapon);
   ```

10. **Implement Weapon Display and UI**
    - Add weapon-specific display in character sheet
    - Create weapon stat blocks with all properties
    - Add weapon comparison and evaluation tools
    - Implement weapon identification for magic items

11. **Add Weapon Persistence**
    - Extend JSON serialization to include weapon properties
    - Add weapon data to character save/load functions
    - Create weapon database for referencing weapon types
    - Add weapon import/export for progress-ii integration

## Dependencies
- Enhanced Item system to support weapon properties
- Random number generation for weapon selection
- Memory management for dynamic weapon structures
- JSON parsing for weapon data persistence
- UI framework for weapon display

## Verification Criteria
- Characters generate with appropriate starting weapons for their class
- Weapon properties correctly affect combat calculations
- Weapon quality and materials provide meaningful stat variations
- Magic weapons generate with balanced enchantments
- Weapon generation integrates smoothly with existing equipment system
- All weapon data persists correctly in save files

## Estimated Complexity
**Medium-High** - Involves:
- Complex data structure design and management
- Integration with multiple existing systems
- Random generation with weighted probabilities  
- Combat mechanics and balancing
- User interface and display components

## Related Issues
- Issue 006: Equipment generation system (provides base infrastructure)
- Issue 012: Character traits system (may influence weapon preferences)
- Issue 010: Lua integration (enables scripted weapon generation)
- Future: Combat system implementation
- Future: Weapon crafting and modification

## Notes
Start with basic weapon types and expand complexity. Balance is critical - weapons should feel meaningfully different without breaking game mechanics. Consider D&D 5e weapon properties as a reference but adapt for this system's needs.