# Critical Path

**Rewritten:** 2026-09-26, after a read-only audit of every open issue file.
The January version tracked the AzerothCore plan, Phase 7 and the threading
rewrite; it is in git history (`git log -p -- issues/CRITICAL-PATH.md`).
**Location:** `issues/CRITICAL-PATH.md` (also reachable as `docs/critical-path.md`,
a symlink)

This document holds four things, and only these:

1. **The path**: which lines of work are moving, and what each is waiting on.
2. **Decisions** that shape more than one issue, with where each was recorded.
3. **Open questions** that block or reshape issues, until they are answered.
4. **Known debt and drift**: bugs left in the code on purpose, and documents
   that disagree with the code.

Counts of done and open issues are not copied here, because they go stale.
Run the dashboard instead:

```bash
lua /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/world-edit-to-execute -m
```

To find issues that disagree with each other (one-sided links, orphans,
reused numbers):

```bash
/home/ritz/programming/ai-stuff/scripts/validate-issues /mnt/mtwo/programming/ai-stuff/world-edit-to-execute
```

---

## 1. The Path

Phases 1-4 (parsing, data model, triggers and JASS, runtime) are built. The
work now moves along four lines, and two of them wait mostly on the owner
watching a demo.

```
 THE CROWD AND ITS THREADING DESIGNS
 units path around units (405f) ──▶ the same crowd on every threading design (515k)
   built; waits on the owner          steps 1-3 committed; step 4 (films, report,
   watching it                         page) in progress, uncommitted

 THE NETWORK
 gameplay messages, server inside ──▶ crossing armies over the network (804)
 the client (803)                      built; waits on the owner watching it
   steps 1-4 built; step 5 (a refused
   order cancels the local guess)
   needs the client-side prediction
   from 515d ─────────────────────────┐
                                      ▼
 THE CERAMIC RENDER ENGINE            
 predict locally, snap to the ─┐
 server's correction (515d)    ├──▶ measured against the hand-written
 a growing asset table (515e) ─┘     thread pool (515f): the verdict that decides
                                     whether the render code ever moves to the
                                     shared thread-pool library (802)

 STOCK DATA FOR CONVERTED MAPS
 game-version layers (112b) ──▶ the converter refuses a map whose stock table
   built; its hunt for the        is unchecked (112, its last box)
   missing versions (Q-5)       older patch program shapes (112d), and the
                                published-values cross-check (112e), beside it
```

Everything else is either not started and not blocking (Phases 6, 9, W, the
map browser) or needs rewriting before it can start (section 4).

---

## 2. Decisions

Newest first. Each names where it was recorded, so the reasoning can be read
in full there.

