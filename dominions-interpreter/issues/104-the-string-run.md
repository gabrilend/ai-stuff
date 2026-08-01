# 104 — The string run

| | |
|---|---|
| Phase | 1 — The Reading |
| Blocks | [106](106-the-world-table.md), [107](107-the-survey.md) |
| Blocked by | [102](102-seeing-through-the-disguise.md), [103](103-the-header-without-the-file.md) |
| Related docs | [file formats](../docs/dominions-file-formats.md), [the reading](../docs/datapath-the-reading.md) |

## Current behavior

The strings in a savegame can be revealed but not interpreted. A walk over a
turn file produces a list of readable text with no idea which entry is a game
name, which is a mod, and which is a map layer.

## Intended behavior

The strings immediately after the header appear in a known order, and reading
them in that order turns a list into facts.

1. the game name, which matches the folder the save sits in
2. for each enabled mod: its `.dm` filename, then **the folder that contains
   it**
3. a readable version string
4. for each map layer: a readable title, then the layer's `.map` file, then its
   `.d6m` file

The structure is recoverable without counting, because the entries are
distinguishable by shape: mod entries end in `.dm`, map entries in `.map` and
`.d6m`, and a layer title is the string in front of a `.map`. Reading by shape
rather than by position survives a game version that adds a field, which
reading by position does not.

### Why the mod list is not optional

Mods add, remove and alter units, spells, items and nations. One game in the
local collection has six of them loaded.

Any lookup from a numeric identifier to a name is only correct in the context
of that game's mod list, and this project does not read `.dm` files yet. So the
mod list is read for a defensive reason as much as an informative one: it is
what tells the rest of the program that it is in a modded game and must not
name anything it did not read as text out of the save itself.

Dominions finds a mod at `mods/<folder>/<file>.dm` and the save records both
halves. The folder name is the half that matters, because that is what the
lookup is by.

### What the map layers are for

Their titles are the game's own — `Pantokrator's Realm`, `The Realm Beneath`,
`The Void` — and a narrator that knows a province is in the Realm Beneath can
say so. The `.d6m` rendered map is named here and **never opened**: it is tens
of megabytes of graphics and holds nothing this program wants.

## Suggested implementation steps

1. Walk the strings from the end of the header using the offset-returning walk
   from issue 102.
2. Take the first entry as the game name, and compare it against the folder
   name. A disagreement is reported, not corrected — it is the standing check
   on the padding ambiguity, and it is how a bad string walk announces itself.
3. Classify the remaining entries by suffix into mods, maps and rendered maps,
   pairing each with the entry beside it.
4. Return a table with the game name, the mod list as `{file, folder}` pairs,
   the version string, and the layers as `{title, map}` pairs.
5. Stop at the first entry that fits none of the shapes — that is where the
   header region ends and the province records begin. Record where, because
   issue 105 starts there.
6. Tests over the whole collection: every started save's game name equals its
   folder name; every mod folder named either exists under `mods/` or is
   reported missing; every map file named exists or is reported missing; a save
   with no mods yields an empty list rather than an error.
7. Write the accompanying information file.

## Relevant files

- the local savegame collection
- the Dominions `mods/` folder, for checking that named folders exist

## Open questions

- The version string in the text region and the version number in the header
  disagreed in one observed file — the header said one thing and the string
  said another. Which is authoritative is not yet known. Both are reported
  until it is; whichever is chosen, it should be chosen on evidence.
