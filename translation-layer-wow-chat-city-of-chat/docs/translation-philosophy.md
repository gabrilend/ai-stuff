# Translation Philosophy

## The Core Insight

To translate between two games, have the LLM-style AI software
development suite compare the **expected behavior** of abilities
across both games.

A fireball is a fireball.

---

## How Translation Works

### Ability Mapping by Behavior

The translation layer does not map opcodes or packet structures
directly. It maps **semantic intent**.

Example: Fireball

```
WoW Fireball                     CoH Fire Blast
-----------                      --------------
Cast time: 3.5s         <-->     Cast time: matched
Cooldown: 8s            <-->     Recharge: matched
Damage: fire, 500-600   <-->     Damage: fire, scaled
Range: 35 yards         <-->     Range: matched (80 feet)
```

The LLM examines both abilities and determines: these are the same
thing, expressed in different game languages.

### Runtime Translation

When a player or monster casts an ability:

1. **Source game** registers the cast (CoH Fire Blast)
2. **Translation layer** recognizes the semantic action: "fireball"
3. **Target game** receives equivalent effect (WoW Fireball damage)
4. **Properties sync**: cooldown, cast time, range - all matched

The quillboar takes WoW fireball damage.
Your CoH power bar shows the recharge matching WoW's cooldown.
It's just a fireball.

---

## The Medium is the Message

The narrative is the content of the medium.

The medium itself is two forms:
- The sender
- The receiver

Compressed into one.

Carrying the weight of destiny.

---

## What This Means for Implementation

### The LLM's Role

The LLM does not generate translation code mechanically.
It **understands** what an ability is supposed to do.

Given two ability descriptions:
- WoW: "Hurls a fiery ball that causes 500 to 600 Fire damage."
- CoH: "Ranged, Moderate Damage, Fire"

The LLM produces: "These are equivalent. Map damage linearly,
preserve cast feel, synchronize cooldowns."

### Behavior Comparison, Not Data Comparison

Traditional translation: "WoW opcode 0x1A3 = CoH message type 47"

This translation: "The player intended to throw fire at an enemy.
Both games express this. Make both games agree it happened."

### The Unified Action Space

Every action exists in a **semantic layer** above both games:

```
Semantic Layer:     [FIREBALL]  [HEAL]  [TELEPORT]  [TAUNT]
                        |         |         |          |
                       / \       / \       / \        / \
WoW Implementation:   FB  ...   FH  ...   BL  ...   Taunt
CoH Implementation:   FBl ...   Heal...   TP  ...   Provoke
```

The translation layer operates at the semantic level.
Game-specific implementations are just... implementations.

---

## Implications

### Imperfect Mappings Are Fine

Not every ability has a 1:1 match. When a CoH Mastermind summons
minions, WoW has no equivalent. The narrative system describes
what happened in WoW terms. Perhaps warlock demons appear.
Perhaps the player gains mysterious allies. The story adapts.

### Player Experience is Preserved

When you cast your fireball:
- It feels like your game's fireball
- The enemy reacts like their game's fireball hit them
- Both experiences are valid and synchronized

You don't need to learn new abilities.
You don't need to understand the other game's systems.
You just play.

### The Weight of Destiny

Every action carries forward.
The sender's intent arrives at the receiver intact.
Two games. One story. One fireball.
