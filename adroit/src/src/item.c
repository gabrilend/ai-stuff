// {{{ item.c - Item definitions and management
#include "item.h"
#include <stdlib.h>
#include <string.h>

// {{{ Predefined items - Armor
Item GAMBESON = {"Gambeson", 0, 1, 5, 20, "Padded cloth armor"};
Item BRIGANDINE = {"Brigandine", 0, 2, 15, 100, "Steel-studded leather armor"};
Item CHAIN_SHIRT = {"Chain Shirt", 0, 3, 25, 200, "Mail armor covering the torso"};
// }}}

// {{{ Predefined items - Helmets and Shields
Item HELMET = {"Helmet", 0, 1, 3, 30, "Steel cap protecting the head"};
Item SHIELD = {"Shield", 0, 1, 8, 25, "Wooden shield with iron rim"};
Item HELMET_AND_SHIELD = {"Helmet and Shield", 0, 2, 11, 55, "Complete head and arm protection"};
// }}}

// {{{ Predefined items - Dungeoneering Gear
Item ROPE = {"Rope", 0, 0, 2, 5, "50 feet of hemp rope"};
Item PULLEYS = {"Pulleys", 0, 0, 2, 15, "Block and tackle system"};
Item CANDLES = {"Candles", 0, 0, 1, 2, "Wax candles for light"};
Item CHAIN = {"Chain", 0, 0, 5, 20, "10 feet of iron chain"};
Item CHALK = {"Chalk", 0, 0, 0, 1, "Marking chalk"};
Item CROWBAR = {"Crowbar", 2, 0, 3, 8, "Iron prying tool"};
Item TINDERBOX = {"Tinderbox", 0, 0, 1, 3, "Flint and steel for fire"};
Item GRAPPLING_HOOK = {"Grappling Hook", 1, 0, 4, 12, "Four-pronged climbing hook"};
Item HAMMER = {"Hammer", 1, 0, 2, 5, "Carpenter's hammer"};
Item WATERSKIN = {"Waterskin", 0, 0, 2, 3, "Leather water container"};
Item LANTERN = {"Lantern", 0, 0, 2, 10, "Hooded lamp"};
Item LAMP_OIL = {"Lamp Oil", 0, 0, 1, 2, "Fuel for lanterns"};
Item PADLOCK = {"Padlock", 0, 0, 1, 15, "Small iron lock"};
Item MANACLES = {"Manacles", 0, 0, 2, 25, "Iron shackles"};
Item MIRROR = {"Mirror", 0, 0, 1, 20, "Polished steel mirror"};
Item POLE = {"Pole", 1, 0, 8, 3, "10-foot wooden pole"};
Item SACK = {"Sack", 0, 0, 1, 1, "Large cloth bag"};
Item TENT = {"Tent", 0, 0, 10, 15, "Two-person shelter"};
Item SPIKES = {"Spikes", 1, 0, 3, 5, "Iron pitons and spikes"};
Item TORCHES = {"Torches", 1, 0, 2, 2, "Pitch-soaked torches"};
// }}}

// {{{ Predefined items - General Gear 1
Item AIR_BLADDER = {"Air Bladder", 0, 0, 1, 5, "Inflatable float"};
Item BEAR_TRAP = {"Bear Trap", 8, 0, 15, 30, "Spring-loaded jaw trap"};
Item SHOVEL = {"Shovel", 2, 0, 5, 8, "Digging tool"};
Item BELLOWS = {"Bellows", 0, 0, 3, 12, "Fire-starting bellows"};
Item GREASE = {"Grease", 0, 0, 1, 3, "Slippery animal fat"};
Item SAW = {"Saw", 1, 0, 3, 10, "Woodcutting saw"};
Item BUCKET = {"Bucket", 1, 0, 2, 3, "Wooden water bucket"};
Item CALTROPS = {"Caltrops", 1, 0, 2, 8, "Scattered spikes"};
Item CHISEL = {"Chisel", 1, 0, 1, 5, "Stone-cutting tool"};
Item DRILL = {"Drill", 1, 0, 2, 8, "Boring tool"};
Item FISHING_ROD = {"Fishing Rod", 0, 0, 2, 5, "Angling equipment"};
Item MARBLES = {"Marbles", 0, 0, 1, 3, "Bag of small spheres"};
Item GLUE = {"Glue", 0, 0, 1, 4, "Strong adhesive"};
Item PICK = {"Pick", 3, 0, 4, 12, "Mining pickaxe"};
Item HOURGLASS = {"Hourglass", 0, 0, 1, 15, "Time measurement device"};
Item NET = {"Net", 0, 0, 3, 10, "Fishing or capture net"};
Item TONGS = {"Tongs", 1, 0, 2, 6, "Gripping tool"};
Item LOCKPICKS = {"Lockpicks", 0, 0, 0, 25, "Thief's tools"};
Item METAL_FILE = {"Metal File", 0, 0, 1, 8, "Sharpening tool"};
Item NAILS = {"Nails", 0, 0, 1, 2, "Iron fasteners"};
// }}}

