# Consideration Matching

A methodology for mapping design considerations to implementation decisions.

---

## What is Consideration Matching?

When designing a system that must serve multiple purposes (like dual interfaces), we face many decision points. **Consideration matching** is the process of:

1. Identifying relevant considerations for a decision
2. Evaluating how each consideration applies
3. Finding patterns across considerations
4. Deriving design principles from patterns

---

## The Consideration Hierarchy

```
Considerations
    │
    ├── Functional Considerations
    │   ├── What must it do?
    │   ├── What must it not do?
    │   └── What edge cases exist?
    │
    ├── Structural Considerations
    │   ├── How is data organized?
    │   ├── How do components connect?
    │   └── What are the boundaries?
    │
    ├── Temporal Considerations
    │   ├── When does it happen?
    │   ├── How often?
    │   └── In what order?
    │
    ├── Modal Considerations
    │   ├── Which mode is this for?
    │   ├── Do modes share this?
    │   └── How do modes differ here?
    │
    └── Meta Considerations
        ├── Why this design?
        ├── What alternatives exist?
        └── What might change later?
```

---

## Consideration Types

### Type 1: Binary Considerations
Either/or decisions.
```
Example: "Should camera be spatial or linear?"
Match: Warcraft → spatial, WoW-chat → linear
Result: Need abstraction that supports both
```

### Type 2: Spectrum Considerations
Degree/amount decisions.
```
Example: "How much screen space for chat?"
Match: Warcraft → 10%, WoW-chat → 70%
Result: Configurable layout proportions
```

### Type 3: Intersection Considerations
What's shared between modes.
```
Example: "Both need player status display"
Match: Warcraft ∩ WoW-chat = {player name, state, resources}
Result: Shared status component, mode-specific styling
```

### Type 4: Disjoint Considerations
Mode-specific with no overlap.
```
Example: "Warcraft needs unit sprites, WoW-chat needs chat bubbles"
Match: Warcraft ⊕ WoW-chat (exclusive to each)
Result: Separate implementation, no shared code needed
```

### Type 5: Dependent Considerations
One consideration affects another.
```
Example: "If high update rate, then need efficient rendering"
Match: Warcraft (60fps) → GPU batching
       WoW-chat (event-driven) → simple text append
Result: Different optimization strategies per mode
```

---

## Matching Process

### Step 1: Enumerate Considerations
For a given design decision, list all relevant considerations:

```
Decision: How to render entities?

Considerations:
[ ] C1: Entity count (few vs many)
[ ] C2: Update frequency (continuous vs sparse)
[ ] C3: Visual complexity (simple vs detailed)
[ ] C4: Interaction model (spatial vs textual)
[ ] C5: Performance constraints
[ ] C6: Mode relevance (both, one, neither)
```

### Step 2: Score Each Consideration
Rate importance and apply to each mode:

```
| Consideration | Warcraft | WoW-Chat | Weight |
|---------------|----------|----------|--------|
| C1: Entity count | High (100+) | Low (10-20) | 0.8 |
| C2: Update freq | 60fps | Event | 0.9 |
| C3: Visual complexity | Medium | Low | 0.5 |
| C4: Interaction | Spatial | Text | 1.0 |
| C5: Performance | Critical | Relaxed | 0.7 |
| C6: Mode relevance | Primary | Secondary | - |
```

### Step 3: Identify Patterns
Look for clusters and relationships:

```
Pattern A: Warcraft is visually demanding
  - C1 high, C2 high, C5 critical
  → Need optimized spatial rendering

Pattern B: WoW-chat is interaction focused
  - C4 textual, C2 event-driven
  → Need responsive text handling

Pattern C: Both need entity representation
  - Shared: entity identity, state
  - Different: visual vs textual presentation
  → Abstract entity → presentation mapping
```

### Step 4: Derive Principles
Convert patterns to design rules:

```
Principle 1: Separate entity model from presentation
Principle 2: Mode-specific renderers share entity data
Principle 3: Performance optimization is mode-specific
Principle 4: Input handling branches early on mode
```

### Step 5: Apply to Implementation
Use principles to guide code structure:

```lua
-- Principle 1 applied
local entity = ecs.get_component(id, "identity")

-- Principle 2 applied
if mode == "warcraft" then
    sprite_renderer.draw(entity)
else
    text_renderer.format(entity)
end
```

---

## Consideration Catalog

A reusable list of common considerations:

### Rendering Considerations
- R1: Frame rate requirements
- R2: Visual fidelity needs
- R3: Animation complexity
- R4: Screen space allocation
- R5: Layer/z-order management
- R6: Culling and optimization

### Input Considerations
- I1: Primary input device (mouse, keyboard, touch)
- I2: Interaction granularity (pixel, tile, entity, text)
- I3: Feedback latency tolerance
- I4: Multi-select needs
- I5: Drag operations
- I6: Text input volume

### Data Considerations
- D1: Update frequency
- D2: Data volume
- D3: Relationship complexity
- D4: History/persistence needs
- D5: Real-time sync requirements
- D6: Serialization format

### UX Considerations
- U1: Information density preference
- U2: Discoverability needs
- U3: Expert vs novice users
- U4: Accessibility requirements
- U5: Customization depth
- U6: Error handling visibility

### Technical Considerations
- T1: Platform constraints
- T2: Dependency availability
- T3: Performance budget
- T4: Memory constraints
- T5: Network requirements
- T6: Build/deploy complexity

---

## Consideration Matching Table Template

For documenting how considerations apply to a specific decision:

```markdown
## Decision: [What are we deciding?]

### Relevant Considerations

| ID | Consideration | Mode A | Mode B | Shared | Weight |
|----|---------------|--------|--------|--------|--------|
|    |               |        |        | Y/N    | 0-1    |

### Patterns Identified

1.
2.
3.

### Derived Principles

1.
2.
3.

### Implementation Notes

-
```

---

## Using This Document

1. Before designing a Phase 5 feature, read through consideration types
2. For each decision point, create a consideration matching table
3. Reference issue 500 for mode-specific considerations
4. Document patterns and principles discovered
5. Let principles guide implementation
6. Update this document with new consideration types discovered

---

## Meta-Considerations

Considerations about considering:

- **Completeness**: Have we considered all angles?
- **Relevance**: Are these considerations actually important?
- **Consistency**: Do our considerations conflict?
- **Changeability**: Might these considerations change?
- **Measurability**: Can we verify we met the consideration?

---

## Related Documents

- issues/500-dual-interface-rendering-considerations.md
- issues/501-507 (apply considerations to each)
- notes/vision (high-level project considerations)
