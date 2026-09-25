# Issue 115b: Patch Notes for the Versions We Don't Read

**Phase:** 1 - Foundation, File Format Parsing
**Type:** Sub-issue of 115
**Priority:** Low
**Dependencies:** 115a (the patch view)

---

## Current Behavior

**Completed 2026-09-25.** `src/cli/patch-notes-fetch.lua` fetched Liquipedia's
pages in three requests in all, at least 30 seconds apart (41 pages in one;
seven more titles in a second, none of which exist: 1.28.0–1.28.5 and 2.0.1
have no page; 46 subpages in a third, pulled in by `{{/human}}` and the like
on the classic pages), into `wc3-installs/external-notes/` beside the
installs, where nothing is fetched again. The User-Agent names the tool only.
`src/cli/patch-notes-build.lua` turns them into `notes.js`: sections and
bullet lines of plain text (links, icons and templates stripped; each
subpage `{{Patch object … text=…}}` a single line), with each version's
release date, build, source page and licence. `scripts/balance-history.sh`
adds it when the cache exists.

The page (`src/viewers/balance-history.html`) lists those versions in the
version menu and as hatched columns marked * on the heat map, each labelled
"not supported by this project — patch notes only"; the notes view opens with
that banner, the reason (a later version left alone, or no patch program
found) and the source and licence. Checked in headless Firefox (1.32.10's
notes; the heat map). The 1.22 notes' balance lines match what the patch
view reconstructs from the tables. `src/tests/test_patch_notes.lua` (6
checks). Liquipedia's text is described in `docs/licensing-and-boundaries.md`
and `docs/versions-we-leave-alone.md`.

Before this, versions the project doesn't read didn't appear at all.

## Intended Behavior

Those versions appear in the explorer as **patch notes only**, never as
numbers on the charts: the notes are a human summary in prose, often
incomplete, not the tables, so they can't be placed on a chart without
guessing.

- **Source:** Liquipedia's Warcraft III wiki, through its MediaWiki API.
- **Marked everywhere they can be picked:** in the version menu, on the heat
  map, and at the top of the notes view: "not supported by this project —
  patch notes only", with the source and its licence.
- **Licence kept apart:** Liquipedia's text is CC BY-SA 3.0. It lives in its
  own file (`notes.js`), credited, never mixed into the project's data or
  committed; the viewer only shows it.
- **Fetched gently, once:** all pages in batched API requests (up to 50
  titles per request; about two requests in total), at least 30 seconds
  apart, with a plain User-Agent naming the tool (no personal details; the
  owner: "No sense giving them more info than they already have"). Cached on
  disk beside the installs (`wc3-installs/external-notes`, a link, ignored by
  git), so nothing is fetched again once it's there, not even after a reboot.

## Suggested Implementation Steps

1. `src/cli/patch-notes-fetch.lua`: the candidate page titles (a data list
   in the script), one batched request for which exist, one for their
   wikitext; writes the cache (raw wikitext per page, plus a record of when
   and from where). Refuses to fetch what's cached.
2. `src/cli/patch-notes-build.lua` (or a step in `balance-history.lua`):
   wikitext → sections and bullet lines of plain text → `notes.js`
   (`window.NOTES`), with each version's source page and licence.
3. Viewer: unsupported versions in the menu and on the heat map (hatched
   columns, in version order), a notes view with the banner, source link and
   licence.
4. Check in headless Firefox; the banner is present on every path to a
   notes-only version.

## Acceptance Criteria

- [x] Fetched in three batched requests, cached on disk, never repeated
- [x] Notes shown for the versions the project doesn't read, as text only
- [x] "Not supported by this project — patch notes only" wherever one can be picked, with source and licence
- [x] Liquipedia text kept in its own file, never committed

## Related Documents

- `issues/completed/115a-what-each-patch-changed.md`
- `docs/versions-we-leave-alone.md`, `docs/licensing-and-boundaries.md`
