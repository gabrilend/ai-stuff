# 704 — The case viewer

A case as one HTML page: the survey, the graph, the design's state, the
requests and their grades, the center, the ledger — the viewing side of
everything, built from the case folder alone.

## Current Behavior

A case is read through the text commands.

## Intended Behavior

**Command `view`** writes `cases/<case>/view.html`, self-contained (inline
style and script, no outside requests), with:

- the survey: languages as a bar chart, the foundations and entry points;
- the graph: levels as columns, issues as boxes coloured by state (built,
  failed, held, waiting), each opening its issue text on click;
- requests: each with its grade and its reach highlighted on the graph when
  hovered;
- the center: the ten heaviest as bars, with a slider replaying the ledger
  line by line to show the center moving;
- the ledger: every line, with the chain verified in the page itself
  (SHA-256 in the page's script) and a mark on any line that fails.

Light and dark themes from the system setting.

## Suggested Implementation Steps

1. **Test:** the page is written for the phase 6 fixture case and contains
   every issue id and every ledger line.
2. **Test:** the page carries the machine's head hash beside the one its own
   script computes; the test checks the machine's is present. Whether the
   page's own computation agrees is shown in a browser by the demo — the test
   runner has no browser.

## Blocked by

- 703
