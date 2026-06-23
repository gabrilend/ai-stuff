# Issue 10-051: Persistent Stage Timing Ring Buffer

## Current Behavior

`run.sh`'s pre-flight stage list shows hardcoded time estimates:

```
6.  generate-embeddings ⚠ (~2-3 hours)
7.  generate-similarity ⚠ (~30 min)
8.  generate-diversity ⚠ (~42 hours)
```

These are baked into the stage definitions and never adjust — they were
ballpark guesses from one operator's machine on one snapshot of the
pipeline. The actual wall-clock time per stage varies across machines
(GPU, CPU, disk speed, network) and across pipeline versions (a faster
embedding backend, a more efficient similarity engine, more poems in
the corpus all shift the numbers). The operator has no way to see
"how long did this stage take last time on THIS box."

After a run completes, the duration of each stage is not persisted.
Each invocation of `run.sh` starts from zero recorded history.

## Intended Behavior

Each stage's wall-clock duration is recorded to a project-local file
when the stage completes successfully. The file is a ring buffer:
each stage's section holds the last 5 timings, with the oldest entry
falling off when a sixth is recorded. The pre-flight stage list
displays the mean of those last-5 timings in place of (or in addition
to) the hardcoded estimate. First-run display falls back to the
hardcoded estimate, with a "(no history yet)" hint.

The file lives at the project root as `.stage-timings`, modelled on the
existing `.file-index-counter` convention (hidden, plain text, persists
across runs, gitignored because it is hardware-specific).

Format:

```
# Stage timing ring buffer. Each section holds the last 5 wall-clock
# durations (in seconds) for that stage. Oldest entry rolls off when a
# new one is appended. This file is hardware-specific — do not commit.

[update-words]
12
14
13
12
15

[extract]
85
82
89
91
86

[generate-embeddings]
8042
7891
8156
```

(Sections with fewer than 5 entries hold whatever has been recorded so
far — common for new stages or after a wipe.)

The pre-flight display becomes:

```
6.  generate-embeddings ⚠ (avg 2h 14m, last 3 runs)
7.  generate-similarity ⚠ (avg 28m, last 5 runs)
8.  generate-diversity ⚠ (no history yet — first-run estimate ~42h)
```

The hardcoded estimates stay in the code as the fallback for first
run / wiped-history cases, but real data overrides them when available.

## Suggested Implementation Steps

### Helpers (single new shell library)

1. Add `scripts/stage-timing.sh` (sourced by `run.sh`, not invoked
   directly). It exposes three functions:
   - `stage_timing_record <stage_name> <seconds>` — append a timing to
     the named section, evict the oldest if the section now has > 5
     entries, write the file back atomically (temp file + mv).
   - `stage_timing_mean <stage_name>` — print the integer mean of the
     section's entries, or empty if no entries exist.
   - `stage_timing_format_seconds <int>` — render seconds as e.g.
     `45s`, `12m 30s`, `2h 14m`, `1d 18h` for human-readable display.
2. The file location is a constant near the top of the library:
   `STAGE_TIMINGS_FILE="${DIR}/.stage-timings"`.
3. Parser is awk-based, not Lua or full INI: each section is a
   `[name]`-prefixed block, entries are bare integers until a blank
   line or the next `[name]`. Simple enough to read/write with awk in
   a one-shot pipeline.

### Stage instrumentation

4. Each existing `run_<stage>` function in `run.sh` (e.g.
   `run_extract`, `run_validate`, `run_generate_embeddings`) wraps
   its body with `local start_ts=$(date +%s)` at the top and a call
   to `stage_timing_record` at the bottom on success.
5. Failure paths (the stage errored out, or the operator Ctrl-Cs)
   do NOT record. A partial timing would skew the mean toward
   "fast" because it reflects "time-until-failure" not
   "time-to-complete." This means the recording call must be the
   last statement before the function returns success.
6. Stages that the operator skipped (`$EXTRACT=false`) are not
   instrumented at all — their `run_*` function never runs.

### Pre-flight display

7. Where `run.sh` currently builds the stage list (the block that
   prints `1. update-words`, `2. extract`, etc.), for each stage:
   - Call `stage_timing_mean <stage>`. If empty → show the existing
     hardcoded estimate with no qualifier change.
   - If non-empty → show `(avg <formatted>, last <count> runs)`
     instead of the hardcoded estimate.
