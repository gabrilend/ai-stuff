# 105 - Build Protocol Packet Visualizer

## Status
- Phase: 1
- Priority: Medium
- Dependencies: 101, 102, 104
- Type: Phase Demo

---

## Current Behavior

No way to visualize or debug the protocol data being researched.
Documentation alone is insufficient for verifying understanding.

---

## Intended Behavior

A terminal-based visualizer that can:

1. Display sample packets from both games in parsed form
2. Show side-by-side comparison of equivalent packets
3. Highlight mapped vs unmapped fields
4. Demonstrate the translation data types in action

This is the Phase 1 demo deliverable, proving that protocol research
has produced actionable understanding.

---

## Suggested Implementation Steps

1. Create packet sample files:
   ```
   assets/samples/
     wow/
       movement.bin     -- Raw WoW movement packet
       movement.lua     -- Parsed representation
     coh/
       movement.bin     -- Raw CoH movement packet
       movement.lua     -- Parsed representation
   ```

2. Build TUI-based visualizer using project TUI library:
   ```lua
   -- Load sample packet
   local packet = load_sample("wow/movement")

   -- Display in formatted view
   tui.box("WoW Movement Packet", {
     { "opcode", packet.opcode },
     { "position_x", packet.x },
     { "position_y", packet.y },
     -- etc.
   })
   ```

3. Add side-by-side comparison mode:
   ```
   +-- WoW Packet ----------------+-- CoH Equivalent -------------+
   | opcode: CMSG_MOVE_START     | msg_type: PLAYER_MOVE         |
   | x: 1234.5                   | pos_x: 1234.5                 |
   | y: 567.8                    | pos_y: 567.8                  |
   | facing: 3.14                | orientation: 180 (degrees)    |
   +-----------------------------+-------------------------------+
   ```

4. Color-code translation confidence:
   - Green: Direct mapping exists
   - Yellow: Approximate mapping
   - Red: No mapping, needs narrative

5. Package as runnable demo:
   ```bash
   # issues/completed/demos/phase-1-demo.sh
   lua src/demos/packet-visualizer.lua
   ```

---

## Technical Notes

- Use the shared TUI library from `/home/ritz/programming/ai-stuff/scripts/libs/tui.lua`
- Sample packets can be fabricated for demo purposes if real captures unavailable
- Focus on demonstrating the DATA TYPES from issue 104, not necessarily real protocol

---

## Success Criteria

Running the demo should clearly show:
1. We understand packet structure of both games
2. We have defined translation data types
3. We can identify what maps and what doesn't

This sets the foundation for Phase 2's LLM integration work.
