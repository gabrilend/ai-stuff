# 502 — Running acceptance

Running an issue's Acceptance commands in the design folder
([007](../docs/007-datapath-the-design.md), *acceptance*).

## Current Behavior

Built as `src/049-acceptance.lua`. Finding the exit status of a command that itself ends with `exit` showed a flaw in the one shell-capture function everything uses: its status marker came after the command in the same shell and was skipped. `fs.capture` now runs the command in a subshell and returns the status number as a third value; acceptance reads 124 or 137 as "stopped at the limit". Checked by tests/052 (a failing second command named with its output; a sleep stopped at a 1 s limit).

## Intended Behavior

- **Accept** (case, issue): runs each command with `bash -c`, working in
  `design/`, under `timeout` (setting, default 120 seconds), capturing
  standard output and error together into `turns/…` of the most recent build
  or repair turn for that issue (`acceptance.txt`); returns pass or the first
  failing command with its output's last 60 lines.
- Commands run one at a time, in the order written; the first failure stops
  the issue's run.

## Suggested Implementation Steps

1. **Test:** a fixture design where one issue's commands pass and another's
   second command fails; the failure names that command and carries its output.
2. **Test:** a command that sleeps past the limit fails as a timeout.

## Blocked by

- 403
- 501
