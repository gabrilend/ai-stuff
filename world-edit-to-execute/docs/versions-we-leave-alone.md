# The Versions We Leave Alone

> **Not to be built by this project.** This document describes, as exactly
> as we can, what supporting the later versions of Warcraft III would take.
> It exists so the choice not to is an informed one, stated in full and on
> the record, and never mistaken for an oversight. None of the steps below
> will be carried out here.

## What this covers

The project reads Warcraft III from **1.07 to 1.29.2**: every version whose
game data lives in MPQ archives, and every version from before Blizzard
stopped several clients sharing one CD key from playing together on a local
network. The versions after that line are left alone:

| Versions | Released | What changed |
|----------|----------|--------------|
| 1.30.0 – 1.30.4 | Aug 2018 – Jan 2019 | Game data moved from MPQ archives to Blizzard's CASC storage; more languages |
| 1.31.0 – 1.31.1 | May – Jun 2019 | Lua as a map scripting language; after these, clients sharing a CD key could no longer play together on LAN |
| 1.32 onward (Warcraft III: Reforged) | Jan 2020 – today | HD models and textures, a Battle.net account required, LAN removed; the terms of use claim custom games made with its editor |

The live game today is Reforged. Everything in the last two rows, and the
storage format of the first, is what Blizzard runs now.

## Why we leave them alone

**Because the game is alive.** Warcraft III is still played, patched, and
cared for by the people who made it and the people who play it every day.
Someone who wants the current version has it: they play the live game. A
project that rebuilt the current version outside it would be, as the owner
put it, "like making a private server for... whatever expansion they're on
now". That is a different act from keeping an old version readable: it
competes with a living thing instead of remembering a finished one.

**Because it's theirs to steward.** The current game, its storage, its
accounts and its terms are the ground Blizzard and today's players stand
on. We treat that ground as sovereign. We don't reach into it, we don't
imitate it, and we don't offer anyone a way around it.

**Because of what the old versions were.** The owner draws the line at the
patch that stopped several people in one home or one room sharing one
copy of the game on their own network: "That change killed the game."
The versions this project keeps are the ones that game was: the one people
played together at LAN parties, in internet cafés, with a sibling or a
cousin on a second computer. Keeping those readable is an act of memory.
The later versions are a different game, with its own people, and they are
not ours to keep.

**Because of how we feel about it.** The owner's relationship to Warcraft
III and the people who made it is one of reverence and care. The world
editor that shipped with it taught a generation to make games; whole genres
began in its custom maps. This project exists because of that gift. Leaving
the living game to its living community is how we honour it.

**And because it would be hard to defend.** The owner: "supporting the new
data format, the one they currently use, I feel like might be legally...
difficult to defend." The reasoning, and the rest of the project's legal
footing, is in [legal-implications.md](legal-implications.md).

## What it would take (not to be done)

Written as precisely as the rest of the project's plans, so that the size of
what we are declining is plain. Each step names the work and why it would be
needed.

### 1. Reading CASC storage

From 1.30 the game's files live in Blizzard's CASC storage instead of MPQ
archives: a `.build.info` file naming the active build, a `Data/` folder of
numbered data files with index files beside them, and two lookup tables
(an *encoding* table from content hash to storage key, and a *root* table
from file name or ID to content hash). Reading it would mean:

- building **CascLib** (Ladislav Zezula's library, the CASC counterpart of
  the StormLib the project already uses) from source through
  `scripts/build-dependencies.sh`, and a LuaJIT binding beside
  `src/mpq/stormlib.lua`;
- a CASC-backed "install layer" kind for the chain (`src/gamedata/chain.lua`),
  reading a version's files by name from its storage instead of from
  archives;
- a fetch source for each version's storage, which exists only as whole game
  installs or through Blizzard's launcher (the project never contacts
  Blizzard's servers).

### 2. The 1.30 and 1.31 data

- The version table and editor builds (World Editor 6061 for 1.30, 6072 for
  1.31) in `src/gamedata/editor_versions.lua`, with evidence as for the
  others.
- `war3map.w3i` format 26 and on (script language switch, game data
  version, later additions) in `src/parsers/w3i.lua`.
- **Lua map scripts** (1.31): `war3map.lua` beside or instead of
  `war3map.j`. The project's scripting runtime would need a sandboxed Lua
  host with Blizzard's native functions exposed to Lua, alongside the JASS
  interpreter (`src/runtime/`, phase 3–4 issues).
- The native functions added from 1.29 to 1.31 (frames, UI, many getters and
  setters), each implemented in the runtime.

### 3. Reforged (1.32 on)

- Its storage layout within CASC (by file ID rather than name for many
  files) in the CASC reader.
- New model and texture formats: MDX versions for HD models, DDS textures,
  physically based materials; the renderer (`docs/render-architecture.md`)
  would need an HD path.
- Skin data (per-object appearance files for the HD and classic looks) in
  the object-data parsers (`src/parsers/objectdata.lua`).
- New object fields and tables, read through the same metadata route as
  today.
- Its terms of use claim rights over custom games made with its editor; any
  map saved by the Reforged editor would carry that claim, which would need
  its own legal review.

### 4. Testing it

- Maps saved by each of those editors, and comparison against the live game
  in the style of Phase W's client comparison: which would mean running the
  live game for reference, which the project does not do.

## What we do instead

- Keep every version up to 1.29.2 readable, faithfully, from each user's own
  copy, and with care for exactly how each patch changed the game
  (`issues/112b-game-version-layers-per-map.md`,
  `issues/112d-older-patch-program-shapes.md`).
- Name the line plainly wherever a tool might meet a later map: a map saved
  by a later editor is not guessed at; the chain says its editor build is
  unknown (`src/gamedata/chain.lua`).
- Point anyone who wants the current game to the current game.
- The balance history page (issue 115b) lists these versions with their
  published patch notes, as text credited to Liquipedia, each labelled "not
  supported by this project — patch notes only". That is a record of what
  Blizzard announced, not support: nothing is read from those versions' files.

## Related documents

- [legal-implications.md](legal-implications.md): the legal footing, and the supported range
- [licensing-and-boundaries.md](licensing-and-boundaries.md): every component's licence
- `issues/112b-game-version-layers-per-map.md`: the supported versions and how each is built
