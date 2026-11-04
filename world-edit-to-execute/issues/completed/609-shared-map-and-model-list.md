# Issue 609: Shared Map-and-Model List

**Phase:** 6 - Asset System
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 604 (content-addressed storage), 605 (local storage manager)
**Blocks:** 609a, 801f
**Uses:** rmail (`/home/ritz/programs/r-mail/`) for every file transfer

---

## Current Behavior

Each player draws units with whatever models they have installed (the asset
resolver: their packs first, then borrowed files, then a placeholder). Issue
603 once planned a host that sends its asset packs to every client on connect, with
assets marked "required", which would make the host decide what everyone sees.

## Intended Behavior

The owner (2026-09-23): "the model is the model. the user uses whichever
models they have installed, not what their playmates suggest they do. However
we should build an ability to share a map+model list if two users want to play
along with each other. It should be easy and automatically applied if the user
selects it."

- **Default: your art is yours.** Joining a game never changes what you see.
  Gameplay doesn't depend on art at all: selection circles, collision, missile
  heights and hit timing come from the map's own unit data (see W05d, "The
  criteria set"), so players with different models share one game correctly.
- **A shared list.** A player can publish a **map-and-model list**: the map
  (content hash, where to fetch it) and, for each unit type, doodad or other
  asset the sharer has replaced, the asset's content hash and where to fetch
  it. Each entry carries its provenance (licence, lineage, similarity score)
  so the receiver sees what they are choosing.
