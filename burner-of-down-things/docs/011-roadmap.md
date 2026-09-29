# 011 — Roadmap

Ten phases: clusters of functionality, foundations first, most blockers
last. Not a schedule; the last issue finished may belong to phase 1.

Every phase is testable without a model. The stand-in harness
([005](005-datapath-the-hands.md)) plays every turn from fixtures, so the
machine around the model is built and demonstrated for free, and the Claude
Code harness is one more row in a table.

| Phase | Builds | Specified by | The demo shows | Measured |
|---|---|---|---|---|
| **1 — The case and the ledger** | The project's path and scratch-space setup; a text-table reader and writer; SHA-256; the ledger with append, verify and head hash; the case folder, its lock and its record; the command dispatcher reading `input/` first and writing `goodbye` last | [003](003-datapath-the-case-and-the-ledger.md) | A case opened; thousands of ledger lines appended; one byte changed in the middle and the verifier pointing at that exact line | Lines appended per second; verification speed; the head hash before and after |
| **2 — The survey** | The walk and its skip table; the language table; include-line scanning and link resolution; the parallel reader; the summary view | [004](004-datapath-the-survey.md) | The owner's own projects surveyed side by side — kiln, rao-chat, wow-chat-2026's source, and this machine — with their foundations and entry points found | Files per second on one thread and on all of them |
| **3 — The hands** | The turn folder; the turn kinds table and prompt table; crafts read from skill files; the snapshot and its comparison; the harness table with `stand-in` and `claude-code`; the pool that runs turns in parallel | [005](005-datapath-the-hands.md) | A pool of stand-in turns, one told to misbehave, and the breach caught and named | Turns per second through the pool; snapshot time per thousand files |
| **4 — The blueprint** | The outline reader and its checks; the graph and its levels; the issue-file reader and its checks; the outline and describe steps driving turns | [006](006-datapath-the-blueprint.md) | A source described by stand-in turns into a blueprint, drawn as its graph level by level, checked by the house validator | Issues, levels, coverage of the survey |
| **5 — The design** | The design folder's layout; waves; build and repair turns; running acceptance; holding an issue's reach when it fails; delivery | [007](007-datapath-the-design.md) | A blueprint built wave by wave, one issue made to fail and its reach held, then repaired | Waves, turns spent, passes and repairs |
| **6 — The update** | Requests found in `input/`; locate turns; reach and grade; holding; amend turns with the blueprint put back on failure; rebuilding the reach | [008](008-datapath-the-update.md) | Three requests, one of each grade, and how much of the design each rebuilt | Issues rebuilt per grade |
| **7 — The center, and the whole loop** | The center from the ledger; ordering requests and waves by it; the paragraph in every turn; `run`, which does whatever a case is waiting for, start to end; the case viewer as an HTML page | [009](009-datapath-the-center.md) | A case run from source to delivered design to three updates with one command, and its center shifting as the requests arrive | The center's weights over the ledger's length |
| **8 — The studio** | The look as data; the paintbrush and its wall; the raylib painter; the `.png`, `.mp4`, `.txt` and source-file ends; charts and diagrams; the pool and its cards; the viewer | [067](067-datapath-the-studio.md) | The machine drawing itself: a case's blueprint as a diagram, its center as a chart and as a clip, its ledger as a text table, one source file written to order — all in the pool, opened in the viewer | Assets per kind, time per asset, bytes |
| **9 — The switchboard** | Tags and parcels; shapes and the station table; the ollama harness; the router; plans joined by shape; observations and adjustments | [068](068-datapath-the-switchboard.md) | Parcels of arbitrary inputs routed by a light local model, planned by shape, a failing result turned into a change to the mechanism behind it | Parcels, routings, attempts, adjustments |
| **10 — The story** | The storyteller; lessons; strategems from recurring lessons | [069](069-the-story.md) | A case's whole life told as a story, its lessons, and a strategem drafted when a lesson recurs | Chapters, lessons, mechanisms counted |

Dependencies run downward: each phase uses only the phases above it.

## The demos

Each phase ends with `issues/completed/demos/phase-N-demo`, run by
`./run-phase-demo`. They lead with numbers and with the machine's real
output — ledgers, surveys, graphs, designs — and each one recombines earlier
phases' tools with what is new.
