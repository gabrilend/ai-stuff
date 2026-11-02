# 904 — The router

The light model's one job: *"it looks like I'm being handed a circle, so here I'll hand this to the place that needs a circle"* — name the shape and the station, nothing else ([068](../docs/068-datapath-the-switchboard.md)).

## Current Behavior

Step 1 is built: `src/141-the-router.lua` routes a parcel with a scripted
stand-in answerer, checking each answer against the station table and
sending back an invented station, an unknown shape or a shape the station
does not take with the nearest names, up to three times, before the
parcel waits for the person; every routing is one `routed` or
`route-failed` ledger line. Its ollama answerer runs each attempt as one
turn of the `ollama` row (903) and is checked with a stand-in ollama
program. Step 2, a real model run by hand, waits on the owner starting
the server and choosing a model (docs/010 question 12). Checked by
`tests/142-checking-the-router.lua` and
`tests/143-checking-the-router-by-harness.lua`.

## Intended Behavior

- A router turn is handed the parcel's tag (if any), the types the machine recognised, and the station table; it answers `shape: …` and `station: …`.
- The answer is checked against the table: an unknown station or a shape the station does not take is sent back with the nearest names, up to three times; then the parcel waits for the person.
- Every routing is a ledger line: parcel, shape, station, attempts.

## Suggested Implementation Steps

1. With the stand-in. **Test:** an invented station is sent back naming the nearest real one; a good answer is recorded. Done.
2. With ollama, by hand (903). The owner's to run; what to run and what to
   look for:

   - Start the server and fetch a light model, e.g. `ollama serve` in one
     terminal and `ollama pull llama3.2:1b` (or any small model) in
     another; `ollama list` should show it.
   - Name it once for the switchboard (docs/010 question 12 is answered
     by this choice): put `router_model = "llama3.2:1b"` in
     `switchboard-settings.lua` at the project's root (090), or pass the
     name as the script's last argument instead.
   - Make a parcel folder holding one file, e.g. a `t.lua` that returns a
     table, and run
     `luajit scripts/147-route-by-hand.lua <parcel folder> [model]`.
   - Look for: the prompt names the parcel's files, their recognised
     types and the station table; the answer is two lines, `shape:` and
     `station:`, and nothing else; the outcome reads `routed: shape
     table, station txt-table`. An answer that invents a station or a
     shape should come back on the next attempt with the nearest names,
     and the model should take the hint within three attempts. Each
     attempt's turn folder (prompt.md, result.json, stderr.txt, exit) is
     kept and its path printed; result.json holds only `{"answer": …}`.
   - With the server stopped, the script must refuse by name before any
     turn runs, and never use another harness.
   - If it routes well, say which model, and mark this step done; if it
     wanders, the prompt (141's `prompt`) is the thing to change.

## Decisions

- Who answers is handed in as `ask(prompt, attempt)`: a scripted
  `stand_in` in-process for checks and demos (the stand-in's idea without
  a case and its turn machinery), or `harness_asker`, one turn of a
  harness row per attempt in `<folder>/route-<n>/`.
- The nearest names are by edit distance (Levenshtein), three at most,
  nearest first, ties by name. A wrong station for a known shape also
  names the stations that do take that shape.
- A shape is known when it is one of 081's types or a shape some station
  takes or gives, so a station's own intermediate shapes (`canvas`) count.
- An answer is read leniently for its first `shape:` and `station:`
  lines (case of the key ignored), but each must be one word.
- Two ledger kinds, added to docs/003 and 016: `routed` (text: parcel,
  shape, station, attempts) and `route-failed` (text: why the last answer
  was sent back; the parcel waits for the person). A line is about the
  parcel: its tag's number, else its folder's name.
- An answerer that raises (a harness refused by name, 903b) is raised
  again: it is never counted as an attempt and never routed around.
- The issue stays open for step 2, the real run by hand, which is the
  owner's: `scripts/147-route-by-hand.lua` runs it and prints every
  prompt, answer and the outcome, writing no ledger and touching no case
  (checked with a stand-in ollama by `tests/148-checking-route-by-hand.lua`).

## Blocked by

- 901
- 902
- 903
