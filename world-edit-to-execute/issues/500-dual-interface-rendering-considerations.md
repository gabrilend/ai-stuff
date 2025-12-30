# Issue 500: Dual Interface Rendering Considerations

**Phase:** 5 - Rendering (Pre-planning)
**Type:** Design/Architecture
**Priority:** Critical
**Dependencies:** None (informs all Phase 5 issues)

---

## Purpose

Document considerations for supporting both **Warcraft-style** (RTS) and **WoW-chat-style** (social/MMO) interfaces. This issue captures the thinking process for designing a flexible rendering system that serves multiple presentation modes.

---

## Interface Modes

### Mode A: Warcraft RTS Interface

```
┌─────────────────────────────────────────────────┐
│  Gold: 500  Lumber: 200  Food: 12/50   12:34   │
├─────────────────────────────────────────────────┤
│                                                 │
│         Isometric Game World View               │
│              (terrain, units)                   │
│                                                 │
├──────────────┬────────────────┬─────────────────┤
│   Minimap    │  Unit Info     │ Command Panel   │
│              │  Portrait      │ [A][B][C][D]    │
│              │  HP/MP bars    │ [E][F][G][H]    │
└──────────────┴────────────────┴─────────────────┘
```

**Characteristics:**
- Top-down/isometric camera
- Real-time unit movement
- Selection-based interaction
- Command queue system
- Spatial awareness critical

### Mode B: WoW-Chat Social Interface

```
┌─────────────────────────────────────────────────┐
│  [Zone: Orgrimmar]  [Guild: <Example>]  [Time]  │
├─────────────────────────────────────────────────┤
│                                                 │
│  [Guild] Player1: Hello everyone!               │
│  [Guild] Player2: Hey! How's it going?          │
│  [Whisper] Friend: Are you there?               │
│  [Say] NPC: Welcome, hero.                      │
│  [System] You have earned 50 gold.              │
│                                                 │
├─────────────────────────────────────────────────┤
│ [Chat Input: ___________________________] [Send]│
├──────────────┬──────────────────────────────────┤
│  Character   │  Action Bar / Quick Commands     │
│  Portrait    │  [1][2][3][4][5][6][7][8][9][0]  │
└──────────────┴──────────────────────────────────┘
```

**Characteristics:**
- Text-centric display
- Persistent chat history
- Channel-based communication
- Avatar/portrait focus
- Social awareness critical

---

## Considerations Catalog

### C1: Shared vs Separate Codebases

| Consideration | Warcraft Mode | WoW-Chat Mode | Resolution |
|---------------|---------------|---------------|------------|
| Core renderer | Spatial rendering | Text rendering | Abstract interface supports both |
| Input handling | Click-to-select, RTS controls | Text input, chat commands | Mode-specific input handlers |
| Data display | Visual (positions, health) | Textual (messages, status) | Same data, different presentation |
| Update frequency | 60 FPS continuous | Event-driven updates | Configurable tick rates |

**Consideration:** Should these be two separate applications or one application with switchable modes?

---

### C2: Data Model Overlap

Both modes need:
- Player identity and state
- Unit/character information
- Resource tracking
- Social connections (allies/enemies)
- Event notifications

**Consideration:** The runtime (Phase 4) already models this. The question is presentation, not data.

---

### C3: Camera and Viewport

| Aspect | Warcraft | WoW-Chat |
|--------|----------|----------|
| Camera type | Spatial (x, y, zoom) | Scroll position (chat history) |
| Viewport | Map region | Message window |
| Navigation | Pan/zoom | Scroll up/down |
| Focus | Selected units | Current channel |

**Consideration:** Camera abstraction should support both spatial and linear (scrolling) modes.

---

### C4: Entity Representation

| Entity | Warcraft | WoW-Chat |
|--------|----------|----------|
| Unit | Sprite/circle at position | Name in chat, portrait |
| Building | Rectangle/sprite | Location reference |
| Player | Team color, units owned | Username, status, avatar |
| Resource | Number display | Inventory text |

**Consideration:** Need entity-to-visual mapping that's mode-aware.

---

### C5: Interaction Patterns

| Action | Warcraft | WoW-Chat |
|--------|----------|----------|
| Select | Click on unit | Click username |
| Command | Right-click destination | Type command |
| Chat | Chat box (optional) | Primary interface |
| View info | Hover/select panel | Click profile |

**Consideration:** Input system needs mode-specific bindings.

---

### C6: Real-time vs Event-driven

