# Issue 801e: Lobby UI

**Phase:** 7 - Multiplayer & Networking
**Type:** Implementation
**Priority:** High
**Dependencies:** Issue 801c (client library), **Phase 5 (Rendering)**
**Parent:** Issue 801 (Matchmaking Server)

---

## Current Behavior

No lobby interface exists for pre-game coordination.

## Intended Behavior

A multiplayer lobby UI that provides:
1. **Game Browser** - List of available games with filters
2. **Lobby Screen** - Pre-game room with chat, player list, ready status
3. **Host Controls** - Start game, kick players, change settings
4. **Client Controls** - Ready toggle, leave lobby

### Game Browser UI

```
┌─────────────────────────────────────────────────────────────────┐
│  [<] MULTIPLAYER    [Find Game]                   [Create Game]│
├─────────────────────────────────────────────────────────────────┤
│  Region: [US-West ▼]  Players: [Any ▼]  Mode: [All ▼]         │
├─────────────────────────────────────────────────────────────────┤
│  MAP NAME                   HOST        PLAYERS   PING   JOIN   │
│  ──────────────────────────────────────────────────────────────│
│  Castle Defense v1.3        Player123   3/4      45ms   [Join] │
│  DotA Allstars 6.88         XxProxX     8/10     120ms  [Join] │
│  Tower Defense Elite        NoobMaster  2/8      35ms   [Join] │
│  Custom Arena Battle        Host99      6/12     85ms   [Join] │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Lobby Screen UI

```
┌─────────────────────────────────────────────────────────────────┐
│  [<] LOBBY: Castle Defense v1.3            [Leave] [✓ Ready]   │
├──────────────────────────┬──────────────────────────────────────┤
│  PLAYERS (3/4)           │  CHAT                                │
│                          │                                      │
│  [H] Player123 ✓         │  Player123: Hey everyone!            │
│  [2] FriendlyGuy ✓       │  FriendlyGuy: Ready to go!           │
│  [3] NewPlayer           │  NewPlayer: First time, be gentle   │
│  [4] ...                 │  Player123: No problem, welcome!     │
│                          │                                      │
│  MAP INFO                │  ────────────────────────────────────│
│  Name: Castle Defense    │  [Type message...            ] [Send]│
│  Mode: Co-op             │                                      │
│  Players: 1-4            │                                      │
│  Asset Pack:             │  [HOST ONLY]                         │
│   medieval-v1 (45 MB)    │  [Start Game]  [Kick Player ▼]      │
│                          │                                      │
└──────────────────────────┴──────────────────────────────────────┘
```

## Suggested Implementation Steps

1. Create `src/ui/multiplayer/` directory
2. Implement game browser screen
   - Connect to matchmaking server
   - Display game list (scrollable)
   - Implement filters (region, players, mode)
   - Implement join button handler
3. Implement lobby screen
   - Display player list with ready indicators
   - Display chat log (scrollable)
   - Implement chat input
   - Implement ready toggle
   - Implement leave button
4. Implement host controls
   - Start game button (only when all ready)
   - Kick player dropdown
   - Lobby settings panel
5. Implement create game dialog
   - Map selection
   - Player count setting
   - Game mode selection
6. Integrate with matchmaking client library
7. Add loading states and error messages
8. Style with consistent theme

## Acceptance Criteria

- [ ] Game browser displays available games
- [ ] Filters work (region, players, mode)
- [ ] Can create lobby as host
- [ ] Can join lobby as client
- [ ] Player list updates in real-time
- [ ] Chat works bidirectionally
- [ ] Ready status toggles correctly
- [ ] Host can start game when all ready
- [ ] Host can kick players
- [ ] Leave button returns to game browser
- [ ] Loading states shown during network operations
- [ ] Error messages displayed for failures
- [ ] UI responsive to window resize

## Related Documents

- Issue 801c - Client library (backend for UI)
- Phase 5 - Rendering (UI framework)
- Issue 506 - UI framework (if using)

## UI/UX Notes

- **Visual Feedback:** Show network latency with color (green <50ms, yellow <100ms, red >100ms)
- **Host Indicator:** [H] icon or crown for host player
- **Ready Status:** Checkmark ✓ for ready, X or empty for not ready
- **Chat Auto-scroll:** New messages scroll to bottom automatically
- **Keyboard Shortcuts:**
  - Enter: Send chat message
  - Ctrl+R: Toggle ready
  - Escape: Leave lobby
- **Accessibility:** All interactive elements keyboard-navigable
- **Loading:** Show spinner when connecting/joining
- **Errors:** Toast notifications for failures (connection lost, kick, etc.)

## Design Mockups

*(Optional: Add wireframes or design mockups here)*

## Notes

- Keep UI simple and functional - fancy graphics can come later
- Prioritize information density (show what matters: players, ready status, chat)
- Consider adding voice chat indicators (future enhancement)
- May want to show asset download progress if assets needed
