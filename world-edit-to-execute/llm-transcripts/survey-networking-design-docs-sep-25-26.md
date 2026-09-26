# Conversation Summary: agent-a0378cef0cdd744f7

Generated on: 2026-09-25 20:27:43
Models: claude-opus-5-5

--------------------------------------------------------------------------------

### User Request 1

In the project /mnt/mtwo/programming/ai-stuff/world-edit-to-execute (read-only;
don't change directory, use absolute paths), survey everything the documentation
and issue files say about NETWORKING / multiplayer: the game's network model
(lockstep vs. server-authoritative vs. client-server state sync), who runs the
simulation, what goes over the wire, tick rates, client prediction/correction,
and how the renderer receives state. Thoroughness: very thorough.

Read at least these (and grep for others: network, lockstep, server,
authoritative, protocol, tick, snapshot, replicate, desync, latency):
- docs/wc3-engine-architecture.md, docs/roadmap.md, docs/render-architecture.md,
  docs/critical-path.md, issues/CRITICAL-PATH.md, docs/wow-client-bridge.md,
  docs/postmortem-azerothcore-integration.md
- issues/801-matchmaking-server.md and 801a..801h,
  issues/603-server-asset-download-protocol.md, 607, 608
- issues/W08-our-own-server-speaking-the-same-protocol.md, W02
- issues/515-render-graph-on-the-ceramic-engine.md (point 4, "the client is a
  renderer")
- issues/completed/401a-core-fixed-timestep-loop.md, 401,
  407f-local-player-support.md, 508a
- issues/progress.md (status of any network-related issues)

Report (up to ~900 words), with file paths and line numbers for each claim:
1. Every distinct networking model the docs describe, and whether they AGREE or
   CONTRADICT each other (e.g. matchmaking docs assuming WC3-style lockstep
   peer-to-peer, while 515/W08 assume an authoritative server). Quote short key
   sentences.
2. What exists as code today for networking (search src/ for socket, enet, udp,
   tcp, server, protocol) — file paths, what they do, completed or not.
3. Which issues are open vs completed, and their dependencies/blockers.
4. What specifically the renderer / game-state side is expected to receive from
   the network (message types, state snapshots, orders), if stated.
5. Gaps: things the 515 design assumes (server states arriving with timestamps,
   corrections that snap, local order answers) that no networking issue yet
   covers.

--------------------------------------------------------------------------------

### Assistant Response 1

I've sent the full networking survey back as my report. The main finding is that
the docs describe two multiplayer models that conflict, and nothing reconciles
them.

- **Peer-to-peer lockstep:** every player runs the simulation and only commands
  go over the wire. This is still the official plan in
  `docs/wc3-engine-architecture.md:556-576`, `docs/roadmap.md:641-672`, and the
  matchmaking issues (`801-matchmaking-server.md:59`: "game traffic is
  peer-to-peer").
- **Authoritative server:** one server runs the game and the client only draws
  and gets corrected. This is the newer model in issue 515 point 4, 515d and
  W08. No document picks one model for the engine or retires the lockstep plan.

Other findings:
- **No networking code exists.** `src/` has no socket, UDP, TCP or matchmaking
  code. The only related pieces are the 62.5 Hz game loop, a unit-movement
  prediction module, and the completed 515c triple buffer, none of which has any
  network input.
- **Everything network-related is still open.** The 801 series (801, 801a-h) is
  open and isn't even listed in `progress.md`. 603, 607 and 608 are pending, W08
  is still design research, and 515d is pending.
- **Nothing defines messages for actual play.** 801a only covers the lobby
  (joining, chat, NAT punching). The roadmap mentions an issue 802 for gameplay
  networking, but it was never written.
- **Some docs disagree with each other:**
  - The tick rate is 62.5 Hz almost everywhere, but `docs/critical-path.md:560`
    targets 100 Hz for 512.
  - "Phase 8" is matchmaking in the roadmap but the threadpool issues 800-800f
    in `progress.md`.
  - 801 and 801h say "all 701 sub-issues" where they mean 801.
- **Asset downloads changed transport.** On 2026-09-23 603 switched to rmail, so
  its custom download protocol won't be built.
- **The groundwork lockstep needs was never done.** 401 requires fixed-point
  maths for determinism, but `gameloop.lua` still uses floats.

The gaps that 515 assumes but no networking issue covers:
- a format for sending server state to the client;
- whether "the time that was true" is wall-clock time or a frame number (W08
  uses a frame number);
- clock or frame sync between server and client;
- order IDs, so a predicted action can be matched to the server's correction and
  cancelled;
- how W08's "fast-forward a late message" rule interacts with 515's
  extrapolate-and-snap drawing;
- any server/client split in the current game loop, which 515's "offline, the
  local sim plays the server" needs.

The report also has line numbers for every claim, short quotes, the list of
message types each doc names, and the dependency chains between issues.

--------------------------------------------------------------------------------

