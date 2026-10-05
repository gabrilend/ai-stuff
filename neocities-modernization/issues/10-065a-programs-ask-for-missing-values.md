# 10-065a: Programs Run on Their Own Ask for Missing Values

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: Medium
- **Type**: Design change
- **Status**: In progress -- see Current Behavior for what is built
- **Created**: 2026-10-04
- **Parent**: 10-065 (`run.sh` demands every value). That issue made `run.sh`
  refuse to start without the values a build needs. This one covers the
  programs `run.sh` starts, when a person runs one of them directly.

## The owner's decision (2026-10-04)

> how about we prompt for each one, and say "how many pages? [200]" and they can
> push enter to use the default. Unless we pass a command line flag like --y or
> whatever then it'll just automatically use the defaults.

## Current Behavior

Before this issue, a program run directly without a value quietly filled it in
from `config.lua` or a number written in the code, and nothing on screen said
so. Through `run.sh` the value is always passed, so this only happened to
someone running a program by hand -- but then they got a build shaped by a
number they never saw.

Built (2026-10-04): the shared helper `libs/ask-for-value.lua` (behaviour in
the Intended Behavior table; reference in `libs/ask-for-value.info.md`; test
`libs/ask-for-value.test.lua`, 21 checks), `run.sh` exporting
`NEOCITIES_NO_PROMPTS=1` to everything it starts, and the four programs marked
"asks (built)" below, each accepting `--yes`/`-y`. Checked by hand in a scratch
copy of the project: each program errors with no keyboard and under
`NEOCITIES_NO_PROMPTS=1`; `--yes` prints one notice per default and runs; a
typed answer under a pretend terminal (`script`) takes effect (a typed 75 gave
a 75-word cloud); `--help` asks nothing. `scripts/test-seed-reproducibility.sh`
now passes `--yes` and still passes.

Found and fixed on the way:
- `scripts/update` passed the fediverse extractor no flag at all when reblogs
  were off, relying on the extractor's silent fallback. Under the new rule a
  build with `--boosts no` would have stopped at stage 2; it now passes
  `--no-boosts` explicitly.
- `config.lua` had no word-page size, so the 50 written in
  `src/generate-word-pages.lua` was applied silently every time. It is now
  `word_cloud.poems_per_page = 50` in `config.lua`, offered as the default.
- `word_cloud.max_words` claimed "0 = unlimited"; 0 actually gave no words.
  The comment now says no limit is `--all`, or answering "all".

- `scripts/update` printed "Warning: ... failed" and carried on when any of its
  five extractors failed (fediverse, messages, archive notes, main notes,
  Bluesky), so a build could run its hour of later stages on a corpus missing
  a whole source. Owner (2026-10-04): "if it encounters an error, it should
  stop so we can fix it before wasting more time on a doomed run." Each now
  stops the update (and `run.sh` stops the build). Its media copy discarded
  every error to get past two ordinary cp failures (an empty folder, a file
  already preserved); it now copies in a way that does not fail on either, so
  a real failure (a full disk) stops the update too.

