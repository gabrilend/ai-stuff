# Translation Layer: WoW <-> City of Heroes

## Roadmap

Each phase is a focused unit of work with its own issues.

---

### Phase 1: Research WoW Protocol

Document WoW's client-server protocol structure.

**Deliverables:**
- `docs/wow-protocol.md`
- Opcode reference table
- Sample packets with annotations

**Issues:** 101-*

---

### Phase 2: Research CoH Protocol

Document City of Heroes client-server protocol structure.
Special attention to Mastermind mechanics.

**Deliverables:**
- `docs/coh-protocol.md`
- Power/ability reference
- Mastermind minion command encoding

**Issues:** 201-*

---

### Phase 3: Create Protocol Mapping Matrix

Systematic comparison of how data maps between both games.
Answers: "When WoW sends X, what does CoH receive?"

**Deliverables:**
- `docs/protocol-mapping.md`
- Translation lookup tables
- Priority ordering by gameplay impact

**Issues:** 301-*

---

### Phase 4: Define Translatable Data Types

Define the Lua data structures that carry translated data.
These are the "language" of the transcriber.

**Deliverables:**
- `src/types/` with core data structures
- TranslatedPacket, CharacterState, CombatEvent, etc.
- Validation functions

**Issues:** 401-*

---

### Phase 5: Build Protocol Packet Visualizer

Terminal-based visualizer proving we understand both protocols.
Side-by-side comparison with translation confidence coloring.

**Deliverables:**
- `src/demos/packet-visualizer.lua`
- Sample packets in `assets/samples/`
- Phase 5 demo script

**Issues:** 501-*

---

### Phase 6: Implement Transcriber Engine with Caching

The core engine that builds semantic meaning structures and
caches LLM-generated translations for reuse.

Each game is an API. The transcriber carries data between them.
The sense is calibrated ahead of time and cached.

**Deliverables:**
- `src/transcriber/` engine
- Cache storage in `assets/cache/`
- Cross-game costume system
- Enhancement-to-costume unlock mechanic
- Phase 6 demo: live translation with caching

**Issues:** 601-*

---

## Future Phases

### Phase 7+: Narrative System

The "collective DM spirit" that guides player experiences,
turning protocol mismatches into narrative opportunities.

### Phase 8+: Integration & Testing

End-to-end testing with actual game clients.
Performance optimization for real-time translation.

### Phase 9+: Expansion Content

- Honnouji Academy setting
- Custom minion systems
- Horse-shield cavalry with Crey bionic weaponry

---

## Technical Constraints

- **Language:** Lua (LuaJIT compatible syntax)
- **Architecture:** Data generation separate from data viewing
- **Error handling:** Prefer explicit errors over silent fallbacks
- **Issue tracking:** Every change requires an issue file
