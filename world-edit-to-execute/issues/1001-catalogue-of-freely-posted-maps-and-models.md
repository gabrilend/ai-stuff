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
- **Facts from a downloaded model:** read through the model reader (116):
  triangle and vertex counts, animation names, the textures it uses and
  whether it takes team colour; and a turntable picture drawn by the
  in-engine model renderer (516).
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

**Three ways to open it (2026-11-04).** The owner, of sharing maps and
models: "we can have a small 'launcher style' system that users can open
to view and browse and such. They could also be viewed and browsed through
the browser." So the catalogue, and the shared map-and-model lists beside
its entries (609), open in:

- **a small launcher** of this project's, started on its own, without the
  editor or the W client;
- **an ordinary web browser**, the same page;
- **the W client's flat pane**, as decided 2026-10-07 (open question 1).

One page serves all three; what differs is only who draws it.

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

1. ~~A page or an in-engine screen first?~~ Answered 2026-10-07: both, as
   one thing. The browser is an HTML page, and the W client draws it into
   a texture and shows it on a flat pane (the owner: "maybe we just render
   the browser to HTML and cast it onto a flat UI pane in the W client?
   And our Azerothcore project ... can do the same"; W client 110f).
2. ~~Where are shared lists (609) shown: next to a map in this catalogue?~~
   Answered 2026-11-04: here, in the launcher and the web page ("Three
   ways to open it", above).
3. ~~Which HTML capabilities the pane needs~~ Answered 2026-10-07:
   scripts are needed (a search that narrows as one types, downloads
   that show progress), and the one thing a still page can't do is "spin
   a 3d model to see the other sides or watch animations in action"
   (the owner). So the page holds a **live model box**: a place in the
   layout the W client fills with a view drawn into a texture (W client
   110f), turned by the mouse, playing the model's animations.
4. ~~Lua for the page's scripts instead of JavaScript?~~ Answered
   2026-10-07: (a), Lua scripts, inside the W client only; "We can build a
   separate javascript web viewer if we want that later" (the owner).
   The question as asked: (the owner: "Can
   we build them in lua instead of javascript? Or is that a terrible
   idea?") Not terrible: the W client already runs Lua for its interface
   (Phase 7, where WoW itself lays out its interface in XML and scripts
   it in Lua). The cost is that an ordinary web browser runs only
   JavaScript, so a Lua-scripted page works only inside the W client,
   unless the page also loads a Lua interpreter written in JavaScript
   (Fengari, which runs Lua 5.3: scripts kept to what LuaJIT and Lua 5.3
   share would run in both). Options: (a) Lua scripts, W client only;
   (b) Lua scripts, plus Fengari so the same page works in web browsers
   and in the AzerothCore project's pages; (c) the browser built as a W
   client interface screen (XML and Lua) rather than HTML. Which?
5. **Scripts in an ordinary web browser.** Asked 2026-11-04. Answer 4
   kept the page's Lua scripts inside the W client, with "a separate
   javascript web viewer if we want that later". The launcher and the web
   browser now want the page too. Does the page carry Fengari (one Lua
   interpreter written in JavaScript, so the same scripts run in all
   three), or does the web browser get the separate JavaScript viewer
   answer 4 left for later? And does the launcher draw the page itself
   (it would need an HTML engine) or open it in the user's web browser?
   Partly answered the same day, the owner: "no to fengari." Still open:
   the scripts meant are the page's moving parts (the search that narrows
   as one types, download progress, the live model box), which answer 4
   wrote in Lua for the W client; an ordinary web browser runs only
   JavaScript, so without Fengari the web page's moving parts are
   JavaScript, or the web page goes without them. Which, and how does the
   launcher show the page?

## Related Documents

- `issues/603-fetch-maps-and-models-from-public-sites.md` (the fetcher)
- `issues/609-shared-map-and-model-list.md`
- `docs/licensing-and-boundaries.md` (content rights)
- `docs/roadmap.md` (phase 10)
- `issues/W02-build-wc3-maps-into-the-wow-client.md` (conversion report)
