# Phase W: The WoW Client Bridge

**Status:** Design (issues W01-W07 created 2026-09-23, none started)
**Phase letter:** W (a lettered phase, like A, B, Q and X, so it can sit beside
the numbered engine phases without renumbering them)
**Issues:** see `issues/phase-W-progress.md`

---

## What this phase is

The numbered phases (1-10) build our own engine: it reads a `.w3x` map the way
an emulator reads a ROM and plays it with community art. Phase W connects that
engine to one specific outside program: the **World of Warcraft 3.3.5a client**
(build 12340), the version the AzerothCore server emulator speaks to.

The WoW client is used in three different roles. Keeping the roles apart is
the main design decision of this phase:

| Role | What the WoW client does | Issue |
|------|--------------------------|-------|
| **Alternate host** | Runs WC3 maps. We convert a `.w3x` into WoW terrain, placements and server scripts, and the player plays it inside the WoW client against a local AzerothCore server. | W02 |
| **Asset source** | Lends its 3D models and textures. Our engine reads them from the owner's installed client and shows them behaving the way WC3 would animate a unit. | W01, W03 |
| **Reference oracle** | Shows the ground truth. The real client and our open client render the same scene at the same time, both are recorded, and the recordings are compared by numbers first and then by a vision LLM. | W04 |

Two more issues then start taking the proprietary part back out:

| Issue | What it does |
|-------|--------------|
| W05 | Asset forge: pick one model, then find an openly licensed replacement on the internet or generate one with ComfyUI's image-to-3D nodes |
| W06 | Theme restyle: run the forge over *every* model (each NPC, each equipment set) with one style template, e.g. "neopunk". A later, compute-heavy job |
| W07 | Phase W capstone demo |

Dependency shape:

```
                 W01 read the WoW client's archives
                  │  (MPQ chain, DBC tables, BLP textures, M2 models)
        ┌─────────┴─────────┐
        ▼                   ▼
  W02 build WC3 maps    W03 show WoW models with
  into the WoW client       WC3 unit behavior
        │                   │
        └────────┬──────────┤
                 ▼          ▼
     W04 compare the real   W05 asset forge
     client against the         │
     open client                ▼
                 │          W06 restyle every model
                 └────┬─────┘
                      ▼
                 W07 phase W demo
```

---

## How this relates to the January pivot

On 2026-01-07 the project archived an AzerothCore integration design
(`docs/postmortem-azerothcore-integration.md`). That design made AzerothCore
the *platform*: WoW characters walking through portals into WC3 maps, hero
progression kept between sessions, and every WC3 mechanic converted into a
server equivalent. It was dropped because it pulled the project away from
preservation and doubled the systems to maintain.

Phase W brings back part of that research on purpose, but with a different
shape:

| January design (archived) | Phase W |
|---------------------------|---------|
| AzerothCore was the platform; the engine fed it | Our engine stays the platform; the WoW client is one host among others |
| Changed earlier phases (phase 5 split into client/protocol phases) | Leaves phases 1-10 alone; W is a side branch |
| Persistent MMO, portals, hero progression | One map at a time on a private local server |
| Planned to ship converted Blizzard-format data | Nothing proprietary is ever stored in or shipped from this repository; the converter runs on the owner's own client files on the owner's machine |

The postmortem's four "resurrection conditions" (engine playable, 100
community requests, 3 maintainers, AzerothCore partnership) are **not met**.
The owner chose to proceed anyway on 2026-09-23. That choice is recorded here
and in the postmortem's addendum so a later reader does not think the
conditions were quietly forgotten.

The vision (`notes/vision`) says the engine "is not a container for any
Blizzard-owned assets". Phase W keeps that true for the *engine*: proprietary
files are read at run time from a client folder the owner points at, like an
emulator reading a ROM dump the user made themselves. W05 and W06 exist so that
dependency can be removed one model at a time.

---

## Where things live on this machine

These are the paths the issues assume. A launcher config (W02) holds them so
no script hard-codes them twice.

| What | Path | Notes |
|------|------|-------|
| WoW 3.3.5a client | `/mnt/mtwo/games/azeroth-core/client/client-files/` | Holds `Data/` with `common.MPQ`, `common-2.MPQ`, `expansion.MPQ`, `lichking.MPQ`, `patch.MPQ`, `patch-2.MPQ`, `patch-3.MPQ`, and the `enUS/` locale archives |
| Client launch script | `/mnt/mtwo/games/azeroth-core/client/run` | Wine prefix, 32-bit (`WINEARCH=win32`). Its `DIR` points at `/mnt/dile/ritz/games/wotlk`, a different folder from the one above (see open questions) |
| AzerothCore source + build | `/mnt/mtwo/games/azeroth-core/azerothcore/` | Has `modules/mod-eluna` (a Lua scripting engine inside the server) and a `docker-compose.yml` |
| Server data extracted from the client | `/mnt/mtwo/games/azeroth-core/data-files/` | `dbc/`, `maps/`, `vmaps/`, `mmaps/`, `Cameras/` |
| The W client | `/mnt/mtwo/games/azeroth-core/custom-client/` | The open client (C + raylib) for AzerothCore's world and converted WC3 maps. Its issues 104-107 build `libwreaders.so`, the reading layer this project uses; its Phase 11 is WC3 map mode. No code yet |
| Map editor for hand touch-ups | Noggit (Noggit Red), not yet installed | Opens and edits WoW `.adt` terrain; used to inspect and tweak what W02's converter writes, never as the only way to make a map |

