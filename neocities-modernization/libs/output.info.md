# output.lua

Everything a program says goes through here: to the terminal, the run's
log, or both (Issue 10-075). The log is one file per run in RAM,
`tmp/shared-memory/logs/run-<started>.log`, named by `run.sh` and handed to
every stage in `NEOCITIES_RUN_LOG`; a program run on its own starts its own.
Every log line is stamped with the time.

## Functions

| function | takes | does |
| --- | --- | --- |
| `say(text, where)` | a string; `"terminal"`, `"log"` or `"both"` (required) | prints and/or appends it; an unknown place or a log that cannot be written is an error |
| `stage(name, event)` | a program's name, `"start"` / `"end"` | a line in the log only |
| `guard(name, main, ...)` | a name, the program's main function and its arguments | logs the start, runs main, logs the end; an error that stops main is logged with its traceback, then raised again |
| `path()` | -- | the run's log file |

The rule: messages, warnings and errors to `"both"`; a progress bar's
redraws to `"terminal"`; a stage's start and end to the log (run.sh prints
its own banners). The GPU library's C code has the same, `vkc_say`.

## Test

`libs/output.test.lua`
