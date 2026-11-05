# 406 — Phase 4 demo: three real turns per version

phase 4, the turn

## Current behavior

Phase 3's demo shows stand-in turns through rmail once 306 is done.

## Intended behavior

`issues/completed/demos/phase-4-demo` runs the rehearsal with the real turn
on all three stand-in voices, against kuvalu's llama.cpp server, and shows:

- the canvas changing, with marks, in the terminal;
- per turn: words changed against the recommendation, fit tries and why;
- per voice and endpoint: seconds and tokens per turn;
- a role switched to another endpoint halfway through with
  `scripts/use-endpoint`, and the switch visible in the numbers.

## Suggested implementation steps

1. The run script.
2. Fill in `issues/phase-4-progress.md`.

## Related documents

- `docs/roadmap.md`, phase 4

## Blocked by

402, 405.

## Blocks

None.

## Decisions (2026-11-05; each the owner's to overturn)

1. **The demo runs against two stand-in llama.cpp servers on 127.0.0.1,**
   not kuvalu's. Nothing is installed here, and 401a's servers are not up
   yet. The stand-ins answer llama-server's routes, and their model edits
   like a voice (047's `rewrite`): one word a turn, from its own words, so
   the canvas shows which model wrote what. Now and then a reply runs past
   the edge, so the fit check sends it back. The run against kuvalu's
   servers is for the owner's machine.
2. **Two models that differ, so the switch shows.** `stand-in-a` answers
   in 0.2 s and runs past the edge every third request. `stand-in-b`
   answers in 0.6 s, every second request. Every voice starts on `a`;
   halfway through, `scripts/use-endpoint fg-sora-2 stand-in-b` runs on
   the workspace's `endpoints` (kuvalu's file). fg-sora-2's turns from the
   next version on ask `b`, and its seconds and tries per turn change in
   the per-voice-and-endpoint table.
3. **Every number is read from the turns' own logs and receipts,** never
   kept by the demo itself. The test checks the demo's output against
   them.
4. **One minute by default** (`--minutes M` for longer). Phase 3's demo
   follows `input/rehearsal`. That file's 30-second timers suit real
   rmail; this demo uses the same file, and a minute shows several turns
   per voice at the rehearsal's own pace only when the timers are short.
   So the owner may want `--minutes 5` with the default timers.
5. **The demo sets the real turn in its copy,** whatever the project's
   `input/turn-runner` says, as phase 3's demo sets the stand-in.

## What was built (2026-11-05)

- `issues/completed/demos/phase-4-demo` and `phase-4-demo.lua`, offered by
  `./run-phase-demo 4`.
- `src/057-test-phase-4-demo.lua`.
- `issues/phase-4-progress.md` filled in.

## Needs the owner's machine

- The same demo against kuvalu's llama.cpp servers (401a) and a real
  outside provider, once they exist. The demo starts its own stand-ins;
  pointing it at real ones means starting it with the project's
  `endpoints` instead, which is a follow-up if the owner wants it.
