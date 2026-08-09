# 10-065: `run.sh` Demands Every Value — No Defaults, No Config Fallbacks

## Status
- **Phase**: 10
- **Priority**: High
- **Type**: Design change (breaking CLI change)
- **Status**: IN PROGRESS — the implementation is in place and verified (see
  Verification). Questions 1–9 were worked through and are answered below, each
  keeping the reasoning it was chosen over. Questions 10–13 surfaced during that
  pass and are unanswered, so the issue is not finished. The "Current Behavior"
  section describes the state this issue started from, not the state today.
- **Created**: 2026-08-07
- **Builds on**: 10-005 (the original CLI flag foundation, which introduced the
  defaults this issue removes)

## Summary

The orchestrator currently guesses. When a value is absent from the command line
it reaches for a hardcoded number, or for `config.lua`, or for a number it
invents at runtime. Each of those guesses is invisible in the output, so two runs
typed the same way can produce different websites and nothing in the log says
why.

This issue removes every guess from `run.sh`. A value the pipeline consumes must
arrive on the command line. When one is absent the script does not run and does
not stop at the first omission — it collects every missing value for the stages
that were actually selected and prints them together, so one run of the script
tells the operator the complete command they should have typed.

## Current Behavior

### Values that are silently invented

Each row is a value some stage consumes. "Where the guess comes from" is what
happens today when the flag is absent.

| Value | Flag | Where the guess comes from |
|---|---|---|
| Worker thread count | `--threads` | Literal `8` inside the similarity stage; absent entirely for HTML, where the child program picks its own |
| Pages per poem | `--pages` | `config.pagination.minimum_pages` |
| Poems per similar/different page | `--poems-per-page` | `config.pagination.poems_per_page` |
| Poems per chronological page | `--chrono-per-page` | Flag omitted from the child's argument list; child picks its own |
| Word-cloud word count | `--wordcloud-words` | Flag omitted; child picks its own |
| Poems per word-cloud page | `--wordcloud-poems` | Flag omitted; child picks its own |
| Master randomization seed | `--seed` | `config.randomization.seed`, and failing that a number mixed from the clock and the process id |
| Embedding model | `--model` | `config.lua`, via the server entry's `model` field |
| Inference server | `--server` | `config.default_inference_server` |
| Include reblogged posts | (see below) | `config.privacy.include_boosts` |

The seed is the clearest illustration of the cost. Three tiers of guess sit
behind it, and the third one *manufactures a value that has never existed
before*. The build is recorded afterward, so it can be reproduced in hindsight —
but the operator who typed the command did not choose it and could not have
predicted it.

### Behaviors that continue after failing

Four stages print a warning and carry on, leaving a half-built site that the
next stage treats as finished:

- input-file sync failure — "continuing anyway"
- word-embedding generation failure — "continuing"
- image-gallery generation failure — "continuing"
- source-browser generation failure — "continuing"

The semantic-colour step has a fifth variant: when the embeddings file is
absent it logs at verbose level only and returns success, so a run with
`--verbose` off reports a clean pipeline having skipped a stage entirely.

### Fallbacks in the supporting machinery

- The interactive menu library, when absent, is replaced by a different and much
  older interactive mode.
- The stage-timing library, when absent, is replaced by a stub that runs the
  stage and records nothing.
- The colour-palette fingerprint reads `color_names` and `color_associations`
  with an empty-table stand-in, so an empty palette fingerprints identically to a
  missing one and the cache is never noticed as stale.
- The embedding-completeness check reads the poem list as "the `poems` field, or
  else the whole document", so a change in that file's shape is absorbed rather
  than reported.

### A duplicate branch that disables a flag

`--include-boosts` appears twice in the argument parser. Bash `case` takes the
first match, so the second branch is unreachable: passing `--include-boosts`
sets the value forwarded to the *parse* stage but never the one read by the
*extraction* stage. The flag is half-connected, and has been since the two
mechanisms were added independently.

### Absent values are reported one at a time

