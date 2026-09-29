# 068 — Datapath: the switchboard

Rapid planning structures with arbitrary inputs and outputs. Something
arrives — a tagged prompt, an integer array and a line of text, a
program's results — and a light model decides what it is and hands it to
the place that needs it. Pass zero: every part present, none detailed.

> things like an src file with a string at the beginning that says
> "language model prompt 14597: something something yadda yadda." then, a
> light llm decides what to do with it. "draw a circle? Well, it looks like
> I'm being handed a circle, so here I'll hand this to the place that needs
> a circle."
>
> "hmmm, I gotta take this integer array and this string of text and create
> an image off of it? Great!" "so it looks like an analysis machine, I ran it
> and I got these results [error error dettected]" "so it looks like the
> sheep are out of the barn because they pushed through the door. Let's
> make that heavier to move from the other side."
>
> — the owner, 2026-09-29

## The words

| Word | Here |
|---|---|
| **a parcel** | anything handed to the switchboard: a file, or several, with whatever they hold |
| **a tag** | the first line of a parcel that asks for something: `language model prompt 14597: <what is wanted>` — numbered, and every number recorded in the ledger once |
| **a shape** | what a parcel is made of and what is wanted back, as types: `integer-array + text → image`, `program → results`, `results → finding`. The switchboard plans by shape, not by content |
| **a station** | a place that handles one shape: the studio's paintbrushes (067), the machine's own steps (describe, build, update), a program to run |
| **the router** | the light model: reads a parcel, answers with its shape and the station for it — nothing else. It never does the work |
| **a plan** | the stations a parcel passes through, in order, each one's output the next one's input, checked by shape at every joint before anything runs |

## The flow

```
  parcel ──► read the tag (if any) ──► the router: "this looks like <shape>; it goes to <station>"
                                              │ answer checked against the station table:
                                              │   a station that does not exist, or a shape
                                              │   the station does not take → sent back, named
                                              ▼
                                        the plan: stations joined by shape
                                              │   integer-array + text ─► chart words ─► .png
                                              ▼
                                        run each station ──► its result is a new parcel
                                              │
                        results that say something went wrong ("error error detected")
                                              ▼
                                        an observation: what happened, and the mechanism that let it
                                              │   "the sheep are out because they pushed through the door"
                                              ▼
                                        an adjustment: a change request to the station at fault
                                              │   "make the door heavier to move from the other side"
                                              ▼
                                        the update step (008): located, graded, amended, rebuilt
```

## The router, and why it is light

It does one small thing: name a shape and a station, from a short list.
A small local model does that well and cheaply, and one running on this
machine (ollama, on the GTX 1080 Ti) costs nothing per parcel. It is a new
row of the harness table (005) — `ollama` — with the same confinement: it
reads the parcel, writes only its answer. Its answer is checked by the
machine against the station table, so a router that invents a station is
caught the way a paintbrush catches an invented word.

| Decision | What each path leads to |
|---|---|
| The router names a station not in the table, or a shape the station does not take | Sent back with the table's nearest names, up to three times; then the parcel waits for the person |
| A plan's joint does not fit (one station's output shape is not the next one's input) | Refused before anything runs, naming the joint |
| The local model is not running | The router refuses, naming it; it does not quietly use a bigger model instead |
| A station's result holds an error | It becomes an observation, never silently dropped |

## Observation and adjustment

The third example is a loop, not a line: something ran, something went
wrong, and the fix is to the mechanism, not to the result. An
**observation** says what happened and names the mechanism that let it
happen; an **adjustment** is a change request against the station whose
mechanism it is — which the machine already knows how to locate, grade and
rebuild (phase 6). The switchboard only has to write the request.
