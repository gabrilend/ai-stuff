# Conversation Summary: agent-ad70205ab8da9b199

Generated on: 2026-09-26 11:55:24
Models: claude-opus-5-5

--------------------------------------------------------------------------------

### User Request 1

READ-ONLY audit. Do not edit, move, or commit anything. Do not cd; use absolute
paths.

Project: /mnt/mtwo/programming/ai-stuff/world-edit-to-execute (a WC3-compatible
game engine, Lua/LuaJIT + some C via raylib). Open issues are in issues/,
completed in issues/completed/. Key docs: docs/roadmap.md,
docs/render-architecture.md, docs/wc3-engine-architecture.md, issues/progress.md
(large), issues/CRITICAL-PATH.md.

Audit these OPEN issue files (all written Dec 2025, untouched since): 501,
501a-e, 502, 502a-e, 503, 503a-e, 504, 505, 505a-f, 506, 506a-f, 507, 507a-f.
They describe a Lua abstract render interface, terrain/sprite/UI/minimap
systems.

Since then the project built issue 508 (vertical slice, raylib/C), 512
(threading), 515 (the "ceramic engine" render graph), and completed issues exist
in issues/completed/ (e.g. 501f). Check git log (git -C <dir> log --oneline --
<path>) and the actual source tree (src/, anything render-related, C files) to
determine for EACH issue:
- status: done-but-not-moved / partially done / not started
- whether it's superseded or contradicted by the later architecture
  (508/512/515), with the concrete evidence (file paths, which completed issue
  or doc supersedes it)
- whether its acceptance criteria still make sense
Also note any sub-issues whose "Current Behavior" section is stale.

Report back a compact table: issue | status | superseded by / evidence |
recommendation (keep / rewrite / retire / complete-and-move). Then a short
paragraph on the overall shape of Phase 5. Be concrete; cite paths. Keep under
~900 words.

--------------------------------------------------------------------------------

### Assistant Response 1

I've sent the audit to you as my handback. I only read files and git history;
nothing was edited, moved or committed.

The 42 issue files (roots 501–507 and their lettered sub-issues) describe a
design the project moved away from:
- **What they assume:** a Lua renderer layer with swappable backends (terminal,
  SDL, LÖVE2D).
- **What was built:** the vertical slice (508) put drawing in C on raylib
  (`src/render/`). Lua only writes values into shared "slots" (`slots.h`)
  through a bridge, and the draw thread only reads them.
- **What comes next:** the ceramic render-graph work (515) is building a second
  render path beside the C renderer. Its one fixed rule is that the raylib main
  thread draws whatever state is present each frame.

**Status of the issues:**
- **Retire:** most of 501 (interface, registry, render events) and 505 (backend,
  wiring, minimal UI, input). They are either done differently by 508 or clash
  with the rule that the draw thread only reads. 505a still has a LÖVE2D
  renderer, though raylib was chosen in December 2025.
- **Done but never moved:** 502a (colour grid from a real map, `terrain.c`),
  503a (shapes) and 503c (team colours and selection). 508's own root file is
  also still open with every box unticked, though all its sub-issues are
  completed.
- **Real gaps worth keeping, rewritten for C/slots:**
  - terrain heights (502b) and water (502c)
  - health bars (503d)
  - a camera you can move (505c); it is fixed at `main.c:1299`
  - the minimap set (507, nothing exists yet)
- **Blocked:** fog of war (502d). There is no visibility system in
  `src/runtime/` for it to display.
- **Stale sections:** every issue's "Current Behavior" still says no rendering
  exists, and no acceptance box is ticked in any of them. 506 still refers to
  WoW-chat modes and "breakout windows", which came from the archived 510.
- **Overlap:** 504 (asset packs) overlaps the Phase 6 asset loader
  (`601-asset-loader-resolution.md`) and the Phase W model work.

**Docs that say the wrong thing:**
- `docs/roadmap.md:469` claims "501a complete", which is false.
- `docs/roadmap.md:468,476` still lists 500 and 510, which were archived in
  January.
- `issues/progress.md:389-413` shows all of these as Pending.

The handback has the full per-issue table with file paths.

The audit leaves two questions for you:
1. Should the UI framework (506) live in C next to `ui.c`, or in Lua writing to
   a buffer the draw thread reads?
2. Should new terrain, sprite and minimap work go into the current C renderer,
   the ceramic path, or both?

--------------------------------------------------------------------------------

