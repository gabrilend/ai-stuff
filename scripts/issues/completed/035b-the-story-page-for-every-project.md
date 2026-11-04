# 035b — The Story Page for Every Project

| | |
| --- | --- |
| Parent | 035 — share the transcript HTML renderer |
| Blocked by | 035a |
| Blocks | 035e |
| Status | complete, 2026-10-04 |

The table of contents takes double-diaper-dungeon's look — the story page —
for every project, and keeps this folder's way of deciding which
conversation made each commit underneath it. The owner's choice, 2026-10-04:
the game's look for all, being the newer one and the one she reviewed live.

## Current behavior

Built as intended below, in `contents/commit-history.lua`,
`contents/attribution.lua` and `contents/contents-page.lua`. Every project
in the ai-stuff repository (34) builds with it. Built for
double-diaper-dungeon's mirror with the rule list `{ "recorded" }`, its
story page is byte for byte the one live on abcd-games.net: 70 commits, 19
groups, 55 linked. The checks are in `tests/test-transcript-site.lua`, under
"the story page for every project".

Before, two tables of contents existed, both hers:

| | this folder (`commit-timeline.lua`) | double-diaper-dungeon (`src/051`) |
| --- | --- | --- |
| history read | the project's own, `--relative -- .` | a public mirror repository, whole |
| commit's own hash | its hash | the `Mirrored-from:` trailer (the project commit it copies) |
| trailers | shown in the body | `Mirrored-from:`, `Co-Authored-By:`, `Claude-Session:` dropped |
| which conversation | evidence: a recorded commit line by hash, else by subject, else the one main transcript it saved | the recorded commit line by hash, only |
| a hash recorded twice | the last transcript read | the first, in name order |
| a row shows | the subject, the body unfolding, a ↗ to the turn | the body's first paragraph, the rest unfolding, a **transcript** button to the commit line; dimmed when none |
| grouping | runs by conversation, the link under the run | groups by conversation, the link as the group's heading with her first words |
| page furniture | a title | a title and the site's strip of links along the top |

## Intended behavior

**One look**: double-diaper-dungeon's, byte for byte, for a page that has
nothing the game's page lacks. Three things only other projects can meet get
a place in it, each drawn only when it happens:

- a conversation filed under another project in the same repository: the
  heading adds "(filed under <folder>)";
- a commit known only by the one transcript it saved (no line to land on):
  the button opens the conversation's page at its top;
- a conversation the commit names whose transcript is gone: the heading says
  "written under a name the project no longer carries".

**Two kinds of history**, chosen by where the history folder sits:

- the folder is its repository's top (a standalone project, or a mirror):
  every commit, empty ones included, since a mirror writes an empty commit
  where a project commit touched no transcript and the story must not skip;
- the folder is inside a larger repository (the ai-stuff monorepo): only
  commits touching it, paths written from it.

**Every commit has a `source`**: the `Mirrored-from:` hash when the message
carries one, else its own hash. Attribution matches on `source`, so a
mirror and a project read the same way. The three machine trailers are
dropped from every body.

**Attribution is a list of rules, tried in order**, set per project (035e):

| rule | the commit belongs to | lands on |
| --- | --- | --- |
| `recorded` | the transcript holding a `*[commit] <hash>...*` line for its `source` (the first transcript in name order, if several) | that line |
| `subject` | the one transcript recording a commit with the same subject (history was rewritten and the hash moved) | that line |
| `saved` | the one main conversation whose transcript it touched, a helper's counting as its parent's | the page's top |

Default `{ "recorded", "subject", "saved" }`; double-diaper-dungeon uses
`{ "recorded" }`, which is what it has always done. Both lists are tested.

**What this part is handed and what it returns.** It loads no transcript
and no conversation code. The builder gives it:

- `conversations`: transcript key (string) → `{ href` (string), `title`
  (string), `summary` (string or nil), `elsewhere` (string or nil) `}`
- `evidence`: `by_hash` (seven hex → `{ key, anchor }`), `by_subject`
  (subject → list of `{ key, anchor }`), `parent_of`, `is_main`
- `opts`: `title`, `intro`, `base_path`, `colours_css` (string), `nav`
  (string of HTML or nil), `nav_css` (string or nil)

and gets back one HTML string.

## Suggested implementation steps

1. `contents/commit-history.lua`: read commits as above, with `source` and
   trailers handled, and the two kinds of history.
2. `contents/attribution.lua`: the three rules as a dispatch table keyed by
   rule name; `group` folds into groups by conversation key.
3. `contents/contents-page.lua`: double-diaper-dungeon's `render_index`,
   `commit_html` and stylesheet, plus the three extra cases above.
4. Tests: a mirror-shaped repository and a monorepo-shaped one built in RAM;
   each rule list; the three extra cases; the page for a game-shaped input
   equal to double-diaper-dungeon's own output (the proof lives in 10-003a).
