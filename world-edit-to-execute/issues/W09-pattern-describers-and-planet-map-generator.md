# Issue W09: Pattern Describers and the Planet Map Generator

**Phase:** W - WoW Client Bridge
**Type:** Implementation (root; split into W09a-W09h)
**Priority:** Medium
**Dependencies:** W02a (terrain → ADT writer), W02c (map registration), W02d (server data for new maps)
**Blocks:** wow-chat-2026 issue 919 (three worlds: Earth, Mars and the Sun)
**Builds on:** the terrain grid shape the WC3 parser already produces (`src/parsers/`), the terrain renderer (502)

---

## Origin

Asked for by the owner on 2026-10-20, from the wow-chat-2026 project
(`/mnt/kaun/wow-chat-2026/issues/919-three-worlds-earth-mars-sun.md` holds
the whole message, verbatim). The part that names this project:

> then, use /home/ritz/programming/ai-stuff/world-edit-to-execute/ to create
> data describers that correlate patterns and generate realistic or plausibly
> interesting conceptions for a world shaped with the same geometry, but
> differing components. For example, what if mars was patterned like earth?
> the west half of north america, or the flat plains of kansas, rolling when
> not at a distance?

## Current Behavior

The project turns a WC3 map's terrain grid into WoW terrain files (W02a,
designed, not built). It has no way to make terrain that did not come from a
WC3 map: no reader for real elevation data, no measure of what a landscape
"is like", and no generator that can make new ground that is like a given
place without copying it.

The sub-issues W09a-W09h are listed below and not yet written as files;
each gets its file when its work starts.

## Intended Behavior

Two separate halves, kept apart on purpose (data generation and data viewing
are separate programs, CLAUDE.md):

1. **Describers** read a real surface (an elevation grid, or a photograph
   when no elevation exists, as for the Sun) and write a **pattern
   description**: a small file of numbers that says what the ground is like
   (how steep, how rough at each size, which way the ridges run, how often
   valleys branch, where it is flat) without containing the ground itself.