Where a check exists at all it exits at the first problem. An operator missing
four values discovers them across four runs.

### `--dry-run` deletes files

Found while testing this issue, and fixed as part of it because it is the same
shape of problem: a stage doing something the operator did not ask for.

Two stages clear their output directory before rebuilding it, and in both the
`rm` sat **above** the `if $DRY_RUN` early-return. So `--dry-run` performed the
deletion and then printed what it "would" do:

- word-cloud stage — clears every per-word page on every run, so `--dry-run`
  alone was enough. Confirmed live: it removed 7,176 files, about 11 GB.
- HTML stage — clears the similar/different/chronological pages, but only under
  `--force`, so it needed both flags and was correspondingly rarer.

The rule the fix encodes: any destructive step in a stage function belongs below
the dry-run check, and the dry-run branch should *announce* the deletion.

## Intended Behavior

### Every consumed value is supplied

For the stages selected on this run, every value listed in the table above must
be present. Absent ones are collected and reported together:

```
can't run generation script, missing these flags:

  --threads N              # parallel workers                (stages 7, 9)
  --pages N                # pages generated per poem        (stages 7, 8, 9)
  --poems-per-page N       # poems per similar/different page (stages 7, 8, 9)
  --seed N                 # master randomization seed       (stages 5, 10)

Every value the pipeline consumes must be given explicitly.
run.sh has no defaults and reads no fallbacks from config.lua.
```

Two properties matter and are worth stating plainly:

- **Requirements follow the selected stages.** `--validate` alone demands
  nothing. `--stage 10` demands the word-cloud values and the seed, and does not
  demand the thread count. Demanding values a run will never read would train the
  operator to type noise.
- **The report is complete.** Collection continues past the first absence. One
  run yields the full list.

### On/off flags stay presence-flags

`--force`, `--verbose`, `--quiet`, `--dry-run`, `--debug`, `--low-priority`:
absent means off. Nothing is consulted to decide that — absence *is* the value,
which is what separates these from the table above. They are not defaults and are
not required.

The single exception is reblogged posts, whose absence currently means "ask
`config.lua`". It becomes `--boosts yes|no`, required by the extraction and parse
stages, and the duplicate parser branch is deleted.

### Assets and output directories keep a derived default

`--dir` and `--output` remain optional. Both derive from the project root when
absent, and that derivation happens **once**, into a variable that every path in
the script is then built from. This is a stated default rather than a fallback:
it is computed in one place, printed where relevant, and — unlike today — the
flags are honoured everywhere `run.sh` reads or writes, instead of reaching one
line each while the surrounding code uses hardcoded paths.

### Failure ends the run

The four "continuing anyway" paths, the silent semantic-colour skip, and the two
library stand-ins all become hard errors naming what was absent and what to do
about it.

## Measurements Behind the Design

Gathered on the development machine on 2026-08-07; re-measure with `du -sh`,
`free -h`, and `findmnt -t tmpfs` rather than trusting these numbers later.

| Quantity | Value |
|---|---|
| `output/` total | 16 GB |
| — `wordcloud/` | 11 GB across 7,176 pages (~1.6 MB each, near-uniform) |
| — `different/` | 1.6 GB across 15,954 pages |
| — `media/` | 2.2 GB |
| `/dev/shm` capacity / already used | 15.5 GB / 3.9 GB |
| `/tmp` capacity | 15.5 GB |
| System RAM | 31 GB |

This is why `output/` keeps a disk default. It does not fit in the RAM-backed
filesystems, and would not leave room for the pipeline's own working set even if
it did. `--output PATH` is the mechanism for pointing a single build at a
RAM-backed directory deliberately — which is exactly what wiring the flag
through the whole script makes possible.

## Suggested Implementation Steps

1. Add a collector: a list of absent values, a function that records one
   (flag spelling, placeholder, short reason, stage numbers), and a reporter that
   prints the block above and exits non-zero. Report and exit once, after all
   checks have run.