// {{{ Predefined items - General Gear 2
Item INCENSE = {"Incense", 0, 0, 1, 5, "Aromatic burning sticks"};
Item SPONGE = {"Sponge", 0, 0, 0, 2, "Absorbent cleaning tool"};
Item LENS = {"Lens", 0, 0, 0, 20, "Magnifying glass"};
Item PERFUME = {"Perfume", 0, 0, 0, 15, "Scented oil"};
Item HORN = {"Horn", 0, 0, 2, 8, "Signaling horn"};
Item BOTTLE = {"Bottle", 0, 0, 1, 3, "Glass container"};
Item SOAP = {"Soap", 0, 0, 0, 2, "Cleaning bar"};
Item SPYGLASS = {"Spyglass", 0, 0, 1, 50, "Telescoping viewer"};
Item TAR_POT = {"Tar Pot", 0, 0, 2, 5, "Waterproofing tar"};
Item TWINE = {"Twine", 0, 0, 1, 2, "Strong string"};
Item FAKE_JEWELS = {"Fake Jewels", 0, 0, 0, 10, "Glass gems"};
Item BLANK_BOOK = {"Blank Book", 0, 0, 1, 8, "Empty journal"};
Item CARD_DECK = {"Card Deck", 0, 0, 0, 3, "Playing cards"};
Item DICE_SET = {"Dice Set", 0, 0, 0, 2, "Gaming dice"};
Item COOK_POTS = {"Cook Pots", 0, 0, 4, 12, "Cooking vessels"};
Item FACE_PAINT = {"Face Paint", 0, 0, 0, 5, "Cosmetic pigments"};
Item WHISTLE = {"Whistle", 0, 0, 0, 1, "Small signaling device"};
Item INSTRUMENT = {"Instrument", 0, 0, 2, 25, "Musical instrument"};
Item QUILL_AND_INK = {"Quill and Ink", 0, 0, 0, 8, "Writing supplies"};
Item SMALL_BELL = {"Small Bell", 0, 0, 0, 3, "Tiny alarm bell"};
// }}}

// {{{ Special items  
Item RATIONS = {"Rations", 0, 0, 2, 5, "Preserved food for travel"};
// }}}

// {{{ Equipment arrays
Item* starting_armor[20];
Item* starting_HandS[20];
Item* starting_Dgear[20]; 
Item* starting_gear1[20];
Item* starting_gear2[20];
// }}}

// {{{ Item management functions
Item* create_item(const char* name, int damage, int armor_bonus, int weight, int value, const char* description) {
    Item* item = malloc(sizeof(Item));
    if (!item) return NULL;
    
    item->name = malloc(strlen(name) + 1);
    if (!item->name) {
        free(item);
        return NULL;
    }
    strcpy(item->name, name);
    
    item->description = malloc(strlen(description) + 1);
    if (!item->description) {
        free(item->name);
        free(item);
        return NULL;
    }
    strcpy(item->description, description);
    
    item->damage = damage;
    item->armor_bonus = armor_bonus;
    item->weight = weight;
    item->value = value;
    
    return item;
}

void free_item(Item* item) {
    if (item) {
        free(item->name);
        free(item->description);
        free(item);
    }
}

