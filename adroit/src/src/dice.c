// {{{ dice.c - Dice rolling implementation
#include "dice.h"
#include <time.h>
#include <stdlib.h>
#include <stdbool.h>

static bool random_initialized = false;

// {{{ init_random
void init_random(void) {
    if (!random_initialized) {
        srand((unsigned int)time(NULL));
        random_initialized = true;
    }
}
// }}}

// {{{ roll_dice
int roll_dice(int n, int d, int modifier) {
    if (n <= 0 || d <= 1) return modifier;
    
    int total = 0;
    for (int i = 0; i < n; i++) {
        total += (rand() % d) + 1;
    }
    return total + modifier;
}
// }}}

// {{{ roll_d
int roll_d(int d) {
    return roll_dice(1, d, 0);
}
// }}}

// {{{ Common dice rolls
int roll_d6(void) { return roll_d(6); }
int roll_d20(void) { return roll_d(20); }
int roll_3d6(void) { return roll_dice(3, 6, 0); }
// }}}

// {{{ roll_3d6_drop_lowest
int roll_3d6_drop_lowest(void) {
    int rolls[3];
    rolls[0] = roll_d6();
    rolls[1] = roll_d6(); 
    rolls[2] = roll_d6();
    
    // Find and remove lowest
    int lowest = rolls[0];
    int lowest_index = 0;
    for (int i = 1; i < 3; i++) {
        if (rolls[i] < lowest) {
            lowest = rolls[i];
            lowest_index = i;
        }
    }
    
    int total = 0;
    for (int i = 0; i < 3; i++) {
        if (i != lowest_index) {
            total += rolls[i];
        }
    }
    return total;
}
// }}}

// {{{ roll_4d6_drop_lowest
int roll_4d6_drop_lowest(void) {
    int rolls[4];
    for (int i = 0; i < 4; i++) {
        rolls[i] = roll_d6();
    }
    
    // Find lowest
    int lowest = rolls[0];
    int lowest_index = 0;
    for (int i = 1; i < 4; i++) {
        if (rolls[i] < lowest) {
            lowest = rolls[i];
            lowest_index = i;
        }
    }
    
    int total = 0;
    for (int i = 0; i < 4; i++) {
        if (i != lowest_index) {
            total += rolls[i];
        }
    }
    return total;
}
// }}}

// {{{ random_range
int random_range(int min, int max) {
    if (min >= max) return min;
    return min + (rand() % (max - min + 1));
}
// }}}

// {{{ Dice interface implementation
static int dice_roll(int n, int d) {
    return roll_dice(n, d, 0);
}

static int dice_roll_with_modifier(int n, int d, int modifier) {
    return roll_dice(n, d, modifier);
}

Dice dice = {
    .roll = dice_roll,
    .roll_with_modifier = dice_roll_with_modifier
};
// }}}