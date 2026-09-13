# 103 - The expansion table

| | |
|---|---|
| Phase | 1 - the patch spine |
| Blocked by | 102, which supplies the numbers being named |
| Blocks | the viewer's meta views, which group patches by expansion |
| Note | the only hand-written table in the project |

## Current behaviour

Builds are numbered and dated but unnamed. Nothing can say that build 22810
belongs to Legion, because no open source states the mapping.

## Intended behaviour

A small hand-written table mapping a product line and a leading version number
to the name a person uses, plus the span of dates that expansion covers.

It is hand-written because no source publishes it, and it is worth being honest
that this makes it the one place in the project where a human opinion enters the
data rather than the interpretation. Two opinions in particular need to be
someone's decision rather than a default:

- Where the Classic re-releases sit relative to the originals they re-release.
  They share version numbers with the original era and were shipped a decade
  later, so date-ordering and version-ordering disagree, and the table has to
  say which one the viewer's timeline obeys.
- Whether the public test realms are their own product lines on the timeline or
  annotations on the line they test for.

## Suggested implementation steps

1. Write the table as data, not code - one entry per expansion per product line.
2. Ask the project owner for the two decisions above rather than picking. Both
   are visible in the viewer and both are the sort of thing one has a taste
   about.
3. Check the table against the build records: every leading version number that
   appears in a build record must be named by the table, and an unnamed one is
   an error that stops rather than a build quietly displayed as blank.

## Related documents

- Open questions, item 9 - who writes this table
