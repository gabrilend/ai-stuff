# 502 — Running acceptance

Running an issue's Acceptance commands in the design folder
([007](../docs/007-datapath-the-design.md), *acceptance*).

## Current Behavior

Nothing runs a design's checks.

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
