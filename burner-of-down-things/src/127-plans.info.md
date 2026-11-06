# 127-plans.lua

Plans joined by shape (docs/068, issue 905): the shortest chain of
stations from one shape to another, found by search, not by a model
(905b); every joint checked before anything runs (905c); and the plan run,
each result kept as a new parcel and handed on (905d). Works on any rows
shaped like 902d's station table (`{name, input, output, run}`).

A **shape** is a string; several inputs are one shape joined by `+`
(`integer-array + text`), compared in one canonical form (parts trimmed,
sorted), so the order they are written in does not matter.

| Function | In | Out |
|---|---|---|
| `canonical(shape)` | a shape | its canonical form; refuses an empty shape or part |
| `find(rows, from, wanted)` | station rows; two shapes | the shortest chain, rows in running order (`{}` when `from` is `wanted`), by breadth-first search over 905a's graph in row order; or nil and a sentence naming the type that cannot be reached, whether any station gives it, and what is reachable |
| `check(plan, from, wanted)` | rows in order; two shapes | true, or nil and a sentence naming the start, the joint (`joint N: 'a' gives 'x' but 'b' takes 'y'`) or the end that does not fit |
| `run(plan, from, wanted, value, keep_folder)` | a plan; its shapes; the parcel's value; where to keep results | checks first and refuses with nothing run; then runs each station's `run(value)` in order, keeping each result as a parcel in `keep_folder/NN-<station>/` (`result.txt` for text, the record `result.lua` for a table). Returns `{result, parcels = {{station, folder}, ...}}`, or nil, why, and the parcels kept before a station failed |
