# Phase 4 Progress — The turn

## Goals
The endpoints file in the project root and choosing endpoints while
running, the llama.cpp client, the turn's prompt, and asking until the
edited canvas fits, with compiler-style reports. Ends with three real turns
per version on kuvalu's llama.cpp server.
(`docs/roadmap.md`, phase 4)

Counts of done and open issues:
`/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/guide-feature -m`

## Completed Issues
- **401b, the client and the endpoints file** (2026-11-05):
  - `libs/llama-chat-client.lua`, this project's copy of delta-version's
    client, with an endpoint record per call and an embedding call.
  - `libs/dkjson.lua`, and `scripts/refresh-vendored` to copy both again
    from their upstreams.
  - `endpoints` in the project root, with proposed ports.
  - `src/046-model-caller.lua`, which reads `endpoints` again for every
    role's every call, and names the endpoint in every failure.
  - Tested against a stand-in llama.cpp server on 127.0.0.1
    (`src/047-stand-in-llama.lua`). The run against 401a's real servers is
    left for the owner's machine.
- **403, the turn prompt** (2026-11-05):
  - `src/049-turn-prompt.lua` builds a voice's opening conversation from
    `input/turn-instructions`, a file of the owner's words with markers.
  - The canvas is shown inside a ruler of column and row numbers. A reply
    that copies the ruler is caught.
  - The look call is one line in the reply, answered for now until the
    owner decides (open questions 3 and 6).
  - A reference prompt in `assets/test-prompts/` shows any change as a
    difference.
- **404, ask until it fits** (2026-11-05):
  - `src/051-ask-until-it-fits.lua` asks a voice's model with the turn's
    opening conversation. Look calls are answered up to the limit.
  - Each canvas reply goes through the fit check and the ruler check. A
    reply that does not fit goes back with the compiler-style report, cut
    at the edge when too large, and the model is asked again, with no last
    try.
  - It counts asks, tries, problems by kind, look calls, tokens and seconds.
  - Run directly, it shows a real model being corrected. That run is for
    kuvalu with 401a's servers.
- **402, choose endpoints at runtime** (2026-11-05):
  - `scripts/use-endpoint ROLE NAME` checks the endpoint (kind, timeout,
    key file, answers and takes the key), then rewrites the one `use.` line
    through a checked temporary file. `scripts/list-endpoints` shows every
    endpoint, whether it answers, and who uses it.
  - Outside providers: the key is read from a file outside the repository
    at the start of each turn and sent as `Authorization: Bearer`, never on
    a command line.
  - The canvas kuvalu sends has one endpoint line per voice, written from
    a fresh read of `endpoints` at every version, so a switch reaches a
    voice with the next version.
  - Real key files and providers are the owner's.
- **405, the turn** (2026-11-05):
  - `scripts/turn` (`src/055-turn.lua`) is the voice's real turn, named in
    `input/turn-runner`. It reads the canvas, takes its own endpoint from
    the canvas, builds the prompt with last turn's note, and asks until the
    reply fits. It then writes the voice's canvas, read back first.
  - Its log and receipt name the endpoint, and count the tries, the
    problems by kind, the look calls, the tokens and the seconds.
  - A turn still asking keeps going when a newer canvas arrives (the
    owner's word). `newer-canvas = "give-way"` in `input/turn` makes it
    stop instead.
  - Run in the rehearsal with the real turn in all three voices against a
    stand-in model. The run against kuvalu's servers is for the owner's
    machine.
- **406, the phase 4 demo** (2026-11-05): `issues/completed/demos/phase-4-demo`
  (also `./run-phase-demo 4`) runs the rehearsal for a minute with the real
  turn in all three voices, against two stand-in llama.cpp servers on
  127.0.0.1 that differ in speed and in how often they run past the edge.
  - Each version is drawn as it is made, with phase 2's marks. Under it:
    which endpoint the turn asked, at which try it fit and what was sent
    back, and words and sentences changed against the recommendation.
  - Halfway through, `scripts/use-endpoint fg-sora-2 stand-in-b` switches
    one voice, and its next turns ask the other model.
  - Then every turn in a table, seconds, tries and tokens per turn for each
    voice and endpoint (where the switch shows), each voice's last receipt
    and the runners' counts.
  - Every number is read from the turns' own logs and receipts, and the
    test checks the output against them.

## Phase 4 is done here, apart from kuvalu's servers

402–406 and 401b are done. A voice's turn reads the canvas, asks the
endpoint the canvas names until its reply fits, and writes the canvas
back, with every try counted. Endpoints are chosen while running with
`scripts/use-endpoint`, and a switch reaches a voice with the next version.

The roadmap's last goal for phase 4, "three real turns per version on
kuvalu's llama.cpp server", is met only against stand-in servers here.
The stand-ins answer llama-server's routes, but their model is not a
language model.

Left for the owner's machine:
- **401a, this project's own llama.cpp servers on kuvalu**: the build, the
  models and the ports. Nothing was installed here.
- **The turn, the rehearsal and the demo against those servers**, and
  404's run that shows a real model being corrected.
- **A real outside provider**, with its key file outside the repository.
- **The demo's timers**: a minute suits short `input/rehearsal` timers;
  with the default 30-second timers, `--minutes 5` shows more.
- **Whether a turn still asking should give way to a newer canvas**: it
  keeps going now (the owner's word); `newer-canvas = "give-way"` in
  `input/turn` changes it.