Item* clone_item(const Item* item) {
    if (!item) return NULL;
    return create_item(item->name, item->damage, item->armor_bonus, 
                      item->weight, item->value, item->description);
}
// }}}

// {{{ initialize_all_items
void initialize_all_items(void) {
    // Initialize armor table
    for (int i = 0; i < 3; i++) starting_armor[i] = NULL;
    for (int i = 3; i < 14; i++) starting_armor[i] = &GAMBESON;
    for (int i = 14; i < 19; i++) starting_armor[i] = &BRIGANDINE;
    starting_armor[19] = &CHAIN_SHIRT;
    
    // Initialize helmets and shields table
    for (int i = 0; i < 14; i++) starting_HandS[i] = NULL;
    for (int i = 14; i < 16; i++) starting_HandS[i] = &HELMET;
    for (int i = 16; i < 19; i++) starting_HandS[i] = &SHIELD;
    starting_HandS[19] = &HELMET_AND_SHIELD;
    
    // Initialize dungeoneering gear table
    starting_Dgear[0] = &ROPE;
    starting_Dgear[1] = &PULLEYS;
    starting_Dgear[2] = &CANDLES;
    starting_Dgear[3] = &CHAIN;
    starting_Dgear[4] = &CHALK;
    starting_Dgear[5] = &CROWBAR;
    starting_Dgear[6] = &TINDERBOX;
    starting_Dgear[7] = &GRAPPLING_HOOK;
    starting_Dgear[8] = &HAMMER;
    starting_Dgear[9] = &WATERSKIN;
    starting_Dgear[10] = &LANTERN;
    starting_Dgear[11] = &LAMP_OIL;
    starting_Dgear[12] = &PADLOCK;
    starting_Dgear[13] = &MANACLES;
    starting_Dgear[14] = &MIRROR;
    starting_Dgear[15] = &POLE;
    starting_Dgear[16] = &SACK;
    starting_Dgear[17] = &TENT;
    starting_Dgear[18] = &SPIKES;
    starting_Dgear[19] = &TORCHES;
    
    // Initialize general gear 1 table
    starting_gear1[0] = &AIR_BLADDER;
    starting_gear1[1] = &BEAR_TRAP;
    starting_gear1[2] = &SHOVEL;
    starting_gear1[3] = &BELLOWS;
    starting_gear1[4] = &GREASE;
    starting_gear1[5] = &SAW;
    starting_gear1[6] = &BUCKET;
    starting_gear1[7] = &CALTROPS;
    starting_gear1[8] = &CHISEL;
    starting_gear1[9] = &DRILL;
    starting_gear1[10] = &FISHING_ROD;
    starting_gear1[11] = &MARBLES;
    starting_gear1[12] = &GLUE;
    starting_gear1[13] = &PICK;
    starting_gear1[14] = &HOURGLASS;
    starting_gear1[15] = &NET;
    starting_gear1[16] = &TONGS;
    starting_gear1[17] = &LOCKPICKS;
    starting_gear1[18] = &METAL_FILE;
    starting_gear1[19] = &NAILS;
    
    // Initialize general gear 2 table
    starting_gear2[0] = &INCENSE;
    starting_gear2[1] = &SPONGE;
    starting_gear2[2] = &LENS;
    starting_gear2[3] = &PERFUME;
    starting_gear2[4] = &HORN;
    starting_gear2[5] = &BOTTLE;
    starting_gear2[6] = &SOAP;
    starting_gear2[7] = &SPYGLASS;
    starting_gear2[8] = &TAR_POT;
    starting_gear2[9] = &TWINE;
    starting_gear2[10] = &FAKE_JEWELS;
    starting_gear2[11] = &BLANK_BOOK;
    starting_gear2[12] = &CARD_DECK;
    starting_gear2[13] = &DICE_SET;
    starting_gear2[14] = &COOK_POTS;
    starting_gear2[15] = &FACE_PAINT;
    starting_gear2[16] = &WHISTLE;
    starting_gear2[17] = &INSTRUMENT;
    starting_gear2[18] = &QUILL_AND_INK;
    starting_gear2[19] = &SMALL_BELL;
}

void cleanup_all_items(void) {
    // Static items don't need cleanup, but custom items would
}
// }}}