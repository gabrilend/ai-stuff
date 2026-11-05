# 066-test-phase-5-demo — info

Runs the phase 5 demo (`issues/completed/demos/phase-5-demo`, issue 504)
as the owner would, short (forty seconds, the rehearsal's timers at one
second give or take half), in a copy of the project, and checks what it
showed against the programs' own record, read here:

- kuvalu's checkout: guide-feature's code in a monorepo folder, one
  commit, its index built at that commit;
- the demo voice's clone, with the index copied in whole, and where it
  went;
- the question at five focuses: each list of pieces is the one the look
  tool gives here for the same index (the stand-in's vector made here),
  4, 6, 8, 10 and 12 pieces from focus 1 to 0, each with its chart, and
  the focused answer as the model reads it;
- every look in the rehearsal's table as the turns' logs have it, focused
  and broad from all three voices, none refused, and one shown as its
  model read it;
- each voice's clone in RAM or on disk as its log says, and the RAM tier
  a tmpfs when one could be written;
- each voice's last receipt's look, index and clone counts;
- no stand-in model left running.

Then through `run-phase-demo`, which offers phase 5, and a short run with
no clone fitting its share of RAM (every clone shown on disk, and why),
which leaves nothing behind in its `TMPDIR` or its RAM tier, and no
stand-in model.

    luajit src/066-test-phase-5-demo.lua [--dir ROOT]

About a minute.
