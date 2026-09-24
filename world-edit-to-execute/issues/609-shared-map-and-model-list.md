# Issue 609: Shared Map-and-Model List

**Phase:** 6 - Asset System
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 603 (asset transfer protocol), 604 (content-addressed storage), 605 (local storage manager)

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
- **One choice, then automatic.** When another player offers a list, the
  receiver sees one prompt: "Use Ana's models for this game?" Choosing yes
  fetches whatever is missing (from the sharer through 603's transfer, or from
  each asset's source URL), verifies every hash, and applies the list as a
  **temporary profile for that game**, reverted afterwards unless the player
  chooses to keep it. Choosing no changes nothing.
- **Remembered choices.** "Always accept lists from this player" and "always
  for this map" make it automatic from then on, as the owner asked.

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
3. Fetch-and-verify through 603 (peer) and plain URLs; refuse any asset whose hash doesn't match.
4. The one prompt, plus the "always" choices, stored per player.
5. Change 603 so its transfers are driven by an accepted list, never pushed as "required".
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

- `issues/603-server-asset-download-protocol.md`, `issues/604-asset-deduplication-system.md`, `issues/605-local-storage-manager.md`
- `issues/W05d-clean-room-describe-build-check-loop.md` (the criteria set: gameplay never reads art)
- `/mnt/mtwo/games/azeroth-core/custom-client/issues/105a-loose-overlays-and-asset-resolver.md`
