# Phase W: The WoW Client Bridge

**Status:** In progress. Issues W01-W07 created 2026-09-23; the move of this project's client into the W client started 2026-10-07 (see "The client's move into the W client" below)
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
| Client launch script | `/mnt/mtwo/games/azeroth-core/client/run` | Wine prefix, 32-bit (`WINEARCH=win32`). Its `DIR` still names `/mnt/dile/ritz/games/wotlk`, an older location; the live client is the folder above (confirmed by the owner 2026-09-24) |
| AzerothCore source + build | `/mnt/mtwo/games/azeroth-core/azerothcore/` | Has `modules/mod-eluna` (the older Lua scripting engine; the project uses its successor ALE, `mod-ale`) and a `docker-compose.yml` |
| Server data extracted from the client | `/mnt/mtwo/games/azeroth-core/data-files/` | `dbc/`, `maps/`, `vmaps/`, `mmaps/`, `Cameras/` |
| The W client | `/mnt/mtwo/games/azeroth-core/custom-client/` | The open client (C + raylib) for AzerothCore's world and converted WC3 maps. Its Phase 11 is WC3 map mode. Has code since 2026-10-07 (wow-chat-2026's custom client moved there): `libwreaders.so` (archives, tables, pictures, models, ground, buildings) is built by its `scripts/build` and loads from LuaJIT with `scripts/libs/wreaders.lua` |
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

**2026-09-23: AzerothCore runs converted maps' rules; the tools live in
userspace; a shared criteria set keeps everyone in one game.** The forge,
the clean-room loop and the fit checks are user-side tools, not engine code:
"anyone can describe their own examples, and if we can isolate a criteria set,
then we should all be able to create whatever we want, and still be able to
communicate the same game." Gameplay reads only the criteria and the map file,
never a player's art (W05d). For now only meshes are made; custom skeletons
and animations come later through a system not yet designed, targeting W05e's
body plans. world-edit-to-execute's maps don't use WoW's world; what the server
still takes from Blizzard for them is listed in
`docs/licensing-and-boundaries.md`. Maps are found, not bundled (issue 1001).

**2026-09-23: animations are reused.** Generated meshes get the skeleton and
animation set of an existing model. The owner picks the set from a catalogue
grouped by race or monster type (W05b).

**2026-10-01: the custom client is a third thing.** In the owner's words:
"the custom client should be able to handle assets and gameplay from both
engines. So it is a third thing, separate from both, yet these two projects
will be doing most of the work on the third." Its work starts this week; it
is not on this project's critical path.

