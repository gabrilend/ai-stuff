# 10-058: Deterministic, Recorded Seeding for All Randomization

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: Medium
- **Type**: Feature / Reproducibility
- **Status**: Implemented — pending full-pipeline validation (2026-06-26). All six
  steps are coded and the word-cloud reproducibility is tested and passing
  (`scripts/test-seed-reproducibility.sh`: same seed => byte-identical page,
  different seed => different word order, seed stamped in the page). Seed precedence
  (CLI > config > auto) and the `output/generation-metadata.json` record are verified
  in `run.sh` via dry-run. NOT yet exercised on a real end-to-end run (the assistant
  cannot run the pipeline): (a) image-order reproducibility against live sources, and
  (b) the metadata round-trip on a true build. Run a full pipeline to close those.
- **Builds on**: 10-030 (image-source position randomization — already has a
  seeded RNG; this issue generalizes its pattern and its config field)
- **Mirrors**: 10-057 (which stamps `top_k` into cache metadata so a later run can
  detect what an earlier run did — the same "stamp the decision into the output"
  move this issue applies to the seed)

## Background / Why This Exists

A build that uses randomness is only reproducible if (a) the randomness flows from
a single known seed and (b) that seed is recorded somewhere durable. This project
satisfies neither today. The one randomizer that affects shipped pages — the
word-cloud shuffle — seeds itself from the wall clock (`os.time()`) and writes the
seed nowhere. So two consecutive builds produce different word clouds, and there is
no way to ask "which seed made *this* build?" after the fact.

Two questions framed this work:

1. *Can all randomization use one seed (config default, CLI flag preferred)?* Yes —
   the surface is small (see Current Behavior). The cross-thread hazard one would
   expect does **not** exist here: the effil HTML workers (`similarity_worker`,
   `diversity_worker`, `cached_diversity_worker` in `scripts/generate-html-parallel`)
   contain no `math.random`/`randomseed`/`shuffle` calls, and the GPU diversity C
   code (`libs/vulkan-compute/src/vk_diversity.c`) is deterministic. All randomness
   lives in single-process stages, so there is no shared mutable RNG stream to
   coordinate and no per-worker sub-seed derivation to design.

2. *Can we recover the seed a previous build used, even one made on older code?* No,
   and that is precisely the gap this issue closes going forward. The clock-seeded
   sites never recorded their seed; an old build's word cloud is unrecoverable. The
   sole exception is image ordering, where a per-source `random_seed` set explicitly
   in `config.lua` (via 10-030) is already durable. Old builds cannot be
   retrofitted; no future build will lose its seed again.

The auto-generate-and-record policy (below) is the chosen answer to "no seed
supplied": rather than refuse to run (the no-fallback default), the run invents a
seed, **records it**, and uses it — so even a build where the operator never thought
about seeding is reproducible after the fact.

## Current Behavior

- **Word-cloud shuffle (in scope, the one shipped-output randomizer):**
  `src/wordcloud-generator.lua` (~line 438) does a Fisher–Yates shuffle of the word
  list for visual variety, calling `math.randomseed(os.time())` **inside** the
  shuffle, every call. Run as its own single-threaded `luajit` process from `run.sh`
  (the word-cloud stage runner, ~line 1447). Two bugs follow from clock-seeding:
  - The seed is never recorded, so the shuffle is not reproducible.
  - `os.time()` has 1-second resolution, so two shuffle calls in the same second get
    the *same* seed and produce the *same* "random" order — re-seeding per call is
    both non-reproducible across runs and accidentally-correlated within a run.
- **Image ordering (in scope, already partly solved):** `src/image-manager.lua`
  (`create_seeded_rng`, ~line 296) is a self-contained linear-congruential RNG used
  for per-source image order; the per-source seed comes from `random_seed` in
  `config.lua`, threaded through `libs/sources-loader.lua`. Invoked from
  `src/main.lua`. Already seedable and recorded **when** a source sets `random_seed`,
  but falls back to system randomness when the field is absent, and is not tied to a
  single run-wide master seed.
- **Validation sampling (OUT OF SCOPE, by decision):**
  `src/validation-engine.lua` (~line 174) seeds from `os.time()` for spot-check pair
  sampling. It does not affect shipped pages; left unchanged.
- **No run record exists.** The pipeline writes no durable run/manifest file;
  "Goodbye!" is only a console print (`src/main.lua` ~923, `run.sh` ~1768). The
  `output/` tree holds artifacts (`wordcloud.html`, `similar/`, `media/`, …) but no
  top-level metadata describing the run. The recording sink this issue needs must
  therefore be **created**, not extended.
- **Stale user-facing doc (in scope):** `src/flat-html-generator.lua` (~3228–3231)
  adds text to the explore-math HTML page claiming the diversity walk "is shuffled
  first with a Fisher–Yates pass … re-seeded from the clock on each build." That
  described the CPU diversity engine deleted in `745ce6a9`; the GPU replacement is
  deterministic. The page now misdescribes the algorithm to readers.

## Intended Behavior

### One master seed, resolved by precedence

A single integer master seed governs every randomization site in a run, resolved in
`run.sh` with this precedence (highest wins):

1. **CLI flag** — `--seed N` (preferred; overrides config).
2. **Config default** — a `seed` field in `config.lua` (proposed under a
   `randomization` table), used when the flag is absent.
