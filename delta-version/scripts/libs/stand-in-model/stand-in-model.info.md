# stand-in-model/

A stand-in for the local llama.cpp chat server, so tools that ask the model
something can be tested without downloading or running a model.

| File | What it is |
|------|------------|
| `server.c` | A small HTTP server on 127.0.0.1 that answers the three requests `llama-chat-client.lua` makes: `GET /v1/models`, `POST /tokenize` and `POST /v1/chat/completions`. It handles one request at a time. |
| `brain.lua` | What the stand-in "model" says. It reads the system prompt's first line, `Task: NAME.`, and answers by a fixed rule for that task (see its header). A user message holding `STAND-IN-FAIL` gets an error reply. |
| `stand-in-model.sh` | `stand_in_start SCRATCH` builds `server.c` with gcc, starts it on a free port and exports `INFERENCE_CHAT_HOST` and `AISTUFF_ROOT`. `stand_in_stop` stops it. |

Tools are tested through the real client: only the address changes. The
brain knows each tool's task by name, so a test can say exactly what a tool
should do with the answer. It is a fixture, not a model, and nothing in a
tool depends on it.

Tasks the brain knows:
- `propose-guideline` (040)
- `classify-section` (049)
- `vision` (051)
- `components` (053), which writes each phrase as the text spells it, so matching tiers can be tested
- `summarize-slice`, `merge-summaries`, `title` and `blurb` (056b). Their answers are short and fixed, so slicing and merging can be counted. `title` adds a second sentence for the tool to drop.

A user message holding `STAND-IN-FAIL` gets an error reply. One holding `STAND-IN-THINK` gets its answer after a `<think>` block, as Qwen3 writes one.

`/tokenize` answers one token per word, in llama.cpp's `{"tokens":[...]}` shape, so a small context size forces many slices on a short text.
