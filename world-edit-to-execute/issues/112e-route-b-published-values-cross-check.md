# Issue 112e: Route B, Published Values as a Cross-Check

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Sub-issue of 112
**Priority:** High
**Dependencies:** 112c (Route A), 112b (the 1.29.2 layer)

---

## Current Behavior

Built and run (2026-09-25). Route B reads Liquipedia's infobox numbers for
every unit, building and item page and compares each with the same column in
Route A's 1.29.2 melee tables, read from the player's install. The live
figures come from `luajit src/cli/route-b-report.lua` (report in
`tmp/shared-memory/route-b/report.md`). At the first full run:

- **Coverage:** 586 pages; 575 objects; 24434 numbers that both routes give.
- **Agreement:** 24305 numbers agree (10020 of them are a cell the game leaves
  blank and the wiki writes as 0).
- **Explained:** 35 differ, each for a reason found:
  - **Upgrade chains** (13 rows). The game stores an upgraded building's
    cost as the whole chain, and the wiki gives the step (Castle: 1065 =
    Town Hall 385 + Keep 320 + 360). Each is proven by the sum, using the
    upgrade lists in the game's race function files.
  - **Research** (9 rows). The Druids' animal forms show fully researched
    values (Bear form: 810 + 2 × 75 = 960 hit points).
  - **Errors on the page at the time** (5 rows):
    - the Destroyer's mana regeneration is written "03", losing the minus;
    - the Tome of Retraining's stock is 2 in 2017, although the 1.36.1 notes
      say it "now has a stock of 2";
    - the Cannon Tower's splash radii are a tenth of the game's.
  - **Another form** (8 rows). The Spirit Walker's page names the ethereal
    form's id, but its attack is the corporeal form's, exactly.
- **Not checkable:** 94 differ on 28 pages that have no revision from before
  1.30, so they show a later patch's numbers. Spot checks against the
  cached patch notes agree with this: Boneyard 175 → 150 gold, Nerubian Tower
  cooldown 1 → 1.3 → 1.15, Moon Well regeneration 1.5 → 1.35 → 1.45,
  Scepter of Mastery 3 charges → 1.
- **Unexplained:** 0.
- **Not compared** (11 pages, each listed with its reason). Most are items
  added after 1.29.2. Three names are shared by several objects, and those
  pages don't say which they mean (Orb of Lightning, Ring of the Archmagi,
  Clockwerk Goblin).

Fetching used 12 batched requests for today's pages, then 168 single
requests for the pages as they stood under 1.29.2: the 153 that differed,
then the 15 pages with wiki-only numbers or no pairing. Requests were 10
seconds apart, give or take 1–2 seconds, and everything is cached on disk.

The reader was fixed along the way, each fix with a test:
- fields are cut at every top-level `|`, as MediaWiki does (some item pages
  put several fields on one line);
- `Infobox_building` is read as `Infobox building`;
- the 2018 building layout is read: no id (paired by name through the race
  name files), `buildtime` and `foodsupply`, and "base / upgraded" values.

The splash fields (radii and damage fractions) were added to the field map.

## Intended Behavior

For every stock object Liquipedia describes, each infobox number compared
with the same field in Route A's 1.29.2 melee tables: `match`, `mismatch`
(both values), `only in A`, `only in B`, with coverage (the share of Route A's
fields Route B confirms). Mismatches are investigated and the finding
recorded, never "fixed".

**Fetching, as the owner set it (2026-09-25):**
1. Which pages: the lists of pages using each infobox template
   (`list=embeddedin`), one request each.
2. Current revisions, 50 pages per request. Where today's value already
   equals Route A's 1.29.2 value, it is confirmed with no more fetching.
3. Old revisions (the last before 2018-08-08) only for pages with a
   difference, one request each (the API allows one page per request for
   old revisions).
4. Every request 10 seconds apart, give or take one to two seconds at random
   (the owner: "let's do +/- 1-2 seconds for each request"), across runs;
   a User-Agent naming only the tool; compressed; cached on disk beside the
   installs (`wc3-installs/external-values`, a link ignored by git), never
   fetched again (the owner: "Then let's cache it on disk"). Runs in the
   background.

Liquipedia's text is CC BY-SA 3.0: kept in its own folder, used only to
check, never to fill a table, never committed.

## Suggested Implementation Steps

1. `src/gamedata/route_b_fields.lua` (reviewed data): infobox field → stock
   table and column, per template. Buildings share the unit map plus the
   2018 names (`buildtime`, `foodsupply`).
2. `src/cli/route-b-fetch.lua`: the phases are discover, current (50 per
   request), old <list> (one per request) and status, with the spacing and
   cache rules above. A page with no revision before the cutoff is recorded
   ("none before …") so it's never asked for again.
3. `src/gamedata/route_b.lua`:
   - the infobox reader (top-level pipes, underscore names, "base /
     upgraded");
   - pairing by id, or by title through the name files (a shared name isn't
     paired);
   - comparison within the page's rounding;
   - explanations: upgrade chains proven by sum, the findings file, and pages
     written after 1.30.
4. `src/gamedata/route_b_findings.lua` (reviewed data): each disagreement
   investigated by hand, with its kind and evidence.
5. `src/cli/route-b-report.lua`: the summary, the unexplained rows, every
   explained row with its reason, and the unpaired pages. It also writes
   `refetch.txt`, the pages the fetcher's `old` phase should take next.
6. Tests (`src/tests/test_route_b.lua`):
   - the reader on hand-made text;
   - the verdicts and the upgrade sum;
   - the real Knight: 835 hit points in both routes, from its 2017 page.

## Acceptance Criteria

- [x] Pages discovered and fetched within the spacing, cached on disk
- [x] Old revisions fetched only for pages whose current values differ
- [x] Report with coverage and every mismatch listed
- [x] Every mismatch investigated, the findings recorded (0 unexplained)
- [x] Tests; `.info.md` beside each new file
- [ ] Open questions answered

## Open Questions

1. **28 pages have no revision from before 1.30.** They include core
   buildings (Ziggurat, Moon Well, Boneyard, Ancient of War), which surely
   had pages in 2017. A likely cause is that the pages were written under
   other titles and later copied to these, which leaves the older history
   behind. These 94 numbers are "not checkable" for now.

   Should the fetcher trace them? It would be one request per page (about
   28, ~5 minutes at the agreed spacing), asking for each page's first
   revision and the note written with it, then fetching the older title's
   2018 revision where one is named. If not, they stay not checkable and the
   issue is complete as it stands.

## Related Documents

- `issues/112-stock-object-tables-by-two-routes.md`
- `issues/completed/115b-notes-for-versions-we-dont-read.md` (the first Liquipedia fetch)
