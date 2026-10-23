# Issue 10-075: Every Run Keeps a Log in RAM

## Current Behavior

A build's terminal output is kept nowhere unless it runs with `--debug`,
which reroutes all of `run.sh`'s output through `scripts/fsync-logger` into
`output/debug-logs/run.log` -- now inside the site folder in RAM (Issue
10-072), so it would be uploaded with the site and is cleared with it. A
normal run's messages exist only on the terminal. When the 2026-10-22 build
ran out of RAM, nothing recorded where or how it stopped.

Terminal output today comes from:
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
3. `run.sh` names the run's log, exports it, and writes its own banners to
   it with a one-line bash function that appends (the banners are the
   triage trail). Its `--debug` rerouting goes, and with it the log inside
   the site folder.
4. Replace `print()` / `io.write` in the pipeline's programs with `say`
   (`"both"` for messages, `"terminal"` for redrawn progress), one program
   at a time, the stages first.
5. Each program wraps its main in a handler that writes an error and its
   traceback to the log before exiting non-zero.
6. A test: a message said to "both" is on the terminal and in the log, one
   said to "terminal" only on the terminal, a failed log write is an error.

## Open Questions

1. The GPU library's C code prints about 146 lines itself (`printf`). Send
   them through the same log (a small C function that appends to the file
   named in `NEOCITIES_RUN_LOG`), or leave the C lines terminal-only?
2. `run.sh` is bash; its banners need an append to the log file. Is that
   one bash function acceptable, given "not through bash" meant not
   rerouting the whole terminal through bash?
3. How many old logs to keep in RAM: all until reboot, or the last N runs?

## Related Documents

- Issue 10-072: the site in RAM (where `--debug` logs now land)
- Issue 10-057: the memory budgeter (the RAM-full build that left no trace)
- `scripts/fsync-logger`, `libs/progress-display.lua`, `libs/utils.lua`

## Metadata

- **Status**: Open (waiting for the owner's next build to finish before code
  changes; three open questions)
- **Created**: 2026-10-23
- **Phase**: 10