- **Delivered over rmail** (owner, 2026-09-23: "the only connection protocol
  for assets that I trust"). Sharing is an rmail message: the list file in the
  body, and the assets as `attach:` lines. Two players who want to play along
  are rmail contacts (they share a secret in their `contacts` files). rmail's
  own consent step is the prompt: the receiver's inbox shows who is sending,
  each file's name and size, and the space it will take, and they accept or
  deny before any byte moves.
- **Only what's missing is sent.** The list goes first, alone. The receiver's
  side answers with the hashes it lacks, and the sharer's reply attaches only
  those. Assets already stored (content-addressed, 604) are never re-sent.
- **One choice, then automatic.** Accepting the list is the one prompt ("Use
  Ana's models for this game?"). Then the attachments arrive, every hash is
  verified, and the list is applied as a **temporary profile for that game**,
  reverted afterwards unless the player chooses to keep it. Declining changes
  nothing.
- **Remembered choices.** "Always accept lists from this player" and "always
  for this map" make it automatic from then on, as the owner asked. This is an
  rmail `on_receive` hook that answers the consent request for trusted
  contacts and hands arriving lists to the engine. (To confirm while building:
  that a hook can answer rmail's consent request the way the person would.)
- Assets with a public source URL may be fetched from there instead, when the
  receiver prefers; the sharer never has to host anything.

**Where each part runs (2026-11-04).** The owner: "The custom model
sharing capability should be for the editor, but we can have a small
'launcher style' system that users can open to view and browse and such.
They could also be viewed and browsed through the browser." So:

- **This project (the editor's side):** building a list from the user's
  packs and a map, sending it over rmail, receiving one, checking every
  file's hash, storing it, and keeping it as one of the user's packs.
- **The launcher and the web page (issue 1001):** browsing lists beside
  the maps and models they belong to.
- **The W client (the game's side):** using a list while a game runs: the
  prompt, the layer in front of the player's packs for that one game, and
  taking it off afterwards or keeping it. Playing happens there (issue
  913), so the parts of this design that say "for that game" are built in
  the W client, through its asset lookup (its 105a), as its issue 1110.
  It reuses this project's list format and rmail road rather than a
  second copy (W client docs/012, answer 6).

**A list travels only with its map (2026-11-04).** The owner: "we only
send models and such when the map that includes them is shared. This
happens either intentionally 'check out my map' or when the map is hosted
'come check out my map' (see the difference?) so we don't need to check
the rmail inbox every 5 seconds." So there is no standalone list and no
inbox watched on a timer:

- **"Check out my map"**: giving someone a map to keep. The map file and
  the sender's list go together in one rmail message; the receiver's
  editor or launcher (this project) asks once, then stores both. Built
  here.
- **"Come check out my map"**: hosting a map for others to join. The
  host's list comes with the join and is asked about while joining.
  Built in the W client (its 1110), with the rules pull request #227
  worked out (that code ran in this project's map viewer, so it moves
  there as a design): one question, answered only by a click; Yes, No,
  "Always from this player", "Always for this map"; one bad file refuses
  the whole list; the models are taken off after the game unless kept.

List format (a Lua table):

| Field | Type | Meaning |
|-------|------|---------|
| map | {hash: string, name: string, sources: list of URL strings} | the map |
| entries | list of {key: string, hash: string, size: uint64, sources: list of strings, provenance_id: string} | `key` is what the entry replaces: a WC3 unit type id (`hfoo`), a doodad id, or a logical asset path |
| author | string | who published the list |
| created | string (date) | when |

## Suggested Implementation Steps

1. List format, writer ("share my current models for this map") and reader.
2. Temporary profile in the resolver: a layer above the player's own packs that exists for one game and is then removed.
3. rmail glue: write the outgoing list message into `~/mail/outbox/`; an `on_receive` hook that recognises a list, replies with the missing hashes, and (for trusted contacts) answers the consent request; verify every arriving attachment's hash and refuse mismatches.
4. The one prompt, plus the "always" choices, stored per player.
5. 603's own transfer protocol is not built; rmail replaces it. (603 was rewritten on 2026-09-26 as the fetcher from public hosting sites; the file server, 607, was retired.)
6. Tests: accepting a list shows the sharer's model for that game only; declining changes nothing; a tampered asset (hash mismatch) is refused; gameplay values (collision, hit timing) are identical with and without the list.

## Acceptance Criteria

- [x] Two players with different models play one game and get identical gameplay results
      (by construction: a list carries only art and sound, and a unit table
      reads the same with a list on; two real players in one game wait on
      phase 8's multiplayer)
- [x] Accepting a list applies it automatically for that game and reverts afterwards
- [x] "Always accept from this player" makes the next list apply without a prompt
- [x] Hash mismatches are refused and reported

The rmail glue and the in-game prompt are 609a. (Since 2026-11-04 the
in-game prompt, and using a list for one game, are the W client's, its
1110; this project asks once when a map is given to keep. See "Where each
part runs" above and "After the editor-and-client split" below.)

## Open Questions

1. Should a list also be able to carry replacement *data tables* (for maps that ship their own spells or units), or only art?
   **Answered while building (2026-11-02): art and sound only.** A data
   table changes how the game plays, which the owner's rule ("gameplay
   doesn't depend on art") keeps out of a list; a map that ships its own
   data carries it inside the map, whose hash the list names.
2. ~~Where are lists published besides direct sharing in a lobby: next to a map in the map browser (1001)?~~ Answered 2026-11-04: in the launcher and in an ordinary web browser, both issue 1001's (the owner: "a small 'launcher style' system that users can open to view and browse and such. They could also be viewed and browsed through the browser").
   (Noted while building, 2026-11-02: a list is a file, so 1001 can show
   lists beside maps once it exists.)

## Related Documents

- `/home/ritz/programs/r-mail/docs/attachments.md` (consent flow), `docs/protocol.md`, `docs/.templates/scripting-tutorial.md` (hooks)
- `issues/603-fetch-maps-and-models-from-public-sites.md` (fetching from public sites; its earlier transfer design, replaced by rmail, is kept at its end), `issues/completed/604-asset-deduplication-system.md`, `issues/605-local-storage-manager.md`
- `issues/W05d-clean-room-describe-build-check-loop.md` (the criteria set: gameplay never reads art)
- `/mnt/mtwo/games/azeroth-core/custom-client/issues/105a-loose-overlays-and-asset-resolver.md`
- `issues/1001-catalogue-of-freely-posted-maps-and-models.md` (the launcher and web page where lists are browsed), `issues/913-test-map-opens-the-w-client.md` (where playing happens)
- `docs/wow-client-bridge.md` ("2026-11-04: the editor keeps its own renderer")

## Implementation Notes

**Date:** 2026-11-02

- **`src/share/list.lua`:** the list: `build` from a pack and a map,
  `encode`, `decode` (read, never run), `check`, `missing`, `bundle`.
- **`src/share/profile.lua`:** `verify`, `apply` (refused whole on any bad
  file), `attach`, `revert`, `keep`; `trust` with `decide`, `always_from`,
  `always_for_map`.
- **`src/assets/loader.lua`:** `push_layer` / `pop_layer`, a folder in
  front of every pack for one game.
- **`src/cli/share.lua`:** `make`, `missing`, `bundle`, `check`.
- **`src/tests/test_share.lua`** (58 tests): building a list (art only,
  data files named as left out, a unit type's model), writing and reading
  it back exactly, odd characters; a received list never run (a call, a
  loop, an expression, concatenation, deep nesting, trailing text, size)
  and data files, climbing or absolute paths, short hashes, negative sizes
  and repeated keys refused; only missing files bundled; a tampered or
  unsent file refusing the whole list with nothing applied; during a game
  the sharer's grass from the layer and the receiver's own unit table
  unchanged, afterwards the receiver's grass and the profile gone and
  collected; kept as a pack; names that climb or repeat refused; trust
  remembered, by player and by map, and a damaged trust file not run; and
  the tool's four commands, including a tampered bundle refused.

### Decisions made while building

1. **Art and sound only** (open question 1): gameplay can't differ between
   two players' lists, so the "identical results" criterion holds by
   construction rather than by testing every unit.
2. **A received list is never run.** The issue's format is a Lua table, so
   the file stays one, but it is read by a small reader of plain data;
   another player's file can't run code, loop or fill the memory.
3. **One bad file refuses the whole list.** A mismatch means the files
   aren't what the sharer listed; applying the rest would show a mix
   neither player chose.
4. **Files, not rmail, for now.** rmail isn't in this repository, so its
   message format and whether a hook can answer its consent step can't be
   read here. The exchange is four file steps (list, missing hashes,
   bundle, check) that rmail's glue will carry; nothing touches the
   network. That glue and the prompt are 609a.
5. **The profile is a loader layer** (`push_layer`): above every pack for
   one game, taken off after. Keeping it re-links its files as a pack, so
   the store's references stay right.
6. **A unit type's entry names its model's path**, and the profile hands
   out `types` for the unit drawing to use; mapping a type to its model
   is 503b's.
7. **Trust is stored per player data folder** as a plain table read the
   same safe way.

### After the editor-and-client split (2026-11-04)

What was built here, read against "Where each part runs" and "A list
travels only with its map" above:

- **Still this project's (the editor's side):** the list format and its
  safe reader (`list.lua`: `build`, `encode`, `decode`, `check`,
  `missing`, `bundle`), checking every file's hash (`profile.verify`),
  keeping a received list as one of the user's packs (`profile.keep`),
  the remembered choices for the one question asked when a map is given
  to keep, and `src/cli/share.lua`.
- **Now the W client's (its 1110):** using a list for one game and taking
  it off after. `profile.apply`, `attach` and `revert`, and the loader's
  `push_layer` / `pop_layer` (decision 5), are where those rules were
  worked out and tested; the W client builds them in its own asset
  lookup (its 105a), reusing this list format. The acceptance lines about
  "that game" were checked here, in this project's loader.
- **A list travels only with its map.** `list.build` already names the
  map by its hash; sending the map file in the same rmail message as the
  list is the rmail glue's (609a, then 609b).