2. Express the stage-to-value mapping as a table rather than a chain of
   conditionals, so a new stage declares what it needs in one line.
3. Run the check **after** the interactive menu has populated its values, so both
   entry paths meet the same requirement. Menu checkboxes always hold a definite
   state; blank menu text fields surface in the report exactly as absent flags do.
4. Move embedding-model resolution and seed resolution to after that check. Both
   currently run early and would otherwise consult `config.lua` before the script
   has established that the operator supplied the values.
5. Delete the guesses: the literal thread count, the two pagination
   `or config` expressions, the seed's config and auto tiers, the model resolver,
   and every conditional that omitted a flag from a child's argument list. Pass
   each value unconditionally.
6. Resolve the assets and output directories once, into variables, and rebuild
   every path in the script from them.
7. Replace the four "continuing anyway" handlers, the silent semantic-colour
   skip, and the two library stand-ins with hard errors.
8. Unify the reblog flag into `--boosts yes|no` and delete the unreachable
   duplicate branch.
9. Reject a flag whose value is absent or is itself another flag, so
   `--threads --pages 5` is an error rather than a thread count of `--pages`.
10. Update the help text: mark required values, delete every "(default: …)"
    parenthetical, and correct the model description (see the first open question).
11. Move every destructive step in a stage function below that stage's dry-run
    check, and have the dry-run branch announce the deletion instead.
12. Verify with `--dry-run` that each stage's child command line now carries every
    value, and that omitting values produces one complete report.

## Verification

Run these; they are cheap and they cover each property the issue claims.

| Command | Expected |
|---|---|
| `./run.sh --generate-html` | Reports 5 absent values, all marked stage 9 |
| `./run.sh --full` | Reports all 10, with multi-stage attributions |
| `./run.sh --stage 5` | Reports `--seed` only |
| `./run.sh --validate --dry-run` | Runs; requires nothing |
| `./run.sh --generate-html --threads --pages 5` | Rejects `--pages` as a value for `--threads` |
| `./run.sh --stage 5 --seed abc` | Rejects a non-integer seed; exits 1 |
| `./run.sh --stage 2 --boosts maybe` | Rejects an answer that is neither yes nor no |
| `./run.sh --stage 2 --stage 3 --boosts no --dry-run` | `--no-boosts` appears on **both** child command lines |
| `./run.sh --stage 10 ... --dry-run` | Announces the page clear; deletes nothing (check the file count before and after) |
| `./run.sh --stage 5 --seed 0 --dry-run` | Seed `0` is accepted, not mistaken for "unset" |
| `./run.sh --stage 9 ... --model <typo>` | Names the model, lists the ones with embeddings on disk |
| `./run.sh --validate --dry-run` then `ls tmp/shared-memory/cache/embeddings/` | No stray `similarities/` at the root: a stage needing no model creates no cache dirs |
| `./run.sh --stage 9 ... --model <typo>` then `cat output/generation-metadata.json` | The previous record is restored; the failed run does not replace it |
| `./scripts/list-inference-choices "$PWD" --models` | Lists every model any configured server can serve |
| `luajit src/generate-gallery-pages.lua "$PWD" --dir "$PWD/assets"` | Runs; the project root is not replaced by the assets path |

## Relevant Files

Modified:

- `run.sh` — the requirement gate, the removals, the dry-run ordering fixes
- `scripts/update` — learned `--no-boosts`, so run.sh can state the negative
  rather than stay silent and rely on this script's own default
- `libs/inference-server-config.lua` — `get_selected_server()` reads the run
  notepad (question 2)
- `src/generate-gallery-pages.lua`, `src/wordcloud-generator.lua`,
  `src/generate-word-pages.lua` — parsers consume `--dir PATH` as a pair
  (question 5)

Added:

- `scripts/list-inference-choices` — reads the server and model names out of
  `config.lua` so the menu can offer them as pick-lists (question 6)

Read, not modified:

