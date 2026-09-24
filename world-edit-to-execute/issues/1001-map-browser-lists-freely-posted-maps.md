# Issue 1001: Map Browser Lists Freely Posted Maps

**Phase:** 10 - Polish, Tools and UX
**Type:** Implementation
**Priority:** Medium
**Dependencies:** None open
**Builds on (completed):** map parsing (phase 1: MPQ, map info, trigger strings, terrain)

---

## Current Behavior

The engine plays whatever `.w3x`/`.w3m` files are already on disk. The only
maps in the project are the DAoW versions in `assets/`. The roadmap's phase 10
lists a "Map browser/launcher UI" in one line, with no design. The owner
confirmed (2026-09-23) that this issue is that map browser. No earlier
written design was found in this project's issues, docs, notes or transcripts,
so this issue is its first written form.

## Intended Behavior

The owner (2026-09-23): "a map searching client that crawled the web and
displayed custom maps that are freely posted and available. That way we don't
have to bundle any. Though, we can..."

A tool with two separate halves (data generation and data viewing):

- **Finder (generator).** Visits the sites where WC3 custom maps are posted
  for free download, and builds a catalogue. For each map: title, author,
  version, page URL, download URL, the site's stated terms, file size, date,
  and a content hash once downloaded. It follows each site's `robots.txt` and
  terms, prefers a site's own feeds or APIs where they exist, rate-limits
  itself, and identifies itself honestly in its user agent. A site whose terms
  forbid automated access is not crawled; it is listed as "visit by hand".
- **Downloader.** Only on the player's request, fetches a chosen map to the
  player's own machine (the way a browser would), checks it parses (phase 1),
  and caches it. Nothing is re-hosted by the project.
- **Catalogue viewer.** Lists the maps with facts read from each file after
  download: player count, map size, tileset, a minimap picture rendered from
  its terrain, trigger count, and whether it converts cleanly for the W client
  (W02's conversion report). Search and filter by those facts.
- **Bundling, with assumed consent until withdrawn.** The owner
  (2026-09-23): "most authors will be unreachable, but we should do our due
  diligence, and then just assume that their consent is given until
  withdrawn." For each bundled map the catalogue records the due diligence:
  every attempt to reach the author (where, when, the message sent, any reply),
  the map's original posting and its stated terms. A map whose original post
  forbids redistribution is not bundled. A public withdrawal channel (an
  address and a file in the repository listing withdrawn maps) removes a map
  from the next release and from the catalogue's bundle list as soon as its
  author asks. The legal caveat is in `docs/licensing-and-boundaries.md`:
  assumed consent limits harm but isn't permission, so fetching from the
  original post stays the default and bundling is the exception.

## Suggested Implementation Steps

1. List candidate sources and, for each, its terms, `robots.txt`, and whether
   it has a feed or API. This list is data, reviewed by the owner before any
   crawling.
2. Catalogue format (a Lua table per map, one file per source).
3. Finder per source, behind one interface, with rate limiting and a polite
   user agent.
4. Downloader with hash, parse check and cache under the user's data folder.
5. Viewer: a page (HTML, as with the other documentation pages) or an in-engine
   screen, reading only the catalogue.
6. Tests: a recorded fixture page per source parses into catalogue entries; a
   source marked "no automated access" is never fetched.

## Acceptance Criteria

- [ ] At least one source crawled within its terms, producing catalogue entries
- [ ] A chosen map downloads to the user's machine, parses, and shows its facts
- [ ] No map is bundled without a due-diligence record, and none whose original post forbids redistribution
- [ ] A withdrawal request removes a map from the bundle list in one step
- [ ] The source list with each site's terms is a reviewable file

## Open Questions

1. Which sites does the owner want first? (Candidates to check: long-running WC3 map archives and modding community sites, and Internet Archive collections of old map packs.)
2. Should the finder also run inside the W client (a map list in WC3 map mode), or stay a separate tool?

## Related Documents

- `docs/licensing-and-boundaries.md` (content rights)
- `docs/roadmap.md` (phase 10)
- `issues/W02-build-wc3-maps-into-the-wow-client.md` (conversion report)