3. **Auto-generate** — when neither is supplied, the run **invents** a seed and
   records it (next section). The auto-seed need only be unique-ish and recorded, not
   cryptographic; mixing `os.time()` with the process id avoids same-second
   collisions between back-to-back runs.

The resolved seed is passed to each randomizing subprocess as a CLI argument, the
same way `--words` already flows from `run.sh` to `src/wordcloud-generator.lua`. No
shared global RNG, no inter-process coordination — each single-process stage receives
the seed and seeds **once** at startup (not per shuffle call).

### Record the resolved seed (the half that answers "which seed?")

Recording is the point of the feature, mirroring how 10-057 stamps `top_k` into cache
metadata. The resolved seed is written to all of:

- **A durable run record** — a small JSON in `output/` (new; e.g.
  `output/generation-metadata.json`) holding at least `{ seed, generated_at, pages,
  poems_per_page }`. This is the canonical "which seed made this build?" answer and
  the natural home for future run-level facts.
- **The artifact that consumed it** — the word-cloud page's metadata block
  (`src/wordcloud-generator.lua` already assembles one ~line 543), so the seed
  travels with the page it shuffled.
- **The console/run log** — echo the resolved seed (already tee'd to `run.log`), so
  transcripts and live runs show it.

### Seed the sites from the master seed

- **Word-cloud shuffle:** seed once from the master seed at process start; remove the
  per-call `math.randomseed(os.time())`. Identical seed ⇒ identical word order.
- **Image ordering:** when a source has no explicit `random_seed`, derive its seed
  deterministically from the master seed (e.g. master combined with a stable
  per-source key) instead of falling back to system randomness, so image order is
  reproducible by default. An explicit per-source `random_seed` still wins (it is a
  deliberate override, like `--seed` over config).

### Fix the stale diversity doc

Rewrite the explore-math page text (`src/flat-html-generator.lua` ~3228–3231) to
describe the **deterministic** GPU diversity walk: no shuffle, no clock, same walk
every build. The page should no longer reference Fisher–Yates or clock re-seeding.

## Design Decisions To Settle Before Building

- **Config shape**: confirm the field name/location — proposed `config.randomization
  .seed` (nil ⇒ auto-generate). A `randomization` table leaves room for future knobs.
- **Seed type/range**: LuaJIT `math.randomseed` takes a number; standardize on a
  non-negative integer (e.g. 32-bit) so it round-trips cleanly through CLI args, JSON,
  and the page metadata.
- **Run-record filename**: `output/generation-metadata.json` vs. folding the seed into
  an existing per-stage output. Recommendation: a dedicated run record, since none
  exists and other run-level facts will want the same home.
- **Image-seed derivation**: the exact rule for combining the master seed with a
  per-source key when no explicit `random_seed` is set (must be stable across runs and
  independent of source iteration order).

## Suggested Implementation Steps

1. **Resolve + record in `run.sh`**: add `--seed N`; read `config.randomization.seed`;
   when both absent, auto-generate. Write the durable run record in `output/`, echo the
   seed to the log, and export/pass the seed to the randomizing subprocess(es).
2. **Word-cloud site** (`src/wordcloud-generator.lua`): accept the seed (CLI arg),
   `math.randomseed` it **once** at startup, delete the per-call clock seeding, and add
   the seed to the page metadata block.
3. **Image-ordering site** (`src/image-manager.lua` + `libs/sources-loader.lua`): when a
   source lacks `random_seed`, derive it from the master seed; keep an explicit
   per-source seed as an override. Generalizes the 10-030 pattern.
4. **Stale doc fix** (`src/flat-html-generator.lua` ~3228–3231): rewrite the
   explore-math diversity text to describe the deterministic GPU walk.
5. **Reproducibility test**: a small script that runs the word-cloud stage twice with a
   fixed `--seed` and asserts the two shuffled outputs are byte-identical, and once more
   with a different seed asserting they differ — proving the seed actually governs the
   order. (Tests are cheap; this validates the whole point of the issue.)
6. **Validator, not hard-coded claims**: extend the test/validator to read back the seed
   from `output/generation-metadata.json` and confirm it matches the seed the run was
   given, closing the "which seed?" loop end to end.

## Out of Scope

- `src/validation-engine.lua` sampling (by decision): a check, not shipped output; left
  clock-seeded.
- Any randomness inside the effil HTML workers or the GPU diversity/similarity C code —
  there is none; confirmed deterministic.

## Related Documents / Tools

- `src/wordcloud-generator.lua` — the word shuffle (primary site) and its page-metadata
  block.
- `src/image-manager.lua` (`create_seeded_rng`), `libs/sources-loader.lua` — the
  existing seeded image-order path from 10-030 that this issue generalizes.
- `run.sh` — seed resolution (CLI > config > auto), the run record, and the per-stage
  subprocess runners that receive the seed.
- `src/flat-html-generator.lua` (~3228–3231) — the stale explore-math diversity text to
  correct.
- `config.lua` — proposed `randomization.seed` field.
- `scripts/generate-html-parallel`, `libs/vulkan-compute/src/vk_diversity.c` — verified
  RNG-free; documented here so a future reader does not re-investigate the
  "randomness across threads?" question.
- Issue 10-030 (image randomization, completed), Issue 10-057 (the metadata-stamp
  pattern this mirrors).
