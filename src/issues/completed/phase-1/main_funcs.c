#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pthread.h"
#include "raylib.h"
#include "unit.h"
#include "item.h" 
#include "dice.h"
#include "starting_gear_tables.h"

// {{{ Global state for character display
typedef struct GameState {
    Unit* current_character;
    bool character_updated;
    bool should_exit;
    pthread_mutex_t mutex;
} GameState;

static GameState g_game_state = {0};
// }}}

// {{{ Game state management
void init_game_state(void) {
    pthread_mutex_init(&g_game_state.mutex, NULL);
    g_game_state.current_character = NULL;
    g_game_state.character_updated = false;
    g_game_state.should_exit = false;
}

void cleanup_game_state(void) {
    pthread_mutex_destroy(&g_game_state.mutex);
    if (g_game_state.current_character) {
        if (g_game_state.current_character->name) {
            free(g_game_state.current_character->name);
        }
        free(g_game_state.current_character);
    }
}

void update_character(Unit* new_character) {
    pthread_mutex_lock(&g_game_state.mutex);
    
    // Free old character if exists
    if (g_game_state.current_character) {
        if (g_game_state.current_character->name) {
            free(g_game_state.current_character->name);
        }
        free(g_game_state.current_character);
    }
    
    g_game_state.current_character = new_character;
    g_game_state.character_updated = true;
    
    pthread_mutex_unlock(&g_game_state.mutex);
}

Unit* get_current_character_copy(void) {
    pthread_mutex_lock(&g_game_state.mutex);
    
    Unit* copy = NULL;
    if (g_game_state.current_character) {
        copy = malloc(sizeof(Unit));
        if (copy) {
            memcpy(copy, g_game_state.current_character, sizeof(Unit));
            // Copy the name string
            if (g_game_state.current_character->name) {
                copy->name = malloc(strlen(g_game_state.current_character->name) + 1);
                if (copy->name) {
                    strcpy(copy->name, g_game_state.current_character->name);
                }
            }
        }
    }
    
    pthread_mutex_unlock(&g_game_state.mutex);
    return copy;
}

bool should_exit_game(void) {
    pthread_mutex_lock(&g_game_state.mutex);
    bool exit = g_game_state.should_exit;
    pthread_mutex_unlock(&g_game_state.mutex);
    return exit;
}

void set_exit_game(bool exit) {
    pthread_mutex_lock(&g_game_state.mutex);
    g_game_state.should_exit = exit;
    pthread_mutex_unlock(&g_game_state.mutex);
}
// }}}

// {{{ init_unit
Unit* init_unit(void) {
    Unit* unit = malloc(sizeof(Unit));
    if (!unit) return NULL;
    
    memset(unit, 0, sizeof(Unit));
    unit->name = get_random_name();
    set_random_stats(unit);
    generate_starting_equipment(unit);
    generate_starting_weapon(unit);
    unit->hp[1] = 10 + get_bonus(unit, CON); // Max HP
    unit->hp[0] = unit->hp[1]; // Current HP
    
    return unit;
}
// }}}

// {{{ get_random_name
char* get_random_name(void){
    char* name = malloc(64);
    if (!name) return NULL;
    strcpy(name, "butts mcgee");
    return name;
}
// }}}

// {{{ set_random_stats
void set_random_stats(Unit* unit){
    // Initialize random if not already done
    init_random();
    
    // Generate HON (Honor) stat first - typically 3d6
    unit->stats[HON] = roll_3d6();
    
    // Generate ability scores using 3d6 drop lowest for each
    unit->stats[STR] = roll_3d6_drop_lowest();
    unit->stats[DEX] = roll_3d6_drop_lowest();
    unit->stats[CON] = roll_3d6_drop_lowest();
    unit->stats[INT] = roll_3d6_drop_lowest();
    unit->stats[WIS] = roll_3d6_drop_lowest();
    unit->stats[CHA] = roll_3d6_drop_lowest();
    
    // Ensure all stats are within valid bounds (3-18)
    for (int i = 0; i < 7; i++) {
        if (unit->stats[i] < 3) unit->stats[i] = 3;
        if (unit->stats[i] > 18) unit->stats[i] = 18;
    }
}
// }}}