| Date | Decision | Recorded in |
|------|----------|-------------|
| 2026-10-01 | **The custom client is a third project**, separate from this one and Everland Ghostsong, playing both; the two do most of the work on it. Its work starts this week and is not on this path. **One generation pipeline for both projects**, and generation plus the similarity score is the route meant to prove legality; the clean-room loop is optional. The score gains a 26-view camera ring, in-engine scenic photoshoots at server startup, region overlays and optional colour. | `docs/wow-client-bridge.md` (Decisions made), issue W05a |
| 2026-09-26 | **The January rendering plan is re-cut** (owner: "sure"). Eight issues describing a Lua renderer with swappable backends, or work the vertical slice already did, are retired to `issues/superseded/`. The other 32 are rewritten for the page split, each keeping its January design below as the record: the page's format and a headless renderer (501), the camera model (501d), terrain built once as chunk meshes (502), what is drawn for a unit besides its model (503), the override file's format (504), camera controls and debug overlays (505c, 505f), the interface as page items (506) and the minimap (507). Three that were mostly built stay open for their small gaps. | issues 501-507 |
| 2026-09-26 | **The editor saves `.w3x`, for now** ("We are already building compatibility for that system so we might as well"). **Player data lives in the project directory** by default, movable by a config file. **Model overrides are made through the game's UI**, not yet planned. | issues 911, 601, 516 |
| 2026-09-26 | A map with no weather holds four zero bytes in its weather code, and the map-info parser keeps them as read: correct data, not something to warn about (owner). The map-info test now prints the code escaped, so the test runner no longer sees raw null bytes. | `src/tests/test_w3i.lua` |
| 2026-09-26 | **Backend in ceramic, renderer in raylib, a page between them.** The owner: "We are building the backend in ceramic, and the renderer in raylib, with C being used (probably as soramech boxes) to create the 'page' that the renderer will draw from with a single thread to display on the screen." Readers that run once (such as the model reader) stay in Lua and hand their data to C, which keeps it for the map. | issues 515, 516, 116 |
| 2026-09-26 | **Draw the model the map asks for; players override it on their own machine; placeholders otherwise.** The owner: "use the models that the map requests. Even if they're stock. The user will build per-stock-model overrides that they can then have rendered on their end." This settles how the owner's earlier answer the same day applies in play: "use the models posted online rather than the ones in the game... use their models only when we are building in compatibility with their formats" (drawing what a map asks for is that compatibility). Stock models come from the player's own install; nothing Blizzard-made is shipped. WC3 textures are decoded by the same shared reader as WoW's. The WoW path's model chooser (W03) is the design for both systems; a stand-in is used until it exists. | issues 116, 117, 516, W03 |
| 2026-09-26 | **Fetching and browsing are split, generation from viewing.** Issue 603 is the fetcher: it finds maps and models on public hosting sites and downloads one over HTTP when a player asks. Issue 1001 is the catalogue: it shows what 603 found and never fetches. The file server (607) is retired; nothing in the project serves files. | issues 603, 1001, `issues/superseded/607-file-server-application.md` |
| 2026-09-26 | Files are still downloaded over HTTP from the public websites that host WC3 maps and models. rmail is for passing files between people; it does not replace fetching from those sites. | issue 603 |
| 2026-09-25 | **One host holds the truth; lockstep is dropped.** The host's machine runs the one simulation and every other player is its client. | `docs/wc3-engine-architecture.md` (Multiplayer Strategy), issue 803 |
| 2026-09-25 | The owner's personal details are never sent to an outside service unless the owner names that detail for that purpose. | `CLAUDE.md` (Privacy) |
| 2026-09-24 | MPQ archives are read through StormLib; the project's own reader was retired. | issue 114, `docs/formats/mpq-archive.md` |
| 2026-09-23 | **Assets pass between people over rmail**, "the only connection protocol for assets that I trust". 603's own transfer protocol is not built. | issue 609 |
| 2026-09-23 | **Stock unit and ability values come from the player's own WC3 install** at map load; nothing Blizzard-made is shipped. Community wikis are a cross-check only, never a source (their licence would bind the tables). | issue W02 (open question 4), issue 112 |
| 2026-09-23 | **Phase W: the WoW 3.3.5a client as an alternate host**, model source and test reference. Proprietary WoW files are read from the owner's client folder at run time and never committed. WC3 triggers run on the server through the ALE scripting engine (successor to Eluna, not script-compatible with it). | `docs/wow-client-bridge.md`, issues W01-W08 |
| 2026-09 | **The ceramic engine** is built as a second, measured render path beside the C renderer. Its one fixed rule: the host thread draws whatever state is present. The hand-written thread pool from issue 512 stays as the benchmark it must beat. | issue 515, `docs/render-architecture.md` |
| 2026-01-07 | **Pure WC3 engine; the AzerothCore integration was abandoned** (complexity against the preservation mission). Phase 7 and the WoW-mode issues were archived on 2026-01-08. Phase W (above) later brought the WoW client back as a *host*, not as the engine. | `docs/postmortem-azerothcore-integration.md`, `issues/archive/wow-mode-2026-01-08/` |
| 2026-01-02 | The renderer runs on the second threading design (a ring-buffer task pool); the first was removed, not wrapped. | `issues/completed/512f-main-integration.md` |
| 2025-12-31 | Camera transitions play back from frame arrays driven by a timer in the thread pool; each thread owns its copy of the data. | issue 409 |
| 2025-12-30 | **C draws; Lua writes render slots.** The vertical slice set this split: Lua never draws, it writes each unit's values into fixed slots and the draw thread only reads them. This replaced the plan for a Lua renderer interface with swappable backends (issues 501-507). | `issues/completed/508-vertical-slice-testing-room.md`, `docs/render-architecture.md` |
| 2025-12-29 | Coordinates are WC3-style, Y up, matching the game data. | this document's January version |
| 2025-12-29 | Raylib is the renderer. | this document's January version |

---

## 3. Open Questions

Each stays here until the owner answers it; then it moves to Decisions with
the answer and the date.

### Q-1: How do the three server routes relate?
**Reshapes:** 801 and its sub-issues, W02e, W08, 803

There are three ways a game can be hosted:
- the engine's own host inside a player's client (803), speaking this
  project's compact message records;
- AzerothCore with a shim that runs WC3 triggers as ALE scripts (W02e);
- our own server speaking the WoW client's protocol (W08), which W08 already
  calls the successor to the shim ("a stage-1 bridge only").

The first and third both run this project's own simulation as the one
authority and differ only in the wire format. If they are one simulation
with two front ends, the matchmaking protocol (801a) should reuse 803's
message layer instead of defining its own, and NAT traversal (801d) serves
only the open-client route.

### Q-4: Where do the missing render features go?
**Reshapes:** the rewrites from Q-3

- Does the UI framework (506) live in C next to the existing panel code, or
  in Lua writing into a buffer the C side draws? Given the split decided on
  2026-09-26 (section 2), the likely answer is: its per-frame layout is
  written into the page by C boxes, and the renderer draws it. Still to be
  confirmed by the owner.
