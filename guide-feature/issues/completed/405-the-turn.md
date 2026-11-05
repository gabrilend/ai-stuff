# 405 — The turn

phase 4, the turn

## Current behavior

The turn runner (304) runs a stand-in turn. The real pieces exist
separately (401–404).

## Intended behavior

The real turn, selected in `input/turn` in place of the stand-in: the seven
steps of `docs/datapath-voice-turn.md`. It reads the canvas, makes sure the
project clone matches (a no-op until 501), reads the endpoints, builds the
prompt, asks until it fits, and writes `outbox/canvas` with `base:` set to
the version it read. Before writing, the canvas is read back with the canvas
reader, so a voice can never send a canvas the blitter would refuse for its
form. The turn counter is kept on disk beside the mailbox.

First run in the rehearsal (305) on kuvalu, one voice, then all three.

## Suggested implementation steps

1. The turn, plugged into the runner through `input/turn`.
2. Run in the rehearsal and read every goodbye receipt.

## Related documents

- `docs/datapath-voice-turn.md`

## Blocked by

101, 102, 304, 305, 404.

## Blocks

406, 503, 704.

## Decisions (2026-11-05; each the owner's to overturn)

1. **A retrying turn keeps going when a newer canvas arrives**, as the
   owner said: "it will just keep spinning until it gets it right." Its
   canvas is then blitted onto the newer version, like any turn that
   crossed a version in the mail. The other way is one setting away:
   `newer-canvas = "give-way"` in `input/turn` makes the turn look for a
   waiting canvas before each new ask, and stop when one is there. It then
   writes nothing and exits 3. The runner counts `turns-gave-way`, sends
   nothing, keeps the turn number, and takes the newer canvas next. The
   first ask always goes out, so a voice under a steady stream of canvases
   still answers some of them.
2. **The turn is the program `input/turn-runner` names, and the project
   now names `scripts/turn`.** Phase 3's stand-in is still there. Phase
   3's demo and rehearsal test name it themselves, so they still show what
   phase 3 built.
3. **Each turn is a run of its own,** with its own log and receipt
   (`turn-<voice>`). The runner already runs each turn as its own process
   and keeps its own receipt of the run. The receipt holds the last turn's
   numbers, and the log keeps every turn's, one summary line each. Both
   name the endpoint (`endpoint-<name>` in the receipt, since receipts
   hold counts).
4. **The advisory note lives in `output/turn-note-<voice>`,** beside the
   turn counter. It is written when a turn's changes were over the
   recommendation and removed when they were not, so a note is never older
   than the last turn that fitted.
5. **The turn counter stays the runner's.** The runner already keeps it on
   disk beside the mailbox's project (`output/turn-counter-<voice>`), moves
   it on only for a canvas sent, and checks the turn's headers against
   it. The turn is told its number and writes it.
6. **The project clone is a logged no-op until 501:** "project NAME at
   COMMIT: the clone comes with issue 501; this turn works on the canvas
   alone."
7. **Exit 3 now means "gave way".** A turn that fails for any other reason
   exits 1. Phase 3's failing-turn test now exits 4.
8. **A clash between two files' C declarations was fixed.** The turn
   runner (038) and the model caller (046) each declared `clock_gettime`
   with a struct of their own, and a process loading both (the turn) took
   the first and refused the second's struct. Both now use the same name,
   `guide_timespec`.
9. **The stand-in model edits like a voice.** For tests and the demo,
   047's `rewrite` reply changes one word of the canvas it was shown, and
   every Nth reply runs past the edge. The rehearsal can then run the real
   turn end to end with real fit retries, and no model is installed here.

## What was built (2026-11-05)

- `src/055-turn.lua`, `scripts/turn`; `input/turn-runner` names it;
  `input/turn` gains `newer-canvas`.
- `until_fits` (051) takes `give_way`; the runner (038) counts exit 3 as
  `turns-gave-way`; the rehearsal (043) copies `input/turn` and
  `input/turn-instructions`; 049 gains `unruler`; 047 gains `rewrite`.
- Tests: `src/056-test-turn.lua` (37), including the rehearsal with the real
  turn in every voice and an endpoint switched with `scripts/use-endpoint`
  while it runs (402's last test).

## Needs the owner's machine

- Step 2 of the issue: the rehearsal against kuvalu's llama.cpp servers
  (401a), one voice and then all three, reading every goodbye receipt.
  Here it runs against the stand-in.