- `libs/runtime-overrides.lua`, `scripts/write-run-overrides` — the per-run
  notepad; already generic over key/value pairs, so recording `--server`
  alongside `--model` needed no change here
- `scripts/cache-dir` — maps a model name to its cache directories; needs no server
- `libs/utils.lua` — `init_assets_root` priority (CLI → config → project default)
  and `embeddings_dir` (always RAM since 10-054)
- `.stage-timings` — the measured durations that replaced the written-down ones
- `config.lua` — sections that stop being consulted by `run.sh`: `pagination`,
  `randomization`, `privacy.include_boosts`, `default_inference_server`

## Open Questions

Answered ones keep their reasoning: the answer is only useful alongside what it
was chosen over.

### 1. `--model` validation — ANSWERED: check the disk, stages 9 and 10

The help text promised a check against the server's `available_models` that the
library deliberately does not perform, and documents why (the server is the only
authority on what is loaded; a second authority drifts). The text was corrected.

Investigating it reframed the question. That reasoning only covers stage 6.
Stages 7–10 use `--model` purely as a **cache directory name** and never contact
a server, so no authority exists to reject a typo. Stages 7 and 8 happen to be
covered anyway — they hard-error when `embeddings.json` is absent. Stages 9 and
10 had no such check.

Demonstrated: `--model qwen3-embedding:4B` (capital B) created a real, empty
`assets/embeddings/qwen3-embedding_4B/` beside the real one, indistinguishable
from a model whose embeddings had simply not been generated yet.

Resolved by giving stages 9 and 10 the check stages 7 and 8 already had, via a
shared `require_embeddings_for_model`. It validates against what is on disk —
the real authority for a cache-reading stage — and lists the model directories
that *do* have embeddings, so a typo is visible by comparison. The
`available_models` list stays what its own comment says it is: documentation.

### 2. `--server` reach — ANSWERED: the notepad resolves it

The gap was larger than first described. A server entry carries
`embedding_prompt_prefix`, the text prepended to every input before embedding, so
**the server choice selects an embedding space, not merely an endpoint**. And the
divergence happened *inside a single stage*: `run.sh` passed `--server` to the
poem-embedding step, while `src/generate-word-pages.lua` — which has no
`--server` flag — resolved `config.default_inference_server`. The word pages then
ranked words against poems by cosine similarity across two different spaces.

Resolved in `libs/inference-server-config.lua`: `get_selected_server()` now reads
the run notepad, mirroring what `get_selected_model()` already did. One change
covers every child, including those that parse no `--server` and those not yet
written. Precedence is in-process `set_selected_server()` → notepad →
`config.default_inference_server`, and a notepad name that does not resolve is a
hard error rather than a fall-through, on the same reasoning as a typoed
`--server`. Verified live: `generate-word-pages.lua` reached
`http://192.168.0.115:10265` (the `gpu-server` given to run.sh) where it would
previously have reached `local` at 192.168.1.100.

### 3. Similarity freshness check — ANSWERED: count the embeddings

The check compared the similarity-file count against the literal `7797`. Two
things were wrong with it, and the second is why no constant could work.

It was already stale: there is one similarity file per EMBEDDING, and the
embedding set includes the image pseudo-embeddings folded in by stage 6.7
(Issue 9-013) — 8,701 against 8,050 poems when measured. A run that died after
7,900 files therefore cleared the threshold and was called complete, leaving
~800 entries with no similarity data for the HTML stage to build pages from.

And it goes stale continuously: the corpus grows whenever a poem is written.

This is the same defect Issue 10-050 fixed one stage earlier, where an mtime
comparison called an interrupted `embeddings.json` fresh. The lesson it recorded
— "counting entries is the honest signal" — had simply not been carried into
stage 7. It now counts the embeddings with the same one-line grep, over a file
the stage is about to read in full anyway, and logs the shortfall when the cache
is incomplete instead of skipping in silence.

### 4. Word pages are 11 GB — SPLIT OUT to issue 10-066

