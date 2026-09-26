# Conversation Summary: agent-ab93ee935af8586c5

Generated on: 2026-09-26 12:47:43
Models: claude-fable-5-1

--------------------------------------------------------------------------------

### User Request 1

Your directive: You are filling in the bodies of the phase 3 issue files for
supcom-derivative-clone: issues 301 through 311. The frames already exist under
/mnt/mtwo/programming/ai-stuff/supcom-derivative-clone/issues/ (created by
./new-issue --from-list from the issues.list you saw). Each frame has a heading
line, a metadata table (Phase, Blocked by, Blocks, Reads, Open questions), and
TODO sections.

For each of the eleven files:
1. Read the frame with cat so you keep its heading and metadata table EXACTLY as
   written (the validator compares the title to the roadmap, and the Blocks
   column was computed as the inverse of Blocked by).
2. Overwrite the file with `cat > path <<'EOF'` keeping the heading and the
   table verbatim, then write these sections: `## Current behavior` (present
   tense; today it is "Nothing." plus what already exists that bears on it: the
   test program tests/021-inflows-and-outflows.lua that names it, the document
   it reads), `## Intended behavior` (the mechanism, concretely, and why — the
   blueprint), `## Suggested implementation steps` (numbered; name the source
   stem from docs/014-the-tests-come-first.md's table — economy, energy-menu,
   roster, cost-table, factories, thorns — the exports the tests call, the
   fields and their types, the validator refusals; prefer listing functions/data
   structures over code snippets), `## Related documents and tools` (bullet
   links, relative paths like `../docs/005-territory-mass-and-energy.md` and
   `../docs/006-factories-and-patterns-in-the-sand.md`, and the test file), `##
   Still open` (restate each open question cited in the table in one sentence,
   plus anything the issue itself raises).

Design points to honour: territory painted on cells pays mass per held cell;
energy is a building on a held cell, lost with the cell, hydrocarbon buffs the
next one; the energy menu is four assignment levels for engineers (none, a
third, two thirds, all) and never a fifth button; builders and engineers are a
roster of counts with health and no position; construction streams cost across
build ticks and stalls when a resource is dry, build power split evenly; the
cost table is ratios (land ten-to-one mass, air the reverse, sea equal, anti-air
equal) with tier multipliers, magnitudes in the catalogue; a factory is a
pre-built line with a queue, a pattern drawn once at placement and never
changed, validated at the door with named refusals; losing a fraction of ground
hurts the same fraction of the roster on a named random stream; thorns are a
team capacity spent per percent taken; improving territory is entirely open (A7)
and 311 should say so plainly and be written as the smallest thing that could
satisfy the vision's sentence.

House rules: LuaJIT source in src/, numbered by ./new-source-file, every file
with a .info.md companion, functions in vimfolds, dispatch tables over branches,
flat arrays with integer zero for nothing, errors over fallbacks, comments say
why. No balance numbers in prose — the vision's own numbers may be quoted once
as the vision's. Refer to issues by number; link only to documents that exist in
docs/. Do not edit any other file, do not touch the phase progress files, do not
run git.

Keep each issue between roughly 50 and 110 lines. Write in the voice of the
existing documents. When done, reply with one line per issue saying what its
intended-behavior section commits to.

--------------------------------------------------------------------------------

### Assistant Response 1

Task: filled the bodies of phase 3 issues 301–311, headings and metadata
tables kept verbatim, three required sections present in all eleven, 78–103
lines each. No other files touched, no git run.

What each intended-behavior section commits to:

- **301** — Held cells pay mass every tick, counted in a sliced walk summed in
  fixed order; lost ground stops paying on the tick it is lost; pay per cell is
  one catalogue number.
- **302** — Exactly four assignment levels (none, third, two thirds, all) as a
  table of rows; a level is a queued command through the door; a fifth index is
  refused by name; the split is computed in one place and read by 303 and 305.
- **303** — Energy is a building on a held cell, gone when the cell flips;
  hydrocarbon is marked by the dune tool and buffs exactly the next building
  finished; energy-duty engineers raise buildings (nearest hydrocarbon first,
  then nearest the truck) on their own construction stream.
- **304** — Builders and engineers are a roster of rows with kind, team, and a
  health pair on a per-kind recovery counter, no position; healing scales with
  engineer count; a member at zero is swept in the die pass; both are made by
  construction streams.
- **305** — Every build is a stream drawing cost in proportion to build power;
  build power is split evenly; a resource shortage scales every draw on that
  resource by one integer fraction so the whole economy stalls proportionally;
  finish handlers are a dispatch table keyed by opener.
- **306** — The cost table is an `assets/` table whose shape (land ten-to-one
  mass, air the reverse, sea and anti-air equal, tier multiples) is validated at
  load by an alignment-keyed rule table; magnitudes live only in the catalogue
  and the ledger.
- **307** — A factory is a pre-built line from a lines catalogue, placed by
  one command carrying cell, domain, line, one-shot flag and pattern, refused by
  name on any bad input; entries are construction streams emitted with pattern
  copies; stop, resume, and demolish exist (A5's working ruling); the row
  carries a position so carriers can move it.
- **308** — A pattern arrives with the placement, is validated along every leg
  against the field and the domain, and is immutable by the absence of any verb
  that touches it — with a test that walks the door's table to prove it; units
  carry copies by index.
- **309** — A fall in held cells hurts the same fraction of the roster that
  tick, chosen without replacement on the `roster-hurt` stream, rounded down
  with no carried remainder; gains hurt nobody; measured in one consequences
  pass shared with thorns and lost buildings.
- **310** — Thorns are a positionless team capacity bought as a stream; each
  whole percent taken fires catalogue damage at the recorded claimers of the
  flipped cells through the ordinary shot buffer and spends a share of capacity;
  zero capacity does nothing.
- **311** — Declared entirely open (A7) and not to be started until worked
  through with a person; the working ruling is a per-cell integer level bought
  with both resources that raises pay and resets when the cell flips, with the
  tests asserting only those two claims.

One note outside scope: 303 and 310 both extend issue 112's claim pass
(hydrocarbon finding, recording which units completed a claim); whoever fills
112 should mention those hooks.

--------------------------------------------------------------------------------

