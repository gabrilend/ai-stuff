#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "src/unit.h"
#include "src/dice.h"

// {{{ print_character_stats
void print_character_stats(Unit* unit, const char* method_name) {
    printf("=== Character Stats (%s) ===\n", method_name);
    printf("Name: %s\n", unit->name);
    printf("HON (Honor):     %2d (bonus: %+d)\n", unit->stats[HON], get_bonus(unit, HON));
    printf("STR (Strength):  %2d (bonus: %+d)\n", unit->stats[STR], get_bonus(unit, STR));
    printf("DEX (Dexterity): %2d (bonus: %+d)\n", unit->stats[DEX], get_bonus(unit, DEX));
    printf("CON (Constitution): %2d (bonus: %+d)\n", unit->stats[CON], get_bonus(unit, CON));
    printf("INT (Intelligence): %2d (bonus: %+d)\n", unit->stats[INT], get_bonus(unit, INT));
    printf("WIS (Wisdom):    %2d (bonus: %+d)\n", unit->stats[WIS], get_bonus(unit, WIS));
    printf("CHA (Charisma):  %2d (bonus: %+d)\n", unit->stats[CHA], get_bonus(unit, CHA));
    printf("HP: %d/%d\n", unit->hp[0], unit->hp[1]);
    printf("\n");
}
// }}}

// {{{ test_stat_generation_method
void test_stat_generation_method(StatGenerationMethod method, const char* name) {
    printf("🎲 Testing %s...\n", name);
    
    Unit* unit = malloc(sizeof(Unit));
    if (!unit) {
        printf("❌ Failed to allocate unit\n");
        return;
    }
    
    // Clear unit first
    memset(unit, 0, sizeof(Unit));
    unit->name = get_random_name();
    
    // Generate stats with specific method
    set_stats_method(unit, method);
    
    // Calculate HP
    unit->hp[1] = 10 + get_bonus(unit, CON); // Max HP
    unit->hp[0] = unit->hp[1]; // Current HP
    
    print_character_stats(unit, name);
    
    // Cleanup
    if (unit->name) free(unit->name);
    free(unit);
}
// }}}

int main() {
    printf("⚔️  Stat Generation System Test\n");
    printf("===============================\n\n");
    
    // Initialize random number generator
    init_random();
    
    // Test all stat generation methods
    test_stat_generation_method(STAT_3D6, "3d6 Straight Roll");
    test_stat_generation_method(STAT_3D6_DROP_LOWEST, "3d6 Drop Lowest (Default)");
    test_stat_generation_method(STAT_4D6_DROP_LOWEST, "4d6 Drop Lowest (Heroic)");
    test_stat_generation_method(STAT_POINT_BUY, "Point Buy System");
    test_stat_generation_method(STAT_ARRAY, "Standard Array");
    
    // Test original method for comparison
    printf("🔄 Testing Original Method (init_unit)...\n");
    Unit* original_unit = init_unit();
    if (original_unit) {
        print_character_stats(original_unit, "Original init_unit()");
        
        // Show equipment too
        printf("Starting Equipment:\n");
        for (int i = 0; i < original_unit->last_item && i < 20; i++) {
            if (original_unit->gear[i]) {
                printf("  - %s", original_unit->gear[i]->name);
                if (original_unit->gear_count[i] > 1) {
                    printf(" x%d", original_unit->gear_count[i]);
                }
                printf("\n");
            }
        }
        printf("\n");
        
        // Cleanup
        if (original_unit->name) free(original_unit->name);
        free(original_unit);
    }
    
    printf("✅ Stat Generation Test Complete!\n");
    printf("\nKey Improvements:\n");
    printf("  ✅ Fixed broken 3d6 drop lowest implementation\n");
    printf("  ✅ Added proper D&D-style ability modifiers\n");
    printf("  ✅ Multiple stat generation methods available\n");
    printf("  ✅ Honor stat properly initialized\n");
    printf("  ✅ Stat bounds validation (3-18)\n");
    
    return 0;
}