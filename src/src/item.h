// {{{ item.h - Item definitions and equipment system
#ifndef ITEM_H
#define ITEM_H

// {{{ Item structure
typedef struct Item {
    char* name;
    int damage;
    int armor_bonus;
    int weight;
    int value;
    char* description;
} Item;
// }}}

// {{{ Equipment type enumeration
typedef enum EquipmentType {
    EQUIPMENT_WEAPON,
    EQUIPMENT_ARMOR,
    EQUIPMENT_HELMET,
    EQUIPMENT_SHIELD,
    EQUIPMENT_TOOL,
    EQUIPMENT_MISC
} EquipmentType;
// }}}

// {{{ Predefined items - Armor
extern Item GAMBESON;
extern Item BRIGANDINE;
extern Item CHAIN_SHIRT;
// }}}

// {{{ Predefined items - Helmets and Shields  
extern Item HELMET;
extern Item SHIELD;
extern Item HELMET_AND_SHIELD;
// }}}

// {{{ Predefined items - Dungeoneering Gear
extern Item ROPE;
extern Item PULLEYS;
extern Item CANDLES;
extern Item CHAIN;
extern Item CHALK;
extern Item CROWBAR;
extern Item TINDERBOX;
extern Item GRAPPLING_HOOK;
extern Item HAMMER;
extern Item WATERSKIN;
extern Item LANTERN;
extern Item LAMP_OIL;
extern Item PADLOCK;
extern Item MANACLES;
extern Item MIRROR;
extern Item POLE;
extern Item SACK;
extern Item TENT;
extern Item SPIKES;
extern Item TORCHES;
// }}}

// {{{ Predefined items - General Gear 1
extern Item AIR_BLADDER;
extern Item BEAR_TRAP;
extern Item SHOVEL;
extern Item BELLOWS;
extern Item GREASE;
extern Item SAW;
extern Item BUCKET;
extern Item CALTROPS;
extern Item CHISEL;
extern Item DRILL;
extern Item FISHING_ROD;
extern Item MARBLES;
extern Item GLUE;
extern Item PICK;
extern Item HOURGLASS;
extern Item NET;
extern Item TONGS;
extern Item LOCKPICKS;
extern Item METAL_FILE;
extern Item NAILS;
// }}}

// {{{ Predefined items - General Gear 2
extern Item INCENSE;
extern Item SPONGE;
extern Item LENS;
extern Item PERFUME;
extern Item HORN;
extern Item BOTTLE;
extern Item SOAP;
extern Item SPYGLASS;
extern Item TAR_POT;
extern Item TWINE;
extern Item FAKE_JEWELS;
extern Item BLANK_BOOK;
extern Item CARD_DECK;
extern Item DICE_SET;
extern Item COOK_POTS;
extern Item FACE_PAINT;
extern Item WHISTLE;
extern Item INSTRUMENT;
extern Item QUILL_AND_INK;
extern Item SMALL_BELL;
// }}}

// {{{ Special items
extern Item RATIONS;
// }}}

// {{{ Item management functions
Item* create_item(const char* name, int damage, int armor_bonus, int weight, int value, const char* description);
void free_item(Item* item);
Item* clone_item(const Item* item);
// }}}

// {{{ Item initialization
void initialize_all_items(void);
void cleanup_all_items(void);
// }}}

#endif // ITEM_H
// }}}