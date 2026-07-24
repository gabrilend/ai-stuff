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

Scores are written by hand in the score vocabulary. A person who can
describe a motion's mechanism but not its vocabulary word has no way
in; the pipeline's front door only accepts score files.

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