Could not be answered here: the pages had been deleted by the `--dry-run` bug
above, so there was none to dissect. What was established is recorded in 10-066,
including the fact that the obvious arithmetic does not reach 1.6 MB (a
surviving chronological page is 12 KB for 7 poems, so 50 poems should be ~85 KB)
and that a search of `generate-word-pages.lua` found no embedded script,
datalist or index to explain the rest. The "shared payload" guess in the original
wording is **unverified and currently unsupported**.

### 5. `--dir` reach — ANSWERED: pass it everywhere it is understood

Measured rather than assumed: `--dir` reached exactly one of eight child
programs. `main.lua` received it; `generate-gallery-pages.lua`,
`wordcloud-generator.lua` and `generate-word-pages.lua` all parse it via
`init_assets_root(arg)` but were never given it;
`generate-source-browser.lua` and `augment-embeddings-with-images.lua` resolve
their own way; and the inline `luajit -e` blocks called
`init_assets_root({'$DIR'})` — a bare positional, which `parse_assets_dir`
discards, so they fell through to `M.DIR .. "/assets"`.

Resolved by passing `$ASSETS_ARG` to the three that understand it and giving the
inline blocks `{'--dir', '$ASSETS_DIR'}`.

**This introduced a regression, which is worth recording because the shape
recurs.** Those children's parsers skipped an unknown FLAG but not its VALUE,
and their next branch claims any token not starting with `-` as the positional
project directory. So the assets path became the project root, and
`package.path` — built from that root — no longer found the program's own
libraries. Fixed by teaching each parser to consume `--dir PATH` as a pair.

The general hazard remains and is worth knowing: in those parsers, any
value-taking flag a child does not recognise will have its value captured as the
project root. Nothing in run.sh currently does that, but a future flag could.

### 6. Interactive menu — ANSWERED, and the premise was wrong

The claim that a model name could not be typed into a menu field was incorrect.
Two different parsers are involved: `lua-menu.sh`'s `menu_add_item` uses
`${value%%:*}` (first colon, lossy) but only for a field's INITIAL value, while
the runtime parser in `menu.lua` uses `"^(.+):(%d+)$"` — last colon, and only
when followed by digits. Every name in this project's config survives it intact:
`qwen3-embedding:4b`, `embeddinggemma-300m`, `nomic-embed-text-v1.5`,
`gpu-server`. Only a value ending in `:<digits>` would be truncated.

Resolved better than "add text fields": the model and server became **pick-lists
built at menu-build time from config.lua**, via the new
`scripts/list-inference-choices`. A list cannot be mistyped, and because the
entries are read from the config rather than written into run.sh, adding a
server or model to the config makes it appear in the menu with no code change —
a hand-maintained copy would have been exactly the second source of truth this
issue exists to remove. The seed stays a typed field, deliberately empty: any
non-negative integer is equally valid, and pre-filling one would be the
auto-generated seed wearing a menu.

### 7. What a build records about itself — ANSWERED: everything the gate required

The record covered the seed, pages and poems-per-page only. That gap was paid in
full: after the word-cloud pages were lost, nothing in the build's own artifacts
said which `--wordcloud-words`, `--wordcloud-poems` or `--chrono-per-page` had
produced them, so two thirds of the site could not be reproduced from its own
record.

It now writes every value the requirement gate asked for, driven by the same
table — a record key is the fifth column of each row, so adding a flag makes it
required, explained, and recorded in one edit rather than three. Only values the
run actually needed are written; a run with no `--server` does not claim one.

Known limitation, stated rather than hidden: the file is replaced, not merged.
`output/` can hold pages from several runs, and a replaced record then describes
only the most recent. Merging would be more truthful and needs a JSON reader
this shell script does not have.

### 8. The accidental seed — ANSWERED: decide at the next build

The current `output/` was built under seed `747235867` with
`"seed_source": "auto-generated"` — the removed third tier, caught in the act.
Deliberately left alone. `--seed` is required from here on, so whatever is typed
next becomes the deliberate, recorded value.

