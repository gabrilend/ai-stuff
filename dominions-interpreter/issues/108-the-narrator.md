# 108 — The narrator

| | |
|---|---|
| Phase | 1 — The Reading |
| Blocks | nothing, and everything benefits |
| Blocked by | [101](101-the-input-gate.md) |
| Related docs | [architecture](../docs/architecture.md) |

## Current behavior

Nothing in the project says what it is doing. There is no log, no place for one
to go, and no convention for what belongs in it.

Note the name. This is the module that reports **what the program is doing**.
The one that writes prose about the game is the herald, in phase 6, and the two
must not be confused — mixing a debug log into a narrative surface is how a
person listening to a story hears a stack trace.

## Intended behavior

One module. Everything that wants to say something says it here, and here
decides where it goes.

### Where it goes

`tmp/shared-memory/`, which is a symlink into `/dev/shm/dominions-interpreter`,
which is guaranteed RAM. Logs are ephemeral by nature and writing them to a
spinning disk is a cost paid for nothing.

The directory is created if absent, by whatever is about to write, every time —
because `/dev/shm` does not survive a reboot and a run script that assumes it
does will fail on the first cold morning.

### In sentences

Log lines are sentences a person can read, not tagged key-value pairs.

    read 118 savegames, 94 of them started, in 0.4 seconds
    december-woes is on turn 35, written by 6.36, with 6 mods
    late_pangaea.2h: found 47 records at stride 210+name, 11% of the file placed
    refusing to start: door cluster-two at 192.168.1.42:8080 did not answer

The reason is not style. This project's logs will be read by somebody trying to
find out why a turn came out wrong, possibly through a screen reader, possibly
weeks later. A line that requires knowing the codebase to interpret is a line
that will be skipped.

### Levels, and the house rule about warnings

Three: what happened, what is worrying, and what stopped.

The middle one carries the house rule that makes it worth having. **A fallback
is a warning, and a warning is an error.** Any code path that substitutes a
default for something it could not read announces itself here, by name, every
time — and an issue file is opened for it. There is no quiet degradation in
this project, and the log is where that promise is kept or broken.

### Timing

Every operation that takes more than an instant reports how long it took, in
seconds, in the same sentence as what it did.

Cheap to add now, and the thing that will be wanted most once three machines
are involved and the question becomes which of them is slow.

## Suggested implementation steps

1. Resolve the log directory from the input gate's project directory, create it
   if absent, and fail loudly if it cannot be created.
2. Open the log append-only and flush every line, so a run can be followed with
   `tail -f` while it happens.
3. Write to standard error as well as to the file when the program is
   interactive, since a person watching a survey wants to see it move.
4. Provide the three levels, and make the warning level take a reason string
   that is not optional.
5. Add a timer helper that returns elapsed seconds, so the timing convention is
   easy enough to follow that it gets followed.
6. Tests: a line written is a line readable; the directory is created when
   missing; a warning without a reason is a programming error and fails at the
   call site rather than logging an empty string.
7. Write the accompanying information file.

## Relevant files

- `tmp/` and `tmp/shared-memory/`, the two RAM tiers
- the run script, which must ensure both exist before anything writes

## Open questions

- Should the log be part of the chronicle, or separate? Currently separate: the
  chronicle is a record of the game and the log is a record of the program, and
  merging them would put stack traces in a history somebody might one day read
  for pleasure. But a turn that went wrong is a place where both matter at once.
