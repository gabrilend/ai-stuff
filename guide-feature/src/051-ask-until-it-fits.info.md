# 051-ask-until-it-fits — info

Asks a voice's model until its reply fits (issue 404; `docs/fit-check.md`,
`docs/datapath-voice-turn.md` steps 5 and 6). There is no last try: "it
will just keep spinning until it gets it right."

Each ask:
1. The model is asked with the whole conversation so far.
2. A look call (`look focused: WORDS` or `look broad: WORDS`, 403) is
   answered by `answer_look`: the turn's look tool (503, 055's `looker`);
   with none given, `NO_LOOK_TOOL`. A call past `look_limit` is answered
   with `LOOKS_USED`.
   Either way the model is asked again.
3. Otherwise the reply is a try. Any one Markdown fence around the whole
   reply is taken off. The rest is checked by the fit check and by the
   copied-ruler check (403).
4. If it fits, the rows are returned, with next turn's advisory note.
5. If not, the report goes back (012's `report`), with the reply cut to the
   canvas and the owner's line when it was too large (027's `cut`). Then the
   model is asked again. A cut reply is never returned.

A failed call to the model is an error that ends the turn; it is never
retried.

| Name | Meaning |
|---|---|
| `until_fits(opts)` | opts: `call(conversation)` returning text and `{ usage, seconds }`, `conversation`, `base` (the to-voices record the turn started from), `recommended`, `look_limit`, `answer_look(look)`, `log(line)`, `give_way()` (405: asked before every ask but the first; a reason stops the loop). Returns `{ rows, note, changes, counts, conversation }`, or `{ gave_way, counts, conversation }` |
| `check(reply, base, recommended)` | the fit check plus the ruler check |
| `feedback(reply, problems, width, height)` | what a try that does not fit sends back |
| `unfence(reply)` | the reply without a fence around the whole of it, and whether there was one |
| `SETTINGS` | `input/turn`: `recommended-words`, `recommended-sentences`, `look-limit`, `newer-canvas` |
| `NO_LOOK_TOOL`, `LOOKS_USED` | the loop's own answers to look calls |

`counts`: `asks` (every call), `tries` (canvas replies checked), `problems`
(kind to how many), `look_calls`, `looks` (focus to how many answered),
`tokens = { prompt, completion }` (the server's usage, summed over asks),
and `seconds` (the model's time, summed).

Run directly, to watch a real model being corrected (step 2 of the issue):

    luajit src/051-ask-until-it-fits.lua --dir ROOT --role fg-sora-1 --canvas FILE [--turn N]

It reads `input/turn`, `input/turn-instructions` and `endpoints`, asks the
role's endpoint, and prints every reply, every try, the canvas that fit and
the counts. It exits 1, naming the endpoint, if a call fails.
