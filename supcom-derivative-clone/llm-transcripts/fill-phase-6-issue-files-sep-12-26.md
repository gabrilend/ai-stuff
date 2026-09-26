# Conversation Summary: agent-ae8be07c06eaee2b2

Generated on: 2026-09-26 12:47:43
Models: claude-fable-5-1

--------------------------------------------------------------------------------

### User Request 1

Your directive: You are filling in the bodies of the phase 6 issue files for
supcom-derivative-clone: issues 601 through 610. The frames already exist under
/mnt/mtwo/programming/ai-stuff/supcom-derivative-clone/issues/ (created by
./new-issue --from-list from the issues.list you saw). Each frame has a heading
line, a metadata table (Phase, Blocked by, Blocks, Reads, Open questions), and
TODO sections.

For each of the ten files:
1. Read the frame with cat so you keep its heading and metadata table EXACTLY as
   written (the validator compares the title to the roadmap, and the Blocks
   column was computed as the inverse of Blocked by).
2. Overwrite the file with `cat > path <<'EOF'` keeping the heading and the
   table verbatim, then write these sections: `## Current behavior` (present
   tense; today it is "Nothing." plus what already exists that bears on it: the
   test program tests/024-watching-it-happen.lua, the document it reads, and for
   608 the generator scripts/017-the-documentation-becomes-html.lua which
   already exists with five toys — sightline, timer, costs, ground, lockstep
   — and a `<!-- toy: name -->` marker mechanism; 608 is about the toys that
   read the catalogue tables once those exist, e.g. a hits-to-kill chart and a
   heal-interval timeline drawn from assets/), `## Intended behavior` (the
   mechanism, concretely, and why — the blueprint), `## Suggested
   implementation steps` (numbered; for 603 name the `lenses` stem from docs/014
   and its exports push/to_screen/to_field; the window is a LOVE 11 program with
   an unnumbered main.lua doorway and conf.lua at the root, the viewer itself a
   numbered file; the viewer reads snapshots only and issues commands through
   the door; refusals are shown where they happened; prefer listing
   functions/data structures over code snippets), `## Related documents and
   tools` (bullet links, relative paths like `../docs/010-the-views.md` and
   `../docs/002-the-dunes-and-the-sightlines.md`, the test file, and for 609 the
   `compile` script at the root which packages main.lua into a .love archive),
   `## Still open` (restate each open question cited in the table, plus anything
   the issue itself raises).

Design points to honour: generate-then-view; a lens is a record (layer, anchor
x/y, zoom, screen rectangle) and a zoom is a push that keeps the point under the
cursor fixed; layers are the dunes, territory, units, patterns, sightlines, the
cloud; the energy menu is four buttons and the roster/territory readout beside
it; drawing a pattern collects points and issues one placement command; the
cloud window is a small lens; the compass wheel is a ring around the truck
issuing one launch command; the terminal viewer (111) stays; 610 is the
generated dune tileset pipeline — a separate generator producing images from
height profiles, the viewer only loading them, design pending until the viewer
exists, and its intended-behavior should say what the pipeline's inputs and
outputs are without committing to a specific image model.

House rules: LuaJIT source in src/, numbered by ./new-source-file, every file
with a .info.md companion, functions in vimfolds, dispatch tables over branches,
errors over fallbacks, comments say why. No balance numbers in prose. Refer to
issues by number; link only to documents that exist in docs/. Do not edit any
other file, do not touch the phase progress files, do not run git.

Keep each issue between roughly 45 and 100 lines. Write in the voice of the
existing documents. When done, reply with one line per issue saying what its
intended-behavior section commits to.

--------------------------------------------------------------------------------

### Assistant Response 1

Task: filled the bodies of issues 601–610 under `issues/`, keeping every
heading and metadata table verbatim; all ten link targets resolve. No other
files touched, no git.

What each intended-behavior section commits to:

- **601** — One LOVE window that never touches the live world: the viewer
  keeps the last two snapshots and blends positions between them by wall-clock
  fraction (never extrapolating), draws non-position fields from the newer only,
  runs the simulation on its own thread with a snapshot channel one way and a
  command channel the other, and routes every named refusal back to the thing
  that issued the command.
- **602** — The ground is shaded once from the heightfield into an image
  (height band, slope facing a fixed light, hard water line, hydrocarbon marks)
  by a windowless function; territory is a per-frame tint over it, with
  claims-in-progress growing and contested cells drawn as both tints halved;
  both are rows in the layer table.
- **603** — The `lenses` file: a lens record (layer, anchor, zoom, screen
  rectangle), `to_screen`/`to_field` inverses, and `push` that moves the anchor
  so the field point under the cursor stays fixed, with a property test; layers
  are a dispatch table (dunes, territory, units, patterns, sightlines, cloud);
  lenses are dragged, resized, panned, pushed, switched, added, closed, drawn in
  list order with topmost-under-cursor hit testing.
- **604** — Four buttons in a fixed strip no lens covers, read from issue
  302's `LEVELS` table so the count cannot drift; button state
  (lit/pending/plain) comes from the snapshot not the click; roster counts with
  health bars, engineers split by duty, own and enemy territory percentages,
  mass/energy totals and incomes, and named stalls beside them.
- **605** — Cell, domain, and line chosen, then points collected by click and
  drag and converted through `to_field` at the moment added; finishing issues
  exactly one placement command; the viewer never validates (it may colour a
  point by the ground under it, a fact); a refusal is drawn at the point it
  names and the drawing is kept for correction; air factories skip the drawing
  step.
- **606** — The cloud is a layer row and the window a small lens over a
  corner; in-cloud planes get stable decorative scatter positions from their
  identifiers (commented as not-data), colour carries the mood, round resolution
  flashes, planes on other missions are drawn on the field by the units layer
  instead; a soft mark on field lenses shows where the cloud is.
- **607** — A ring around the selected truck in the field plane, heading
  computed in field coordinates, one click issues one launch command; the ring
  fills as an arc from the launch pair so readiness is shown, a premature click
  is refused by the door and the refusal drawn on the ring; snapping to a small
  set of headings is left as a switch for the handheld.
- **608** — The generator gains a catalogue loader and a data-embedding step;
  five catalogue-driven toys (`hits`, `heal`, `falloff`, replaced `costs`
  flagging ratio disagreements, `sight`) plus a census bar on the roadmap page;
  a marker whose table is absent fails the build, and markers are only placed
  once the tables exist.
- **609** — `main.lua` as the one unnumbered doorway that reads `input/`
  through a shared numbered reader, picks a room from an environment variable
  through a table (unknown room is a named error), and forwards callbacks;
  `conf.lua` holds settings only; `./run-prototype` dispatches
  `window`/`headless`/`terminal`/`replay`/`archive`, ensures RAM tiers, honours
  the seed override, and writes `output/goodbye` last; `./compile` then produces
  the archive.
- **610** — A `scripts/` pipeline, never run by the game, that maps
  heightfield cells to a shared class table, asks an image model (left pending)
  for tiles per class, keeps every tile in a rated pool, and writes a manifest
  with provenance into `assets/`; the ground layer blits by class and variant
  from a named stream when a manifest exists and shades otherwise, refusing a
  manifest with a missing image by name.

Outside my scope but noticed: `tests/024-watching-it-happen.lua` does not exist
with a body yet (only the claimed stub), so the "covers:" lines these issues
assume are the parent's to write.

--------------------------------------------------------------------------------

