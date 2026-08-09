# 10-067: Split `src/` Into One Directory Per Pipeline Stage

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: Medium
- **Type**: Restructuring
- **Status**: OPEN — not started. The feasibility report at the end is scaffolding:
  prune each section as its claim stops being news, so that what remains is
  always a description of the code as it is.
- **Created**: 2026-08-08

## Summary

`src/` is a flat directory of 43 Lua files. Nothing in the layout says which part
of the pipeline a file belongs to, so answering "what runs during stage 7?"
means reading `run.sh` and following requires by hand.

This issue gives each of the ten pipeline stages its own directory, named for the
stage number and nothing else: `src/1/`, `src/2/`, … `src/10/`. A file used by
more than one stage goes to the **earliest** stage that needs it.

Note the numbering is the DATA-FLOW stage, not the project phase. Phase numbers
group functionality by when it was built; stage numbers group it by where the
poems are in their journey. A file written in phase 8 can belong to stage 3.

## Current Behavior

- 43 `.lua` files sit flat in `src/`, 1.3 MB total. One subdirectory exists
  (`src/html-generator/`), grouping by component rather than stage.
- Which stage a file serves is discoverable only by tracing `run.sh`'s dispatch
  into each stage function and following `require` chains from there.
- Tests sit beside the code they test, in the same flat namespace, under three
  different naming conventions (`X.test.lua`, `test-X.lua`, `X-test.lua`).
- Some files serve no stage at all and are only reachable from their own tests or
  from a standalone menu; see Issue 10-060, which tracks those separately.

## Intended Behavior

```
src/
  1/   update-words          2/   extract           3/   parse
  4/   validate              5/   catalog-images    6/   embeddings
  7/   similarity            8/   diversity         9/   html
  10/  wordcloud
```

A reader who wants to know what stage 6 does lists `src/6/`. A reader who wants
to know what stage 6 depends on looks at which other directories its files
`require` from — and each such reach is visible as a path, rather than being
invisible as it is now.

Two rules govern placement:

1. **Earliest stage wins.** A module used by stages 6 and 9 lives in `src/6/`.
   The later stage reaches backward, which is legible; a module in stage 9 that
   stage 6 needs would be a reach forward, which is not.
2. **Tests follow their subject** into the same directory.

## The Value, Stated Plainly

The win is not tidiness. It is that a cross-stage dependency becomes **visible as
a path**. Today `generate-word-pages.lua` requiring `flat-html-generator.lua` is
one unremarkable line among many; after the split it reads as stage 10 reaching
into stage 9, and the reader immediately knows that stage 9 cannot be changed
without considering stage 10. That is the encapsulation the request is really
after: not walls, but honest labelling of every wall-crossing.

## Suggested Implementation Steps

1. Produce the stage assignment for all 43 files, resolving each multi-stage file
   by the earliest-stage rule. The report below is a first pass, not the answer.
2. Decide the shared-module question (report §3) — it is the one decision that
   changes the shape of the result, so settle it before moving anything.
3. Move files in dependency order, deepest-shared first, one stage per commit, so
   a regression bisects to a single stage.
4. After each move, update `package.path` entries and every `require` that names
   the moved module. `src/` is currently on the path as a flat directory; each
   new subdirectory needs to be reachable, or requires need directory-qualified
   names (`require("6.similarity-engine")`).
5. Update the shell callers. `run.sh`, `generate-embeddings.sh` and `scripts/*`
   name `src/<file>.lua` paths directly, including inside inline `luajit -e`
   blocks — those are string literals no Lua tooling will catch.
