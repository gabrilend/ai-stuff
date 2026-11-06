# 304 — The turn hook on each voice

phase 3, the relay through rmail

## Current behavior

Nothing exists. The owner: "the minicomputer's r-mail inbox will be set up
to have a hook script upon receive that executes a turn of the LLM
machinery".

## Intended behavior

Two small parts on each voice, described in `docs/datapath-round-trip.md`,
steps 3–4:

- **The turn hook**, set as both `on_receive` and `on_update`. It takes the
  canvas body as 302 does, writes it to `tmp/shared-memory/turn/waiting`
  (temporary name, then rename, replacing whatever was waiting), starts the
  turn runner in the background unless it is already running, prints
  nothing, and exits at once. `on_update` holds rmail up, and a turn takes
  minutes.
- **The turn runner**. It takes the lock (making a directory, which either
  succeeds or fails in one step, so two runners can never both hold it),
  then repeats: take the waiting canvas, run one turn, until nothing is
  waiting. Then it releases the lock and exits. A lock left behind by a
  runner that died is noticed by its recorded process number and cleared,
  with a log line.

In this phase, "run one turn" is a stand-in: a script that edits a few words
of the canvas from a scripted list, so phases 3 and 4 can be tested apart.
The real turn (405) replaces it through a setting, not by editing the runner.

## Suggested implementation steps

1. Hook, runner, lock, stale-lock check.
2. Tests: two canvases arriving during one turn (only the newest is used);
   a hook call while the runner is busy; a dead runner's lock.

## Related documents

- `docs/datapath-round-trip.md`
- `docs/datapath-voice-turn.md`, "One turn at a time"

## Blocked by

None.

## Blocks

305, 405, 704.
