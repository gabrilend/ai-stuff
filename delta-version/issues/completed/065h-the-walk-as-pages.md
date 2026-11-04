# Issue 065h: The Walk as Pages

**Status**: Completed 2026-10-10
**Parent**: 065-the-reading-walk.md
**Dependencies**: 065a, 065b, 065c
**Blocks**: None

## Current Behavior
`scripts/reading-walk-pages.lua <project>` writes the walk as pages; on the
kanji-learning-image-generator project, one page per source file and one
small-screen page per stop, in a fraction of a second. Tests: the pages
section of `scripts/test-reading-walk.sh`.

## Intended Behavior
The same map as the terminal walk, as a small website in the house style: the
files in reading order on the left; one file's stops on the right, each with
summary, description (marked when it came from a comment or is missing),
where it is used — each use a link to the stop that makes it — the recorded
reasons, its chapter, its code coloured by kind (comments, strings, numbers,
keywords), and links to the stops before and after, across files, so the site
reads start to finish. Colours are tokens that follow the reader's light or
dark setting; narrow screens stack the file list above.

The small-screen view: one page per stop, black background, only text lit (an
unlit OLED pixel costs nothing), name and summary large, back and next links.

No page carries a script, so none needs the feedback box the house rule asks
of script-driven pages. Pages are written one job per page across one worker
per CPU.

## Suggested Implementation Steps
1. Front page, stylesheet.
2. File pages: stops, uses linked to their makers, reasons, highlighted code,
   previous and next.
3. Small-screen pages.
4. Tests: page counts, use links, cross-file next link, highlighting,
   escaping, black small screen, no scripts.

## Decided against
- One long page for the whole project: hundreds of stops with their code is
  too heavy to open; one page per file keeps the file list as the table of
  contents.
- Scripts for keyboard paging on the small screen: access keys on plain links
  do it without one.
