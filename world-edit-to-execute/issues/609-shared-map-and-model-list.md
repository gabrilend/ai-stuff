# Issue 609: Shared Map-and-Model List

**Phase:** 6 - Asset System
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 604 (content-addressed storage), 605 (local storage manager)
**Uses:** rmail (`/home/ritz/programs/r-mail/`) for every file transfer

---

## Current Behavior

Each player draws units with whatever models they have installed (the asset
resolver: their packs first, then borrowed files, then a placeholder). Issue
603 plans a host that sends its asset packs to every client on connect, with
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
5. 603's own transfer protocol is not built; rmail replaces it.
6. Tests: accepting a list shows the sharer's model for that game only; declining changes nothing; a tampered asset (hash mismatch) is refused; gameplay values (collision, hit timing) are identical with and without the list.

## Acceptance Criteria

- [ ] Two players with different models play one game and get identical gameplay results
- [ ] Accepting a list applies it automatically for that game and reverts afterwards
- [ ] "Always accept from this player" makes the next list apply without a prompt
- [ ] Hash mismatches are refused and reported

## Open Questions

1. Should a list also be able to carry replacement *data tables* (for maps that ship their own spells or units), or only art?
2. Where are lists published besides direct sharing in a lobby: next to a map in the map browser (1001)?

## Related Documents

- `/home/ritz/programs/r-mail/docs/attachments.md` (consent flow), `docs/protocol.md`, `docs/.templates/scripting-tutorial.md` (hooks)
- `issues/603-server-asset-download-protocol.md` (earlier transfer design, replaced by rmail), `issues/604-asset-deduplication-system.md`, `issues/605-local-storage-manager.md`
- `issues/W05d-clean-room-describe-build-check-loop.md` (the criteria set: gameplay never reads art)
- `/mnt/mtwo/games/azeroth-core/custom-client/issues/105a-loose-overlays-and-asset-resolver.md`
