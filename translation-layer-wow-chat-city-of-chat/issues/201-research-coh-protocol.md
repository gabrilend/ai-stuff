# 102 - Research CoH Protocol Structure

## Status
- Phase: 1
- Priority: High
- Dependencies: None

---

## Current Behavior

No documentation exists about CoH's client-server protocol within
this project. While CoH has active private servers (Homecoming, etc.),
their protocol details are not yet captured here.

---

## Intended Behavior

A comprehensive document (`docs/coh-protocol.md`) should exist that covers:

1. **Packet structure** - Header format, message types, encoding
2. **Authentication flow** - Login, character selection, server transfer
3. **World data** - Zone instances, door missions, contacts
4. **Combat data** - Powers, damage, enhancements, buffs
5. **Social data** - Chat channels, teams, supergroups
6. **Character data** - Archetypes, powersets, slots, costumes
7. **Mastermind-specific** - Minion commands, pet AI states

Special attention to Mastermind class since the vision specifically
mentions wanting to play one in Outland.

---

## Suggested Implementation Steps

1. Research CoH private server implementations:
   - Homecoming server codebase (if accessible)
   - SEGS (Super Entity Game Server) project
   - i24/i25 server documentation

2. Focus on the Rogue Isles content:
   - Villain-side progression systems
   - Arachnos contact system
   - Patron power unlocks

3. Document packet format with examples:
   - Include decoded packet samples
   - Note differences from WoW structure for translation

4. Create power/ability reference:
   - Mastermind primary/secondary sets
   - Minion types and their attributes
   - How pet commands are encoded

5. Map CoH concepts to WoW equivalents:
   - Archetypes <-> Classes
   - Powersets <-> Talent trees
   - Enhancements <-> Item stats

---

## Resources

- SEGS Project: https://github.com/Segs/Segs
- Homecoming forums and wikis
- Paragon Wiki (archived game documentation)
- CoH Modding communities

---

## Notes

City of Heroes has a more accessible codebase than WoW due to private
server development. This may be the easier protocol to document first.
The translation direction CoH->WoW may be simpler to implement initially.
