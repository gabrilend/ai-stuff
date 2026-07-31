# datapath — the fabricated data

*the server's own headers → a schema → tables and terrain that never came from a
client → a world server that boots*

There is no copy of the original client, and there will not be one. Everything
the server expects to have been extracted from one, we make instead.

This is not a workaround. It is the deepest reading of what the vision asks for:

> *"…liberate it from being bound to a single client on the internet we found."*

A server fed with extracted retail data is still bound to that client — it just
holds the binding at one remove, in a directory of files somebody else's program
produced. A server fed with data we generated is not bound to it at all. There
is no copy of anything anywhere in the pipeline.

---

## What the server refuses to start without

The world server loads a set of **client data tables** at startup and exits if
they are absent. This is a hard boot requirement, not a degradation:

| Needs | What it is | Where it normally comes from |
|---|---|---|
| **the data tables** | ~100 fixed-layout binary tables: maps, areas, races, classes, spells, items, and so on | extracted from the client's archives |
| **height data** | per-tile terrain grids | extracted, per map |
| **collision data** | triangle soup for line of sight | extracted, per map |
| **navigation data** | pathfinding mesh | *built from the two above*, by a tool |

And one large thing that is **not** on this list, which is the whole reason this
is possible: the **world database** — creatures, items, quests, spawns,
gameobjects, starting positions — ships as SQL alongside the server source. It
was never client data. It is already ours to use.

So the gap is narrower than it first looks. We are not reconstructing a game. We
are producing the fixed-layout tables and the terrain grids that the server reads
before it will agree the world exists.

---

## The schema is in the tree we already clone

The single fact this entire phase rests on:

> **The server's own source defines the layout of every file it loads.** Not
> approximately, not by convention — the loader's format descriptor *is* the
> schema, in the tree we clone on every build.

Each table is registered in the server's loading code with a format string that
gives the type of every column in order — an index, an integer, a float, a
string, or a column deliberately ignored. That string is machine-readable, and
it is authoritative in the strongest sense: it is what the loader will actually
apply to our bytes.

```
   upstream/azerothcore/…/DBCStores.cpp        the format strings
   upstream/azerothcore/…/MapDefines.h         the terrain file headers
                    │
                    ▼   an extractor, run at build time
   the schema, as data
                    │
                    ▼   plus our content, from input/
   the tables and terrain the server demands
```

**This is the third time this pattern has appeared** — the opcode table, the
encryption seeds, and now the data schemas — and it is now a strategem in its
own right: `strategems/the-upstream-tree-is-the-schema.md`. Transcribing any of
it by hand would mean a silent mismatch the day upstream adds a column, which
presents as a server that loads garbage rather than one that complains.

Three properties fall out, and the second is the valuable one:

1. **We cannot get a layout wrong**, because we did not write it down.
2. **An upstream change to a table's shape breaks the build, not the server.**
   The extractor sees a new column; the generator has no value for it; the build
   stops and names the table. Compare with the alternative, where the server
   starts and misreads every row after the inserted column.
3. **It costs nothing to regenerate.** The tables are a build artifact, like the
   clone. Same discipline: version the intent, regenerate the result.

---

## The table format itself

Simple enough to write in an afternoon, which is the other reason this is
tractable:

```
   ┌────────────────────── 20-byte header ──────────────────────┐
   │  magic  │ record count │ field count │ record size │ string │
   │ 4 bytes │   u32        │   u32       │   u32       │ block  │
   └────────────────────────────────────────────────────────────┘
   ┌──────────────── records: count × size, fixed ───────────────┐
   │  every field is 4 bytes. A string field holds an OFFSET     │
   │  into the block below, not the text.                        │
   └────────────────────────────────────────────────────────────┘
   ┌──────────────── string block ───────────────────────────────┐
   │  \0 then null-terminated text. Offset 0 is the empty string, │
   │  which is why the block always starts with a zero byte.      │
   └────────────────────────────────────────────────────────────┘
```

One trap worth writing on the wall: a **localised** string is not one column. It
is sixteen language columns plus a flags column — seventeen — and the format
descriptor accounts for all of them. A generator that emits one column for a
name produces a file whose every subsequent field is shifted, and the server
will read it without complaint.

---