---

## Scale: one WC3 tile becomes one WoW terrain cell

This is the number everything in W02 hangs on, so it is written out.

WoW terrain is a grid of files called ADTs. One ADT is 533.33 yards square
(1600/3). It is cut into 16 × 16 **chunks** of 33.33 yards, and each chunk into
8 × 8 **cells** of 4.1667 yards. Each chunk stores heights at the 9 × 9 cell
corners ("outer vertices", shared with neighbouring chunks) plus 8 × 8 cell
centres ("inner vertices"): 145 floats, stored in the chunk's `MCVT` block.

A WC3 map is a grid of tiles 128 game units wide, with a height stored at every
tile corner ("tilepoint"): a map W tiles wide has W + 1 tilepoints across.

Mapping one WC3 tile onto one WoW cell makes the two corner grids line up
exactly: WC3 tilepoints become ADT outer vertices one-to-one, and the inner
vertices are the average of their four corners. That fixes the scale at

    128 WC3 units = 4.1667 yards,  so  1 yard ≈ 30.72 WC3 units

Checks that this scale is sane:

| Quantity | WC3 value | Converted | WoW reference |
|----------|-----------|-----------|---------------|
| Footman move speed | 270 units/s | 8.8 yd/s | Player run speed 7.0 yd/s |
| Cliff step | 128 units | 4.17 yd | about two character heights |
| Classic max map (256 × 256 tiles) | — | 32 × 32 chunks | 2 × 2 ADT files |
| Largest modern map (480 × 480 tiles) | — | 60 × 60 chunks | 4 × 4 ADT files (partly filled) |

So even the biggest WC3 map is at most 16 ADT files. The WoW client already
streams far larger maps, so size is not the constraint; texture layers are
(see W02: a chunk may blend at most 4 textures, and 8 × 8 WC3 tiles can hold
more than 4 ground types).

---

## The harness

The owner's phrase for W03 is "the harness between the user's control and the
client's output". In this project that harness is a chain with a recordable
stream at each end:

```
 input events        orders             simulation state         draw list          frame
 (mouse, keys)  ──▶  (move, attack,  ──▶ (positions, facing, ──▶ (model, anim    ──▶ (pixels)
  recorded           cast; phase 4      HP, animation state)     name + time,
  per tick           orders)            per tick                 team colour)
```

If the input stream and the tick rate (62.5 ticks/s, phase 4) are fixed, the
simulation is deterministic, so the draw list is reproducible. That is what
lets W04 put our open client's frames next to the real client's frames for the
same moment and ask "are these the same?".

---

## Separation of concerns inside the phase

Following the house rule "generate data in one place, view it in another":

| Generator (writes data) | Viewer (reads data) |
|-------------------------|---------------------|
| W02 converter writes ADT/WDT files, a patch MPQ, SQL rows and server scripts into a build folder | The WoW client and Noggit display them |
| W03 resolver writes a per-frame draw list | The raylib renderer draws it |
| W04 recorders write frame folders; comparator writes a JSON report | An HTML page shows the report side by side |
| W05/W06 forge writes candidate models plus provenance records | The engine and a gallery page show and rate them |

---

## Datapaths

Each feature has its own datapath document, updated whenever an issue changes
the flow:

- `docs/datapath-wc3-map-into-wow-client.md` (W02)
- `docs/datapath-wow-models-in-engine.md` (W01, W03)
- `docs/datapath-client-comparison-testing.md` (W04)
- `docs/datapath-asset-forge.md` (W05, W06)

---

## Decisions made

**2026-09-23: borrowed art, measured distance.** In the owner's words: "The
blizzard files aren't added to the engine because they aren't ours. However we
don't have enough 3d models, so we need to use Blizzard's because we have them,
until we can create new ones based on them. With sufficient alterations, they
will be visually distinct, but that requires some iteration, and for now we
should just try and have a 'similarity score' that rates the distance from the
original model, and we should try to improve our artwork bit-by-bit until it's
sufficiently distinct."

So every model the engine shows carries a **similarity score** against the
Blizzard original it replaces (W05a). The replacement-progress statistic
counts a model as replaced only when its score is past the distinctness
threshold, not merely when a new file exists.

**2026-09-23: the host becomes the open client.** In the owner's words: "the
purpose of creating a custom client is so that we can heavily modify it" and
"we are creating a new, custom, open source client. These problems will soon
disappear." The stock 3.3.5a client's limits (an addon can't read ground
clicks; the camera can't look straight down) are temporary. W02's control
work targets the custom-client project
(`/mnt/mtwo/games/azeroth-core/custom-client/`), which can offer native RTS
input and a top-down camera. The stock-client addon with ground-targeted
spells is only a stopgap until then.

