# Scoring options: how bright should a square be?

The grid looks like GitHub's contribution graph, one square per day, but a
square's brightness is not how many commits happened that day. It is how much
of what was written that day later work kept or built on. This document lists
the ways "kept or built on" can be measured, so one (or a mix) can be chosen
before the roadmap is written.

Measurements quoted below were taken on the ai-stuff monorepo on 2026-10-21.
To re-measure, run the same git commands named under each option against the
repository in question; repository size changes the costs.

Options are ordered from most likely to work well to most unusual.

## Shared vocabulary

- **a commit's lines**: the lines a commit added (each line is a string of
  text, credited to the commit's hash, a 40-character hex string).
- **the future of a commit**: every commit made after it on the same branch.
- **a day's score**: some combination (sum, average or maximum, still to be
  decided) of the scores of that day's commits.

## Option 1: Survival (are its lines still alive?)

**Mechanism.** At the newest commit, `git blame` reads every file and says,
for each line, which commit last wrote it. Count, per commit, how many of the
lines it added are still standing. Score = lines still alive / lines added
(a number from 0.0 to 1.0).

**What it rewards.** Code that was written once and never needed replacing:
foundations, settled libraries, things that were right the first time.

**What it misses.**
- Code that was used heavily for months and then rewritten scores 0, even if
  everything after it depended on it while it lived.
- When a file is moved or a block is cut and pasted, plain blame credits the
  move to the moving commit. `git blame -M -C` follows moved lines back to their
  author, at several times the cost.
- **Age bias:** a commit from yesterday has had no time to be replaced, so it
  scores near 1.0. Without a correction, the right edge of the grid always
  glows. Correction: compare a commit only against commits of similar age, or
  score only a fixed window (for example, its next 90 days).

**Cost.** One blame per file at the newest commit. The monorepo holds about
twelve thousand tracked files; a busy script blamed in 0.2 seconds, so a full
pass is on the order of 40 minutes on one thread, a few minutes spread across
all cores. The result can be cached under the newest commit's hash and only
redone for files that changed.

## Option 2: Name references (do later commits call what it defined?)

**Mechanism.** Read each commit's diff (`git log -p`). From the lines it added,
pull out the names it defined: Lua `function name(` and `local function name(`,
C function definitions, shell functions, Lua `require` module names. Then, for
each later commit, count how many of those names appear in the lines it added.
Score = number of later commits that mentioned something this commit defined.

**What it rewards.** Exactly "used": a helper that twenty later commits call
glows; a function nothing ever called goes dark. This is the option closest
to the vision's sentence "future recent code uses came from those particular
pieces of machinery".

**What it misses.**
- Short or common names (`init`, `run`, `draw`) match everywhere. Names need a
  minimum length, or a filter that drops names defined in many places.
- Commits that wrote no definitions (data files, documentation, tweaks to a
  body) score 0, even if they mattered.
- Each language needs its own pattern for "this line defines a name".

**Cost.** One pass over the full text of every diff in the chosen range, which
is larger than the per-file line counts (those took 20 seconds for one year,
2026 commits). Expect minutes, not hours, and it splits cleanly across threads
by commit.

## Option 3: Built-upon regions (did later commits extend it, or erase it?)

**Mechanism.** Every diff is a list of hunks: "in file F, at line L, removed
these, added those". Keep, for each file, a map of which commit wrote each
current line, and walk the history forward, updating the map hunk by hunk.
Whenever a later hunk lands inside or right beside lines commit X wrote:
- if it adds lines without removing X's, X gains a point ("built on");
- if it removes X's lines, X loses a point, or simply gains none ("replaced").

**What it rewards.** Code that became a place where work grew. It separates
"worked on a lot because it kept breaking" from "worked on a lot because
everything new attached to it", which a plain touch count cannot.

**What it misses.** "Beside" is a guess about meaning: a line added next to a
function is not always using it. Needs a chosen distance (how many lines
counts as "beside").

**Cost.** One forward walk through all diffs, keeping a line-ownership map for
every file in memory. The heaviest option to write, moderate to run. The walk
is ordered, so it parallelises by file, not by commit.

## Option 4: Later touches (how often did work come back to it?)

**Mechanism.** For each commit, list the files it changed. Score = number of
later commits that changed the same files. The per-file line counts
(`git log --numstat`) are all it needs: 20 seconds for one year of the
monorepo.

**What it rewards.** Hot spots: the files where attention keeps returning.

**What it misses.** Attention is not use. A file that is rewritten every week
because it never works glows as bright as a library everything depends on.
For the vision's goal ("prune the darker spots") this is risky: it would
protect churn and suggest pruning stable code.

**Cost.** The cheapest. Useful as a first draft of the grid and click-through
while a better score is built.

## Option 5: Require graph (did later files load the files it created?)

**Mechanism.** Find files that load other files: Lua `require "x"` and
`dofile`, shell `source`, C `#include "x"`. A commit that created file F
gains a point for every later-created file that loads F.

**What it rewards.** Libraries and shared modules: the parts other parts are
built from. Coarse (whole files, not lines) but very clear in meaning.

**What it misses.** Everything inside a file: a commit that improved a widely
loaded library without creating it gets nothing.

## Things every option has to decide

- **What not to count.** In this monorepo, `llm-transcripts/` files are huge,
  appended to and almost never deleted: under Option 1 they would score as
  the best code ever written and drown the grid. Generated files (docs/HTML,
  build outputs, images) have the same problem. An ignore list (folders and
  file types) is needed under every option.
- **Age bias.** Recent commits have had less future. Options 1, 2, 3 and 5 all
  need either a fixed future window or comparison against same-age commits.
- **Day from many commits.** Summing commit scores lets quantity back in;
  averaging rewards quiet days with one good commit; the maximum shows "the
  best thing made that day".
- **Merges.** Monorepo history is mostly linear; merge commits can be skipped
  and their parents scored.

## Combining

The scores are numbers per commit, so they can be shown separately (a switch
in the viewer that recolours the grid by each rule) or blended as a weighted
sum. Showing them side by side first is a cheap way to see which one matches
your sense of "this was the good work".

## Open questions

1. Which option (or which pair) should the first version compute?
2. Should a day's brightness be the sum, the average, or the maximum of its
   commits' scores?
3. Which folders and file types are left out of the count? (transcripts,
   generated HTML, images are the obvious first three)
4. How long a future does a commit get: everything since, or a fixed window?
5. The two reference screenshots (1.png, 2.png) are still loose in the
   project root: keep them in notes/ beside the vision, in assets/, or leave?
