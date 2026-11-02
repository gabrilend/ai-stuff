# 141-the-router.lua

The router (docs/068, issue 904): handed a parcel's tag, the types the
machine recognised in it and the station table, a light model answers
`shape: …` and `station: …`, nothing else. The machine checks the answer
against the table and sends back an unknown station, an unknown shape or a
shape the station does not take, with the nearest names, up to three
times; then the parcel waits for the person. Every routing is one ledger
line, `routed` or `route-failed` (docs/003).

Who answers is handed in: `stand_in` (scripted answers, for checks and
demos) or `harness_asker` (one turn of the `ollama` row per attempt, 903).
A harness that refuses is raised by name, never routed around.

| Function | In | Out |
|---|---|---|
| `route(opts)` | `{rows, parcel, ask, ledger, about}`: a station table; a parcel (079); `ask(prompt, attempt)` → text, or nil and why; optional ledger path and about | `{status = "routed", shape, station, row, attempts}` or `{status = "waiting", attempts, sent_back}`; appends one `routed` or `route-failed` line when given a ledger |
| `recognised(p)` | a parcel | `{tag_number, wish, tag_finding, files = {{name, shape}}}`; a file nothing recognises is `unknown` |
| `prompt(seen, rows, sent_back)` | `recognised`'s answer; the table; why the last answer was sent back (optional) | the router turn's prompt |
| `parse(text)` | an answer | shape, station; or nil, nil and a finding when it lacks a one-word `shape:` or `station:` line |
| `check(rows, shape, station)` | the table; an answer | the station's row, or nil and why it is sent back, with the nearest names |
| `known_shapes(rows)` | the table | 081's types and every shape a station takes or gives, sorted |
| `nearest(word, names, n)` | a word; names; how many (default 3) | the nearest names by edit distance, nearest first, ties by name |
| `distance(a, b)` | two strings | their Levenshtein distance |
| `stand_in(answers)` | answers by attempt (strings or functions of the prompt) | an answerer that keeps every prompt in `.prompts` |
| `harness_asker(project, folder, model, harness)` | the project; a folder for the turns; a model name; a harness row (default `ollama`) | an answerer running each attempt as `<folder>/route-<n>/`, reading the answer 138 wrote; asks for the row first, so a stopped server refuses before any turn |
| `MOST_ATTEMPTS`, `NEAREST` | | 3 and 3 |
