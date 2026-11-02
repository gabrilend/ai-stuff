# 138-one-answer.lua

The single-answer turn wrapper (docs/068, issue 903d), run by 037's
`ollama` row: `luajit 138-one-answer.lua <program> <arguments...> < prompt`.
Runs the model command with the prompt passing through on standard input,
keeps only what it prints on standard output, and prints it as one JSON
object, `{"answer": "..."}`, for the turn's shell line to write into
`result.json`. The machine writes the answer, not the model; the wrapper
itself writes nothing to disk. The model's standard error passes through
to `stderr.txt`; its exit status is the wrapper's.

| Function | In | Out |
|---|---|---|
| `json(printed)` | what the model printed | `{"answer":"..."}` and a newline, the text exactly as printed (no trimming) |
| `run(words)` | the command as an array of words | what it printed on standard output, and its exit status |
