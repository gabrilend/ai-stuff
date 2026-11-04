# libs/reading-guide.lua — info

The guide's judgement for the reading walk (issue 065g): what the AI is told,
and the move read back from its answer. The AI is any function
`(system string, user string) -> reply string | nil, error`.

| | |
|---|---|
| `M.foundations(map, index)` | earlier stops used inside this stop's own lines (list of stop indexes, nearest first, at most 8) — the only places the guide may step back to |
| `M.system_text` | the guide's standing instructions: never ask or test the reader; judge only from what they chose to do; answer one line |
| `M.user_text(map, index, recent)` | this moment: the stop, its summary, its foundations, the reader's recent actions (list of strings) |
| `M.parse(reply, foundations)` | a move `{ move = "next" \| "more" \| "summary" }` or `{ move = "back", to = integer }`, or nil and why. The first line holding a move counts; a BACK to a stop not offered is refused. |
| `M.choose(model, map, index, recent)` | ask and parse in one |
| `M.llama_model(scripts_dir)` | the default AI through `llama-chat-client.lua`; nil and why when no server answers. `INFERENCE_CHAT_HOST` / `INFERENCE_CHAT_MODEL` point it at another server (ollama: `localhost:11434`, a model name such as `llama3.2:latest`). |

## The four moves

| Reply | The walk does |
|---|---|
| `NEXT` | the next stop in the project's order |
| `BACK n` | stop n (a foundation); the reader's next "next" returns to where they were |
| `MORE` | shows where the stop is used, stays |
| `SUMMARY` | prints the stop's summary, goes on |

An answer that cannot be used is shown to the reader, who then chooses; the
program never picks a move in the guide's place.
