# 402 — Choose endpoints at runtime, including outside providers

phase 4, the turn

## Current behavior

The endpoints file and reader exist (401), and every role points at
kuvalu.

## Intended behavior

- **`scripts/use-endpoint ROLE NAME`**: checks the endpoint answers, then
  rewrites the one `use.ROLE` line in `endpoints` (temporary file, then
  rename). The next turn of that role uses it, with nothing restarted. It
  prints the old and new choice.
- **`scripts/list-endpoints`**: every endpoint, its kind, whether it answers
  now, and which roles use it.
- **Outside providers**: an endpoint with a `key-file`. The key is read from
  that file, which lives outside the repository, at the start of each turn,
  and sent as the provider requires. A missing or unreadable key file is an
  error for that turn. Under the owner's router rules
  (`docs/network.md`), an outside provider is reachable only on connections
  a voice opens, and that is the only way the model caller uses it.

Every turn records the endpoint it used in the log and goodbye receipt, so a
canvas's history can be traced to the models that wrote it.

## Suggested implementation steps

1. The two scripts.
2. Key handling in the model caller.
3. Tests: switching a role between two endpoints while the rehearsal runs
   (the switch shows in the next turn's log); a missing key file.

## Related documents

- `docs/endpoints.md`
- `docs/network.md`

## Open questions

- None left: kuvalu names each voice's endpoint in the canvas it sends
  (`docs/endpoints.md`).

## Blocked by

401.

## Blocks

406, 703.

## Decisions (2026-11-05; each the owner's to overturn)

1. **Each voice gets its own line in the canvas, not one shared header.**
   The owner's answer was that only kuvalu keeps `endpoints` and tells each
   voice which endpoint to use in the canvas. A single `endpoint` header
   could not say that fg-sora-2 uses another endpoint than fg-sora-1, which
   the file's `use.` lines allow. So the to-voices canvas has an
   `endpoints:` section after `cuts:`, one line per voice:
   `endpoint: VOICE NAME TIMEOUT ADDRESS [KEY-FILE]`. kuvalu writes it at
   every version from a fresh read of `endpoints`; a voice with no `use.`
   line, or whose endpoint has no timeout or no http address, gets no line
   and the log says why; an `endpoints` file that cannot be read sends the
   version with an empty section, logged and counted
   (`versions-without-endpoints`), and every voice's turn then fails saying
   so. The old `endpoint` setting of `input/to-voices` is gone.
   This keeps the other documents that had the voice read or copy
   `endpoints` itself (405's first draft, `docs/datapath-voice-turn.md`
   step 3, issue 703) in line with the owner's answer: they now say the
   voice reads its line from the canvas.
2. **The key file's path travels; the key never does.** The canvas line
   names the key file's path; each voice that uses an outside provider
   needs the file at that path on its own machine (703). The key is read at
   the start of each turn and refused, naming the file but never the key,
   when the file is inside the project, missing, unreadable, empty, or holds
   more than one word.
3. **The key is sent as `Authorization: Bearer KEY`,** as llama-server's
   `--api-key` and OpenAI-style providers take it, from a temporary file
   only its owner can read, handed to curl as `-H @file` and removed after
   the request. Then it is on no command line another program could read.
   A provider that wants its key another way needs a `NAME.key-header`
   field; none is added until one does.
4. **use-endpoint checks more than "answers".** `GET /v1/models` answers
   without a key on llama-server, so it cannot show a key is taken. The
   script also counts the tokens of one word (`POST /tokenize`), which
   needs the key and which every turn does anyway. It also checks the kind,
   the timeout and the key file, so a switch it makes cannot fail the next
   turn for any reason it could see now.
5. **The rewrite keeps the line's comment and spacing,** adds a line for a
   role that has none, and goes through `endpoints.part`, read back whole
   by the same reader the turns use, then renamed. The same choice again
   writes nothing.
6. **Where the scripts run: kuvalu.** That is where `endpoints` is. A
   voice's view of its endpoint is the canvas line; checking that each
   voice can reach it is 703's.
7. **The stand-in server can ask for a key** (`--key-file`, like
   llama-server's `--api-key-file`), so the tests send real headers over
   HTTP. It leaves `GET /v1/models` and `/health` open, as llama-server
   does, and its request log says whether each request was authorized,
   never the key.

## What was built (2026-11-05)

- `src/053-endpoint-tools.lua`, `scripts/use-endpoint`,
  `scripts/list-endpoints`.
- Keys: `load_key` and `from_canvas` in `src/046-model-caller.lua`; the
  header file in `libs/llama-chat-client.lua`; `--key-file` in
  `src/047-stand-in-llama.lua`.
- The `endpoints:` section: `src/006-canvas-text.lua`,
  `src/035-to-voices.lua`, `docs/canvas-format.md`.
- Tests: `src/054-test-endpoint-tools.lua` (52), and the section in
  `src/007-test-canvas-text.lua` and `src/036-test-to-voices.lua`, where a
  `use.` line switched between two versions shows in the next one's line.
  The issue's "switch while the rehearsal runs, shown in the next turn's
  log" needs the real turn: it is checked in 405's rehearsal and shown in
  406's demo.

## Needs the owner's machine

- The real key files, at the paths `endpoints` names, outside the
  repository, on kuvalu and on each voice that uses an outside provider.
- A provider's real address and whether it takes `Authorization: Bearer`.
