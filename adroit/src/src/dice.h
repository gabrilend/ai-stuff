// {{{ dice.h - Dice rolling system
#ifndef DICE_H
#define DICE_H

#include <stdlib.h>
#include <time.h>

// {{{ Dice rolling functions
// Roll n dice with d sides, add modifier
int roll_dice(int n, int d, int modifier);

// Roll single die with d sides
int roll_d(int d);

// Common dice rolls
int roll_d6(void);
int roll_d20(void);
int roll_3d6(void);

// Roll and take highest/lowest
int roll_3d6_drop_lowest(void);
int roll_4d6_drop_lowest(void);
// }}}

// {{{ Random utilities
void init_random(void);
int random_range(int min, int max);
// }}}

// {{{ Dice namespace-style interface (like the original code)
typedef struct Dice {
    int (*roll)(int n, int d);
    int (*roll_with_modifier)(int n, int d, int modifier);
} Dice;

extern Dice dice;
// }}}

#endif // DICE_H
// }}}