// {{{ set_stats_method
void set_stats_method(Unit* unit, StatGenerationMethod method) {
    init_random();
    
    switch (method) {
        case STAT_3D6:
            unit->stats[HON] = roll_3d6();
            for (int i = STR; i <= CHA; i++) {
                unit->stats[i] = roll_3d6();
            }
            break;
            
        case STAT_3D6_DROP_LOWEST:
            set_random_stats(unit);  // Use existing implementation
            return;
            
        case STAT_4D6_DROP_LOWEST:
            unit->stats[HON] = roll_3d6();
            for (int i = STR; i <= CHA; i++) {
                unit->stats[i] = roll_4d6_drop_lowest();
            }
            break;
            
        case STAT_POINT_BUY:
            // Point buy: Start with 8s, spend 27 points
            for (int i = HON; i <= CHA; i++) {
                unit->stats[i] = 8;
            }
            // TODO: Implement interactive point buy or random distribution
            unit->stats[HON] = 10;  // Default honor
            break;
            
        case STAT_ARRAY:
            // Standard array: 15, 14, 13, 12, 10, 8 (randomly assigned)
            int standard_array[] = {15, 14, 13, 12, 10, 8};
            unit->stats[HON] = 10;  // Fixed honor
            
            // Shuffle and assign to ability scores
            for (int i = STR; i <= CHA; i++) {
                int index = random_range(0, 5 - (i - STR));
                unit->stats[i] = standard_array[index];
                // Shift remaining elements
                for (int j = index; j < 5 - (i - STR); j++) {
                    standard_array[j] = standard_array[j + 1];
                }
            }
            break;
    }
    
    // Ensure all stats are within valid bounds (3-18)
    for (int i = 0; i < 7; i++) {
        if (unit->stats[i] < 3) unit->stats[i] = 3;
        if (unit->stats[i] > 18) unit->stats[i] = 18;
    }
}
// }}}

// {{{ get_bonus and get_defence
int get_bonus(const Unit* unit, enum Stats stat){ 
    // D&D-style ability modifier: (stat - 10) / 2 
    return (unit->stats[stat] - 10) / 2;
}

int get_defence(const Unit* unit, enum Stats stat){ 
    return unit->stats[stat] + 10; 
}
// }}}

// {{{ generate_starting_equipment
#include "starting_gear_tables.h"
void generate_starting_equipment(Unit* unit){
    unit->gear[unit->last_item] = &RATIONS;
    unit->gear_count[unit->last_item] = 2;
    unit->last_item += 1;
    
    /* FIXME: unit gear assigned in error when multiple items are   */
    /*        used. for example: 2x rations when starting new char   */
    /*        and rolling for armor that might be NULL like armor   */
    unit->gear[unit->last_item++] = starting_armor[dice.roll(1, 20) - 1];
    unit->gear[unit->last_item++] = starting_HandS[dice.roll(1, 20) - 1];
    unit->gear[unit->last_item++] = starting_Dgear[dice.roll(1, 20) - 1];
    unit->gear[unit->last_item++] = starting_gear1[dice.roll(1, 20) - 1];
    unit->gear[unit->last_item++] = starting_gear2[dice.roll(1, 20) - 1];
}
// }}}

// {{{ generate_starting_weapon
#include "starting_weapon_tables.h"
void generate_starting_weapon(Unit* unit){
    /* TODO: Implement weapon generation */
}
// }}}

// {{{ snatch_hp
int snatch_hp(Unit* unit, int val){
    unit->hp[0] = unit->hp[0] + val;
    if (unit->hp[0] > unit->hp[1])
        { unit->hp[0] = unit->hp[1]; }
    else if (unit->hp[0] < 1) { unit_terminate(unit); }
    return unit->hp[0];
}
// }}}

/* only connect things if they're related, preferrably if they're the same */
/* for example, unit.hp[0] < 1 is not connected to the 1 above because ... */

// {{{ unit_item_run
void unit_item_run(Unit* unit, Item* item, UnitItemFunction f_ptr){
    f_ptr(unit, item);
}
// }}}

