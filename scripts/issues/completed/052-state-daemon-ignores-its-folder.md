# Issue 052: state-daemon.sh ignores the folder it is given

## Status
- **Priority**: High
- **Type**: Bug fix
- **Status**: Completed
- **Created**: 2026-11-03

## Current Behavior

`state-daemon.sh DIR start` reports "Daemon started", but nothing can reach
it: `state-daemon.sh DIR set a 1` answers `ERR:daemon_not_running`.

`start` runs the daemon as a new copy of the script (`bash "$0" _daemon`)
and does not pass DIR on. The daemon falls back on `$STATE_DAEMON_DIR` or
`/tmp/state-daemon`, while every client command looks in DIR. If that
default folder does not exist, `mkfifo` fails. The read loop then retries
the missing pipe with no pause, writing an error line to `DIR/daemon.log`
many times a second for as long as the process lives. `start` checks only
that the process is alive after half a second, so it reports success.

Found while looking at `state-daemon.sh` for issue 014's interactive mode.

## Intended Behavior

- The daemon runs in the folder it was started for.
- A daemon that cannot make its request pipe logs why and exits.
- `start` reports success only once the daemon is listening: its request
  pipe exists and its PID file names it. Otherwise it reports failure, exits
  1 and stops the process.

## Suggested Implementation Steps

1. Pass the folder to the daemon (`STATE_DAEMON_DIR="$DIR"` on its command).
2. Exit the daemon when `mkfifo` or `chmod` on the request pipe fails.
3. In `start_daemon`, wait up to two seconds for the pipe and the PID file.
4. A test that runs a daemon in a temp folder.

## What Happened

**2026-11-03.** All four steps are done in `state-daemon.sh`. Tested by
`tests/test-state-daemon.sh` (21 checks). It starts a daemon in a temp
folder, runs every command, restarts the daemon to check state survives,
then starts one in a folder where the pipe cannot be made. Against the old
script 18 of the 21 checks fail, and the run leaves four daemons spinning;
the test now stops any daemon it started when it exits.

Decisions:

- **The folder goes through the environment** (`STATE_DAEMON_DIR`) and not
  as a first argument. The daemon then reads it exactly as it reads a folder
  set by the user, and the `_daemon` command line stays the same.
- **"Started" means listening.** A live process is not enough, because the
  bug was a live process that could not listen. Two seconds is the limit,
  checked every tenth of a second.
- **A failed start kills the process it started**, so no half-started daemon
  is left behind.
