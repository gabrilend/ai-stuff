Looking at this issue, I can see it's already been analyzed previously (there's a sub-issue analysis section at the bottom from an earlier session). Let me provide my own assessment.

## Analysis

This issue covers **7 distinct protocol domains** plus foundational research. The scope is substantial:

- Packet structure (foundational)
- Authentication flow
- World data
- Combat data
- Social data
- Character data
- Mastermind-specific mechanics

**Inconsistency noted:** The filename says `201-` but the header says `# 102 -`. I'm using `201` as the parent ID to match the filename.

## Recommendation: Split This Issue

**Reasons to split:**

1. **Independent research domains** - Each protocol area can be investigated separately without blocking others
2. **Clear dependency chain** - SEGS codebase must be understood before packet structure, which must come before domain-specific research
3. **Better progress tracking** - Completing 9 smaller issues provides clearer visibility than one massive research task
4. **Parallel work potential** - After foundations (a, b), domains c-h can proceed simultaneously

## Recommended Sub-Issues

| ID | Name | Description |
|----|------|-------------|
| 201a | clone-analyze-segs | Clone SEGS project and identify key protocol-handling source files |
| 201b | document-packet-format | Document base packet structure: headers, message types, byte ordering |
| 201c | document-auth-flow | Research login handshake, character selection, server transfers |
| 201d | document-world-data | Document zone instances, door missions, contacts, map transitions |
| 201e | document-combat-data | Document powers, damage events, enhancements, buff/debuff encoding |
| 201f | document-social-data | Document chat channels, team formation, supergroup structures |
| 201g | document-character-data | Document archetypes, powersets, slots, costume encoding |
| 201h | document-mastermind-pets | Document minion commands, pet AI states, Mastermind-specific packets |
| 201i | map-coh-to-wow | Create concept mapping table between CoH and WoW equivalents |

**Dependency chain:** `201a → 201b → (201c-201h parallel) → 201i`
