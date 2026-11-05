# 057-test-phase-4-demo — info

Runs the phase 4 demo (`issues/completed/demos/phase-4-demo`, issue 406)
as the owner would, short (forty seconds, the rehearsal's timers at one
second give or take half), in a copy of the project, and checks what it
showed against the turns' own logs and receipts, read here:

- the voices ran real turns, some sent back for running past the edge;
- every version drawn, in order, with the marks as numbers under the rows;
- under each version, its turn: endpoint, tries and why, words changed;
- the table of every turn;
- per voice and endpoint, turns and seconds and tries per turn, adding up;
- the switch: `scripts/use-endpoint` ran on the workspace's `endpoints`,
  fg-sora-2 then on both endpoints and the others on the first only, and
  the second model's slower replies showing;
- each voice's last turn receipt and each runner's counts;
- no stand-in model left running.

Then through `run-phase-demo`, which offers phase 4, and a short run that
leaves nothing behind in its `TMPDIR`, not even a stand-in model.

    luajit src/057-test-phase-4-demo.lua [--dir ROOT]
