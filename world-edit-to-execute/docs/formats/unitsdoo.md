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

Each unit entry contains fixed fields followed by optional variable-length sections.

#### Fixed Fields

| Type | Field | Description |
|------|-------|-------------|
| char(4) | TypeID | Unit type (e.g., "hfoo" = Footman) |
| char(4) | SkinID | Skin override (Reforged only, if version >= 11) |
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

#### Item Drop Table (Optional)

| Type | Field | Description |
|------|-------|-------------|
| int32 | TablePointer | -1 = none, else table index |
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

#### Gold/Lumber (Buildings Only)

| Type | Field | Description |
|------|-------|-------------|
| int32 | Gold | Gold in building (-1 = default) |
| float32 | TargetAcq | Target acquisition range (-1.0 = default) |

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

#### Hero Data (Heroes Only)

Present only if TypeID starts with capital letter (hero unit).

| Type | Field | Description |
|------|-------|-------------|
| int32 | Level | Hero level |
| int32 | StrBonus | Strength bonus (from tomes) |
| int32 | AgiBonus | Agility bonus |
| int32 | IntBonus | Intelligence bonus |
| int32 | ItemCount | Inventory item count |

For each inventory item:

| Type | Field | Description |
|------|-------|-------------|
| int32 | Slot | Inventory slot (0-5) |
| char(4) | ItemID | Item type |

#### Random Unit Data

| Type | Field | Description |
|------|-------|-------------|
| int32 | RandomFlag | 0=normal, 1=random level, 2=random group |

If RandomFlag == 1 (random from level):

| Type | Field | Description |
|------|-------|-------------|
| char(3) | Prefix | "YYU" for unit, "YYI" for item |
| byte | LevelChar | '0'-'9' or 'A'-'Z' (level 0-35) |

If RandomFlag == 2 (random from group):

| Type | Field | Description |
|------|-------|-------------|
| int32 | GroupIndex | Random group table index |
| int32 | Position | Position within group |

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

Level character maps to numeric level:

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
| 7 | Reign of Chaos base format |
| 8 | The Frozen Throne format (most common) |
| 11+ | Reforged format (adds SkinID field) |

---

## References

- [WC3MapSpecification](https://github.com/ChiefOfGxBxL/WC3MapSpecification)
- [w3x-spec](https://github.com/SimonMossmyr/w3x-spec)
- war3map.doo format (similar structure for doodads)