**2026-10-01: one pipeline, and the score is the route to legality.**
Everland Ghostsong's generated models pass the same similarity score (W05a)
as this project's. Generation plus the score is the route the system means
to prove; the clean-room loop (W05d) is optional. The score gains a
26-view camera ring (42 with 5 heights), scenic-vista photoshoots rendered
in-engine at server startup, region overlays that mark which parts are most
similar, and colour as an optional part. What needs a score: only what is
pulled directly from the game and used as an input to an AI process
(answers open question 12 for now: the server's data is examined later).
Details and the owner's words: W05a.

**2026-10-07: one engine, two games; WC3 maps on AzerothCore, server-authoritative.**
The W client took in wow-chat-2026's working client (C on raylib) and is
to take in this project's client too, in C: "The renderers need to merge.
We should be able to load both model types and animations and
particles... all visual stuff. Also audio is shared ... The goal is to be
able to play both games seamlessly in the same binary" (the owner). Lua
stays the scripting language. On networking: "I think we transition WETE
to Azerothcore then", and, weighing lockstep: "I think lockstep isn't
worth the implementation cost. Let's just do server-authoritative and
call it good. Maybe lockstep for WETE LAN games or something...?" So a
converted map runs on AzerothCore as the WoW world does: players send
orders, the server runs the map's rules and sends each player what it
can see. This project's own engine may keep a lockstep LAN mode. This
is W08's stage 1 (AzerothCore installed, not bundled); W08's own server
(stage 2, for the licence) is unchanged by it. Details: the W client's
docs 000, 001 and 004; wow-chat-2026 issue 173v.

## The client's move into the W client

Started 2026-10-07. The W client's roadmap
(`/mnt/mtwo/games/azeroth-core/custom-client/docs/009-roadmap.md`, "The
second crosswalk") lists every part of this project's client and where
it goes: a **C twin** in the W client (checked byte for byte against
the Lua here once, then the Lua reader is deprecated), **replaced** by a
part the W client already has, or **staying here** (the editor, the
extractors, the map browser).

| Step | State |
|------|-------|
| WC3's pictures (BLP1, with its JPEG) in C: W client issue 107a (completed) | Reading built 2026-10-07. Every BLP1 in `war3.mpq` and `War3x.mpq` decodes to the same bytes as `src/parsers/blp.lua` (W client `tests/050-blp1-matches-lua.lua`) |
| WC3 models (MDX) into the W client's model structure: its 401 step 2 | next |
| WC3 animations through the same posing: its 402 step 1 | after 401 |
| WC3 particles and ribbons: its 403 | after 402 |

Found on the way: the W client's own archive reader opens WC3's
`war3.mpq` and `War3x.mpq` directly. Maps with damaged or hidden file
tables are still read here through StormLib before conversion.

**2026-10-07: who does what.** The owner: "The end result ideally is that
this project handles the editor and the WC3 extractors and the custom map
browser. The custom client should handle the custom models ... and
rendering and such. That doesn't involve gameplay, because the gameplay
can be built into the maps themselves with the editor, which stays here."

| world-edit-to-execute | The W client | AzerothCore |
|-----------------------|--------------|-------------|
| The editor (writes a map, its rules included) | Drawing, sound, input, the interface | Runs a map's rules while people play: every trigger and WC3 mechanic, in ALE Lua or by server patches ("We might be able to implement those in Lua ALE? But patches are fine too.") |
| The extractors (WC3 files into a converted map), through the W client's C readers | The custom model system (packs, resolver, scores) | Holds the truth |
| The custom map browser, drawn as an HTML page onto a flat pane in the W client ("maybe we just render the browser to HTML and cast it onto a flat UI pane in the W client? And our Azerothcore project ... can do the same.") | Pictures drawn without a window (previews) | |

**2026-10-07: the editor is a mode of the W client** (superseded
2026-11-04, below). "let's make the editor a mode of the W client." Its
code stays here and is worked on here; the W client loads it and draws
for it, so there is one renderer. This project's renderer (`src/render/`)
retires only once the W client's editor mode opens, edits, saves and
test-plays a map (W client issue 1109).

**2026-11-04: the editor keeps its own renderer; Test Map opens the W
client.** The owner: "world-edit-to-execute should be in charge of the
data extraction from wc3. It should be a map-editor for wc3 and World of
Warcraft, sorta like Noggit except with the capability of the
world-edit.exe from warcraft3. It has a lua renderer right now, but we're
building a C renderer for in-game - the lua renderer is only for the
editor, not the client." And: "there should be a button to test the map
that opens the w-client. The map editor should have a renderer (lua) that
displays the map and such so you can edit it of course."

So there are two renderers, each with one audience. The Lua one here draws
what is being edited; the C one in the W client draws what is being
played. Neither retires the other. The editor stops being a game: this
project's map viewer (play mode, the F5 run of its Lua simulation) gives
way to the Test Map button, which converts the map being edited and opens
it in the W client against a local AzerothCore (W client issue 1109,
reshaped to that).

| world-edit-to-execute | The W client | AzerothCore |
|-----------------------|--------------|-------------|
| The extractors: WC3 files into a converted map | Drawing for play, in C | Runs a map's rules while people play |
| The editor, for WC3 maps and WoW maps (Noggit's reach, world-edit.exe's depth), drawn by this project's Lua renderer | What Test Map opens | Holds the truth |
| Packs and the asset lookup for the editor (`src/assets/loader.lua`), the Lua twin the W client's C lookup is checked against | Packs and the asset lookup for play (its 105a), the same manifest format | |
| Sharing a map with its models, "check out my map": the map and its list in one rmail message, received by the editor or launcher (issue 609) | Hosting a map with its models, "come check out my map": the list comes with the join, asked about once, used for that game, taken off after (its 1110, carrying the rules of pull request #227) | |
| A small launcher for browsing maps, models and shared lists, and the same catalogue as a page in an ordinary web browser, its moving parts in JavaScript (issue 1001) | A web browser addon that opens that same page inside the game (its 710) | |
| Wire-frames where the editor has no model (issue 602) | Wire-frames where the player has no model (its 105a, step 4) | |

**Who sees a wire-frame.** The owner: "The wire-frame rendering should be
in the custom-client for when we don't have a model, but that should be
only for when the map doesn't provide one, or when the map provides one
that's from a proprietary source and the viewer/player doesn't have access
to it - for example a player who hasn't bought WC3 should probably see
wireframes if they're playing on a default Blizzard map." The W client's
lookup order already says this: the player's packs, then what the server
delivered with the map, then the player's own Blizzard install, then the
wire-frame. A server never delivers a file whose source is Blizzard's
(open question 16, answered). The editor draws wire-frames too (the
owner, same day), for the same two cases.

**Our own models are the default; Blizzard's plug in.** The owner, the
same day: "we're going to be creating our own assets that have 'feature
parity' with the blizzard models, but which are aesthetically distinct.
We have a whole pipeline for this set up ... we're going to have sensible
defaults, and if users want, they can plug in their Blizzard assets,
since they should be compatible." The pipeline is the asset forge (W05:
find or generate a replacement; W05a, the similarity score; W05b,
borrowed skeletons and animation sets; W05c, the "default client
compatible" seal; W05d, the clean-room loop; W05e, body plans; W06, one
style for every model). Its output is the **baseline standard model set**
the W client's docs/012 waits for ("which will be a requirement until we
develop our own baseline standard model set"). With it, the lookup reads:
the player's packs, the server's files, the player's own Blizzard
install if they plugged it in, the baseline set, and only then the
wire-frame. A player without WC3 sees the baseline set's models; a
wire-frame means nothing at all matched, neither a model of the map's
own, nor theirs, nor ours.

**2026-10-07: one reader per format, in C.** "Let's just deprecate the
lua version and keep the C version." Each Lua reader here is retired
once its C twin in the W client (`libwreaders.so`, called through
LuaJIT's FFI) matches it byte for byte; the first, BLP1 and JPEG,
already does. This project's Lua runtime (combat, pathing, economy) is
not a reader: it stays as the reference AzerothCore's version of each
rule is checked against.

## Open questions

These are written in the issue files too; each must be answered before the
issue that holds it can be called complete.

1. ~~Mission boundary~~ (answered above: borrowed art, measured distance).
2. ~~One reader or two~~ (answered: one C library in the W client, `libwreaders.so`, called here through the FFI).
3. ~~Which client folder.~~ Answered 2026-09-24: `/mnt/mtwo/games/azeroth-core/client/`
   (game files in `client-files/`).
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
11. ~~Who runs a WC3 map's rules in the W client?~~ Answered 2026-09-23:
    AzerothCore, with triggers converted to server scripts (W02e). Licence
    consequences: `docs/licensing-and-boundaries.md`.
12. **Server data.** (Deferred 2026-10-01: only what is pulled from the game and fed to an AI process needs a score now; the rest is examined later.) Is AzerothCore's Blizzard-derived database (quests, NPC
    text, spells) inside "legally distinct", or only the client-side game?
13. ~~WC3 ground in the W client~~ Answered 2026-10-07: one ground mesh
    painted both ways, WC3 cliffs seated onto it ("Cliffs placed onto a
    terrain mesh should jump to the highest point that their lowest point
    intersects with the terrain... or something similar"). W client
    roadmap, second crosswalk.
14. ~~Flat-shaded designs~~ Answered 2026-10-07: placeholder art in the
    W client, and a test of its custom model system.
15. ~~The thread pool~~ Answered 2026-10-07: the ceramic engine becomes
    the W client's shape, with no main loop: workers run every part as
    stations, and render threads (one per OpenGL context) only draw. W
    client issue 110 and its sub-issues.
16. ~~**Does a server ever hand out Blizzard's files?**~~ Answered
    2026-11-04: never. The owner: "well yes they aren't our files so we
    can't distribute them. We're building an architecture around them,
    that allows them to fit inside should the user provide them. This is
    why we started with data extractors, they are the most important part
    to understanding the nature of the structure we need to build." So
    the server's step of the W client's lookup carries only files that
    aren't Blizzard's: a map author's own ground, placements and imports.
    Stock models a map uses are drawn from the player's own install if
    they plugged it in, or from the baseline standard model set the asset
    forge makes (the owner, same day: "we're going to have sensible
    defaults, and if users want, they can plug in their Blizzard assets";
    see "Our own models are the default" above). The question as asked:
    does a player without WC3 get a default Blizzard map's converted
    ground with wire-frames standing on it, or is the map not offered to
    them at all? (The map file's own part of this is question 17.)
17. ~~**A Blizzard map's own file.**~~ Answered 2026-11-04, the owner:
    "we don't place any limitations on what maps players host for each
    other." So the project ships no Blizzard file, and it doesn't check or
    block which map a player hosts: a host serves the map they chose, and
    the other players' clients draw its stock models from their own packs,
    their Blizzard install, or the baseline set. The question as asked:
    the baseline set covers a default map's models, but the map itself
    (its ground, placements, triggers) is Blizzard's file too. Is a
    default Blizzard map played only from the player's own copy, or does
    the project make its own maps standing in for them, the way the
    baseline set stands in for the models?

---

## Related documents

- `docs/postmortem-azerothcore-integration.md` — why the January design was archived
- `docs/archive/azerothcore-2026-01-07/data-conversion-pipeline.md` — earlier WC3 → AzerothCore conversion research (terrain, units, items, doodads, triggers). Read with the correction noted at its top
- `docs/wc3-engine-architecture.md` — the engine Phase W connects to
- `issues/completed/601-asset-loader-resolution.md`, `issues/602-wireframe-fallback-renderer.md` — the asset lookup chain W03 extends
- `/mnt/mtwo/games/azeroth-core/custom-client/docs/003-asset-formats.md` — WoW file formats as the custom-client project understands them

## Revision history

| Date | Change |
|------|--------|
| 2026-09-23 | Created with issues W01-W07 |
| 2026-09-23 | Owner's answers: borrowed art with a similarity score; custom client as host; reused animation sets. Added W05a, W05b |
| 2026-09-23 | custom-client rewritten as the W client; shared reader library; seal (W05c); replace every asset kind; lineage |
| 2026-10-07 | The client's move into the W client started: the crosswalk, WC3's pictures read in C; open questions 13-15 |
| 2026-11-04 | The editor keeps its Lua renderer and edits WoW maps too; Test Map opens the W client; sharing belongs to the editor, using a list in a game to the W client; who sees a wire-frame; our own baseline model set is the default and Blizzard's plug in; open question 17 |
