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
   built; waits on patch          is unchecked (112, its last box)
   downloads (question Q-5)     older patch program shapes (112d), and the
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

### Q-3: What happens to the old renderer-interface issues (501-507)?
**Reshapes:** about 40 issues in Phase 5

They describe a Lua renderer with swappable backends, which the slot split
(decided 2025-12-30) replaced. About 8 of them are retired in substance
(the interface, registry, render events, default visual mode and its
backend, wiring, minimal UI, input); about 3 are built (the terrain colour
grid, basic unit shapes, team colours and selection); about 25 still name
real missing features (terrain heights, water, fog, health bars, a movable
camera, the minimap, the UI framework, asset packs) and need rewriting for
the C renderer.

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

### Q-5: May the patch programs be downloaded?
**Blocks:** 112b's completion, 112d

The version layers need each patch's game data. Public mirrors that are not
Blizzard's servers have been found (the Internet Archive's `wc3_patches`,
about 9.9 GB, and others listed in 112b); downloading waits on the owner's
go-ahead on source and size.

### Q-6: Is the thread-pool library move (802) kept?
**Depends on:** 515f

The ceramic engine's plan keeps the hand-written pool as its benchmark. 802
would replace that pool with the shared library. Wait for 515f's verdict, or
retire 802 now?

### Q-7: Are the guild files still live?
**Affects:** `GUILD-ROSTER.md`, `Q00-adventurer-quest-log.md`,
`B01-the-phantom-priority.md`

The roster lists two bounties as unclaimed that are completed. The quest log's
paths still resolve. The bounty's bug is real (debt D-1). Keep them as the
way newcomers find work, or archive them and make D-1 an ordinary bugfix?

### Q-8: Phase 7 leftovers from before the pivot
**Affects:** ghost and spirit rules

The archived death system asked four questions about the spirit world (can
enemies see a ghost, can ghosts use abilities, what if the hero dies while
reviving, can corpses share a tile). They were never answered and are parked
with the archived issues. Kept here only so they are not mistaken for
answered if death rules come back.

---

## 4. Known Debt

Bugs knowingly left in the code. Each names the line as of 2026-09-26.

### D-1: A better path does not move a queued point forward
**Where:** `src/runtime/pathfinding/astar.lua`, around lines 355-358
**Tracking:** bounty B01

When the pathfinder finds a shorter route to a point already waiting in its
queue, it records the shorter distance but leaves the point at its old place
in the queue. The point is then taken out later than it should be, and the
search does extra work. The two standard remedies: move the point up in the
heap (a heap that can find and re-sort one entry), or push it a second time
and skip stale copies when they come out (costs memory).

### D-2: Straight-line test compares to exactly zero
**Where:** `src/runtime/pathfinding/smooth.lua`, line 80

Path smoothing drops a middle point when three points are in line, by
testing the cross product for exactly zero. With fractional coordinates,
rounding makes that rare, so some straight runs keep points they could drop.
Remedy: compare against a small threshold.

### D-3: Reading four bytes without checking there are four
**Where:** `src/compat.lua`, the LuaJIT branch of the 32-bit readers (around
line 168)

On LuaJIT the readers take four bytes without checking the data is long
enough. A truncated file fails on arithmetic with a missing value, which
names the wrong cause. Remedy: check the length and raise an error that says
the file is truncated and where.

Fixed since the January version: the timer that was never removed (bounty B02)
and the component defaults shared by every entity (bounty B03; each entity
now gets its own deep copy).

---

## 5. Documentation Drift

Places where a document disagrees with the code or with another document.

| Where | Says | Reality |
|-------|------|---------|
| `issues/progress.md` | only Phase W has a per-phase progress file | the dashboard warns for every other phase |
| 911, 912 | export to `.wowmap` and "both modes" | WoW mode was dropped; both issues now say so at the top, and 911 asks what the editor saves instead (its open question 1) |
| 601 | lookup order: map, then community packs; folder `~/.world-edit-engine/` | for models the order is now the player's override for a model path, then the model the map requests (imported, or stock from the player's own install), then a placeholder (516, decided 2026-09-26); the player's install also supplies stock data (112); the roadmap says `~/.wc3-engine/` |

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
