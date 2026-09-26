# 038-the-stand-in.lua

A harness with no model: `luajit 038-the-stand-in.lua <project> <turn folder>`.
Plays the turn from the case's `stand-in.lua` script: a table keyed by
`"kind about"` or `"kind"`, each value an entry or `function(turn)` returning
one. `turn`: kind, about, id, prompt, folder, case_folder, attempt (1, 2, …
per kind and about).

An **entry**: `writes` (path relative to the case, or `turn/<name>` → text),
`exit` (number), `sleep` (seconds), `say` (text for result.json),
`misbehave` (`write-outside`, `write-source`, `fail`, `hang`).
Exits 4 when the case has no script, 5 when the script has no entry.
