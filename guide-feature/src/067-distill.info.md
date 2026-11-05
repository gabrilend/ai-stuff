# 067-distill — info

Distill mode's asking (issue 601): the distiller's prompt, and one canvas
made from every voice's newest. The blitter (016) calls `run` once for the
arrivals it held; it blits the rows under the name `kuvalu`.

## The instruction file, `input/distill-instructions`

The format of `input/turn-instructions` (049's `parse_spec` reads both), in
three parts:

- `[system]`: the standing rules. Must hold `{{width}}` and `{{height}}`;
  may hold `{{words}}`, `{{sentences}}` (from `input/distill`) and
  `{{count}}` (how many voices have written).
- `[user]`: must hold `{{canvas}}` (the current canvas in its ruler) and
  `{{voices}}`; may hold `{{version}}`. The current canvas must come before
  `{{voices}}`: the stand-in distiller reads the first ruled canvas.
- `[voice]`: filled once per voice and put in place of `{{voices}}`. Must
  hold `{{name}}` and `{{voice-canvas}}`; may hold `{{turn}}`, `{{base}}`
  and `{{changes}}`.

`{{changes}}` lists the words the voice erased (removed or wrote over),
then the words it wrote, each in reading order:

    erased "cat" at row 1, column 5
    wrote "dog" at row 1, column 5

or "(no words changed against that version)".

## Settings, `input/distill`

`recommended-words`, `recommended-sentences`: the counts the distiller is
told and measured against for an advisory line (advice only). Read at every
distill, with the instruction file and the endpoints file.

## Exports

| Name | Meaning |
|---|---|
| `run(opts)` | one distill: `root`, `current`, `newest` (`{ voice, canvas, found, turn, base }` each, in order), optional `log`, optional `call` (tests); returns 051's result (`rows`, `note`, `counts`) and `endpoint`, the endpoint's name. Errors are raised for the blitter to log |
| `build(opts)` | the conversation: `instructions`, `current`, `newest`, `recommended` |
| `changes_text(found)` | the changed-word lines |
| `parse(text)`, `read_instructions(root)` | the instruction file |
| `SETTINGS`, `SPEC`, `SOURCE`, `ROLE` (`distiller`), `VOICE` (`kuvalu`) | |

Tests: `068-test-distill.lua`.