### 9. When the build record is written — ANSWERED: write early, roll back on failure

Surfaced while implementing question 7. The record is written BEFORE the stages
run, so that an interrupted build still leaves its parameters behind — and the
cost of that showed up immediately: a mistyped `--model`, caught by the new
stage-9 check, had already replaced a record describing a real build with one
describing nothing.

Resolved without giving up either property. The record about to be replaced is
copied into the RAM tier first, and an EXIT trap puts it back when the run exits
non-zero. An interrupted build still leaves its parameters; a failed build leaves
the previous record intact. If the cache copy itself cannot be made, the write is
refused rather than performed irreversibly.

Note the interaction with an interrupt: `cleanup_on_interrupt` exits 130, so
Ctrl-C now restores the previous record too. That is the instructed behaviour and
it is defensible — an interrupted build's parameters are still on the command
line the operator typed — but it is a deliberate narrowing of the original
"written early so an interrupted build leaves it" rationale.

## Open Questions

### 10. What clears `/dev/shm` — ANSWERED: logging out, not rebooting

Between 2026-08-07 ~16:00 and 2026-08-08 08:15 the RAM tier was emptied while
`/tmp` survived intact, on a machine with two days of uptime.

The cause is `elogind`, which runs here as a runit service. Its config at
`/etc/elogind/logind.conf:42` reads `#RemoveIPC=yes` — commented out, so the
compiled-in default of `yes` applies. `RemoveIPC` deletes every IPC object a user
owns when that user's **last login session ends**, and POSIX shared memory — the
contents of `/dev/shm` — is such an object. `/tmp` is not, which is exactly why
the exec tier survived while the shared-memory tier did not.

Every observation fits: no reboot, `/dev/shm` emptied, `/tmp` intact, both
user-owned project directories gone, no `tmpfiles.d` rule, no cron entry.

Confirmed to the point of being actionable rather than proven by experiment — the
remaining check would be whether lingering is enabled for the user, and that was
deliberately not pursued. The mechanism is documented behaviour and the evidence
is consistent.

**Why it matters beyond curiosity:** the code described the RAM tier as "wiped on
reboot". A reboot is rare; closing the last terminal is not. Anything living
there should be assumed gone by tomorrow. The comments in `libs/utils.lua`
(`embeddings_dir`) and `run.sh`'s help text were corrected to say so.

The design itself holds: these caches are regenerable, the rebuild is about 20
minutes per `.stage-timings`, and the one artifact deliberately kept on disk —
the diversity cache — survived exactly as intended.

### 11. The unreachable disk caches — ANSWERED: reverse 10-054 and reach them

First the correction that changed the question. Those files are not sediment
from an abandoned model. `config.default_inference_server` is `local`, whose
`model` is `nomic-embed-text-v1.5` — so this is **the configured default model's
cache**, and it is nearly complete:

| | |
|---|---|
| `assets/embeddings/nomic-embed-text-v1.5/` | 4.4 GB total |
| — `similarities/` | 3.8 GB, 9,054 files |
| — `similarity_rankings_cache.json` | 414 MB |
| — `embeddings.json` | 109 MB, **7,904** entries against 8,050 poems |
| — `word_embeddings.json` | 99 MB |
| — `diversity_cache.json` | 2.1 MB (the only file current code could read) |

The 4.4 GB figure also corrects an earlier undercount in this issue of "109 MB".

Resolved by reversing Issue 10-054: `utils.embeddings_dir()` returns the disk
path again, so all of it is live. The reasoning is question 10's finding, not
disk-vs-RAM preference — 10-054 traded durability for SSD write endurance
believing it was giving up survival across a *reboot*, and what it was actually
giving up was survival across a *logout*. A ~20-minute rebuild per session, to
avoid roughly 4 GB of writes per full regeneration, is the wrong side of that
trade.