6. Re-run the pipeline stage by stage after each move. A broken `require` in a
   stage nobody ran that day is exactly the failure this project has been bitten
   by before (see Issue 10-054's history).

## Relevant Files

- `run.sh` — stage dispatch; the authority on which entry point belongs to which
  stage, and a caller that hardcodes `src/` paths
- `generate-embeddings.sh` — requires `similarity-engine` from inline Lua
- `src/main.lua` — the entry point for four separate stages; see report §2
- `src/flat-html-generator.lua` — 224 KB, required by six modules; see report §3
- Issue 10-060 — dead code, some of which need not be moved at all

---

# Feasibility Report (prune as it becomes obsolete)

Measured 2026-08-08. Every claim here is checkable with the command beside it.

## §1 — Scale

| Quantity | Value |
|---|---|
| Files in `src/` (flat) | 43 `.lua` |
| Total size | 1.3 MB |
| Largest | `flat-html-generator.lua`, 224 KB |
| Existing subdirectory | `src/html-generator/` (groups by component, not stage) |
| Test files | ~11, in three naming conventions |

## §2 — The hard case: `main.lua` is four stages in one file

`src/main.lua` dispatches on mode (`src/main.lua:945-952`):

| Mode | Stage |
|---|---|
| `parse_only` | 3 |
| `validate_only` | 4 |
| `catalog_only` | 5 |
| `html_only` | 9 |

The earliest-stage rule puts it in `src/3/`. Stages 4, 5 and 9 then invoke their
entry point out of stage 3's directory — technically fine, and it would be
*honest*, since that is genuinely what happens today. But it means three of the
ten directories do not contain their own entry point, which is the one thing a
reader will most expect to find there.

The alternative is splitting `main.lua` into four thin entry points over shared
internals. That is a bigger change than this issue proposes and would want its
own issue. **This is the decision that most shapes the outcome, and it is not
mine to make.**

## §3 — Shared modules and where the earliest-stage rule sends them

Measured dependency edges:

| Module | Required by | Earliest stage | Consequence |
|---|---|---|---|
| `flat-html-generator.lua` (224 KB) | `main.lua`, `wordcloud-generator.lua`, `generate-word-pages.lua`, `regenerate-clean-site.lua`, 2 tests | 9 | stage 10 reaches back into 9 |
| `poem-bars.lua` | `flat-html-generator.lua`, `generate-word-pages.lua` | 9 | same reach |
| `image-pseudo-embeddings.lua` | `augment-embeddings-with-images.lua` (6.7), `generate-gallery-pages.lua` (9) | 6 | stage 9 reaches back into 6 |
| `image-render.lua` | `flat-html-generator.lua` only | 9 | clean |
| `validation-engine.lua` | 3 modules | 4 | check callers before assuming |

`flat-html-generator.lua` is the structural problem in miniature: at 224 KB it is
17% of `src/` by size, it is required by six modules, and the word-cloud stage
depends on it. Whatever directory it lands in becomes a hub the tree reaches into
from elsewhere. Splitting the file itself is out of scope here but worth its own
issue — the fact that stage 10's page generator needs stage 9's HTML generator
may be a real coupling worth breaking rather than merely labelling.

## §4 — What breaks, and why the compiler will not tell you

Lua resolves `require` at runtime against `package.path`. Moving a file breaks
nothing until the moment that line executes. There is no build step to catch it.
Three categories, in ascending order of how easy they are to miss:

1. **Lua `require` calls** — greppable, mechanical.
2. **Shell paths naming `src/<file>.lua`** — `run.sh`, `generate-embeddings.sh`,
   `scripts/*`. Greppable, but they are strings, so nothing verifies them.
3. **Inline `luajit -e` blocks inside `.sh` files** — Lua source inside shell
   string literals, setting their own `package.path`. This is the category that
   has bitten this project before: Issue 10-054 records an audit that missed
   writers because they built paths into a variable first, and Issue 10-060
   records a file deleted as dead that a shell script was requiring.

The mitigation is running each stage after each move, not reading harder.

## §5 — Interaction with other open work

- **Issue 10-060 (dead code)** — three functions and one whole file are already
  marked `[DEPRECATED / DEAD CODE / PRUNE CANDIDATE]`. Prune before splitting and
  there is less to place; split first and dead code gets a stage number it does
  not deserve. **Recommend 10-060 lands first.**
- **Issue 10-065 (explicit CLI values)** — touches `run.sh` heavily. Both issues
  edit the same stage-dispatch region, so sequencing them avoids a merge tangle.
- **Issue 10-066 (word-page size)** — will likely change `generate-word-pages.lua`
  substantially. Cheaper to move a file once, after it settles.

## §6 — Honest assessment

The mechanical part is straightforward and the risk is concentrated in one place:
runtime `require` resolution with no compile-time check, in a codebase where
shell scripts embed Lua as strings. That is manageable with per-stage commits and
a real run after each.

The genuinely open question is §2 — whether `main.lua` is placed by the rule and
three directories go without an entry point, or whether it is split first. Every
other decision follows from that one.

## Open Questions

1. **`main.lua`**: place it in `src/3/` by the earliest-stage rule, or split it
   into four entry points first? (§2)
2. **Stages 6.5, 6.7 and 6b** — semantic colours, image augmentation, word
   embeddings — are sub-stages of 6 in `run.sh`'s dispatch, not stages of their
   own. Do they fold into `src/6/`, or does the directory scheme grow to match
   what the pipeline actually runs?
3. **`libs/`** is untouched by this proposal, but contains pipeline-specific code
   (`inference-server-config`, `progress-display`, `runtime-overrides`). Does the
   stage scheme extend there, or does `libs/` stay the home for
   stage-independent code?
4. **Tests**: follow their subject into the stage directory, or gather into one
   `src/tests/`? Following the subject is assumed above; it also means the three
   existing naming conventions become visible side by side, which may be worth
   settling at the same time.
