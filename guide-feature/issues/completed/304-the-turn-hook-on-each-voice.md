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

## Decisions (2026-11-05; each the owner's to overturn)

1. **The turn folder is per voice: `tmp/shared-memory/turn/<voice>/`.**
   The voice is the `name` in the config of the mailbox the canvas arrived
   in (the hook finds it from the inbox path rmail gives). On a fg-sora
   machine there is one voice and this is one more folder level; on
   kuvalu, in the rehearsal (305), three voices share one project without
   sharing a lock or a waiting canvas. The docs say `turn/<voice>/waiting`
   now.
2. **The lock is a directory put in place by a rename, not made by
   `mkdir`.** The directory is made under another name with `pid` already
   in it and then renamed onto `lock`; both are one step, but `mkdir`
   leaves a moment when the lock exists with no number in it, which
   another runner could take for a dead runner's. Letting go moves the
   lock aside before removing it, so `lock` is never an empty directory,
   which a rename would replace.
3. **A lock records the process's start time beside its number**, from
   `/proc/<pid>/stat`. A number the system has since given to another
   process then reads as not running, so a runner that died long ago
   cannot block its voice for ever. Where there is no `/proc`, the number
   alone is used.
4. **A dead runner's lock is cleared by the next runner, not by the
   hook.** The hook only reads the lock (to decide whether to start a
   runner); the runner clears it, logs `cleared a lock left by process N,
   which is not running`, and takes it. One place changes the lock.
5. **After letting go, the runner looks for a waiting canvas once more**
   and takes the lock again if one is there. A canvas whose hook saw the
   lock held just before it was let go would otherwise wait until the next
   one arrived.
6. **The runner is started with `setsid`, its input and output on
   /dev/null.** rmail reads `on_update`'s output to its end, so a runner
   holding that output would hold rmail up for the whole turn; the test
   for this fails twenty ways when the redirection is taken out.
7. **The canvas is taken only from the `guide` contact**, named in
   `input/turn-runner`, which the hook reads too. A `the-canvas` from
   anyone else is logged and left alone.
8. **The turn is a program, named by `turn` in `input/turn-runner`,**
   called as `<turn> --dir ROOT --voice NAME --turn N --canvas FILE --out
   FILE`. 405 puts the real turn in that setting. The runner reads back
   what it wrote and checks voice, turn, base and size, so a wrong turn
   program cannot send kuvalu a canvas it would refuse.
9. **The turn number grows only when a canvas is sent**, and is kept on
   disk in `output/turn-counter-<voice>` (the project's output folder, not
   the mailbox, which is rmail's). An unchanged or failed turn keeps its
   number, so kuvalu's `turns-skipped` counts only canvases lost on the
   way.
10. **A turn that changed no row sends nothing.** The voice's living
    message keeps its last canvas, which kuvalu has already blitted.
11. **The stand-in writes one word a turn into the voice's own third of
    the canvas, a row lower each turn**, from `words` in
    `input/stand-in-turn`, and waits `seconds` (2 in the file) as a model
    would. Three voices then rarely cut each other's words, but do when a
    word is longer than its third allows or rows wrap round, so cuts still
    happen in a long rehearsal.
12. **Each step is a line in `turn/<voice>/events`** with the time to the
    millisecond (received, replaced, taken, sent, unchanged, failed,
    refused, busy), for the rehearsal's timings, besides the human log
    lines.
13. **No timeout on a turn here.** The stand-in cannot hang; the real
    turn's time limits belong to 405 (asking until it fits).

## Implementation notes (2026-11-05)

- `src/037-turn-hook.lua` (`scripts/turn-hook`), `src/038-turn-runner.lua`
  (`scripts/turn-runner`), `src/039-stand-in-turn.lua`
  (`scripts/stand-in-turn`); `input/turn-runner`, `input/stand-in-turn`.
- `src/040-test-turn.lua`: 59 pass, every hook called through the voice
  mailbox's own config line, as rmail calls it.
- Mutation checks, 20, were each caught but one: the runner's last look
  for a waiting canvas after letting go of the lock (decision 5). The
  moment it guards is a few microseconds wide; a test cannot place a
  hook call inside it without changing the runner to let it.
- `docs/datapath-round-trip.md` steps 3–4 and the table of what lives
  where, `docs/datapath-voice-turn.md` ("One turn at a time", "What the
  turn counts"). `.file-index-counter` is at 040.

**Needs the owner's machine:** the hook under a real rmail daemon on each
fg-sora (702, 704), where `on_update` holds the daemon up for as long as
the hook runs. The rehearsal (305) runs it under a stand-in carrier.

## Note (2026-11-05, issue 305)

Two changes from the rehearsal:

- **The turn hook reads rmail's `-from-<sender>` inbox names too** (see
  302's note).
- **The stand-in no longer repeats itself (decision 11).** Its rows and
  words come round again (every 12 turns with 6 rows and 4 words), and a
  turn that writes a word already there sends nothing and keeps its
  number. So a long rehearsal stopped changing the canvas. The stand-in
  now writes the next word in the list that is not already there. A turn
  is unchanged only when every word is. `src/040-test-turn.lua` has 61
  passing tests.