Worth recording as a design observation: **the reversal was one line.** 10-054's
real work was routing every reader and every writer of a movable cache through
one function — the part its own history shows failing twice before it stuck. That
centralization is what let the decision it encoded be revisited cheaply when the
facts changed. `embeddings_dir_disk()` was kept as a separate function even
though it now returns the same path, because the distinction it marks — which
caches must never be volatile — is the record that made the reversal safe to
reason about.

Verified: stage 9 no longer errors for the default model; stage 7 reports its
cache fresh at 9,054/7,904; stage 6 correctly reports embeddings incomplete at
7,904/8,050 and would run incrementally to close the gap. Each stage checks its
own input-to-output relationship, which is why two different "incomplete"
answers here are both right.

A note the operator should keep: the corpus is 146 poems ahead of the embeddings.
Stage 6 will fill that gap on the next run and stages 7-10 will then need
regenerating behind it.

### 12. Auto-seeds in the child programs — ANSWERED: already settled by 10-058

Two survive, and neither is an oversight. Issue 10-058 decided both, deliberately
and in writing, before this issue existed.

`src/wordcloud-generator.lua` invents a seed when run directly, prints it, and
says how to reproduce it. That is 10-058's stated policy, quoted from it: the
auto-generate-and-record answer to "no seed supplied" is chosen *"rather than
refuse to run (the no-fallback default)"*, so that even a build where the
operator never thought about seeding is reproducible after the fact. It cannot
fire through the pipeline, because run.sh now always passes `--seed`.

`src/validation-engine.lua` (~line 174) seeds from the clock before sampling
pairs. 10-058 names this file and rules it **out of scope by decision**: *"a
check, not shipped output; left clock-seeded."*

Recorded rather than changed. The rule this issue enforces is about values that
reach the published site; both of these were examined by the issue that owns
seeding and consciously left as they are. Reversing another issue's stated
decision because it looks like the pattern being removed here would be
overreach — the distinction 10-058 draws (shipped output versus a diagnostic
check, announced versus silent) is a real one.

Worth knowing for anyone re-opening this: 10-058's recording design has three
sinks, and the second one is doing more work than the first. The seed is stamped
into the word-cloud page itself, so every archived cloud in `archive/wordclouds/`
carries its own seed in an HTML comment and is independently reproducible. The
canonical record it points at, `output/generation-metadata.json`, is replaced
every build and therefore describes only the most recent one.

### Follow-on for 10-058, not this issue

A seed reproduces word ORDER, not the CORPUS. Replaying an archived cloud's seed
today shuffles today's poems, not the vocabulary that build drew from — nothing
records which `poems.json` a given cloud was built against. 10-058 is still open
("Implemented — pending full-pipeline validation") and is the right home for
that. Two of its own items also remain unvalidated on a real run: image-order
reproducibility against live sources, and the metadata round-trip.

### 13. Stage duration estimates were wrong by orders of magnitude — RESOLVED, but note the pattern

Not a question so much as a caution worth keeping. The help text advertised
"~2-3 hours" for a stage measuring ~10 minutes, "~30 min" for one measuring ~17
seconds, and "~42 hours" for one measuring ~40 minutes — while carrying a
contradictory "~1 min" for that same stage in its own banner. All of them were
removed in favour of the measured averages the script already records and
already prints. The pattern to watch for: a number written into a comment has no
mechanism that makes it wrong loudly.

## Related Issues

- **10-005** — introduced the CLI flags and the defaults removed here. Its
  "Default Behavior" section is stale in a second way: it documents "no stage
  flags runs all stages", which a later change had already replaced with an
  error.
- **10-058** — introduced the master seed and its three-tier resolution; the
  lower two tiers are removed here, and the recording it added is kept.
- **10-016** — per-stage force flags; unaffected (presence-flags).
- **10-017** — inference server selection; source of open question 2.
- **10-054** — moved regenerable caches to RAM; source of the measurements above.
- **10-064** — adds `--reverse`. When implemented it must declare which stages
  require it in the table from step 2.
