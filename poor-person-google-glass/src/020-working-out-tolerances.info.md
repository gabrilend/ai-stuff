<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 009 (tolerance calculations): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 020-working-out-tolerances

Every answer a calculation gives: nominal, worst case (all 2ⁿ corners of the inputs' extremes, plus the middle), usual spread (root-sum-square of each input's larger one-sided effect from the middle), each input's share, and verdicts. No randomness.

| Offers | Takes | Gives |
|---|---|---|
| `work_out(calculation)` | a checked calculation (019) | list, per output, of { name, unit, nominal, worst = { low, high }, spread = { centre, low, high }, shares = list of { input, percent } (largest first), at_least, at_most, worst_verdict, spread_verdict ("pass"/"fail"/"no limit") } |