// {{{ unit_unit_run
void unit_unit_run(Unit* unit1, Unit* unit2, UnitUnitFunction f_ptr){
    f_ptr(unit1, unit2);
}
// }}}

// {{{ item_item_run
void item_item_run(Item* item1, Item* item2, ItemItemFunction f_ptr){
    f_ptr(item1, item2);
}
// }}}

/* run functions */
// {{{ take_item
Item* take_item(Unit* unit, Item* item){
    for (int i = 19; i > 0; i--){ 
        if (unit->gear[i] == item){ 
            unit->gear[i] = NULL;
            return item; 
        } 
    }
    return NULL;
}
// }}}
/* starts from the end first because ... */ 
/* if an item is dropped, it's still stored in inventory */
/* if it's not taken care of... */
/* it can get incinerated */

/* or taken */

// {{{ give_item
Item* give_item(Unit* unit, Item* item){
    for (int i = 0; i < 20; i++){ 
        if (unit->gear[i] == NULL){ 
            unit->gear[i] = item;
            return item; 
        } 
    }
    return NULL;
}
// }}}

// {{{ set_honor
void set_honor(Unit* unit, int val){
    if (unit->stats[0] < val)
        {unit->stats[0] = val;} else --unit->stats[0];
}
// }}}

/* when people have low honor... they're less likely to be cooperated with */

// {{{ deal_damage
void deal_damage(Unit* attacker, Unit* target, Item* weapon){
    int damage = weapon ? weapon->damage : 1;
    target->hp[0] -= damage;
    if (target->hp[0] < 1) unit_terminate(target);
}
// }}}

// {{{ unit_terminate
void unit_terminate(Unit* unit){
    unit->hp[0] = 0;
    // TODO: Handle unit death, drop items, etc.
}
// }}}

// {{{ Character display functions
const char* stat_names[] = {"HON", "STR", "DEX", "CON", "INT", "WIS", "CHA"};

void draw_character_stats(Unit* character, int x, int y) {
    if (!character) return;
    
    // Character name
    DrawText(TextFormat("Name: %s", character->name ? character->name : "Unknown"), 
             x, y, 20, DARKBLUE);
    y += 30;
    
    // HP
    DrawText(TextFormat("HP: %d/%d", character->hp[0], character->hp[1]), 
             x, y, 18, RED);
    y += 25;
    
    // Stats
    DrawText("Stats:", x, y, 18, DARKGREEN);
    y += 25;
    
    for (int i = 0; i < 7; i++) {
        int bonus = get_bonus(character, i);
        Color color = (bonus >= 0) ? DARKGREEN : MAROON;
        DrawText(TextFormat("%s: %2d (%+d)", stat_names[i], character->stats[i], bonus),
                 x + 20, y, 16, color);
        y += 20;
    }
}

void draw_character_equipment(Unit* character, int x, int y) {
    if (!character) return;
    
    DrawText("Equipment:", x, y, 18, DARKBROWN);
    y += 25;
    
    if (character->last_item == 0) {
        DrawText("  No equipment", x + 20, y, 14, GRAY);
        return;
    }
    
    for (int i = 0; i < character->last_item && i < 20; i++) {
        if (character->gear[i] && character->gear[i]->name) {
            if (character->gear_count[i] > 1) {
                DrawText(TextFormat("  %s x%d", character->gear[i]->name, character->gear_count[i]),
                         x + 20, y, 14, DARKPURPLE);
            } else {
                DrawText(TextFormat("  %s", character->gear[i]->name),
                         x + 20, y, 14, DARKPURPLE);
            }
            y += 18;
        }
    }
}

void draw_instructions(int x, int y) {
    DrawText("Controls:", x, y, 18, DARKBLUE);
    y += 25;
    DrawText("  SPACE - Generate new character", x + 20, y, 14, BLUE);
    y += 18;
    DrawText("  1-5   - Use different stat methods", x + 20, y, 14, BLUE);
    y += 18;
    DrawText("  ESC   - Exit", x + 20, y, 14, BLUE);
    y += 18;
    
    DrawText("Stat Generation Methods:", x, y + 10, 14, GRAY);
    y += 30;
    DrawText("  1 - 3d6 Straight", x + 20, y, 12, GRAY);
    y += 15;
    DrawText("  2 - 3d6 Drop Lowest", x + 20, y, 12, GRAY);
    y += 15;
    DrawText("  3 - 4d6 Drop Lowest", x + 20, y, 12, GRAY);
    y += 15;
    DrawText("  4 - Point Buy", x + 20, y, 12, GRAY);
    y += 15;
    DrawText("  5 - Standard Array", x + 20, y, 12, GRAY);
}
// }}}

