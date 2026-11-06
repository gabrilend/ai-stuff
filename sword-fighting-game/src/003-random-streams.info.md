<!-- made by scripts/build-info-pages from the comments in 003-random-streams.lua; change the comments and rebuild, not this page -->
# 003-random-streams


Named seeded generators: the determinism everything else rests on.

There is no global generator and nothing reads the clock. Each system draws
from its own stream, made from the run's seed and the stream's name, so that
changing how often the minds roll cannot change which swings are parried.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.new` | `seed, name` | (no comment in the source) |
| `Stream:next_raw` | nothing | The next 31-bit non-negative integer. Everything else is built on this. |
| `Stream:float` | nothing | A number in [0, 1). |
| `Stream:between` | `lo, hi` | An integer in lo..hi inclusive. |
| `Stream:chance` | `p` | (no comment in the source) |
| `Stream:range` | `lo, hi` | A number in [lo, hi). |
| `Stream:pick` | `list` | (no comment in the source) |
| `M.add_draws` | `total, set` | Adds a set's draw counts into a name -> count table, for the receipt. |
| `M.make_set` | `seed` | Every stream a run uses, keyed by name. |

## Tables of rows

| Name | What it is |
| --- | --- |
| `NAMES` | The streams a battle carries. Adding a system that needs chance means adding its name here, so the receipt can report its draws. |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `hash_name` | `name` | FNV-1a over the name's bytes. The FNV prime is 2^24 + 403, so the multiply is done as a shift plus a small multiply: a plain h * prime would pass 2^53 and lose its low bits inside a double. |
