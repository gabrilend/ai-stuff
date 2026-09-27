# Phase 3 Progress — The hands

## Goals
A model is run one turn at a time, told what it may read and write, and checked afterwards by comparing snapshots, so a turn that writes outside its folders is caught and named. Build turns can never see the source. A stand-in plays every turn for free; Claude Code is one row of the harness table (docs/005).

Counts: run `/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/burner-of-down-things -m`.

## Completed Issues
- 301 turn folders and kinds — six kinds, full prompt templates, the clean room held by the table itself.
- 302 crafts and instructions — rules, the person's chosen skills, the center's slot.
- 303 snapshots and confinement — before-and-after pictures; links by target; huge files by size and time.
- 304 the harness table and the stand-in — any harness is one row; a free stand-in that can misbehave on purpose.
- 305 the Claude Code harness — restricted, file tools only, reaching exactly the turn's folders; one live turn run on the subscription and kept, touching only its own file.
- 306 the turn pool — many turns at once, each judged kept, failed or breach.
- 307 phase 3 demo — throughput, every misbehaviour caught, the command lines, snapshot costs.

The phase's goal is met, including one real turn of Claude Code. Run `tests/run-tests hands` and `./run-phase-demo 3`.