// {{{ draw
void* draw(void* args){
    const int screenWidth = 1000;
    const int screenHeight = 700;

    InitWindow(screenWidth, screenHeight, "Adroit - RPG Character Generator");

    SetTargetFPS(60);

    Unit* display_character = NULL;

    while (!WindowShouldClose() && !should_exit_game())
    {
        // Handle input
        if (IsKeyPressed(KEY_SPACE)) {
            Unit* new_char = init_unit();
            if (new_char) {
                update_character(new_char);
            }
        }
        
        // Handle stat generation method keys
        if (IsKeyPressed(KEY_ONE)) {
            Unit* new_char = init_unit();
            if (new_char) {
                set_stats_method(new_char, STAT_3D6);
                new_char->hp[1] = 10 + get_bonus(new_char, CON);
                new_char->hp[0] = new_char->hp[1];
                update_character(new_char);
            }
        }
        if (IsKeyPressed(KEY_TWO)) {
            Unit* new_char = init_unit();
            if (new_char) {
                set_stats_method(new_char, STAT_3D6_DROP_LOWEST);
                new_char->hp[1] = 10 + get_bonus(new_char, CON);
                new_char->hp[0] = new_char->hp[1];
                update_character(new_char);
            }
        }
        if (IsKeyPressed(KEY_THREE)) {
            Unit* new_char = init_unit();
            if (new_char) {
                set_stats_method(new_char, STAT_4D6_DROP_LOWEST);
                new_char->hp[1] = 10 + get_bonus(new_char, CON);
                new_char->hp[0] = new_char->hp[1];
                update_character(new_char);
            }
        }
        if (IsKeyPressed(KEY_FOUR)) {
            Unit* new_char = init_unit();
            if (new_char) {
                set_stats_method(new_char, STAT_POINT_BUY);
                new_char->hp[1] = 10 + get_bonus(new_char, CON);
                new_char->hp[0] = new_char->hp[1];
                update_character(new_char);
            }
        }
        if (IsKeyPressed(KEY_FIVE)) {
            Unit* new_char = init_unit();
            if (new_char) {
                set_stats_method(new_char, STAT_ARRAY);
                new_char->hp[1] = 10 + get_bonus(new_char, CON);
                new_char->hp[0] = new_char->hp[1];
                update_character(new_char);
            }
        }
        
        if (IsKeyPressed(KEY_ESCAPE)) {
            set_exit_game(true);
        }
        
        // Get updated character data
        if (display_character) {
            if (display_character->name) free(display_character->name);
            free(display_character);
        }
        display_character = get_current_character_copy();

        BeginDrawing();
            ClearBackground(RAYWHITE);
            
            // Title
            DrawText("ADROIT - RPG Character Generator", 20, 20, 28, DARKBLUE);
            DrawLine(20, 55, screenWidth - 20, 55, LIGHTGRAY);
            
            if (display_character) {
                // Character stats (left column)
                draw_character_stats(display_character, 50, 80);
                
                // Character equipment (middle column)  
                draw_character_equipment(display_character, 350, 80);
                
                // Instructions (right column)
                draw_instructions(650, 80);
            } else {
                DrawText("Press SPACE to generate your first character!", 
                         50, 200, 20, DARKGREEN);
                draw_instructions(50, 250);
            }
            
            // Footer
            DrawText("Integrated Module Framework - Phase 1 Complete", 
                     20, screenHeight - 25, 12, GRAY);
        EndDrawing();
    }
    
    // Cleanup display character
    if (display_character) {
        if (display_character->name) free(display_character->name);
        free(display_character);
    }

    CloseWindow();
    return NULL;
}
// }}}

// {{{ game
void* game(void* args){
    return NULL;
}
// }}}

// main() function removed for demo compilation
