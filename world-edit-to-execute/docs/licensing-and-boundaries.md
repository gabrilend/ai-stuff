# Licensing and Boundaries

Which licence covers which piece of the WoW Client Bridge, where the pieces
touch, and which combinations work. Written 2026-09-23 when the owner decided
that AzerothCore runs converted WC3 maps' rules. This is an engineering map of
the licences as written, not legal advice.

## The pieces and their licences

| Piece | Licence | Where it runs |
|-------|---------|---------------|
| world-edit-to-execute (converter, forge, scorer) | GNU AGPL v3 (the `ai-stuff` repository's `LICENSE`) | the owner's machine |
| The W client (`custom-client`) | **none yet**: no LICENSE file, which legally means "all rights reserved" | players' machines |
| AzerothCore | GNU AGPL v3 | the server |
| ALE (`mod-ale`, Lua inside AzerothCore) | GNU GPL v3 (checked 2026-09-23 at github.com/azerothcore/mod-ale). A fork of Eluna, which it replaces; its scripts are not compatible with Eluna's | inside the server process |
| StormLib (MPQ) | MIT | linked into the W client's reader library |
| raylib | zlib | linked into the W client |
| LuaJIT | MIT | linked into the W client; used by world-edit-to-execute |
| OpenSSL 3 (SRP6, RC4, HMAC) | Apache 2.0 | linked into the W client |
| miniz | MIT | linked into the W client |
| RGPL ("Our Great Public Library", the owner's draft at `ai-stuff/RGPL`) | draft; not applied to any project yet | — |
| Blizzard's client files | not licensed to us for redistribution; read locally only | the owner's machine |

## Where the pieces touch

```
  W client  ◀── network protocol ──▶  AzerothCore (AGPLv3)
  (licence ?)                            └─ ALE (GPLv3)
                                              └─ converted trigger scripts + native shim (Lua)
                                                   ▲
  world-edit-to-execute (AGPLv3) ── writes ────────┘
```

1. **W client ↔ AzerothCore: separate programs talking over a network
   protocol.** Talking to a program doesn't combine the two licences. The W
   client can have any licence, **as long as it doesn't copy AzerothCore's
   code** (packet structures, opcode tables, crypto helpers copied from its
   headers). Reimplementing the protocol from observed behaviour and public
   documentation is fine; opcode numbers are facts. Copying code would bring
   AGPL v3 terms into the W client.
2. **Converted scripts + native shim ↔ ALE: code running inside the
   server.** Lua scripts loaded by ALE call its API and share the server's
   process. Whether that makes a combined work is debated. The safe reading
   treats them as combined with ALE (GPL v3) and AzerothCore (AGPL v3).
   - Under **AGPL v3** (this project's current licence): compatible. AGPL v3
     §13 and GPL v3 §13 explicitly allow combining the two.
   - Under the **RGPL draft**: not compatible. The draft deliberately drops
     that permission ("DECIDED — no permission to combine with GPLv3 code").
3. **world-edit-to-execute → generated scripts: a program's output.** The
   transpiler's licence doesn't pass to what it writes (the RGPL draft says
   the same: "finished output … travels free"). The generated scripts take
   whatever licence their inputs carry; see content rights below.
4. **The W client's own libraries** (MIT, zlib, Apache 2.0) are all permissive
   and combine with AGPL v3 or with the RGPL draft. Apache 2.0 is compatible
   with GPL v3 and AGPL v3 (not with GPL v2, which doesn't matter here).

## What this means in practice

- **Today everything is compatible.** world-edit-to-execute is AGPL v3,
  AzerothCore is AGPL v3, ALE is GPL v3, and the W client's dependencies
  are permissive.
- **Anything that runs inside the server stays under AGPL v3 or GPL v3**,
  even if the rest moves to the RGPL. That means the JASS-native shim (W02e),
  any C++ AzerothCore module for WC3 orders, and SQL/Lua shipped as a server
  module. Keep it in its own folder with its own LICENSE so a later switch
  elsewhere doesn't catch it.
- **The move to the RGPL (2026-09-23).** The projects are moving to the
  owner's RGPL. It can't be combined with GPL v3 code (the draft drops that
  permission) or with AGPL v3 code (AGPL forbids adding the RGPL's extra
  clause). The plan, in W08:
  - *Stage 1:* AzerothCore is **installed, not bundled**, like the Blizzard
    client. RGPL code never contains or links it; the only code that runs
    inside it (the shim) stays AGPL v3 in its own folder. No new Lua engine is
    needed for this.
  - *Stage 2:* our own server, built as a soramech map, speaking the same
    protocol, made clean-room and checked against AzerothCore by replaying the
    same sessions against both. Then the whole stack can be RGPL, and LuaJIT
    (MIT) runs the triggers.
- **The W client needs a LICENSE file.** Until it has one, nobody else may
  legally use it.
- **AGPL's network clause applies to the server.** Anyone running a modified
  AzerothCore (with the WC3 module) for other players must offer them the
  source. That fits the project's aims; it just has to be done.

## Content rights (not software licences)

Separate from code licences, and not settled by any of the above:

- **WC3 maps** belong to their authors (for example the DAoW maps in
  `assets/`). Converting one for personal play is one thing; publishing a
  converted map is another and needs the author's permission. Blizzard's
  2020 Warcraft III terms also claim rights over custom games made with its
  editor; how far that reaches back to maps made under the original terms is
  an open question. **Plan (2026-09-23):** the map browser (issue 1001) lists
  maps that are freely posted on the web, and the player's own machine
  downloads the ones they pick, the way a browser would. **Bundling policy
  (owner, 2026-09-23):** "most authors will be unreachable, but we should do
  our due diligence, and then just assume that their consent is given until
  withdrawn. Like social media sites hosting things that other users posted,
  except slightly inverted." So each bundled map carries a record of the
  attempts to reach its author, and there is a fast, public way to withdraw.
  One difference from social media sites, stated plainly: those sites are
  *hosts* of what their users uploaded, and in the US that role (with a
  takedown process) is what shields them. Here the project would be the one
  uploading, and assumed consent is not permission under copyright. The
  withdrawal channel limits the harm; it doesn't remove the exposure.
  Fetching from the original post, rather than bundling, has none of it.
- **Blizzard's assets** are never redistributed (see `docs/wow-client-bridge.md`).
- **AzerothCore's world** (zones, quests, NPC text, loot) is Blizzard-derived.
  world-edit-to-execute's maps don't use it: each converted map is its own
  terrain, its own creatures and its own scripts. What the server **still**
  takes from Blizzard even for our maps:
  - the data tables (DBC files) extracted from the client, which it loads at
    startup and needs to run at all: spells, factions, races and classes,
    display info, map list;
  - the rows our maps point at: display ids until models are replaced, spells
    and spell visuals used for converted WC3 abilities, the faction and race of
    the player's own character;
  - the rest of the world database, which a stock install loads into memory
    even though our maps never touch it.

  So for our maps the concern shrinks from "the whole world" to the data
  tables and the handful of rows we reference. **Decided (2026-09-23): this
  project's world database starts empty**, holding only what each converted
  map needs (W02h). The data tables are generated from each map's own object
  data where possible; the W client treats data tables as assets too, with
  Blizzard's as a counted, borrowed fallback.

## Before any release

Nothing here is released yet. Before one:

1. **Review every bundled library** (owner, 2026-09-23: "we will have to
   review these inclusions before release"): StormLib, raylib, LuaJIT,
   OpenSSL 3, miniz, and anything added later. For each: the exact version,
   its licence text, what the licence requires in our distribution (notices,
   source offers), and whether a smaller or better-licensed choice exists.
2. **Give the W client a LICENSE file** (open question 1 below).
3. **Keep server-side code in its own AGPL v3 folder** with its own LICENSE.
4. **Confirm no AzerothCore code was copied into the W client** (a search for
   its file headers and distinctive identifiers).
5. **Confirm nothing from Blizzard's client or any bundled WC3 map is in the
   release**, other than maps whose authors agreed.

## Open questions

1. Which licence for the W client: AGPL v3 (matching everything else today),
   or the RGPL once it's finished?
2. If the projects move to the RGPL, confirm the server-side pieces stay AGPL
   v3 in their own folder (recommended above).
