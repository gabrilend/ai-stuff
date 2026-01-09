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

## Decided Answers (2025-12-31)

### D1: AzerothCore Integration Depth

**Decision:** Full emulation (Option D)

Create a single, unified server architecture that hosts all WC3 games. Develop a
unified client that switches on-the-fly between:
- **Top-down tactical view** (WC3 style)
- **Over-the-shoulder 3rd person view** (WoW style)

Both perspectives are fully comprehensive and use the same graphical scaling and
visualization elements. A player can play WC3 in WoW style, and WoW in WC3 style.

### D2: Simultaneous Views / Window Management

**Decision:** User-configurable (Options B, C, D all available)

- **Picture-in-picture** - Small chat overlay on RTS, or small RTS preview in chat
- **Split screen** - Both views side by side
- **Separate windows** - Multi-monitor support, each view in its own window

**Breakout windows:** UI panels (chat, professions, inventory) can be:
- Managed by the OS (window decorations, standard window behavior)
- Managed by the client (software window management, drag within client)

**WC3 default layout:**
- Permanent panels along top and bottom limiting viewport
- Overlay menus (e.g., ESC menu) appear on top of all elements
- Single-player: overlays pause the game
- Multiplayer: overlays do not pause

**Note:** wow-chat is a custom WoW addon (user's project) that provides the chat
interface model. Users can switch between WC3 mode and WoW mode at runtime.

### D3: Chat Message Sources

**Decision:** All sources (Option E)

Chat panel is separate and can be OS-managed or client-managed in both modes.

Message sources:
- **Player-to-player communication** (multiplayer chat)
- **NPC dialogue** (hardcoded trigger strings or Ollama-generated)
- **System messages** ("+50 gold", "Unit X attacked Unit Y for Z damage")

**Technical detail:** Messages are parsed from server packets. As packets they are
compressed; when expanded to text they become readable by:
- Players (chat display)
- Addons (data processing)
- Ollama (AI interpretation)

Future potential: Data stream (translated to English) could feed playerbot
personalities for AI-controlled units.

### D4: Character Persistence / Hero Identity

**Decision:** WC3 hero IS the WoW character (Option A)

When playing WoW, the player moves their character through zones, fights foes,
completes quests. This same gameplay can be performed in the WC3 interface by
guiding the hero through maps representing the unit's state in Azeroth.

**Architecture:**
- Both systems share maps and visuals
- Translation layer between AzerothCore (WoW functionality) and
  world-edit-to-execute (WC3 parser/renderer/engine)
- Both share the same data
- Both run in parallel, rendering the same underlying state

### D5: Visual Style / Theming

**Decision:** Unified theme (Option A) + Content-driven overrides (Option D)

**Base:** Unified visual theme across both modes (same fonts, colors, UI elements)

**Overrides:** When loading a WC3 custom map (playable in either WC3 or WoW style),
graphics are determined by models embedded in the map file. This allows:
- Map creators to define custom visuals
- Users to replace graphics with their own choices
- ROM-style interpretation of assets (maps are free to distribute)

**Future:** In-game mod browser for discovering and loading custom content (later phase)

### D6: Camera Transition Architecture

**Decision:** Frame-based binary vectors with mise en place threading

Camera transitions between perspectives (WC3 top-down ↔ WoW 3rd-person) use binary
vector arrays ("frames") as described in issue 409. This approach enables:

- **Timer in thread pool:** Transitions run as scheduled tasks in the thread pool
- **Mise en place philosophy:** Duplicate data, compute in parallel, sync rhythmically
  - No mutexes or locks - each thread owns its data copy
  - Sync points at defined intervals rather than per-operation
- **Smooth interpolation:** Frame sequences describe the camera path as a shape
- **Interruptible:** New input can abort/modify in-progress transitions

**Reference:** `notes/conversations/2025-12-30-frame-encoding-dna.md` for frame encoding details.

### D7: Chat System Architecture

**Decision:** WoW-centric first, minimal friction

The chat system is designed around WoW conventions as the primary interface:

- **Native WoW protocol:** Messages follow WoW channel/whisper patterns
- **Minimal game state friction:** Chat is a separate subsystem, not tied to game ticks
- **Available in both modes:** Same chat panel works in Warlord and Hero perspectives
- **Decoupled from simulation:** Chat messages are UI events, not gameplay events

This allows the chat to feel responsive regardless of game tick rate or simulation load.

### D8: wow-chat Integration (Reference Implementation)

**Decision:** Use libs/wow-chat as reference architecture

The wow-chat addon (cloned to `libs/wow-chat/`) demonstrates the "empty world" gameplay:

**Architecture:**
- All base creatures/monsters dropped from SQL database
- World is procedurally populated around each player via periodic events

**Spawn Systems:**
| System | Interval | Description |
|--------|----------|-------------|
| Mordaunts (ambush.lua) | 21s | Hostile creatures attack-move toward player |
| Travellers (travel.lua) | 210s | Friendly NPCs walk "downhill" through the area |
| Treasure (treasure.lua) | 120s | Loot chests spawn near player |

**Key Concepts:**
- **Mordaunts:** Level-appropriate monsters from creature_template, rank-filtered
  (regular, rare, rare-elite based on group size)
- **Travellers:** Vendors, trainers, innkeepers that walk paths determined by terrain
  height (always moving "downhill" toward lower elevation)
- **Player-centric spawning:** Content materializes around each player, supporting
  both solo and multiplayer emergent gameplay

**Integration Point:** The same periodic event architecture can drive entity spawning
in both WC3 and WoW perspectives - same underlying events, different visual presentation.

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
