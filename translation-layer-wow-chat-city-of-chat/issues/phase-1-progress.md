# Phase 1: Research WoW Protocol Structure

## Status
- Priority: High
- Dependencies: None

---

## Current Behavior

No documentation exists about WoW's client-server protocol within
this project. The transcriber cannot function without understanding
what data WoW clients send and receive.

---

## Intended Behavior

A comprehensive document (`docs/wow-protocol.md`) should exist that covers:

1. **Packet structure** - Header format, opcodes, payload encoding
2. **Authentication flow** - Login sequence, session management
3. **World data** - Zone transitions, entity spawning, movement
4. **Combat data** - Abilities, damage, buffs/debuffs
5. **Social data** - Chat, party, guild communications
6. **Character data** - Stats, inventory, talents

The document should identify which data types are essential for
cross-game translation and which can be ignored or approximated.

---

## Suggested Implementation Steps

1. Research existing WoW protocol documentation:
   - WoWDev wiki and archives
   - Private server implementations (TrinityCore, AzerothCore)
   - Packet sniffing tools and their documentation

2. Focus on protocol versions that are most accessible:
   - Classic/Vanilla may have best documentation
   - Consider which expansion aligns with desired gameplay

3. Document packet format with examples:
   - Include hex dumps of sample packets
   - Annotate each field with meaning and data type

4. Create opcode reference table:
   - Map opcode numbers to human-readable names
   - Note which opcodes are bidirectional

5. Identify translation-critical data:
   - Mark fields that MUST be translated for gameplay
   - Mark fields that can be approximated or ignored

---

## Phase Completion Criteria

- [ ] `docs/wow-protocol.md` exists with packet structure documentation
- [ ] Opcode reference table created
- [ ] Translation-critical fields identified
- [ ] Sample packets documented with annotations

---

## Resources

- TrinityCore: https://github.com/TrinityCore/TrinityCore
- WoWDev wiki (archived)
- Mangos project documentation

---

## Notes

WoW's protocol is proprietary. This research is for educational and
interoperability purposes. The transcriber does not seek to bypass
authentication or enable unauthorized access.

---

## Log

- 2025-12-19: Phase created from issue 101