## The terrain, and a very large convenience

The height files are per-tile, and their headers are structs in the tree, same
as everything else. But the format has a flag meaning **"this tile is flat, at
this one height."** When it is set, the grid is *absent* — there is nothing to
generate at all. There is a matching flag for a tile that is entirely one area.

```
   a flat tile:   header  +  "no height, ground is at Z"   ≈ a few dozen bytes
   a real tile:   header  +  a 129×129 grid + a 128×128 grid + areas + liquid
```

So the first fabricated world is nearly free: a floor, one area, no liquid, and
a map table row saying it exists. That is enough for a character to stand on and
walk across, which is exactly what phases 3 and 4 need to prove the protocol.

The collision and navigation data are not needed for that. Both are switchable
off in the server's own configuration — line of sight, height from collision,
and pathfinding each have a setting — and turning them off is a supported
configuration, not a hack. They arrive later, when there is something worth
colliding with.

Which leaves the honest ordering:

```
   flat ground, no collision, no paths     ← boots; a character can walk
        │
        ▼   once there is geometry worth having
   collision generated from our shapes     ← line of sight, standing on things
        │
        ▼   built by the server's own tool, unmodified
   navigation mesh                          ← free; it consumes the two above
```

The navigation mesh never has to be written. It is built by a tool that ships
with the server, from height and collision data — so producing those two
correctly is the entire job, and the hardest-sounding artifact is the one we get
for nothing.

---

## Where the content comes from

Layout from upstream; **content from `input/`**, because that is where a program
learns how to start.

```
   input/world/*.shape        the geometry, authored, in text
   input/world/*.def          maps, areas, and what a whisp is
          │
          ▼   tools/fabricate
   the tables  ·  the height files  ·  (later) collision
```

The `.shape` format is therefore not a fixture after all — it is the authoring
format, and the generated files are derived from it. It went from authoritative,
to a fixture, and back, across three answers in one sitting; this note is here
so that flip is visible rather than looking like it was always obvious.

### The constraint that keeps the SQL usable

The world database ships with the server and references identifiers that the
tables are expected to contain: a starting position on a particular map, a race,
a class, a display. If we invent identifiers freely, that SQL stops matching and
we inherit the job of rewriting it too.

So the rule for the first fabricated set is: **keep the identifiers, replace the
content.** Race one is still race one; the row that describes it is ours. The
starting map is a map we made, and the starting position is moved onto it by a
data change — which is an idempotent insert, reversible, and therefore an
ordinary patch.

Diverging from the shipped identifiers is a decision available later, once
something is actually gained by it. Doing it on day one would cost a rewrite of
data we were handed for free.

---

## What can go wrong, and how it presents

The failure modes here are unusually nasty, because a fixed-layout binary file
with no checksums fails *quietly*. Worth knowing in advance:

| Mistake | How it presents |
|---|---|
| a column count off by one | every later field reads as garbage; often no error at all |
| a localised string emitted as one column | same, and it looks like a content bug |
| a string offset past the block | a name that is random memory, or a crash far away |
| an identifier the SQL does not know | a character that cannot be created, blamed on the client |
| a wrong magic or version | the one clean failure: a refusal that names the file |

The defence is not care. It is a **round-trip check**: generate a table, load it
back with a reader built from the *same* extracted schema, and compare against
what went in. Anything that survives that has the right shape, whatever else may
be wrong with it. This is the same assertion the patch verifier makes, pointed
at a different artifact.

---

## Where this lands

```
tools/
    extract-schema     upstream headers → the layouts, as data
    fabricate          layouts + input/ → tables and terrain
    verify-tables      round-trip: generate, read back, compare
src/world/
    mapfile            the height format — read by the client too
```

Everything under `tools/` produces build artifacts. None of the output is
tracked; it is regenerated from `input/` plus the clone, on demand, exactly like
the patched tree. The clone is disposable, the tables are disposable, and
`input/` plus `patches/` is the project.

## Related

- `strategems/the-upstream-tree-is-the-schema.md` — the pattern, three times over
- `strategems/the-tree-is-a-build-artifact.md` — why none of this is committed
- `docs/datapath-the-world-of-shapes.md` — what the geometry becomes
- `docs/architecture.md` — why no client data is the stronger position
