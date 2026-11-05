# 055-turn — info

One voice's real turn (issue 405), run by the turn runner (038) as the
program `input/turn-runner` names, `scripts/turn`:

    scripts/turn --dir ROOT --voice NAME --turn N --canvas FILE --out FILE

The seven steps of `docs/datapath-voice-turn.md`: read the canvas; the
project clone (501: `058`'s keeper, logged and counted, the turn going on
without one when it cannot be had); the voice's endpoint from its line
in the canvas (`from_canvas`, 402), key read here; the opening conversation
(403) with last turn's note; ask until it fits (404); the voice's canvas,
`base:` the version read, read back with the canvas reader before it is
written to `--out`.

| Function | Meaning |
|---|---|
| `run(opts)` | one turn: `root`, `voice`, `turn`, `canvas`, `out`; returns `"sent"` or `"gave-way"`, raises on failure after logging it |
| `voice_canvas(record, rows, voice, turn, written)` | the from-voice text, checked by reading it back |
| `project(opts, record, run, where)` | step 2: the clone keeper, logged and counted; returns the kept clone, or nil and why. `opts.clone` passes the keeper's seams |
| `summary(opts, endpoint, counts, changes, recommended)` | the log line of a turn's numbers |
| `note_path(root, voice)` | `output/turn-note-<voice>`, last turn's advisory note |
| `GAVE_WAY` | 3, the exit status of a turn that gave way |

Settings: `input/turn` (051's `SETTINGS`): `recommended-words`,
`recommended-sentences`, `look-limit`, and `newer-canvas`: `"keep-going"`
(default, the owner's word) or `"give-way"` (before each new ask, stop if a
newer canvas waits in `turn/<voice>/waiting`; exit 3).

Each turn is its own run: log `tmp/shared-memory/turn-<voice>.log`, receipt
`output/goodbye-turn-<voice>`. Both name the endpoint. The receipt counts
`endpoint-<name>`, `asks`, `tries`, `problems-<kind>`, `look-calls`,
`looks-<focus>`, `tokens-prompt`, `tokens-completion`,
`model-milliseconds`, `words-changed`, `sentences-changed`,
`over-recommended`, `clone-ram` or `clone-disk`, `clone-made`,
`clone-fetched`, `clone-moved`, `clone-milliseconds` or `clone-failed`, and
`gave-way` or `failed`.

Exit status: 0 written, 1 failed (the reason on stderr), 2 wrong
arguments, 3 gave way.
