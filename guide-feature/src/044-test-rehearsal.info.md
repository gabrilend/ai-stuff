# 044-test-rehearsal — info

Runs `scripts/rehearse` in a throwaway project for twenty seconds. The
carrier's timers are 1 ± 0.5 s and a stand-in turn takes half a second.

What it checks:
- The rehearsal runs and reports. The mailboxes are made by the setup
  script.
- Every voice's turns are blitted more than once.
- In every timing row, the stages are in order.
- Every row is named blitted, unchanged, superseded or in flight.
- Each turn takes the stand-in's time, and whole rows are present.
- A voice's canvas waits no longer than its contact's timer.
- Every base is a version that was made.
- The events are there. The second voice's canvas arrives under rmail's
  `canvas-from` name.
- The receipt's counts agree.
- The workspace is gone afterwards, with no process left.
- `--keep` keeps the workspace.
- With `carrier = "rmail"` and a stand-in daemon command, four daemons
  are each given their config and all are stopped.

    luajit src/044-test-rehearsal.lua [--dir ROOT]