2. **The generator** takes a *shape* from one world (its large features: the
   continents of Earth, the Tharsis bulge and Hellas basin of Mars, the
   Sun's supergranule cells) and *components* from a description of
   another, and grows terrain that has the first one's geometry and the
   second one's texture. "Mars patterned like Earth" is Mars's shape filled
   with the Rockies' and Kansas's descriptions.

The output is a terrain grid in the same shape the WC3 parser produces (a
height field, ground texture indices, water level), so W02a's writer, W02c's
registration and W02d's server data turn it into a map the WoW client walks
on with no new conversion code.

### Why the generator must invent small-scale ground

One WoW map is at most 64 × 64 terrain tiles of 533.33 yards each, about
34,133 yards (31.2 km) across. Spreading a whole planet over one map, area
for area (worked by hand; W09c's scale calculator replaces these numbers):

| World | Surface (km²)        | Real metres per game yard | A 2.5 km mountain becomes |
|-------|---------------------:|--------------------------:|--------------------------:|
| Mars  |       144,800,000    |                    351    |                 7.1 yards |
| Earth |       510,000,000    |                    661    |                 3.8 yards |
| Sun   | 6,090,000,000,000    |                 72,000    |   (granules: ~14 yards)   |

At that scale Colorado (about 450 km wide) is a patch about 680 yards across,
and the Rockies are a bump a player steps over. Real heights cannot be copied
in: they vanish. So the large shapes come from the real world, and everything
a player sees within a few hundred yards is *grown* from the describers, at
the steepness and roughness of the place it imitates. That is the reason for
describers rather than a heightmap import.

### And at real-world scale, the other way round

The owner, 2026-10-20: "can we make it real-world scale? My character is
about 6 feet tall." A recipe's scale is a field, and at one game yard per
real yard the roles swap: one map holds a 31 km square, real heights go in
as they are (US lidar at 1 m is finer than the client's 3.8 m cells), and
the describers only add detail smaller than a cell, checked against the
real ground. A region is then many maps from one recipe (Colorado is
about 277). Whole planets at real scale cannot be files (Earth would be
about 523,600 maps, hundreds of petabytes); they would need ground made on
demand as a player walks, which only a client that streams its terrain
(the custom client's streamed tiles) could take. The details, and the
question of whether "real" means real beside WoW's oversized buildings, are
in wow-chat-2026's 919.

## Suggested Implementation Steps

| ID   | Name                               | Dependencies       | Description |
|------|------------------------------------|--------------------|-------------|
| W09a | ground-data-fetcher-and-readers    | None               | The `fetch-ground` tool and one reader per source, each source's licence written beside its reader (sources and tools below). Readers turn every source into the same in-memory grid: one cell per sample, with a latitude/longitude, a height (float, metres), a land-cover class (uint8) and the OpenStreetMap features crossing it (river, lake, road, as flags) |
| W09b | pattern-describers                 | W09a               | Measure a region and write its pattern description (below). One describer per measure, each a black box with a number list out. Many regions measured at once on a thread pool (one region per worker) |
| W09c | sphere-to-map-projection           | W09a               | Lay a whole sphere onto one or more WoW maps, giving more yards to the places that matter: an emphasis-weighted cartogram (a map whose areas are resized by a weight, the way election maps resize states by population), and the scale calculator that says metres per yard at every cell |
| W09d | shape-plus-components-synthesis    | W09b, W09c         | Grow terrain: large shape from world A, small-scale texture from descriptions of world B. Patches of grown ground are laid in along a space-filling path (a Hilbert curve, which visits every cell of a square while keeping neighbours near each other) and blended at their overlaps, so the whole map is always covered with no seams. Ground synthesis runs on the GPU in batches where it parallelises |
| W09e | climate-water-and-biomes           | W09d               | Sunlight by latitude and season (axial tilt: Earth 23.4°, Mars 25.2°), prevailing winds in latitude bands, rain on the windward side of ridges and a dry shadow behind them (the Rockies are why Kansas is dry), rivers from the height field (each cell drains to its lowest neighbour; flow adds up downhill), erosion, and a biome per cell from temperature and rain, mapped to WoW ground textures |
| W09f | sun-photograph-and-rigid-bedrock   | W09a, W09e         | Deproject a flat photograph of the Sun into a sphere of statistics, and give the Sun an unbreakable bedrock layer that erosion and rivers stop at |
| W09g | pattern-and-planet-viewer          | W09b, W09c         | The separate viewing half: draws descriptions side by side, the projection's stretch, and the generated ground, without generating anything itself |
| W09h | wc3-maps-from-the-same-ground      | W09b, W09d         | The generator also writes WC3 maps, and WC3 maps' objectives are carried onto generated ground at the spots whose ground matches theirs (below) |

Execution order:
`W09a → W09b → W09c → W09d → W09e → W09f`, with `W09g` beside W09b onward
(each generator stage gets a view as soon as it writes something), and
`W09h` after W09d.

### WC3 maps from the same ground (W09h)

The owner, 2026-10-20: "can we make the map generator also generate maps
for wc3? since they both are built for the same custom client. . . we can
use overlays of the WC3 custom maps (or the default standard maps and
campaigns) to find statistically spots that are similar topography and
then we can use those spots to create maps so that we can easily port the
objectives over. They're just data points, right?"

Three parts:

1. **A second writer.** The generator's terrain grid goes out as WC3 files
   as well as WoW ones. The editor already writes them (`src/editor/save.lua`:
   terrain `war3map.w3e`, pathing `war3map.wpm`, doodads `war3map.doo`,
   units `war3mapUnits.doo`; `src/editor/new_map.lua` starts an empty map).
   What is new is the conversion from the grid: WC3 terrain is a grid of
   tilepoints 128 WC3 units apart (one WoW cell, 4.1667 yards, by
   `docs/wow-client-bridge.md`'s scale rule), each with a height, a cliff
   level (whole steps of 128 units), one of at most 16 ground tiles per
   map, and water. So the steepest generated slopes become cliff steps, the
   rest stays smooth height, and the 16 tiles are chosen from the biomes
   that cover the most ground. A WC3 map is at most 480 × 480 tilepoints
   (about 2,000 yards), so a WC3 map is a window cut from a generated
   world, not a whole world.
2. **Describing WC3 maps.** W09b's describers run on WC3 terrain too (its
   heights and cliffs are a height field like any other), over the custom
   maps in `assets/` and the standard melee and campaign maps read from the
   player's own WC3 install (borrowed, never shipped, as in W02). Each WC3
   map gets a description, measured over the whole map and over windows
   around each of its objectives.
3. **Finding matching spots, and carrying the objectives over.** A sliding
   window passes over a generated world (or a real one), and each window's
   description is compared with a WC3 map's (a weighted distance between
   the two number lists). The closest windows are candidate spots: ground
   shaped the way that map's ground is. The map's objectives are carried
   onto the best spot by one transform (move, turn, scale, the same for
   every point). Windows are compared in parallel (GPU batches, or one
   window strip per worker thread):
   - **points**: start locations, gold mines, creep camps, shops, waygates,
     every placed unit (`war3mapUnits.doo`);
   - **areas**: the regions triggers use (`war3map.w3r`, rectangles in map
     units), moved by the same transform;
   - **the script**: triggers that name regions or units by id keep working
     once those move; coordinates written as numbers in the script are found
     and moved too, and each one moved is listed in a report.

   Each carried point is checked on its new ground: is it walkable, is a
   gold mine on buildable ground, can every start location reach the others
   by walking. A point that fails is reported, not quietly nudged (a nudge
   rule the owner chooses may move it, with each nudge counted).

"They're just data points, right?" Mostly. Points and rectangles move
cleanly. What does not move with them is what the ground provides: a choke
point is narrow because of the ground around it; a base is defensible
because a cliff stands behind it. That is why the spot is chosen by matching
ground first, and why every carried point is re-checked for walking paths
and building room after it lands. Triggers that test the terrain directly
(cliff level or ground type at a point) are listed as needing a look.

### Where the ground comes from

Google Maps was the first idea; its terms forbid copying its imagery or 3D
data into another product. Decided 2026-10-20, the owner: "Well let's use
an open streetcar dataset. And maybe satelite images mixed with topographic
data. Which honestly might be easier to wield." Three kinds of data, each
answering a different question:

| Kind | Answers | Earth | Mars | Sun |
|------|---------|-------|------|-----|
| Elevation (topographic) | how high is the ground | USGS 3DEP (US, public domain); Copernicus DEM GLO-30 (world, free with attribution) | MOLA (USGS Astrogeology, public domain) | none: the photograph's brightness stands in (W09f) |
| Satellite land cover | what covers the ground (forest, grass, bare rock, snow, water, town) | ESA WorldCover, 10 m, already sorted into 11 classes (CC BY 4.0); raw Sentinel-2 or Landsat images when a class is not enough | CTX/HiRISE images (NASA) for bright and dark ground | SDO/HMI continuum images (NASA) |
| OpenStreetMap | where the rivers, lakes, roads and towns are, by name | Geofabrik's regional extracts | none | none |

**One overlay.** The owner: "we will need to create an overlay for these
two to overlay each other with datapoints accessible from both",
OpenStreetMap and the land cover, "projected onto" the elevation. The
readers put all three on one grid, the elevation's: every cell holds its
height (float, metres), its land-cover class (uint8, one of WorldCover's
11) and a list of the OpenStreetMap features that cross it (each a uint64
OpenStreetMap id with a uint8 kind: river, lake, road, building, place).
The index runs both ways: a cell gives its features, and a feature id
gives the list of cells it covers (uint32 cell indices), so a river can be
followed cell by cell and a cell asked what runs through it. Every layer
is lined up to the same cells when read (the land cover's 10 m pixels and
OpenStreetMap's lines are resampled onto the elevation's grid), and a
layer's own resolution is kept beside it so a reader knows what is finer
than its data. The viewer (W09g) draws any layers over each other.

What each is for: elevation gives the large shapes and the describers'
numbers; land cover gives the biomes directly on Earth (so W09e's climate
pass is checked against the real thing there, and only invents them on Mars
and the Sun); OpenStreetMap gives real rivers to check W09e's rivers
against, and names for zones (919b).

**OpenStreetMap's licence** (the Open Database Licence): a picture or a
game map *made from* it needs only the credit "© OpenStreetMap
contributors"; a *database* made from it (for example our grid of river
flags, if we hand it out) must be offered under the same licence. So the
fetched and derived OpenStreetMap data stays out of the repository and is
rebuilt by the tools on each machine, and the credit goes on every map
made with it.

### The tools (modelled on this owner's `update` and `compile`)

The owner, 2026-10-20: "as we're building this process we should make tools
and utilities to accomplish tasks instead of doing it once for the project.
That way we can build and update them easily. Look to our update and
compile scripts for information." (The scripts meant are wow-chat-2026's
`scripts/update` and `scripts/compile`.) What they do that these tools
copy:

- **Fetching is separate from building**, as `update` (pull sources) is
  from `compile` (build them). `fetch-ground` only downloads; `build-world`
  never downloads.
- **Pinned versions in one table.** `update` keeps one table of which
  commit each profile's source is pinned to, with the reason for each pin
  in a comment. `fetch-ground` keeps one table of each source's dataset
  version and the files a recipe needs from it.
- **Parallel checks with a live status line per source.** `update` checks
  every module at once in background workers, each writing its state
  ("checking", "missing", "current", "needs-update") to a status file in
  RAM, and draws a spinner per module. `fetch-ground` checks and downloads
  every source tile the same way, workers writing to
  `tmp/shared-memory/`.
- **Only what changed is rebuilt.** `update` decides whether a rebuild is
  needed from what moved. `build-world` keeps a fingerprint of each stage's
  inputs and settings (sources, recipe fields, describer version) and
  re-runs a stage only when its fingerprint changed, then every stage after
  it.
- **Built aside, then swapped in.** `compile` builds into a shadow folder
  and promotes it at the end, so a failed build never leaves half a server.
  `build-world` writes a world into a shadow folder and swaps it in whole.
- **Quick tests during the build**, as `compile` runs its quick tests: the
  re-describe check (grown ground must match the description it grew from),
  the scale check, and the W09h reachability check when WC3 output is on.
- **A failure says where it stopped and what finished**, as `compile`'s
  ending report does; and a clean run writes a goodbye receipt (when, which
  recipe, which fingerprints, counts of cells grown, tiles written, folds
  and warnings).
- **Every script** has the house `${DIR}` header (a fixed project path,
  replaceable by an argument) and a `--help`.

The tools, all in world-edit-to-execute's `scripts/`:

| Tool | Does |
|------|------|
| `fetch-ground RECIPE` | brings every source file the recipe needs, checks what is already there, says per source what it did |
| `describe-ground RECIPE` | writes the pattern descriptions for the recipe's regions (W09b) |
| `build-world RECIPE` | every stage after fetching, rebuilding only stale stages; `--stage NAME` to stop after one; `--wc3` to also write WC3 maps (W09h) |
| `world-scale RECIPE` | the scale calculator: metres per yard, heights in yards, per cell, maps needed (W09c); also measures the client's character and building models so "real scale" can be set to either |
| `view-world RECIPE` | the separate viewer (W09g); reads, never writes |

A **world recipe** (`worlds/<name>.lua`, data only) is the one place a
world is defined: its bounds or whole sphere, scale, sources, the regions to
describe, which descriptions fill which shapes, its climate settings
(tilt, bedrock), its map id. Earth, Mars, the Sun and the Front Range test
map (wow-chat-2026 919a) are four recipes for the same tools.

### The pattern description (W09b's output)

A plain Lua table file, one per region, generated (its first line says what
made it, from which source file, with which settings). Fields, all numbers:

- **heights**: mean and standard deviation (floats, metres), and a 32-bin
  histogram (32 floats, fraction of cells). Kansas is one tall spike, the
  Front Range a wide spread.
- **slope**: 32-bin histogram of slope angles (32 floats, fraction of cells,
  bins in degrees).
- **roughness by size**: the power spectrum of the height field, as power
  per octave from 30 m to 300 km (16 floats). This is "rolling when not at
  a distance": Kansas has almost no power at small sizes and a little at
  large ones.
- **ridge direction**: a 36-bin rose of the directions hillsides face (36
  floats, fraction of cells). The Rockies run north-south, so the rose has
  two strong petals, east and west.
- **valley branching**: from the river network (W09e's flow routing, run on
  the real ground): branch ratio and length ratio between stream orders
  (2 floats).
- **flat ground**: fraction of cells under 2° slope (float), and a 16-bin
  histogram of flat-patch sizes (16 floats, bins in km²).
- **cliffs**: fraction of cells over 45° (float). Utah's canyons are high here.

A description is a few kilobytes and holds none of the real ground, so
descriptions of real places can be kept, compared and mixed freely.

## Acceptance Criteria

- [ ] Every world is a recipe run through the same tools; a second `build-world` run with nothing changed rebuilds nothing, and a changed recipe field rebuilds only the stages after it
- [ ] Descriptions for at least Kansas, the Colorado Front Range, the Utah canyon country and one Mars region, generated by one command each
- [ ] Synthesised ground, re-described, matches the description it was grown from within stated tolerances per field (the describers check the generator)
- [ ] One generated map converts through W02a/W02c/W02d and is walkable in the client
- [ ] One generated window written as a WC3 map opens in the project's own editor and plays in the engine
- [ ] One melee map's objectives carried onto its best-matching generated spot, every start location reachable from every other, and the report of moved and failed points written
- [ ] Every borrowed source (elevation data, photographs, WoW ground textures) is counted in a report, and nothing borrowed is committed

## Open Questions

1. ~~Google Maps?~~ Answered 2026-10-20: OpenStreetMap, satellite images
   and elevation data instead (Where the ground comes from, above).
2. **One map per world or several?** One WoW map per planet gives the
   scales in the table above. Six maps per planet (a cube's six faces, each
   its own map; walking off one edge teleports onto the next) gives each
   face the whole 34,133 yards: Earth at about 270 m per yard instead of 661.
   The client limits the number of maps only by their ids. Which?
3. **What counts as "where it's most dense"?** The owner: "curved where it's
   most dense". W09c gives more yards to denser places; dense in what:
   roughness (the describers' own measure), places the owner names
   (Colorado, Utah), or where players actually go (measured later)?
4. **How tall may the ground be?** WoW heights are floats, but the stock
   continents stay within some range the client's camera, fog and flying
   are tuned for. Step one of W09d measures that range from the extracted
   server maps; is staying inside it a rule, or a starting point?
5. **Carrying a campaign map's objectives** (W09h). Campaign maps are
   stories as well as ground. Is the aim playable copies of those maps on
   new ground (the same story on Mars), or only their layouts as seeds for
   new maps? The first carries Blizzard's scripts and text, so it could
   only ever be built on the player's own machine from their own install.
6. **Which client plays the generated WC3 maps?** The owner: "since they
   both are built for the same custom client". They play in this project's
   engine, and through W02 in the WoW client. Is the custom client
   (`/mnt/kaun/custom-client/`) meant to open `.w3x` files directly too?
