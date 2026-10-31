# 601 — prose-to-scene translator

## Founding words

Spoken by gabrilend, 2026-07-23, amending the architecture:

> we could use a small local LLM to translate fairly literally.
> Sometimes the user will say the wrong word or forget how to spell
> it, but can still describe the mechanism. I'm thinking... llama.cpp
> on my little cluster of 3?
>
> you are a marvel to me. come, celebrate profundity, and fable
> yourself to the max.

## Amendment, 2026-07-23

Gabrilend, answering the cluster-topology question and reshaping the
model's output: *"there will be an orchestrator"* — the porch speaks
to one door and the cluster's shape stays behind it — and:

> the LLM will generate tool-calls for each thing they want to "paint"
> onto the canvas. They will give a timeframe in seconds (only one
> decimal point accepted) a color a shape and a fade-in-and-out enum
> pattern pick. These are then collected, and mapped out and written
> as a lua script which can then be run to generate the gif
> programmatically.

So: not one whole-scene reply, but **one tool-call per stroke**,
collected, ordered by time with the walk-back insertion (see the
score issue), and written as a canonical score file.

## Current Behavior

In progress — everything testable without the cluster is built and
proven; the live transport waits for the orchestrator to light.
Working today: the grammar generator (pure function of the
vocabulary tables, times structurally tenths, misspelling
impossible), the prompt builder (the format contract and both
reference scores, verbatim), the tool-call parser and collector
(walk-back insertion as calls arrive), the canonical score writer
carrying prose sentences as comments, the bounded retry loop with
the wall's teaching quoted back verbatim (proven against a scripted
fake orchestrator: a misspelled hue corrected in exactly two
attempts), exhausted patience surfacing errors beside the best
draft, and the cluster roster reader with its polite refusals
(input/cluster.example ships). Since 2026-10-31 the HTTP adapter is
built too (see What Happened), proven against a fake llama.cpp server;
what waits is a run against a real model on her machine.

## Intended Behavior

The translator: a client program (a porch, not a room of the house)
that turns one `.prose` file into one candidate score file, by
collecting stroke tool-calls from a model.

- **Prompt built from the truth**: system prompt assembled at run time
  from the scene-format document plus the shipped reference scenes as
  few-shot examples. The vocabulary is never written a second time for
  the model's benefit — the prompt builder reads what people read.
- **One tool-call per stroke**: the model paints by calling a stroke
  tool — timeframe in seconds (tenths only, enforced by grammar),
  color, shape, fade enum — as many calls as the prose needs, in any
  order it likes. Time is the ordering truth, not utterance order.
- **Grammar generated from the vocabulary**: a GBNF grammar (llama.cpp
  constrained decoding) produced by a generator that reads the same
  vocabulary tables the validator trusts — legal fade enums, easing
  names, hue names, shape kinds, the one-decimal time rule.
  Misspelling becomes physically impossible in output; the model's
  whole freedom is choosing among legal readings of the mechanism
  described. Never hand-maintain the grammar: the tool generates it,
  always.
- **The collector**: tool-calls accumulate into the stroke list,
  ordered as they arrive by the canonical writer's walk-back
  insertion (decrement the index until the comparison is a no-op;
  equal times settle in arrival order).
- **Transport**: HTTP via luasocket, JSON via dkjson (both on the
  shared shelf, `libs/lua/`). The porch speaks to **the orchestrator**
  — one endpoint named in `input/cluster`, the cluster's shape its
  business, not ours. Zero endpoints is a polite refusal with
  instructions, not a fallback.
- **Output**: the collected strokes are written as a canonical score
  file, the person's own sentences carried as comments above the
  strokes they became (the shipped vision translation already models
  this style).
- **The wall argues, bounded**: a candidate that fails validation gets
  the errors — actor, field, nearest legal word — quoted back verbatim
  for a small fixed number of retries; still failing, it is presented
  to the person with its errors attached. No silent repair, no silent
  drop.
- Tests: prompt and grammar builders are pure functions of the
  vocabulary (snapshot-tested against it, so vocabulary growth is
  detected, not drifted past); the collector's ordering against
  shuffled and equal-timed tool-calls; the retry loop against a
  scripted fake orchestrator; a canned run of tool-calls collects
  into a score that compiles.

## Suggested Implementation Steps

1. The grammar generator from the vocabulary tables (tool-call
   shaped).
2. The prompt builder from the format document and reference scores.
3. The cluster file reader and the HTTP client against the
   orchestrator's door.
4. The collector (walk-back insertion) feeding the canonical score
   writer, prose comments carried.
5. The bounded retry loop wired to the validator's errors.
6. Tests as described (fake orchestrator; no cluster required to
   test).

## Blockers

- 401 (the format is the prompt's raw material), 402 (the wall and
  its nearest-legal-word suggestions).

## Related Documents

- docs/datapath-prose-translation.md (this issue's specification)

## Trying it on her machine

Nothing here has met a real model yet. To try it:

1. Start llama.cpp's server on any machine the porch can reach, with a
   context long enough for the prompt (the prompt is the whole language,
   read verbatim: about 14 thousand tokens today; `./porch --check`
   prints the current figure):

   ```bash
   llama-server -m MODEL.gguf --host 0.0.0.0 --port 8080 -c 18432
   ```

2. Name its door. `input/cluster` is one `name host port` line per
   door, and stays out of git:

   ```bash
   cd /mnt/mtwo/programming/ai-stuff/gif-generator
   echo "mind 127.0.0.1 8080" > input/cluster
   ./porch --check
   ```

3. Say something, read what it heard, then film it:

   ```bash
   ./porch "curve the ball around the circle"
   ./run heard
   ```

   The score lands in `input/heard.lua` (or `heard-2.lua` and on, never
   over an existing one); `--name=NAME` picks another name.

## What Happened

2026-10-31, the last mile (branch `claude/601-the-porch-goes-live`, on
top of 704):

- **The door.** `porch.door_transport(door)` posts each request to
  `http://host:port/completion`, the body llama.cpp's server takes
  (`porch.llama_body`: the prompt, what the person said, the wall's
  words on a retry, the grammar beside it, a seed). It sends with curl,
  so the porch needs no HTTP library. A door that doesn't answer, or
  answers with something that isn't a completion, is a sentence naming
  the door. `porch.door_health(door)` asks `/health`.
- **A reply that isn't tool-calls** (a model that chats instead of
  calling) used to stop the porch with an error; now it fails that one
  reading, and the next try is told why.
- **The front door.** `./porch` (`src/060-porch-say.lua`): `--check`
  asks every door and says how long a context the prompt needs; a
  sentence is sent to the first door that answers (or `--door=NAME`),
  the read-back lines are printed, and the score is written to
  `input/`. Filming stays `./run NAME`, so the lines are read first.
- **Proof.** `src/033-porch-test.lua` is 42 of 42: the request body, a
  translation through a door with a fake shell that answers as
  llama.cpp's server does (a misspelling mended on the second asking),
  `/health`, a door that doesn't answer, a reply with no tool-calls,
  and a host that could break the command line. By hand, here: `./porch
  --check` and a sentence against a small fake llama.cpp server, one
  door up and one down. The fake's first reply forgot the world's stars
  and the wall said so; the second landed and its score was written.
- `input/cluster` is in `.gitignore`, since it names machines on her
  network.

Still open: which model, and on which machine (704, question 2).
