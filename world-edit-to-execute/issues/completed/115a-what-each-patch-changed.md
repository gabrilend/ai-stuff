# Issue 115a: What Each Patch Changed

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Sub-issue of 115
**Priority:** Medium
**Dependencies:** 115 (the balance history explorer)
**Blocks:** 115b

---

## Current Behavior

**Completed 2026-09-25.** The explorer's header has a version menu ("what
1.22a changed"), each heat-map column opens its version, and
`index.html#tft/v/1.22a` opens one directly. The patch view lists every
number that differs from the version before, grouped by object (name, id,
kind), old → new with the difference; "new:" and "removed" where an object
appears or disappears; filtered by kind and search; clicking an object opens
its history (`src/viewers/balance-history.html`, `renderPatch`).

Checked in headless Firefox on 1.22a: it matches the official patch notes
line for line (Scout Tower repair 12 → 20, Knight damage 25 → 28 and
cooldown 1.5 → 1.4, Ziggurat armor 1 → 5, Necropolis build time 120 → 100,
Orb of Venom's poison 10 → 8 seconds, Dryads level 2 → 3) and shows one
change the notes don't mention (Storm, Earth, and Fire lasts 45 seconds,
not 60).

Before this, the explorer showed only how many numbers each version
changed, and per-object charts. The owner (2026-09-25), choosing it from
three ideas: "can we add a way to see what each patch changes?"

## Intended Behavior

Pick a version (a heat-map column, or a version list) and see every number
that version changed from the one before it: grouped by object (name, id,
kind), each field with old → new and the difference; objects that appear
for the first time or disappear marked as such. Filterable by kind and by
search, like the object list. Reconstructed patch notes, exact, from the
tables. The address `#tft/v/1.22a` opens a patch.

Built on the data the generator already writes; no generator change needed.

## Suggested Implementation Steps

1. A version list in the header and clickable heat-map columns.
2. The patch view: changes of version i against i−1, grouped by object,
   sorted by kind then name; counts per kind at the top.
3. Address support (`#game/v/version`), and back to the heat map.
4. Check in headless Firefox: 1.22a shows the Knight's damage 25 → 28 and
   cooldown 1.5 → 1.4.

## Acceptance Criteria

- [x] Each supported version's changes, grouped by object, old → new
- [x] Reachable from the heat map and a version list; address opens it
- [x] Checked in headless Firefox on 1.22a

## Related Documents

- `issues/completed/115-balance-history-explorer.md`
