// {{{ unit.h - Unit/Character definitions and management
#ifndef UNIT_H
#define UNIT_H

#include "item.h"

// {{{ Forward declarations
typedef struct Unit Unit;
typedef struct Building Building;
// }}}

// {{{ Stats enumeration  
enum Stats {
    HON = 0, /* HON is honor */
    STR = 1,
    DEX = 2,
    CON = 3,
    INT = 4,
    WIS = 5,
    CHA = 6
};
// }}}

// {{{ Character traits, emotions, opinions (placeholders)
typedef struct Traits {
    int placeholder; // TODO: Define trait system
} Traits;

typedef struct Emotions {
    int placeholder; // TODO: Define emotion system  
} Emotions;

typedef struct Opinions {
    int placeholder; // TODO: Define opinion system
} Opinions;

typedef struct Building {
    char* name;
    int type;
    // TODO: Define building system
} Building;
// }}}

// {{{ Unit structure
typedef struct Unit {
    char* name;
    int hp[2];              /* [current, max] */
    int stats[7];           /* 7 for ability scores + honor */
    Item* gear[20];         /* Equipment inventory */
    int gear_count[20];     /* Quantity of each item */
    int last_item;          /* Index of last item in inventory */
    int armour_bonus;       /* Total armor bonus from equipment */
    Traits traits;
    Emotions emotions;
    Opinions opinions;
    /* 1-5:---------- law
     *    6-15:------ neutrality  
     *        16-20:- chaos */
    int alignment;
    Unit* followers_array;  /* Array of follower units */
    Building* buildings_array; /* Array of owned buildings */
} Unit;
// }}}

// {{{ Unit management functions
Unit* init_unit(void);
void free_unit(Unit* unit);
Unit* clone_unit(const Unit* unit);
// }}}

// {{{ Character generation
typedef enum StatGenerationMethod {
    STAT_3D6 = 0,           // Straight 3d6
    STAT_3D6_DROP_LOWEST,   // 3d6 drop lowest (current default)  
    STAT_4D6_DROP_LOWEST,   // 4d6 drop lowest (heroic)
    STAT_POINT_BUY,         // Point buy system
    STAT_ARRAY              // Standard array (15,14,13,12,10,8)
} StatGenerationMethod;

char* get_random_name(void);
void set_random_stats(Unit* unit);
void set_stats_method(Unit* unit, StatGenerationMethod method);
void generate_starting_equipment(Unit* unit);
void generate_starting_weapon(Unit* unit);
// }}}

// {{{ Stat and combat functions
int get_bonus(const Unit* unit, enum Stats stat);
int get_defence(const Unit* unit, enum Stats stat);
int snatch_hp(Unit* unit, int val);
void unit_terminate(Unit* unit);
// }}}

// {{{ Item interaction functions
typedef void (*UnitItemFunction)(Unit* unit, Item* item);
typedef void (*UnitUnitFunction)(Unit* unit1, Unit* unit2);  
typedef void (*ItemItemFunction)(Item* item1, Item* item2);

void unit_item_run(Unit* unit, Item* item, UnitItemFunction f_ptr);
void unit_unit_run(Unit* unit1, Unit* unit2, UnitUnitFunction f_ptr);
void item_item_run(Item* item1, Item* item2, ItemItemFunction f_ptr);
// }}}

// {{{ Inventory management
Item* take_item(Unit* unit, Item* item);
Item* give_item(Unit* unit, Item* item);
// }}}

// {{{ Honor and social systems
void set_honor(Unit* unit, int val);
// }}}

// {{{ Combat functions  
void deal_damage(Unit* attacker, Unit* target, Item* weapon);
// }}}

#endif // UNIT_H
// }}}