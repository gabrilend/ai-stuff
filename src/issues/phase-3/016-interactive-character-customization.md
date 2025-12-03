# Issue 016 - Implement Interactive Character Customization

## Current Behavior
The character generation system in `src/main.c` line 171 has a TODO comment:
```c
// TODO: Implement interactive point buy or random distribution
```
Currently, character stats are generated using one of the 5 random generation methods, but there's no way for users to:
- Choose their preferred stat generation method interactively
- Customize character stats through point-buy allocation
- Make interactive choices during character creation
- Manually assign stat arrays or modify generated stats
- Preview character builds before finalizing

## Intended Behavior
Implement a comprehensive interactive character creation system that allows players to:
- Choose between multiple character generation methods (random, point buy, standard array, etc.)
- Interactively allocate points in a point-buy system
- Preview how stat allocations affect character capabilities
- Customize character background, name, and appearance
- Make informed decisions about character build optimization
- Save and load character templates for reuse

## Suggested Implementation Steps

### Phase 3A: Interactive Interface Framework
1. **Create Character Creation Menu System**
   ```c
   typedef enum CreationMethod {
       METHOD_RANDOM_4D6_DROP_LOWEST,
       METHOD_RANDOM_3D6_STRAIGHT,
       METHOD_RANDOM_2D6_PLUS_6,
       METHOD_RANDOM_4D6_REROLL_ONES,
       METHOD_RANDOM_3D6_6_TIMES,
       METHOD_POINT_BUY,
       METHOD_STANDARD_ARRAY,
       METHOD_CUSTOM_VALUES,
       METHOD_COUNT
   } CreationMethod;
   
   typedef struct CreationOptions {
       CreationMethod method;
       int point_buy_budget;       // Points available for point buy
       bool allow_stat_rerolls;    // Can reroll individual stats
       int max_rerolls;            // Maximum reroll attempts
       bool enforce_minimums;      // Minimum stat requirements
       bool enforce_maximums;      // Maximum stat limits
       bool show_racial_modifiers; // Display racial stat bonuses
   } CreationOptions;
   ```

2. **Implement Interactive Menu Functions**
   ```c
   CreationMethod display_method_selection_menu(void);
   CreationOptions configure_creation_options(CreationMethod method);
   bool confirm_character_creation(const Unit* character);
   void display_stat_preview(const int* stats, CreationMethod method);
   ```

### Phase 3B: Point Buy System Implementation
3. **Design Point Buy Mechanics**
   ```c
   typedef struct PointBuyState {
       int stats[7];               // Current stat allocations
       int points_spent;           // Points used so far
       int points_available;       // Total points for allocation
       int base_stat_cost[21];     // Cost table for stats 8-18
       int racial_modifiers[7];    // Racial bonuses if applicable
       bool is_valid_build;        // All requirements met
   } PointBuyState;
   
   int calculate_stat_cost(int stat_value);
   int calculate_total_cost(const int* stats);
   bool can_increase_stat(const PointBuyState* state, int stat_index);
   bool can_decrease_stat(const PointBuyState* state, int stat_index);
   PointBuyState* create_point_buy_state(int total_points);
   ```

4. **Implement Point Buy Interface**
   ```c
   void display_point_buy_interface(PointBuyState* state);
   bool process_point_buy_input(PointBuyState* state, char input);
   void show_point_buy_help(void);
   bool finalize_point_buy(PointBuyState* state, Unit* character);
   
   // Interactive point allocation
   bool increase_stat(PointBuyState* state, int stat_index);
   bool decrease_stat(PointBuyState* state, int stat_index);
   void reset_point_buy(PointBuyState* state);
   void optimize_point_buy_for_class(PointBuyState* state, int character_class);
   ```

### Phase 3C: Advanced Customization Options
5. **Implement Standard Array System**
   ```c
   typedef struct StandardArray {
       int stat_values[6];         // Predefined values: 15,14,13,12,10,8
       int assignments[7];         // Which value goes to which stat
       bool used_values[6];        // Track which values are assigned
   } StandardArray;
   
   StandardArray* create_standard_array(void);
   void display_array_assignment(const StandardArray* array);
   bool assign_value_to_stat(StandardArray* array, int value_index, int stat_index);
   bool validate_array_assignment(const StandardArray* array);
   ```

6. **Add Custom Value Entry**
   ```c
   typedef struct CustomStats {
       int desired_stats[7];
       int stat_limits[2];         // [minimum, maximum] allowed
       bool enforce_total_limit;   // Limit total stat points
       int max_total_stats;        // Maximum sum of all stats
   } CustomStats;
   
   CustomStats* create_custom_stats(void);
   bool set_custom_stat(CustomStats* custom, int stat_index, int value);
   bool validate_custom_stats(const CustomStats* custom);
   void apply_custom_stats(const CustomStats* custom, Unit* character);
   ```

