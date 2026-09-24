# Issue W04: Compare the Real Client Against the Open Client

**Phase:** W - WoW Client Bridge
**Type:** Implementation (root; test apparatus)
**Priority:** Medium
**Dependencies:** W02 (launcher and server setup), W03 (open client rendering and replay)
**Unlocks:** W07

---

## Current Behavior

Nothing checks whether a model shown by our engine (or, later, by the
custom-client project) looks and moves like the same model in the real WoW
client. The only checks are unit tests on parsers and simulation. The machine
has wine and ffmpeg; it does not have Xvfb (a virtual screen) or xdotool
(synthetic keyboard and mouse input).

## Intended Behavior

An automated rig that, given a short **scenario** (a creature standing, then
walking, casting, dying; a camera position), does all of this unattended:

1. Starts a throwaway AzerothCore server (its own database, from the local
   checkout's `docker-compose.yml` or build) and fills the scenario in with GM
   commands sent over the server's SOAP or remote console.
2. Runs the real WoW client under wine on a virtual screen, logs in, places the
   camera, and records the screen with ffmpeg.
3. Runs the open client on the same scenario at the same time and resolution,
   and records it the same way.
4. Lines the two recordings up by a start marker and the server's event times.
5. Scores every frame pair with image statistics (structural similarity,
   silhouette overlap, colour histogram distance), spread across threads.
6. Sends only the worst-scoring pairs, with the scenario text, to a vision LLM
   that says what differs (pose, timing, colour, scale, missing effect) in a
   fixed JSON shape.
7. Writes a JSON report (generator) and an HTML page (viewer) with the frames
   side by side, a score-over-time chart and the LLM's notes.

Numbers decide pass or fail; the LLM explains. The reasoning is in
`docs/datapath-client-comparison-testing.md`.

## Suggested Implementation Steps

1. Scenario format: a Lua table (actors, timeline, camera). Five starter
   scenarios: idle, walk loop, melee attack, spell cast, death and corpse.
2. Server populator: SOAP client (enable SOAP in the test `worldserver.conf`);
   log every command with its server time.
3. Client runner: install Xvfb and xdotool; wine prefix per rig; xdotool types
   the test account at the login screen (addons cannot run there); an addon
   then fixes camera distance and pitch and hides the interface.
4. Recorder: ffmpeg screen capture of the virtual display at a fixed rate into
   `tmp/shared-memory/w04/<run>/a/`; the open client writes its frames directly
   into `…/b/`.
5. Aligner, measurer (thread pool; one frame pair per task), judge (LLM client
   behind one small interface so the model can be swapped), reporter.
6. A self-test: compare a recording with itself (must score perfect) and with a
   recording shifted by 3 frames (must be caught by the numbers alone).

## Acceptance Criteria

- [ ] One command runs a scenario end to end with no hand steps
- [ ] The self-tests in step 6 pass
- [ ] The five starter scenarios produce reports
- [ ] The judge's output always parses as the fixed JSON shape; a malformed answer is an error, not a skipped pair
- [ ] Recordings live only in `tmp/shared-memory/` unless the owner decides otherwise

## Open Questions

1. Which vision model judges: local (Ollama) or the Claude API?
2. Recorded frames contain Blizzard art. RAM-only (current plan), or kept on disk for regression history?
3. Is the "open client" first our engine (W03, recommended, since it exists sooner) or the custom-client project?

## Related Documents

- `docs/datapath-client-comparison-testing.md`, `docs/wow-client-bridge.md`
- `/mnt/mtwo/games/azeroth-core/custom-client/` (the other open client)