- ~~Do terrain, unit and minimap features target the current C renderer,
  the ceramic path, or both?~~ Answered 2026-09-26: the backend is ceramic,
  the renderer is raylib, and C boxes build the page the renderer draws
  (section 2).

### Q-5: What closes the hunt for the remaining patch versions?
**Blocks:** 112b's completion

~~May the patch programs be downloaded?~~ Already done (the owner,
2026-09-26: "I thought we already downloaded most of them?"): layers are
built for 23 Frozen Throne versions and 20 Reign of Chaos versions
(`wc3-installs/patch-layers/`, `patch-layers-roc/`). What remains is 112b's
standing hunt ("hunt down every patch you can find"): the English Frozen
Throne versions 1.10, 1.12, 1.13, 1.15-1.18, 1.28.0-1.28.3 and 1.29.0, and
some Reign of Chaos ones, found on no mirror so far. Does 112b stay open
until they turn up, or does the hunt move to an issue of its own so 112b
can close on what is built?

### Q-6: Is the thread-pool library move (802) kept?
**Depends on:** 515f

The ceramic engine's plan keeps the hand-written pool as its benchmark. 802
would replace that pool with the shared library. Wait for 515f's verdict, or
retire 802 now?

### Q-7: Are the guild files still live?
**Affects:** `GUILD-ROSTER.md`, `Q00-adventurer-quest-log.md`,
`B01-the-phantom-priority.md`

The roster lists two bounties as unclaimed that are completed. The quest log's
paths still resolve. The bounty's bug was real (debt D-1) and was fixed by
the web session on 2026-09-29 (bounty B01, merged from pull request #1
on 2026-10-01). Keep the guild files as the way newcomers find work, or
archive them?

### Q-8: Phase 7 leftovers from before the pivot
**Affects:** ghost and spirit rules

The archived death system asked four questions about the spirit world (can
enemies see a ghost, can ghosts use abilities, what if the hero dies while
reviving, can corpses share a tile). They were never answered and are parked
with the archived issues. Kept here only so they are not mistaken for
answered if death rules come back.

---

## 4. Known Debt

Bugs knowingly left in the code. Each names the line as of when it was
written down.

None open as of 2026-11-02.

Fixed since the January version: the timer that was never removed (bounty B02)
and the component defaults shared by every entity (bounty B03; each entity
now gets its own deep copy).

Fixed since 2026-09-26:
- **D-1, a better path did not move a queued point forward**
  (`src/runtime/pathfinding/astar.lua`): bounty B01, resolved 2026-09-29
  by a Claude web session and merged from pull request #1 on 2026-10-01,
  for the owner's review. It chose lazy deletion: each queue entry carries
  the distance it was pushed with, and an entry whose distance is out of
  date is skipped when it comes out; ties go to the point already farther
  along. It also stopped A* returning a path longer than the shortest
  (`issues/completed/B01-the-phantom-priority.md`).
- **D-2, the straight-line test compared to exactly zero**
  (`src/runtime/pathfinding/smooth.lua`): issue 410, 2026-11-02. It now
  compares the sine of the angle to a tolerance, and a path that doubles
  back keeps its turn.
- **D-3, the binary readers read four bytes without checking there were
  four** (`src/compat.lua`): issue 118, 2026-11-02. A short read now
  raises "truncated data", naming the byte and the parser's line, on
  LuaJIT and on Lua 5.3+.

---

## 5. Documentation Drift

Places where a document disagrees with the code or with another document.

| Where | Says | Reality |
|-------|------|---------|
| `issues/progress.md` | only Phase W has a per-phase progress file | the dashboard warns for every other phase |
| 911, 912 | export to `.wowmap` and "both modes" | WoW mode was dropped; the editor saves `.w3x` (decided 2026-09-26); the design text is rewritten when Phase 9 starts |
| 911 (sub-issue 911c), `editor/mapfile.lua` | the unified format (a project folder or one `.wex` file) is built, and the editor opens and saves projects | built 2026-09-30 by a Claude web session working from a 2026-09-24 checkout, before the 2026-09-26 decision that the editor saves `.w3x` only and `.wex` is not built; merged 2026-10-01. Keep it, or retire it? (asked in 911's open questions) |
| 601, `docs/wc3-engine-architecture.md`, `docs/roadmap.md` | player data in `~/.world-edit-engine/` or `~/.wc3-engine/` | player data lives in the project directory, movable by a config file (decided 2026-09-26); the paths wait on the folder's name inside the project |

---

## How to Use This Document

- **A new question** goes into section 3 with what it reshapes or blocks and
  the options as they stand. Write it into the affected issue too.
- **An answer** moves the question to section 2, with the date and the file
  where the reasoning is written down.
- **New debt** goes into section 4 with the file and line, and why it was
  left.
- **Drift** goes into section 5 when found, and comes out when fixed.
- **The path** in section 1 is redrawn whenever an issue on it completes.
