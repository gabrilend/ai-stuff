# Issue 10-075: Every Run Keeps a Log in RAM

## Current Behavior

**Built 2026-10-23 (all steps).**
- `libs/output.lua`: `say(text, where)` with where "terminal", "log" or
  "both"; `stage(name, event)` writes a stage's start or end to the log
  only; `guard(name, main, ...)` runs a program's main and logs its start,
  its end, or the error and traceback that stopped it. Every log line is
  stamped with the time; a log that cannot be opened or written is an
  error.
- `utils.log_info` / `log_warn` / `log_error` go to both.
- `run.sh` names the run's log `tmp/shared-memory/logs/run-<started>.log`,
  prints its path once, and exports it (`NEOCITIES_RUN_LOG`); its banners
  stay terminal-only and are marked as a refactor target. `--debug` keeps
  its disk copy for freezes that need a power-off, moved from
  `output/debug-logs/` (inside the site, so it would have been uploaded) to
  `logs/debug/`.
- The build's programs run their main through `guard`: `src/main.lua`,
  `generate-word-pages`, `wordcloud-generator`, `generate-source-browser`,
  `generate-gallery-pages`, `augment-embeddings-with-images`,
  `semantic-color-calculator`, `similarity-engine`, and by hand
  `poem-extractor`, `poem-validator`, `image-manager`.
- The GPU library: `vkc_say` in `libs/vulkan-compute/src/vk_compute.c`
  (with `VKC_SAY` / `VKC_SAY_ERR`) prints a line and appends it, stamped,
  to the run's log; its 99 message lines go through it, the progress bar
  does not. Run on its own (no `NEOCITIES_RUN_LOG`) it prints only.
- `scripts/run-tests` gives the tests the run's log, or one shared log of
  their own when run by hand.
- Tests: `libs/output.test.lua` (11 checks: each place, the stamp, the two
  refusals, a stopping error in the log, the helpers).
- The programs' own `print()` calls go through `output.print` (print's
  behaviour, plus the log): 864 calls in 54 files, converted by a tool that
  changes only a `print(` starting a statement. Each is written
  `require("output").print(...)`, so the page workers' thread code needs
  nothing from outside its thread. Seven standalone scripts that set no
  library path gained one line pointing at `libs/`.
- Terminal only, on purpose: help and usage text, progress redraws
  (`io.write`), the tests' own output (the runner keeps each test's log), and
  the few inline Lua snippets inside `run.sh`.

**Before:** Terminal output today comes from:
- `utils.log_info` / `log_warn` / `log_error` (`libs/utils.lua`), the shared
  message helpers;
- about 885 `print()` calls and 116 `io.write` / `io.stderr:write` calls
  across `src/`, `libs/` and `scripts/` (count again with
  `grep -c 'print(' src/*.lua libs/*.lua scripts/*.lua`);
- the progress bars (`libs/progress-display.lua`; in C,
  `vkc_progress_update` in `libs/vulkan-compute/src/vk_compute.c`);
- about 146 `printf` calls in the GPU library's C code;
- `run.sh`'s own banners and messages (`log_stage`, `log_info`, `echo`).

## Intended Behavior

Owner, 2026-10-23: "we should not do it through bash, but rather in the
lua. We don't have to write progress bar updates to the log. Anytime we
would output something to the terminal, pass it through a function with a
'logged' value (just a 0 or 1 or whatever) and either write it to the log,
or the terminal, or both. Easy."

- One output function in Lua, `say(text, where)`: `where` says terminal,
  log, or both. Every message a program prints goes through it.
- The log is one file per run in RAM, `tmp/shared-memory/logs/run-<date>-<time>.log`,
  named by `run.sh` at the start of the run and handed to every stage in an
  environment variable, so every stage of one run appends to one file. A
  program run on its own (no run.sh) starts its own log the same way.
- Progress-bar redraws go to the terminal only; a stage's start and end
  lines, messages, warnings and errors go to both. A Lua error that stops a
  program is written to the log before the program exits.
- The terminal keeps working as it does today: the bars still animate,
  because nothing reroutes the terminal.

## Suggested Implementation Steps

1. `libs/output.lua`: `say(text, where)` with `where` one of
   `"terminal"`, `"log"`, `"both"`; the log file from the environment
   (`NEOCITIES_RUN_LOG`), else a new one in `tmp/shared-memory/logs/`;
   each log line stamped with the time; a write to the log that fails is an
   error (a log that silently stops is worse than none).
2. `utils.log_info` / `log_warn` / `log_error` go through `say(..., "both")`.
3. `run.sh` names the run's log after the moment the run started
   (`run-2026-10-23_14-05-09.log`) and exports it; its own banners stay as
   they are, terminal only (owner, 2026-10-23: "leave them as-is, and in the
   lua when we would pass to the next stage, write it just to the log and
   not the terminal. Maybe also mark it as a potential refactor target.").
   So each Lua stage, as it starts and as it ends, writes a line naming
   itself to the log only. The banners are marked in `run.sh` as a refactor
   target: the stage sequence could move into Lua, where they would go
   through `say` like everything else. Its `--debug` rerouting goes, and
   with it the log inside the site folder.
4. Replace `print()` / `io.write` in the pipeline's programs with `say`
   (`"both"` for messages, `"terminal"` for redrawn progress), one program
   at a time, the stages first.
5. Each program wraps its main in a handler that writes an error and its
   traceback to the log before exiting non-zero.
6. A test: a message said to "both" is on the terminal and in the log, one
   said to "terminal" only on the terminal, a failed log write is an error.

## Answered Questions

- The GPU library's C output (about 66 error lines, 25 status lines, its
  progress bar): errors and status lines into the log through one small C
  function that appends to the file named in `NEOCITIES_RUN_LOG`, the bar
  terminal-only (owner, 2026-10-23: "yes").

- `run.sh`'s banners: left as they are; each Lua stage logs its start and
  end to the log only; the banners are a refactor target (owner, quoted in
  step 3).
- Old logs: "However many, until a reboot. Name them with the date / time
  that the run started." Kept in RAM, so a reboot clears them.

## Related Documents

- Issue 10-072: the site in RAM (where `--debug` logs now land)
- Issue 10-057: the memory budgeter (the RAM-full build that left no trace)
- `scripts/fsync-logger`, `libs/progress-display.lua`, `libs/utils.lua`

## Metadata

- **Status**: Completed 2026-10-23
- **Created**: 2026-10-23
- **Phase**: 10
