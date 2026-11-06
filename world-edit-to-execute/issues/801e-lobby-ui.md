# Issue 801e: Lobby UI

**Phase:** 8 - Multiplayer & Networking
**Type:** Implementation
**Priority:** High
**Dependencies:** Issue 801c (client library), **Phase 5 (Rendering)**
**Parent:** Issue 801 (Matchmaking Server)
**Blocks:** 801h (the integration tests)

---

## Current Behavior

No lobby interface exists for pre-game coordination.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #309 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- A kick reuses the leave message with an optional field and the same protocol version: an older server reads it as the host leaving and closes the lobby, and an older client ignores being kicked.
- The lobby's "closed" handler sends the player back to the browser even after the game has started, losing the host address at the moment it's needed.
- Keyboard focus is stored as a position in the button list, which shifts when players join or leave, so Enter can kick the wrong player or start the game.
- During a countdown the idle-lobby timeout still applies; a countdown as long as that timeout closes the lobby before the start.
- Any player marking not-ready cancels the countdown, the host included, though the host's readiness isn't needed to start.
- Players are told the countdown rounded up to whole seconds while the server uses the exact value.
- A lobby update saying this player left is shown as "kicked by the host".
- A countdown message with no seconds silently becomes 0.
- New functions lack folds; the keyboard handler and the lobby-update handler are long if/else chains.

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

---

## Decisions (2026-11-05)

Made without the owner, each one theirs to overturn. Questions Q-1
(matchmaking over 803's messages) and Q-4 (the UI in C or Lua) are open.

1. **Lua, drawn through `render.ui_*`, like the in-game interface.** The
   screens (`src/ui/multiplayer/lobby_ui.lua`) are built the way
   `ui/wc3/hud.lua` and the editor's panels are: state, `update(input)`,
   `draw(ui)` over the 2D calls of `render/ui2d.c`. So they run headless
   in tests with a recorder, and if Q-4 settles on C, the drawing is the
   one part to move: the state and actions stay as they are.
2. **The countdown is the server's** (`countdown_seconds`, `--countdown`
   on the daemon; 0, the default, starts at once as before). The server
   says "countdown" with the seconds, and starts the game itself when they
   are up, so every player sees the same start. A player leaving, kicked
   or marking itself not ready stops it ("cancel"), and so can the host;
   nobody joins during one, and it isn't listed. The issue's parent asks
   for a countdown and names no length; 0 keeps the existing behaviour,
   and the configuration file of 801g is the place to set one.
3. **No new message types.** A kick is LEAVE_GAME from the host with the
   player's id (a new optional field); the countdown and its stop are
   LOBBY_UPDATE events "countdown" and "cancel" (with a new optional
   `seconds`); a kick is LOBBY_UPDATE "kick", sent to the kicked player
   too, whose lobby closes with "kicked by the host". Older clients
   decode all of it (the fields are optional).
4. **The host is the first player** of every player list (the server
   keeps it first); the library gives it as `lobby.host_id`.
5. **Start when every other player is ready**, checked by the screens, not
   the server: the server still lets a host start when it likes (801b),
   so a game without these screens isn't held to it.
6. **A Kick button on each player's row** instead of the mockup's
   dropdown: one click, and it fits the row layout.
7. **Each game's ping shows "-"** until something measures the trip to
   that host: nothing does yet (the punch of 801d is the place). The
   header shows the round trip to the matchmaking server, coloured green
   under 50 ms, yellow under 100, red from 100.
8. **Toasts, not raises.** Every failure (a refused join, a call the
   library refuses, a lost connection, a kick, a closed lobby) is a toast
   for four seconds; the screens never raise on a network failure.
9. **Keyboard:** the issue's keys (Enter sends chat, Ctrl+R ready, Escape
   leaves) plus Tab and Shift+Tab between the buttons that work, Space to
   press one (Enter, in the lobby, when nothing is typed), Up/Down and
   Enter in the browser, Page Up/Down and the wheel for the chat. A click
   doesn't take the keyboard's focus.

## What happened (2026-11-05)

- Server (`server.lua`): the countdown, its stop, kicks, joins refused
  during a countdown. Protocol: the optional `player_id` of LEAVE_GAME and
  `seconds` of LOBBY_UPDATE. Client (`client.lua`): `kick`,
  `cancel_start`, `starting_in`, `host_id`, `game`; events `countdown`,
  `countdown_cancel`, `player_leave(player, how)`; a kick closes the
  kicked player's lobby. Daemon: `--countdown N`.
- `src/ui/multiplayer/lobby_ui.lua` with its info page: the browser
  (filters, rows, joining), the create dialog, the lobby (players with [H]
  and ticks, map info, chat with scrolling, ready, start, stop, kick,
  leave), loading text, toasts, and a layout for any window size.
- `src/tests/test_matchmaking_lobby_ui.lua` (115 checks, no network): the
  countdown and what stops it, kicks and their refusals, through the
  server's core and the library; then the screens driven by clicks and
  keys and drawn into a recorder, at four window sizes with no button
  outside the window or over another. `test_matchmaking_daemon.lua`
  checks `--countdown` over a socket (32 checks now).
- In `run-net-tests.sh`; `src/cli/run-tests.sh -d DIR matchmaking` runs
  and counts it.
- Mutation check: 59 mutants of the server, library and screens, with
  `ulimit -f`; all 59 are caught, ten of them only after checks were added
  (the host kicking itself, a start a second early, two looks for games at
  once, a second start during a countdown, the game leaving a lobby
  itself, the browser not looking again after a kick, a lobby line not
  scrolling the chat down, R without Ctrl, a row past the list's end, a
  lost connection on the create dialog).

**Left:** the screens have only been drawn into a recorder: seeing them on
a real screen needs raylib, which isn't installed here, and a way into
them from the game's front menu. So the issue stays open.
