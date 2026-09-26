# Issue 1001: Catalogue of Freely Posted Maps and Models

**Phase:** 10 - Polish, Tools and UX
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 603 (writes the catalogue files this reads)
**Builds on (completed):** map parsing (phase 1: MPQ, map info, trigger strings, terrain)
**Formerly:** "Map Browser Lists Freely Posted Maps"
(`1001-map-browser-lists-freely-posted-maps.md`, renamed 2026-09-26)

---

## Current Behavior

Nothing to browse. The engine plays whatever `.w3x`/`.w3m` files are already
on disk; the only maps in the project are the DAoW versions in `assets/`. The
roadmap's phase 10 lists a "Map browser/launcher UI" in one line, and the
owner confirmed (2026-09-23) that this issue is that browser.

Until 2026-09-26 this issue held both halves: finding and downloading maps,
and showing them. The owner agreed to split them along the line between
generating data and viewing it: finding and downloading, for maps and
models both, moved to issue 603; this issue keeps the viewing.

## Intended Behavior

The owner (2026-09-23): "a map searching client that crawled the web and
displayed custom maps that are freely posted and available. That way we don't
have to bundle any. Though, we can..."

This issue is the **data-viewing half**. It reads only the catalogue files
that issue 603 writes, one per source, and never fetches anything itself.
When the player chooses an item, it asks 603's downloader for it, and shows
the result the downloader records.

- **What it lists.** Every catalogue entry, maps and models together or
  filtered by kind, with what the source states: title, author, version,
  the stated terms, size, date, and the preview image the site offers.
  Sources marked "visit by hand" are listed with a link, never fetched.
- **Facts read from a downloaded map:** player count, map size, tileset, a
  minimap picture rendered from its terrain, trigger count, and whether it
  converts cleanly for the W client (W02's conversion report). Search and
  filter by those facts.
- **Facts from a downloaded model:** what the model check recorded (603).
  Richer facts (polygon count, animations, a rendered turntable) wait on a
  reader for WC3 models (603, open question 2).
- **Bundling, with assumed consent until withdrawn.** The owner
  (2026-09-23): "most authors will be unreachable, but we should do our due
  diligence, and then just assume that their consent is given until
  withdrawn." For each bundled map or model the catalogue records the due
  diligence: every attempt to reach the author (where, when, the message
  sent, any reply), the item's original posting and its stated terms. An item
  whose original post forbids redistribution is not bundled. A public
  withdrawal channel (an address and a file in the repository listing
  withdrawn items) removes an item from the next release and from the bundle
  list as soon as its author asks. The legal caveat is in
  `docs/licensing-and-boundaries.md`: assumed consent limits harm but isn't
  permission, so fetching from the original post stays the default and
  bundling is the exception.

## Suggested Implementation Steps

1. Read the catalogue files through 603's catalogue reader; nothing here
   parses a website.
2. The viewer: a page (HTML, as with the other documentation pages) or an
   in-engine screen. Lists, filters, and a detail view per item.
3. Map facts: run a downloaded map through the Phase 1 parsers and the
   minimap renderer; cache the facts beside the entry.
4. The due-diligence record and the withdrawal list, as data files.
5. Tests: a fixture catalogue shows the expected rows; a withdrawn item
   disappears from the bundle list in one step; the viewer makes no network
   request (checked by running it with networking unavailable).

## Acceptance Criteria

- [ ] The viewer lists maps and models from 603's catalogue files, and filters by kind
- [ ] A chosen map, once downloaded through 603, shows its facts
- [ ] A chosen model, once downloaded through 603, shows what its check recorded
- [ ] No item is bundled without a due-diligence record, and none whose original post forbids redistribution
- [ ] A withdrawal request removes an item from the bundle list in one step
- [ ] The viewer itself never fetches

## Open Questions

1. A page or an in-engine screen first? A page is quicker and matches the
   documentation pages; an in-engine screen is where a player picking a map
   to play would be.
2. Where are shared lists (609) shown: next to a map in this catalogue?
   (Asked in 609 too.)

## Related Documents

- `issues/603-fetch-maps-and-models-from-public-sites.md` (the fetcher)
- `issues/609-shared-map-and-model-list.md`
- `docs/licensing-and-boundaries.md` (content rights)
- `docs/roadmap.md` (phase 10)
- `issues/W02-build-wc3-maps-into-the-wow-client.md` (conversion report)
