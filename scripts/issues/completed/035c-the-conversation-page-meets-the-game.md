# 035c — The Conversation Page Meets the Game's

| | |
| --- | --- |
| Parent | 035 — share the transcript HTML renderer |
| Blocked by | 035a |
| Blocks | 035e |
| Status | complete, 2026-10-04 |

The two copies of the conversation page grew apart after 2026-09-26, each
learning things the other lacks. This joins them into one.

## Current behavior

Built as intended below, in `conversation/conversation-page.lua`. The two
switches live in the settings and are applied by the builder's shaping step,
which the film matcher shares. The stylesheet is four pieces
(`STYLE_TOP`, `STYLE_HARNESS`, `STYLE_CONTENTS`, `STYLE_BOTTOM`). The rule
for a commit line's id is the page's own `commit_anchor`; the builder hands
its answers to the table of contents. With both switches off, the game's 33
conversation pages are byte for byte the live ones. Checks under "the
conversation page meets the game's".

Before, the two copies had each learned what the other lacked:

| learned only here | learned only in double-diaper-dungeon |
| --- | --- |
| the recap contents list drawn at the top (issue 037) | a film beside every message (its issue 10-007) |
| harness lines above the first request, as a turn | an id on every commit line, `commit-<seven hex>`, for the story page to land on |
| "not recorded" for an archived transcript's missing facts | the films' stylesheet, and the commit line lighting up when landed on |
| colours from a palette file | colours from the game's balance table |

Read against the game's 33 transcripts on 2026-10-04, this folder's reader
finds a contents list in 7 and harness lines in 1. The game's reader drops
both, so its live pages show neither.

## Intended behavior

One `conversation/conversation-page.lua` holding both columns.

**Two switches, each a project setting (035e), both on by default:**

- `recap_contents` — draw the contents list at the top.
- `harness_lines` — keep the lines above the first request as a turn. Off
  means the turn is taken out of the conversation by the builder before
  anything numbers the turns, so `turn-N` ids and film choices count only
  the turns that are drawn.

double-diaper-dungeon turns both off to stay byte-identical with what is
live; whether to turn them on there is its own question.

**A page carries only the rules it uses.** The harness and contents rules
join the stylesheet only on a page that draws a harness turn or a contents
list, at the place they stand today. This keeps the game's pages byte-equal
and makes every page a little smaller. The film and commit-line rules are
always present, as on the game's pages.

**Colours come in as a CSS string** (`opts.colours_css`), made by the builder
from the project's settings — a palette file through `site-palette.lua`, or a
project's own function (the game reads its balance table). The page no
longer opens a palette itself.

**Films come in as a list** (`opts.films`, one per exchange: a file name or
false) with `opts.film_size` (whole number, CSS pixels). The page builds each
film's address as `<base_path>/films/<name>`.

**A link to a sibling transcript** keeps this folder's rule (a bare name with
no `/` or `:`), checked against the game's pages for equality.

## Suggested implementation steps

1. Fold the game's film markup, commit ids and stylesheet tail into this
   folder's page.
2. Stylesheet in pieces, the two optional pieces placed where they stand.
3. Replace the palette loading with `opts.colours_css`.
4. Tests: a page with films, without, with a contents list, with harness
   lines; a commit line gets its id; the stylesheet has no contents rules on
   a page with no contents.

## Added 2026-10-04: her quoted lines are a quieter green

Asked for after she read the pages:

> Can we change the quoted parts of the user's message to have a slightly
> different font color? Maybe slightly closer to dark-gray, but still green?

The lines she quotes back (a `>` line in her message, drawn as a blockquote)
wore the same green as her own words, so a reader could not tell at a glance
which words were hers and which she was pointing at. They are now her green
mixed 60 to 40 with a dark gray (`#555555`), through CSS `color-mix`, so the
quote follows the palette if her green is ever tuned. The rule sits beside
the one that colours her words, in `STYLE_TOP`; the assistant's quotes are
left as they were. Checked by a test that the rule is in every page's sheet.
