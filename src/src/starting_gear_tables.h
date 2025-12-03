// {{{ starting_gear_tables.h - Equipment generation tables
#ifndef STARTING_GEAR_TABLES_H
#define STARTING_GEAR_TABLES_H

#include "item.h"

// {{{ External declarations for equipment arrays
extern Item* starting_armor[20];
extern Item* starting_HandS[20];  // Helmets and Shields
extern Item* starting_Dgear[20];  // Dungeoneering gear
extern Item* starting_gear1[20];  // General gear 1
extern Item* starting_gear2[20];  // General gear 2
// }}}

// {{{ Initialization function
void initialize_starting_tables(void);
// }}}

#endif // STARTING_GEAR_TABLES_H
// }}}