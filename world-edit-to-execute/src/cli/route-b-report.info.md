# route-b-report.lua

Compares every cached wiki page with the game's own 1.29.2 melee tables and
writes `tmp/shared-memory/route-b/report.md`. It fetches nothing.

- **Summary:** pages read (as they stood under 1.29.2, or today's), objects
  compared, how many numbers agree, disagree, appear only on the wiki, or
  can't be read.
- **Tables:** the unexplained disagreements, the numbers only the wiki gives
  and the unreadable values; then every explained row with its reason (by
  hand, an upgrade chain's sum, a page written after 1.30); then the pages not
  compared, with the reason.
- **Also writes** `refetch.txt`: today's pages that still differ, the list the
  fetcher's `old` phase takes.
- **Prints** one line of totals.

Usage: `luajit src/cli/route-b-report.lua [--dir DIR] [output folder]`

Issue: `issues/112e-route-b-published-values-cross-check.md`
