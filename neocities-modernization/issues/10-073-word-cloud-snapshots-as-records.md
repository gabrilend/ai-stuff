# 10-073: Word-Cloud Snapshots Kept as Records, Rebuilt on Demand

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: Low
- **Type**: Storage change + viewer tool
- **Status**: Open
- **Created**: 2026-10-20
- **Related**: 10-063 (publishes the HTML snapshots in the source browser;
  this issue replaces that route), 10-058 (the seed in each snapshot's name),
  10-052 (the source browser)

## The owner's words (2026-10-20)

> We also only need to record enough information to recreate the page, we
> don't need the entire HTML or anything. Just a list of the words and their
> color / size weight, in the correct order, I think. Then we can have a tool
> or utility that rebuilds them with a given input.

> let's do a zip with a tool or utility that lets you select from them, or
> take one as a cli argument, builds the page, and displays it in your
> browser. The links should point to the live site.

## Current Behavior

Every word-cloud build writes a full copy of the cloud page into
`archive/wordclouds/`, named by date, word count and seed (the archiving step
in `src/wordcloud-generator.lua`). Each copy is the whole page: head, styles,
menu, the cloud, and an index of every word at the bottom. A 555-word
snapshot is about 500 KB; a 7,000-word one is larger. `du -sh
archive/wordclouds` gives the current total.

The cloud itself is one paragraph of links. Each word is
`<a href="wordcloud/WORD.html"><font size="N" color="#RRGGBB">WORD</font></a>`,
with the word wrapped in `<b>` when it is coloured (not the faint grey), and
`&nbsp;` between words. So a word carries four facts: the word, a size from
1 to 7, a colour, and bold or not. The order is the shuffled order from the
seed.

The source browser publishes these copies, trimmed to only the cloud with
their links pointed at the live site (`libs/wordcloud-snapshot.lua`), and the
whole-site check skips them.

The three snapshots from 2026-10-07 are uncommitted, waiting on this design.

## Intended Behavior

- **A record, not a page.** Each build saves a small text record of its
  cloud: when it was made, the seed, the number of poems and words, and then
  one line per word, in order: word, size, colour, bold. Nothing else.
- **Records are plain text files, one per build,** in `archive/wordclouds/`
  — not a zip (owner, 2026-10-20: favour change detection over file size).
  Git can see inside text, so each commit stores only what is new; a zip
  would be a fresh opaque copy of every record in every commit. A 555-word
  record is roughly 15 KB.
- **Records ride along in git like the transcripts** (owner: "treat them
  like llm-transcripts. They are low priority, but should be kept in git
  whenever we can"): any commit in this project carries every new record,
  whoever made the commit, the same way it carries changed transcripts.
- **A viewer tool** (Lua, in `scripts/`):
  - with no argument, lists the records (date, word count, seed) and asks
    which one to show;
  - with a record named on the command line, uses that one;
  - builds the cloud page from the record into the project's RAM folder
    (`tmp/shared-memory/`), with every word linking to the word page on the
    live site, and opens it in the browser.
  - A word that has no page on the live site today still links there; the
    owner accepted a dead link for an old word (2026-10-07: "if there isn't
    a page for that word, then oh well").
- **The existing HTML snapshots are converted** to records by the same
  reader that knows the cloud's layout, so the history from 2026-06-24 on is
  kept, and then the HTML copies are deleted (owner: "sure"; git history
  keeps them).
- **The source browser stops publishing `archive/wordclouds/`**, since
  there are no HTML copies left to publish.

## Suggested Implementation Steps

1. Record format: plain text, one header block then one word per line, tab
   between fields. Write it down as a comment where the record is written
   and where it is read.
2. Writer: replace the full-page copy in `src/wordcloud-generator.lua` with
   a record written from the same list of words, sizes and colours that the
   page is drawn from (not by reading the page back).
3. Write the record as its own text file, named as the HTML copies are
   today (date, word count, seed) with a `.txt` ending. Fail loudly if it
   cannot be written, as the HTML copy does today.
4. Reader + page builder: a library that reads a record and builds the cloud
   paragraph. Test: build today's cloud through the generator and through a
   record of it, and check the two paragraphs are identical except for the
   link targets.
5. Viewer: the script above. Open the browser the way the phase demos do.
6. Converter: read each existing HTML snapshot, write its record, and check
   that a page rebuilt from the record matches the old page's cloud. Then
   delete the HTML copies (`git rm`, so the deletion is one recorded step).
7. Source browser: drop the HTML-snapshot handling (the "view" kind from
   10-063); the records are text files and publish as text like any other.
   The download zip keeps carrying `archive/`. Remove the trimming library
   only if nothing else uses it.
8. Ride-along: done by instruction, not by changing the shared commit tool
   (owner, 2026-10-20: "There's no reason to add a patch to the hook if
   it's just for this project"). The project's `CLAUDE.md` tells every
   session to claim new records and include them in each commit.
9. Tests run by the build.

## Answered Questions (2026-10-20)

- Git: records ride along like the transcripts, by the project
  `CLAUDE.md` instruction (step 8).
- Zip or text: plain text, for change detection.
- Old HTML copies: deleted once converted and checked.