Inventory (found with a search for "flag or fallback" expressions, then by
reading each program's argument handling):

| Program | Value | Fallback today | Status |
|---|---|---|---|
| `src/wordcloud-generator.lua` | words in the cloud (`--words`/`--all`) | `config.lua` `word_cloud.max_words`, else 200 | asks (built) |
| `src/wordcloud-generator.lua` | chronological page size (`--chrono-per-page`) | `config.lua` `pagination.chronological_poems_per_page` | asks (built) |
| `src/generate-word-pages.lua` | chronological page size (`--chrono-per-page`) | the same | asks (built) |
| `src/generate-word-pages.lua` | words (`--words`/`--all`) | `word_cloud.max_words`, else 200 | asks (built) |
| `src/generate-word-pages.lua` | poems per word page (`--poems-per-page`) | 50 written in the code (`config.lua` had no such setting) | asks (built), and only in the mode that writes pages; the 50 now lives in `config.lua` |
| `src/main.lua` | include reblogs (`--include-boosts`/`--no-boosts`) | `privacy.include_boosts`, else no | asks (built), only when extracting |
| `scripts/extract-fediverse.lua` | include reblogs | `privacy.include_boosts`, else no | asks (built) |
| `src/flat-html-generator.lua` (a library, used through `main.lua --html-only`) | pages per poem, poems per page, chronological page size, threads | a built-in table, then `config.lua` `pagination`, then the command line | not yet: the defaults are layered inside the library; asking belongs at `main.lua`'s edge, and the library should stop holding defaults |
| `scripts/generate-html-parallel` | pages, poems per page | built-in 15 and 100, then `config.lua` | not yet: stale, see below |
| `scripts/generate-html-pthreads` | pages, poems per page | `config.pagination.pages` (a setting that does not exist), else 5; poems per page else 100 | not yet: stale, see below |
| `scripts/validate-poem-representation` | chronological page size | `config.lua`, else 500 | not yet: stale, see below |

Three of these programs are stale beyond their fallbacks, found while making
this inventory:
- `scripts/generate-html-pthreads` reads its diversity cache from
  `assets/embeddings/embeddinggemma_latest/`, a folder that no longer exists
  (model folders are now named like `embeddinggemma-300m`). Nothing calls it.
- `scripts/generate-html-parallel` hard-codes the same missing folder for its
  similarity files. Only `src/main.lua`'s own interactive menu calls it.
- `scripts/validate-poem-representation` counts chronological pages named
  `output/chronological-*.html`; they now live in `output/chronological/`, so it
  always finds none.
Adding questions to programs that cannot run is wasted work. Each needs a
decision first: repair or retire (open question 1).

## Intended Behavior

A value missing from the command line is resolved in this order, by one shared
helper (`libs/ask-for-value.lua`) so every program behaves the same:

| Situation | What happens |
|---|---|
| the value is on the command line | it is used |
| `--yes` (or `-y`) is on the command line | the default is used, and one line says so: `--yes: using 200 for --words (config.lua word_cloud.max_words)` |
| the program was started by `run.sh` | an error: a value `run.sh` failed to pass is a bug in `run.sh`, not a question for whoever is watching. `run.sh` marks its children by exporting `NEOCITIES_NO_PROMPTS=1` |
| no one is at the keyboard (input is not a terminal: a pipe, a cron job, another program) | an error naming the flag and the default it would have used, so a script never hangs waiting for an answer nobody will type |
| otherwise | the question, with the default in brackets: `How many words in the word cloud? [200]`. Enter takes the default; anything else must be a valid answer or the question is asked again |

Questions and notices go to the error stream, so a program whose normal output
is piped somewhere still shows them.

Why the default still comes from `config.lua`: the default shown in brackets
has to come from somewhere, and `config.lua` is where the owner keeps
preferences. What changes is that the default is now *shown and confirmed*
instead of applied silently -- the property 10-065 was after.

## Suggested Implementation Steps

1. `libs/ask-for-value.lua`: the helper and its rules (table above), with
   answer kinds "count" (a whole number of 1 or more), "count or all", and
   "yes/no". Test: `libs/ask-for-value.test.lua` covers every row of the table.
2. `run.sh`: export `NEOCITIES_NO_PROMPTS=1` before starting any stage.
3. The four programs that take these values directly: accept `--yes`/`-y`,
   and replace each silent fallback with the helper -- at the point the value
   is used, not when the program loads, so a mode that never needs the value
   never asks (stage 6 runs `src/generate-word-pages.lua --embeddings-only`,
   which needs no page size).
4. `src/main.lua --html-only` and `src/flat-html-generator.lua`: resolve pages,
   poems per page, chronological size and threads in `main.lua` with the
   helper, and make the library take them as required inputs.
5. The three stale programs: repair or retire, per open question 1.

## Open Questions

1. **The three stale programs.** `scripts/generate-html-pthreads` (nothing
   calls it), `scripts/generate-html-parallel` (only `main.lua`'s own menu calls
   it) and `scripts/validate-poem-representation` all point at files that moved.
   Repair them, or retire them under 10-060?
