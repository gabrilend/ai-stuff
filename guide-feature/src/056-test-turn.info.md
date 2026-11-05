# 056-test-turn — info

Tests for the real turn (issue 405), against stand-in llama.cpp servers
(047) on 127.0.0.1 whose model edits the canvas it is shown (`rewrite`).

- One turn: the voice's canvas written (voice, turn, base, size), the
  model's one-word edit in it, the opening conversation with the ruler,
  only this voice's endpoint asked; the receipt and the log name the
  endpoint and give the numbers; the project clone's line.
- A reply past the edge: sent back with the report, asked again, the
  reply that fits written, both tries logged.
- The advisory note: kept after a turn over the recommendation, in the
  next turn's prompt, dropped after a turn within it.
- A voice with a key (sent, never logged); refusals: a model error, no
  endpoint line, a canvas that does not read, missing arguments.
- The newer canvas: `give-way` stops after the first reply that does not
  fit, exits 3 and writes nothing; `keep-going` asks on and sends;
  `give-way` with nothing waiting goes on. The runner counts a turn that
  gave way, sends nothing and keeps the turn number.
- The whole round: the rehearsal (043) with the real turn in all three
  voices, in the background; `scripts/use-endpoint` switches fg-sora-2 to
  another endpoint while it runs; fg-sora-2's log shows turns on the first
  endpoint, then on the other; only fg-sora-2 asked the other; the runner
  sent the turns and none failed.

It takes about a minute (the rehearsal runs 30 seconds). With `KEEP=1` in the
environment, a failed run leaves its throwaway folder to read, and says
where.

    luajit src/056-test-turn.lua [--dir ROOT]