8. The hardcoded estimates stay in the code as fallbacks AND as
   sanity-check sentinels: if the recorded mean is wildly off from
   the hardcoded estimate (e.g., off by 10×), a future linter or
   review could flag the estimate as out of date.

### Gitignore

9. Add `.stage-timings` to `.gitignore` so it does not get committed.
   The file's content is purely a function of the operator's hardware
   and how many times they have run the pipeline — useless to share.

### Ring-buffer semantics

10. The buffer size is a constant in the helper:
    `STAGE_TIMING_RING_SIZE=5`. Tuning options:
    - **Larger (10+)**: smoother mean, but slower to react to a real
      change (e.g., after a llama.cpp version bump that doubled the
      embedding throughput).
    - **Smaller (3)**: noisier mean, faster to track real changes.
    - 5 is the recommended balance.
11. When the recording function appends an entry and the section
    grows past the ring size, the oldest entries (top of the section)
    are removed until the section is at exactly `STAGE_TIMING_RING_SIZE`.

### Edge cases

12. Concurrent runs writing to `.stage-timings`: the atomic temp+mv
    write avoids torn files but does not prevent the LATER mv from
    clobbering changes the earlier process made. For a one-operator
    dev pipeline this is fine; if the project ever moves to a CI
    or shared-host model, the recording would need a file-lock.
13. Stages that finish in < 1 second: still record (`date +%s`
    rounds, so very fast stages appear as 0 or 1). Don't filter —
    a stage that ran "in essentially no time" is valid history.
14. File missing or unreadable: helper functions silently return
    empty (mean) / no-op (record). The pipeline always continues;
    timing is a nice-to-have, not a contract.

## Related Documents

Files this issue touches:
- `run.sh` — pre-flight stage list rendering; each `run_<stage>`
  function wrapped with timing capture.
- `scripts/stage-timing.sh` — new shell library, sourced by run.sh.
- `.gitignore` — add `.stage-timings`.
- `.stage-timings` — new file at project root (created on first
  successful stage completion).

Connected issues:
- This is independent of any other phase-10 ticket. The hardcoded
  estimates in `run.sh` were added incrementally as new stages
  landed; replacing them with measured data is purely additive.
- `issues/10-049-replace-ollama-with-llamacpp.md` doubled the embedding
  throughput (no Ollama overhead, larger usable batches via
  `/v1/embeddings`) — the hardcoded "~2-3 hours" estimate is therefore
  particularly stale right now. Adopting measured timings will make the
  improvement visible after the first end-to-end run on the new path.
- `issues/10-050-batched-embedding-generation-with-long-text-chunking.md`
  will further compress embedding-stage wall time. Same reasoning —
  measured timing will reflect each upgrade automatically.

## Risks

- **Outlier sensitivity.** A single anomalously-slow run (e.g., the
  operator was watching a video on the same GPU) pulls the 5-sample
  mean noticeably. Median over the 5 samples would be more robust,
  but mean is simpler to explain. Consider median if outliers become
  a UX problem.
- **First-run misleading.** When the file does not exist yet,
  every stage shows the hardcoded estimate. The operator might
  assume those are measured. The "(no history yet)" qualifier
  next to the hardcoded estimate addresses this explicitly.
- **Ring size choice.** 5 is mid-range. Switching to 10 later
  means the existing file's 5-entry sections stay valid (it just
  takes 5 more runs to fill them); switching to 3 means the
  helper has to truncate on read. Easier to start at 5 and grow
  than to shrink.
- **Format-evolution.** The plain-text section format is meant to
  be editable by hand. A future need (e.g., recording GPU type
  alongside the timing, so cross-machine comparisons make sense)
  would require a schema migration. Keeping the format minimal
  for now is the right call; a real migration can build on this.

## Expected Outcome

- The pre-flight stage list shows real measured durations on the
  operator's hardware, updated incrementally each run.
- The hardcoded "~2-3 hours" / "~30 min" / "~42 hours" estimates
  become fallbacks for first-run only.
- A new `scripts/stage-timing.sh` library exposes the three helper
  functions, sourced by `run.sh`.
- A `.stage-timings` file at the project root persists across
  runs (gitignored).
- Operators can see immediately whether a pipeline change made
  things faster or slower without reading the clock by hand.
