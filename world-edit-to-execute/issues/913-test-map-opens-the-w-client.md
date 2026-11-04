# Issue 913: Test Map Opens the W Client

**Phase:** 9 - Editor
**Type:** Implementation
**Priority:** High
**Dependencies:** W02 (converts a WC3 map into WoW's files), W client issue 1109 (opens a handed-in map)
**Builds on:** 901 (the editor's F5 key), 911 (saving maps)
**Blocks:** W10 step 9

---

## Current Behavior

F5 in the editor plays the map being edited inside this project's own
viewer, with the game's rules run by this project's Lua simulation
(`src/runtime/`, `src/demo/wc3map/`). Nothing starts an AzerothCore or the
W client.

## Intended Behavior

The owner, 2026-11-04: "there should be a button to test the map that
opens the w-client." Asked who starts the local AzerothCore: "the editor."

F5 (and a Test Map button) does, in order:

1. Saves the map being edited.
2. Converts it through W02 into a build folder: terrain tiles, the map's
   registration, server rows and scripts, the map's own imported files.
   No Blizzard file is copied in; the W client finds those in the player's
   own install or draws a wire-frame.
3. Starts a local AzerothCore with that build, or reuses the one it
   already started, and waits until it accepts logins.
4. Launches the W client with the option that opens a handed-in map (W
   client issue 1109), straight into the map.
5. Waits for the W client to exit, reads its goodbye receipt (when it
   ended, frames drawn, seconds run), and shows it; a missing receipt is
   reported as a crash.

The editor owns the server it started: it stops it when the editor
closes, and restarts it when the next Test Map needs a new build.

## Suggested Implementation Steps

1. Settings: where AzerothCore and the W client live (paths read from the
   editor's settings, never hard-coded).
2. The server keeper: start, wait for its login port, reuse, stop.
3. The conversion call (W02) into a build folder under the project's
   `tmp/`.
4. Launch the W client with the map option; wait; read the receipt.
5. F5 and the toolbar button run steps 2-4; a log of each step goes to
   `tmp/shared-memory/`.

## Acceptance Criteria

- [ ] F5 on Daow 4.4 opens the W client on that map, against a local
      AzerothCore the editor started.
- [ ] A second F5 reuses the running server.
- [ ] Closing the editor stops the server it started.
- [ ] The receipt is shown after the W client closes; a crash is reported.

## Open Questions

1. **The old in-editor play.** Does F5's current run in this project's own
   viewer stay as an offline quick preview (no server needed), or retire
   once Test Map works?

## Related Documents

- `docs/wow-client-bridge.md` ("2026-11-04: the editor keeps its own
  renderer; Test Map opens the W client")
- W client: `/mnt/mtwo/games/azeroth-core/custom-client/issues/1109-test-map-from-the-editor.md`
- `issues/W02-build-wc3-maps-into-the-wow-client.md`
