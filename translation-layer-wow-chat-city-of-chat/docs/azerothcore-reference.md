# AzerothCore Reference for Protocol Research

This document captures key architectural patterns from [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) that inform protocol translation work.

---

## Source Code Locations

| Domain | File | Purpose |
|--------|------|---------|
| Opcodes | `src/server/game/Server/Protocol/Opcodes.h` | All opcode definitions |
| Player stats | `src/server/game/Entities/Player/Player.cpp` | Stat calculations, auras |
| Spell auras | `src/server/game/Spells/Auras/SpellAuraEffects.cpp` | Aura effect handlers |
| Packets | WorldPacket class | Packet serialization |

---

## Stat System Architecture

### character_stats Table

The [character_stats](https://www.azerothcore.org/wiki/character_stats) table stores:

**Primary Stats:**
- `strength`, `agility`, `stamina`, `intellect`, `spirit`

**Combat Metrics (percentages):**
- `blockPct`, `dodgePct`, `parryPct`
- `critPct`, `rangedCritPct`, `spellCritPct`

**Resistances:**
- `resHoly`, `resFire`, `resNature`, `resFrost`, `resShadow`, `resArcane`

**Power & Damage:**
- `maxhealth`, `maxpower1` through `maxpower7` (mana, rage, focus, energy, happiness, rune, runic power)
- `attackPower`, `rangedAttackPower`, `spellPower`
- `armor`, `resilience`

### Stat Modifier Auras

From the [spell-aura-reference](https://www.azerothcore.org/wiki/spell-aura-reference):

| Aura Type | ID | Purpose |
|-----------|-------|---------|
| SPELL_AURA_MOD_STAT | 29 | Direct stat modification |
| SPELL_AURA_MOD_PERCENT_STAT | 80 | Percentage stat increase |
| SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE | 137 | Total stat percentage |
| SPELL_AURA_MOD_ATTACK_POWER_OF_STAT_PERCENT | 268 | AP from stat |
| SPELL_AURA_MOD_SPELL_DAMAGE_OF_STAT_PERCENT | 174 | Spell damage from stat |
| SPELL_AURA_MOD_SPELL_HEALING_OF_STAT_PERCENT | 175 | Healing from stat |
| SPELL_AURA_MOD_MANA_REGEN_FROM_STAT | 219 | Mana regen from stat |

### Stat Type Enumeration

Stats use index values (EffectMiscValueA):
- 0 = Strength
- 1 = Agility
- 2 = Stamina
- 3 = Intellect
- 4 = Spirit
- -1 = All stats

---

## Network Protocol

### WorldPacket Structure

From [wowdev.wiki](https://wowdev.wiki/World_Packet):

```
+--------+--------+------------------+
| Size   | Opcode | Payload          |
| 2 bytes| 2 bytes| variable         |
+--------+--------+------------------+
```

- Port: 8085 (world server)
- Header encrypted with session key (except auth packets)
- Little-endian byte order

### Opcode Categories

| Range | Category | Examples |
|-------|----------|----------|
| 0x000-0x080 | General | Auth, ping, realm |
| 0x081-0x094 | Guild | Invite, roster, ranks |
| 0x095-0x0A8 | Chat/Channels | Chat messages, join/leave |
| 0x0A9-0x0FF | Party/Group | Invite, leave, loot |
| 0x100+ | World/Game | Movement, combat, items |

### Chat Opcodes (Most Relevant for wow-chat)

| Opcode | Name | Direction |
|--------|------|-----------|
| 0x095 | CMSG_MESSAGECHAT | Client → Server |
| 0x096 | SMSG_MESSAGECHAT | Server → Client |
| 0x097 | CMSG_JOIN_CHANNEL | Client → Server |
| 0x098 | CMSG_LEAVE_CHANNEL | Client → Server |
| 0x099 | SMSG_CHANNEL_NOTIFY | Server → Client |
| 0x09A | CMSG_CHANNEL_LIST | Client → Server |
| 0x09B | SMSG_CHANNEL_LIST | Server → Client |
| 0x225 | CMSG_CHAT_IGNORED | Client → Server |

### Movement Optimization

AzerothCore uses `SMSG_COMPRESSED_MOVES` to batch movement packets:
- Reduces header overhead (~50% of outbound traffic is movement)
- Combines all movement in one server tick into single packet
- Important for busy zones

---

## Database Schema References

### Class Stats: [player_class_stats](https://www.azerothcore.org/wiki/player_class_stats)
Per-class stat values at each level.

### Race Stats: [player_race_stats](https://www.azerothcore.org/wiki/player_race_stats)
Base stats by race.

### Aura Storage: [character_aura](https://www.azerothcore.org/wiki/character_aura)
Persistent auras saved on logout:
- Up to 3 auras per spell (one per effect slot)
- Stores modifier values for restoration

---

## Key Design Patterns

### 1. Dispatch Table for Opcodes

```cpp
// Opcodes.h pattern
OpcodeHandler opcodeTable[NUM_MSG_TYPES];

// Registration
opcodeTable[CMSG_MESSAGECHAT] = { "CMSG_MESSAGECHAT", STATUS_LOGGED, &WorldSession::HandleMessagechatOpcode };
```

### 2. Aura Effect Handlers

```cpp
// SpellAuraEffects.cpp pattern
AuraEffectHandler[SPELL_AURA_MOD_STAT] = &AuraEffect::HandleModStat;

void AuraEffect::HandleModStat(AuraApplication const* aurApp, uint8 mode, bool apply)
{
    // Apply or remove stat modifier
}
```

### 3. Stat Update Flow

1. Base stats from `player_class_stats` + `player_race_stats`
2. Equipment bonuses applied
3. Aura modifiers stacked (flat → percent → multiplier)
4. Derived stats calculated
5. `UpdateStats()` sends to client

---

## Relevance to Translation Layer

For wow-chat (WoW ↔ CoH translation):

**Direct Translation:**
- Chat opcodes (0x095-0x0A8) map well to text-based chat
- Channel concepts exist in both games

**Requires Mapping:**
- Stats don't 1:1 map (WoW has 5 primary, CoH has different system)
- Combat events have different granularity
- Movement packet frequency differs

**Ignore/Approximate:**
- Aura visuals (cosmetic)
- Spell animations
- Detailed combat log entries

---

## Additional Resources

- [AzerothCore GitHub](https://github.com/azerothcore/azerothcore-wotlk)
- [AzerothCore Wiki](https://www.azerothcore.org/wiki/)
- [WoWDev Wiki - Opcodes](https://wowdev.wiki/Opcodes)
- [WoWDev Wiki - World Packet](https://wowdev.wiki/World_Packet)
- [Eluna WorldPacket API](https://www.azerothcore.org/eluna/WorldPacket/index.html)
- [acore-client](https://github.com/azerothcore/acore-client) - Web client consuming opcodes

