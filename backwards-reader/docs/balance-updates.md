# balance updates

Knobs turned and levers pulled. Append-only. Not for features — those get
issue files — only for numbers that moved and why.

---

## 2026-07-29 — the starting numbers

Everything below is a first guess, written down as a guess so that the
first person to measure it knows they are allowed to overrule it.

| Knob | Value | Why this value |
|---|---|---|
| depth budget | 6 | rung 6 is where the vision wrote `[stack overflow]`; the budget errors rather than truncates, so a too-small value is loud and safe |
| door starting `cost_ms` | 5000 | pessimistic on purpose — an unmeasured door must not win the first race and swallow the queue before anything is known about it |
| `cost_ms` decay | 0.25 toward each new observation | fast enough to notice a door throttling within a few units, slow enough that one slow answer does not reroute the whole reading |
| failure `cost_ms` penalty | ×4 per failure | three consecutive failures put a door two orders of magnitude above its neighbours, which is effectively out without a separate failover path |
| per-door concurrency | 4 | matches a plain `llama-server --parallel 4`; queueing beyond it just hides the queue where the price cannot see it |
| contrast band | 0.15 – 0.55 | a guess, and marked as one — until `input/band` is calibrated the reader records distances but refuses to rank by them |
| mirror temperature | 0.8 | inversion is a creative turn, not a retrieval; too low and the model paraphrases, which shows up as a near-zero angle |
| mirror max tokens | 2× the input's token estimate | a mirror much longer than its original is a model that started explaining itself instead of turning |