**2026-09-23: the custom-client project becomes the W client.** The
custom-client project (`/mnt/mtwo/games/azeroth-core/custom-client/`) was
rewritten to this design. It is now the **W client**: one open client for both
AzerothCore's world and converted WC3 maps (its Phase 11, "WC3 Map Mode").
It builds the reading layer once, in C, as `libwreaders.so`, which this
project calls from Lua through LuaJIT's FFI (answers open question 2). It
loads converted maps as loose overlay folders, so `patch-W.MPQ` is only for
the stock client. The W design did not replace custom-client's networking,
login, UI, gameplay and social phases; those stay, because the W client
needs them to talk to AzerothCore.

**2026-09-23: "default client compatible" seal.** In the owner's words: "the
stock client doesn't need to read our archives, but it'd be neat. I think
models and such will have to have a seal or medal that says 'default client
compatible' and most models wouldn't have it." (W05c)

**2026-09-23: everything is replaced, and the goal is a legally distinct
game.** In the owner's words: "this we will have to replace over time as well.
Same for things like particle effects, textures, etc. Eventually, we want to
have a complete, legally distinct game, reverse engineered (with these
llm-transcripts as proof) from the best, yet legacy and deprecated, version of
the most powerful, impactful, and successful example of the genre." The
similarity score covers every asset kind, and every replacement records its
**lineage**: `derived` (made from or while looking at the original) or
`independent`. The score shows distance; lineage shows whether a clean-room
claim is available. Details:
`/mnt/mtwo/games/azeroth-core/custom-client/docs/012-asset-replacement-and-provenance.md`.

**2026-09-23: animations are reused.** Generated meshes get the skeleton and
animation set of an existing model. The owner picks the set from a catalogue
grouped by race or monster type (W05b).

## Open questions

These are written in the issue files too; each must be answered before the
issue that holds it can be called complete.

1. ~~Mission boundary~~ (answered above: borrowed art, measured distance).
2. ~~One reader or two~~ (answered: one C library in the W client, `libwreaders.so`, called here through the FFI).
3. **Which client folder.** `client/run` points at `/mnt/dile/ritz/games/wotlk`
   but the client files found are in `client/client-files/`. Which is the
   live install? (W02, W04)
4. **Scale.** Accept 1 WC3 tile = 1 WoW cell (4.1667 yd)? (W02)
5. ~~How the player commands units inside the WoW client~~ (answered above:
   natively in the custom client; the stock-client addon is only a stopgap).
6. **Which model judges the recordings.** A local vision model through Ollama,
   or the Claude API? (W04)
7. **Where the forge's "select a model" button lives first.** In our engine
   (it can read the model path directly), or in the WoW client as an addon
   (which cannot see model paths and must ask the server)? (W05)
8. **Publishing recordings.** Recorded frames of the real client contain
   Blizzard art. Keep them in RAM-backed `tmp/` only, or is keeping them on
   disk for regression history acceptable? (W04)
9. **Borrowed animations.** Reusing Blizzard skeletons and animation sets
   means the *motion* stays theirs even once mesh and texture are distinct. The
   similarity score only measures appearance. Should animations get their own
   score and replacement route later (e.g. retargeted motion capture)? (W05b)
10. **Distinctness threshold.** Which score counts as "sufficiently
    distinct"? The score is an engineering measure of how far one thing is from
    another. It is **not** a legal test of whether something is a derivative
    work. (W05a)
11. **Who runs a WC3 map's rules in the W client?** AzerothCore with converted
    server scripts (W02e), or this project's own simulation (phases 3-4)
    running inside the W client? Written in the W client's issue 1108.
12. **Server data.** Is AzerothCore's Blizzard-derived database (quests, NPC
    text, spells) inside "legally distinct", or only the client-side game?

---

## Related documents

- `docs/postmortem-azerothcore-integration.md` — why the January design was archived
- `docs/archive/azerothcore-2026-01-07/data-conversion-pipeline.md` — earlier WC3 → AzerothCore conversion research (terrain, units, items, doodads, triggers). Read with the correction noted at its top
- `docs/wc3-engine-architecture.md` — the engine Phase W connects to
- `issues/601-asset-loader-resolution.md`, `issues/602-wireframe-fallback-renderer.md` — the asset lookup chain W03 extends
- `/mnt/mtwo/games/azeroth-core/custom-client/docs/003-asset-formats.md` — WoW file formats as the custom-client project understands them

## Revision history

| Date | Change |
|------|--------|
| 2026-09-23 | Created with issues W01-W07 |
| 2026-09-23 | Owner's answers: borrowed art with a similarity score; custom client as host; reused animation sets. Added W05a, W05b |
| 2026-09-23 | custom-client rewritten as the W client; shared reader library; seal (W05c); replace every asset kind; lineage |
