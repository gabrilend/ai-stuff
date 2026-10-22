# Issue 10-074: Every Batch Step Runs In Parallel

## Current Behavior

Owner, 2026-10-22: "we want both. If the other 'worker queue'
implementations aren't running in parallel, then we need to update them to
do so." Both means: every page passes through the one worker queue
(`run_page_workers` in `src/flat-html-generator.lua`), and every batch of
independent items is processed in parallel (worker threads on the CPU, or
batches on the GPU), per the house rule "never ever do batch processing on a
single thread".

Survey of the `run.sh` stages, 2026-10-22. Times are the last recorded runs
in `.stage-timings` (read them with the plan view, `./run.sh --dry-run`);
"how" is what the step does with its items today.

| stage | time (last / average) | how | parallel today? |
|---|---|---|---|
| 8 diversity walks | 3059 s / 3106 s; **84 s** measured after the fix below | GPU, batches of 3,584 walks | yes (GPU). The time was not parallelism: every walk went all 9,265 steps and 99 were kept. Fixed 2026-10-22 (step 7) |
| 6 embeddings | 9 s / 428 s | batched requests to the inference server (GPU) | yes (Issue 10-050) |
| 9 pages (similar, different, chronological) | 282 s / 104 s | worker pool | yes |
| 10 word cloud + word pages | 56 s / 152 s | one thread, one word after another | **no**: Issue 10-035 |
| download zip | 113 s | one `zip` process over the site and source | **no** |
| 5 picture catalog | 115 s / 107 s | one picture at a time, four helper programs each (two `stat`, `identify`, `md5sum`) in `src/image-manager.lua` | **no** |
| 7 similarity | 20 s / 27 s | GPU, all pairs at once | yes |
| 6.7 pictures folded into the embeddings | 25 s / 21 s | one thread (`src/augment-embeddings-with-images.lua`) | **no** |
| 2 extraction | 17 s / 16 s | one extractor after another, each one thread | **no** |
| 6b semantic colours | 13 s / 13 s | one thread | **no** |
| 9 gallery pages, source browser | inside stage 9's time | one thread each (`src/generate-gallery-pages.lua`, `src/generate-source-browser.lua`) | **no**, and not through the worker queue |
| page check | inside the build | `scripts/validate-output --jobs N` | yes |
| 1 update, 3 parse, 4 validate | 10 s, 3 s, 1 s | small | -- |

## Intended Behavior

- Every page the site serves is drawn by a worker job: similar, different,
  chronological, word (10-035), gallery and source-browser pages.
- Every step that handles many independent items hands them to workers (or
  to the GPU in one batch); the main program only plans, hands out jobs and
  collects results.
- The thread count is the build's one `--threads` value, passed to every
  step (it already governs pages and the page check).

## Suggested Implementation Steps

1. Word pages: Issue 10-035 (centre once, rank on the GPU, draw as worker
   jobs).
2. Picture catalog: the per-picture facts (size, date, dimensions, hash) for
   all pictures at once -- one `stat` and one `md5sum` call over a list of
   files, `identify` over a list, split across `--threads` processes -- in
   place of four programs started per picture. Same catalog out, checked by
   comparing the old and new catalog files.
3. Gallery pages and source browser: page jobs in the worker queue.
4. Pictures folded into the embeddings, semantic colours: measure where the
   time goes first; each is one pass over all items, and may be one GPU
   batch (colours: every poem against seven anchors is a small table of dot
   products) or worker threads.
5. Extraction: the four extractors are independent of each other and can
   run at once.
6. Download zip: measure compression against reading; a parallel compressor,
   or writing the zip without compression (the site's pictures are already
   compressed), whichever is the cost.
7. **Diversity walks (done 2026-10-22).** Issue 9-014's tiling, pipelining
   and half-precision storage were already built (June). The cost was the
   walk length: the GPU walked every poem (9,265 steps) and
   `scripts/precompute-diversity-sequences-gpu` kept the first 99. Now
   `compute_all_diversity_sequences_batched` takes `max_steps` and stops each
   walk at the K the pages show (pages x poems per page). A greedy walk's
   first K steps do not depend on its length: all 9,266 walks matched the
   full-length cache on their first 99 poems, in 84 s instead of 3,046 s.
   The walk keeps its own poem plus K (it kept K in all, so every poem's last
   "different" page was one poem short). The wrapper also gained `--model`
   and `--output PATH` (try the step without replacing the cache), passed
   through the environment because its Lua runs inline and never received
   arguments (its `--save-binary` never worked). Pinned by
   `libs/vk-diversity-walk-length.test.lua`.

Each step: a before/after check that its output is unchanged, and the
stage's time from `.stage-timings` before and after.

## Related Documents

- Issue 10-035: parallel word pages (step 1)
- Issue 8-058: one page drawer, one worker queue
- Issue 9-014: diversity shader memory pattern (built in June; completed)
- Issue 10-050: batched embedding requests (already parallel)
- `scripts/stage-timing.sh`, `.stage-timings`: where the times come from

## Metadata

- **Status**: Open
- **Created**: 2026-10-22
- **Phase**: 10