| Aspect | Warcraft | WoW-Chat |
|--------|----------|----------|
| Update model | Continuous simulation | Event queue |
| Visual updates | Every frame | On new message |
| Animation | Smooth movement | Typing indicators, timestamps |
| Latency sensitivity | High (gameplay) | Lower (social) |

**Consideration:** Rendering loop should support both continuous and event-driven updates.

---

### C7: Screen Real Estate

| Element | Warcraft Priority | WoW-Chat Priority |
|---------|-------------------|-------------------|
| Game world | Primary (70%+) | Secondary (preview?) |
| Chat/text | Secondary (small box) | Primary (70%+) |
| Controls | Always visible | Minimal/hidden |
| Status info | Compact bar | Detailed panel |

**Consideration:** Layout system needs flexible space allocation.

---

### C8: Visual Identity

| Aspect | Warcraft | WoW-Chat |
|--------|----------|----------|
| Color palette | Faction/team colors | Guild/class colors |
| Typography | Minimal, functional | Primary, styled |
| Icons | Command buttons | Emotes, status |
| Borders/frames | Stone/metal RTS | Fantasy chat bubbles |

**Consideration:** Theming system should support distinct visual languages.

---

## Design Patterns to Consider

### Pattern 1: View Adapter
```lua
-- Same game state, different presentations
local game_state = runtime.get_state()

if mode == "warcraft" then
    warcraft_view.render(game_state)
elseif mode == "wow_chat" then
    chat_view.render(game_state)
end
```

### Pattern 2: Component Composition
```lua
-- Build interface from reusable parts
local interface = {
    warcraft = { minimap, unit_panel, command_grid, game_view },
    wow_chat = { chat_window, character_panel, action_bar },
    shared = { status_bar, notification_area },
}
```

### Pattern 3: Event Translation
```lua
-- Same events, mode-specific handling
events.on("unit_created", function(unit)
    if mode == "warcraft" then
        sprites.add(unit)
    elseif mode == "wow_chat" then
        chat.system_message(unit.name .. " has appeared")
    end
end)
```

---

## Questions for Consideration Matching

These questions help match considerations to design decisions:

1. **Primary use case?**
   - Playing WC3 maps (Warcraft mode primary)
   - Social/chat experience (WoW-chat mode primary)
   - Equal importance (both fully featured)

2. **Mode switching?**
   - Runtime toggle (switch during gameplay)
   - Startup selection (choose before launch)
   - Separate builds (different executables)

3. **Data synchronization?**
   - Same game state, different views
   - Different data models per mode
   - Hybrid (shared core, mode-specific extensions)

4. **Development priority?**
   - Warcraft first, chat later
   - Chat first, Warcraft later
   - Parallel development

5. **Asset sharing?**
   - Common asset pack format
   - Mode-specific assets
   - Layered (base + mode overlays)

---

## Consideration Matrix Template

For each Phase 5 issue, evaluate against both modes:

```
Issue: [Number] [Name]

| Consideration | Warcraft Impact | WoW-Chat Impact | Shared? |
|---------------|-----------------|-----------------|---------|
| [C1]          |                 |                 |         |
| [C2]          |                 |                 |         |
| ...           |                 |                 |         |

Mode-specific requirements:
- Warcraft:
- WoW-Chat:

Shared implementation opportunities:
-
```

---

## Successor Issues

After this consideration document is reviewed, create:
- 500a: Define mode abstraction layer
- 500b: Design shared component library
- 500c: Specify mode-specific extensions

---

## Notes

This is a **thinking document** - its purpose is to capture considerations before implementation. The considerations here should be referenced when designing each Phase 5 issue.

The "consideration matching" process:
1. Read this document before starting a Phase 5 issue
2. Evaluate how the issue applies to both modes
3. Note which considerations are relevant
4. Design for flexibility where modes differ
5. Share code where modes align

---

## Sub-Issue Analysis

**Analysis Date:** 2025-12-29

### Recommendation: Keep as Single Issue (Thinking Document)

This issue explicitly states it is a **thinking document** - not an implementation issue. Its purpose is to:
- Capture considerations before implementation
- Inform all other Phase 5 issues
- Document the dual-interface philosophy

**No implementation work** is expected from this issue. It should be referenced by 501-507 during their design phases but does not produce code.

If concrete work emerges from this document, it should be captured as:
- 500a-c: Mode abstraction layer design (mentioned in Successor Issues)
- Updates to 501-507 to incorporate dual-mode considerations

---

## Related Documents

- issues/501-507 (Phase 5 issues this informs)
- notes/vision (project philosophy)
- notes/consideration-matching.md (methodology)
