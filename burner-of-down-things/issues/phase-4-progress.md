# Phase 4 Progress — The blueprint

## Goals
The source written down as house-format issue files: one turn plans the outline, the machine checks it (coverage, cycles, ids), many turns describe the issues in parallel, and the house validator checks each. The graph of blockers gives the build order (docs/006).

Counts: run `/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/burner-of-down-things -m`.

## Completed Issues
- 401 the outline and its checks — one turn plans the whole blueprint; five named checks catch a bad plan and hand the findings back.
- 402 the graph and its levels — build order and reach, the structure grading and building lean on.
- 403 issue files and their checks — shape, blockers, acceptance commands, and the house validator's verdict.
- 404 describing in parallel — every issue at once, retried with findings, held when it cannot pass; a real fixture program and hand-written blueprint to test against.
- 405 phase 4 demo — a program described into a clean blueprint, its mistakes caught along the way, drawn as a graph.

The phase's goal is met with the stand-in. A blueprint written by a real
model waits on the live check held open in phase 3 (issue 305). Run
`tests/run-tests blueprint` and `./run-phase-demo 4`.
