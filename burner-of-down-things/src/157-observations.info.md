# 157-observations.lua

Observations (docs/068, issue 906 step 1): a station's result that holds an
error becomes an **observation** — what happened, and the mechanism that let
it happen — written by a turn that reads the result and, when there is one,
the station's blueprint. The mechanism goes through the lesson's own checks
(085: a short sentence, not a mood), so an observation and a lesson can
never disagree about what a mechanism is. An answer that names no mechanism
is sent back with its reason, up to `MOST_ATTEMPTS` (3) times; after that the
result waits for the person and is never silently dropped. Kept observations
are appended to a file, never rewritten. Turning an observation into an
adjustment (a request file in the station's case for the update step, 008)
is step 2.

| Function | In | Out |
|---|---|---|
| `holds_error(result)` | a result: text, or a table | the error's words — a line opening with the word `error` (any case), or a table's non-empty `error` string — or nil |
| `build(fields)` | `{station, what_happened, mechanism}` | the observation, or nil and why: a missing field, or a mechanism the lesson check refuses (a mood, too long, …) |
| `prompt(station, result, blueprint, sent_back)` | the station, its result, its blueprint (optional), the last reason an answer was sent back (optional) | the observing turn's prompt |
| `parse(text)` | an answer | its `what happened:` and `mechanism:` lines (first of each) |
| `observe(opts)` | `station`, `result`, `blueprint`, `ask(prompt, attempt)`, `file` | `{status="clean"}` (no error: no one is asked), `{status="kept", observation, attempts}`, or `{status="waiting", attempts, sent_back}` |
| `append(path, one)` | a file; a kept observation | appends `## station`, what happened, `Mechanism: …` in one append-mode write |
