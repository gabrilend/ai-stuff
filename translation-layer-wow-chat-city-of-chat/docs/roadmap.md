# Translation Layer: WoW <-> City of Heroes

## Roadmap

### Phase 1: Protocol Research

Understand the communication protocols of both games to determine what
translation is actually possible.

**Goals:**
- Document WoW client-server protocol structure
- Document CoH protocol structure (leveraging private server documentation)
- Identify data types that can be mapped between games
- Identify fundamental incompatibilities and workarounds
- Create protocol comparison matrix

**Deliverables:**
- `docs/wow-protocol.md` - WoW protocol analysis
- `docs/coh-protocol.md` - CoH protocol analysis
- `docs/protocol-mapping.md` - Translation mapping document
- Phase 1 demo: Protocol packet visualizer

---

### Phase 2: LLM Integration Design

Design the system that uses LLM-generated code to handle translation
dynamically, making it feel like it "just works."

**Goals:**
- Define LLM's role in runtime translation
- Design prompt templates for code generation
- Create sandboxed execution environment for generated code
- Build feedback loop for iterative refinement
- Handle edge cases through narrative adaptation

**Deliverables:**
- `docs/llm-integration.md` - LLM system architecture
- `src/llm/` - LLM integration module
- `src/sandbox/` - Code execution sandbox
- Phase 2 demo: Live translation code generation

---

### Phase 3: Narrative System

Build the "collective DM spirit" that guides player experiences,
turning protocol mismatches into narrative opportunities.

**Goals:**
- Design narrative engine that contextualizes translations
- Create character archetype mappings (Mastermind <-> ?, Blood Elf <-> ?)
- Build world-space translation (Outland <-> Rogue Isles regions)
- Implement ability/mechanic translation with narrative justification
- Handle the weird stuff (floating crystals in Naxxramas)

**Deliverables:**
- `docs/narrative-system.md` - Narrative engine design
- `src/narrative/` - Narrative generation module
- `assets/mappings/` - Character/world/ability mappings
- Phase 3 demo: Cross-game character creation with narrative

---

### Phase 4: Integration & Testing

Bring all systems together and ensure the code actually functions
correctly across real game scenarios.

**Goals:**
- Integrate protocol layer with LLM system
- Integrate narrative system with translation output
- End-to-end testing with actual game clients
- Performance optimization for real-time translation
- Edge case handling and graceful degradation

**Deliverables:**
- Full translation layer binary/script
- Test suite covering common scenarios
- Performance benchmarks
- Phase 4 demo: Live cross-game session

---

## Future Phases (Post-MVP)

### Phase 5: Expansion Content
- Honnouji Academy setting (Avatar elements via CoH + WoW mechanics)
- Custom minion systems for Masterminds in WoW zones
- Horse-shield cavalry with Crey bionic weaponry

### Phase 6: Community Features
- Multi-player narrative synchronization
- Player-contributed translation rules
- Shared DM spirit training from player sessions

---

## Technical Constraints

- **Language:** Lua (LuaJIT compatible syntax)
- **Architecture:** Data generation separate from data viewing
- **Error handling:** Prefer explicit errors over silent fallbacks
- **Issue tracking:** Every change requires an issue file