### Phase 3D: Character Preview and Validation
7. **Implement Character Build Preview**
   ```c
   typedef struct CharacterPreview {
       int final_stats[7];         // Stats after all modifiers
       int hp_total;               // Calculated hit points
       int ac_base;                // Base armor class
       float carry_capacity;       // Weight carrying capacity
       char** skill_modifiers;     // Calculated skill bonuses
       char** saving_throws;       // Saving throw bonuses
       char* build_summary;        // Text description of build
   } CharacterPreview;
   
   CharacterPreview* generate_character_preview(const int* stats, 
                                               int character_class,
                                               int character_race);
   void display_character_preview(const CharacterPreview* preview);
   void display_stat_comparison(const int* stats1, const int* stats2);
   ```

8. **Add Build Optimization Suggestions**
   ```c
   typedef struct BuildSuggestion {
       char* suggestion_text;      // "Consider increasing STR for melee"
       int suggested_changes[7];   // Recommended stat adjustments
       float effectiveness_rating; // 0-100% build effectiveness
       char** synergies;          // List of stat synergies
       char** warnings;           // Potential build problems
   } BuildSuggestion;
   
   BuildSuggestion* analyze_character_build(const int* stats, int character_class);
   void display_build_suggestions(const BuildSuggestion* suggestions);
   ```

### Phase 3E: Character Templates and Presets
9. **Implement Character Templates**
   ```c
   typedef struct CharacterTemplate {
       char* template_name;        // "Fighter Tank", "Sneaky Rogue"
       char* description;          // Template description
       int recommended_stats[7];   // Suggested stat array
       CreationMethod creation_method;
       char* equipment_suggestions;
       char* gameplay_tips;
   } CharacterTemplate;
   
   CharacterTemplate** load_character_templates(int* template_count);
   void display_template_menu(CharacterTemplate** templates, int count);
   bool apply_template(const CharacterTemplate* template, Unit* character);
   CharacterTemplate* create_custom_template(const Unit* character);
   ```

10. **Add Template Management**
    ```c
    bool save_character_template(const CharacterTemplate* template);
    bool load_character_template(const char* filename, CharacterTemplate* template);
    void list_available_templates(void);
    bool delete_character_template(const char* template_name);
    ```

### Phase 3F: Enhanced User Experience
11. **Implement Reroll and Modification Options**
    ```c
    typedef struct RerollOptions {
        bool allow_individual_rerolls;  // Reroll one stat at a time
        bool allow_full_rerolls;        // Reroll entire stat set
        int rerolls_remaining;          // Reroll budget
        bool keep_highest;              // Option to keep best of multiple rolls
        int generations_to_compare;     // Generate N sets, pick best
    } RerollOptions;
    
    bool reroll_individual_stat(Unit* character, int stat_index, CreationMethod method);
    bool reroll_all_stats(Unit* character, CreationMethod method);
    void display_reroll_options(const RerollOptions* options);
    ```

12. **Add Character Creation Workflow**
    ```c
    typedef enum CreationStep {
        STEP_METHOD_SELECTION,
        STEP_STAT_GENERATION,
        STEP_STAT_ADJUSTMENT,
        STEP_CHARACTER_DETAILS,
        STEP_EQUIPMENT_SELECTION,
        STEP_FINAL_REVIEW,
        STEP_COMPLETE
    } CreationStep;
    
    CreationStep process_character_creation_step(CreationStep current_step, Unit* character);
    void display_creation_progress(CreationStep current_step);
    bool allow_step_navigation(CreationStep from_step, CreationStep to_step);
    ```

## Dependencies
- Enhanced UI system for interactive menus and navigation
- Input handling for keyboard/mouse interaction
- Character validation and constraint checking
- Template storage system (JSON files)
- Integration with existing character generation functions

## Verification Criteria
- Point buy system correctly calculates costs and enforces limits
- Standard array assignment works for all stat combinations
- Custom value entry validates input ranges appropriately
- Character previews accurately reflect final character capabilities
- Templates save and load correctly with all data preserved
- Reroll options respect configured limits and methods
- User can navigate freely between creation steps
- All creation methods produce valid, balanced characters

## Estimated Complexity
**Medium-High** - Involves:
- Complex user interface and input handling
- Mathematical modeling for point costs and validation
- State management across multiple creation steps
- File I/O for template persistence
- Integration with multiple existing systems
- User experience design and flow optimization

## Related Issues
- Issue 012: Character traits (may be selectable during creation)
- Issue 013: Weapon generation (starting weapon selection)
- Issue 015: Building system (may affect character backgrounds)
- Future: Character advancement and level progression
- Future: Multiplayer character sharing and comparison

## Notes
This system transforms character creation from a passive random process to an engaging, strategic decision-making experience. Focus on clear user feedback and intuitive navigation. Consider accessibility features and support for both mouse and keyboard interaction. The point-buy system should be mathematically balanced to prevent overpowered characters while allowing meaningful customization.