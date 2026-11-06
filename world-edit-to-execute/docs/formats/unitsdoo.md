# war3mapUnits.doo - Unit Placement Format Specification

The war3mapUnits.doo file contains preplaced unit, building, and item data.
This includes positions, ownership, custom abilities, hero data, and item drops.

---

## Overview

The Units.doo file defines all preplaced objects that are not doodads:
- Units (footmen, grunts, ghouls, archers, etc.)
- Buildings (town halls, barracks, farms, etc.)
- Heroes (with levels, stats, and inventory)
- Items (placed on ground, not in inventories)
- Random unit/item spawners

Unlike war3map.doo (doodads), entries are variable-length due to optional
sections like item drops, abilities, and hero data.

---

## Data Types

| Type | Size | Description |
|------|------|-------------|
| int32 | 4 bytes | Little-endian signed integer |
| uint32 | 4 bytes | Little-endian unsigned integer |
| float32 | 4 bytes | IEEE 754 single precision |
| byte | 1 byte | Unsigned 8-bit integer |
| char(4) | 4 bytes | Four-character type ID (e.g., "hfoo") |

---

## File Structure

### Header

| Offset | Type | Field | Description |
|--------|------|-------|-------------|
| 0x00 | char(4) | FileID | Always "W3do" |
| 0x04 | int32 | Version | 7=RoC, 8=TFT, 11+=Reforged |
| 0x08 | int32 | Subversion | Usually 0x09 |
| 0x0C | int32 | UnitCount | Number of unit entries |

### Unit Entry (Variable Length)

Every entry has every part below, in this order; only the counts make an
entry longer. This is the order the World Editor writes (issue 202f): it
reads every byte of the test maps' files, 347 units in all, versions 7 and
8, ending exactly at the end of each file.

#### Fixed Fields

| Type | Field | Description |
|------|-------|-------------|
| char(4) | TypeID | Unit type (e.g., "hfoo" = Footman) |
| int32 | Variation | Visual variation index |
| float32 | X | X coordinate |
| float32 | Y | Y coordinate |
| float32 | Z | Z coordinate |
| float32 | Angle | Facing angle (radians) |
| float32 | ScaleX | X scale factor |
| float32 | ScaleY | Y scale factor |
| float32 | ScaleZ | Z scale factor |
| byte | Flags | Unit flags (see below) |
| int32 | Player | Owner player number (0-27) |
| byte | Unknown1 | Usually 0 |
| byte | Unknown2 | Usually 0 |
| int32 | HP | Hit points (-1 = default) |
| int32 | MP | Mana points (-1 = default) |

Reforged (1.32+) adds a char(4) SkinID after TypeID; no test map has it,
and the parser doesn't read it.

#### Item Drops

| Type | Field | Description |
|------|-------|-------------|
| int32 | TablePointer | Version 8 with subversion 11+ only: -1 = none, else the map's item table |
| int32 | SetCount | Number of item sets |

For each item set:

| Type | Field | Description |
|------|-------|-------------|
| int32 | ItemCount | Items in this set |

For each item:

| Type | Field | Description |
|------|-------|-------------|
| char(4) | ItemID | Item type (e.g., "ratc") |
| int32 | Chance | Drop chance percentage (0-100) |

#### Gold and Target Acquisition

Every entry, not only buildings:

| Type | Field | Description |
|------|-------|-------------|
| int32 | Gold | Gold held (a gold mine's; 12500 by default) |
| float32 | TargetAcq | Target acquisition range (-1 = normal, -2 = camp) |

#### Hero Section

Every entry, hero or not (a non-hero has level 1, or 0 for a start
location, and no bonuses); a non-hero can carry items too.

| Type | Field | Description |
|------|-------|-------------|
| int32 | Level | Hero level |
| int32 | StrBonus | Version 8 only: strength bonus (from tomes) |
| int32 | AgiBonus | Version 8 only: agility bonus |
| int32 | IntBonus | Version 8 only: intelligence bonus |
| int32 | ItemCount | Inventory item count |

For each inventory item:

| Type | Field | Description |
|------|-------|-------------|
| int32 | Slot | Inventory slot (0-5) |
| char(4) | ItemID | Item type |

#### Modified Abilities

| Type | Field | Description |
|------|-------|-------------|
| int32 | AbilityCount | Number of modified abilities |

For each ability:

| Type | Field | Description |
|------|-------|-------------|
| char(4) | AbilityID | Ability type (e.g., "AHbz") |
| int32 | Autocast | 1 = autocast enabled |
| int32 | Level | Ability level |

#### Random Unit Data

| Type | Field | Description |
|------|-------|-------------|
| int32 | RandomFlag | 0 = any of a level, 1 = from a random group, 2 = from its own table |

If RandomFlag == 0 (every entry that isn't random has this too):

| Type | Field | Description |
|------|-------|-------------|
| byte(3) | Level | A 24-bit level (-1 = any) |
| byte | ItemClass | Item class of a random item (0 = any) |

If RandomFlag == 1 (from a random group in war3map.w3i):

| Type | Field | Description |
|------|-------|-------------|
| int32 | GroupIndex | Random group table index |
| int32 | Position | Position (column) within the group |

If RandomFlag == 2 (from a table of its own):

| Type | Field | Description |
|------|-------|-------------|
| int32 | Count | Number of choices |

For each choice: char(4) type ID, int32 chance.

A random object's type ID says what it stands for: uDNR (unit), bDNR
(building), iDNR (item); older maps use YYU/YYI placeholders.

#### Custom Color

| Type | Field | Description |
|------|-------|-------------|
| int32 | CustomColor | -1 = the owner's color, else a player color |

#### Waygate Destination

| Type | Field | Description |
|------|-------|-------------|
| int32 | WaygateDest | -1 = not waygate, else region creation_number |

#### Creation Number

| Type | Field | Description |
|------|-------|-------------|
| int32 | CreationNumber | Unique editor ID (for trigger references) |

---

## Type ID Reference

### Unit Type Prefixes

| Prefix | Faction | Examples |
|--------|---------|----------|
| h | Human | hfoo (Footman), hkni (Knight), hsor (Sorceress) |
| o | Orc | ogru (Grunt), okod (Kodo Beast), oshm (Shaman) |
| u | Undead | ugho (Ghoul), uabo (Abomination), uban (Banshee) |
| e | Night Elf | earc (Archer), edry (Dryad), emtg (Mountain Giant) |
| n | Neutral | nzom (Zombie), ngnr (Gnoll), nmrr (Murloc) |

### Hero Type Prefixes

Capital first letter indicates hero:

| Prefix | Faction | Examples |
|--------|---------|----------|
| H | Human | Hpal (Paladin), Hamg (Archmage), Hmkg (Mountain King) |
| O | Orc | Obla (Blademaster), Ofar (Far Seer), Otch (Chieftain) |
| U | Undead | Udea (Death Knight), Ulic (Lich), Udre (Dreadlord) |
| E | Night Elf | Edem (Demon Hunter), Ekee (Keeper), Emoo (Priestess) |
| N | Neutral | Nbrn (Dark Ranger), Npbm (Brewmaster), Nplh (Pit Lord) |

### Building Type IDs

| ID | Building |
|----|----------|
| htow | Human Town Hall |
| hbar | Human Barracks |
| hbla | Human Blacksmith |
| ogre | Orc Great Hall |
| obar | Orc Barracks |
| ofor | Orc War Mill |
| unpl | Undead Necropolis |
| usep | Undead Crypt |
| uzig | Undead Ziggurat |
| etol | Night Elf Tree of Life |
| eaow | Night Elf Ancient of War |
| eate | Night Elf Altar of Elders |

---

## Player Numbers

| Number | Player |
|--------|--------|
| 0-11 | Player 1-12 (standard players) |
| 12-23 | Player 13-24 (extended) |
| 24 | Neutral Hostile (red creeps) |
| 25 | Neutral Passive (critters, merchants) |
| 26 | Neutral Victim (rescuable) |
| 27 | Neutral Extra |

---

## Ability ID Format

```
A{race}{code}

A    = Ability prefix
race = H(uman), O(rc), U(ndead), E(lf), N(eutral)
code = 2-character ability code
```

Examples:
- AHbz = Blizzard (Human)
- AOcr = Critical Strike (Orc)
- AUan = Animate Dead (Undead)
- AEsh = Shadow Strike (Night Elf)

---

## Random Level Encoding

The YYU/YYI placeholders of older maps carry a level character
(`unitsdoo.decode_random_level`):

| Char | Level | Char | Level |
|------|-------|------|-------|
| '0' | 0 | 'A' | 10 |
| '1' | 1 | 'B' | 11 |
| '2' | 2 | 'C' | 12 |
| ... | ... | ... | ... |
| '9' | 9 | 'Z' | 35 |

---

## Version Differences

| Version | Format |
|---------|--------|
| 7 (subversion 9) | Reign of Chaos: no item table pointer, no stat bonuses |
| 8 (subversion 11) | The Frozen Throne (most common) |
| 8, game 1.32+ | Reforged: adds SkinID after TypeID (not read) |

---

## References

- [WC3MapSpecification](https://github.com/ChiefOfGxBxL/WC3MapSpecification)
- [w3x-spec](https://github.com/SimonMossmyr/w3x-spec)
- war3map.doo format (similar structure for doodads)
