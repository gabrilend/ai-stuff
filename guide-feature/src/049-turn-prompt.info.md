# 049-turn-prompt — info

The conversation a voice's turn begins with (issue 403), in the order of
`docs/datapath-voice-turn.md`, step 4. The words are in
`input/turn-instructions`, not here, so the owner can change how the voices
are spoken to without touching source.

## The instruction file

Three parts, each starting with `[system]`, `[user]` or `[look]` on a line
of its own. A line starting with `#` is a comment. `{{name}}` markers are
filled in: `voice`, `width`, `height`, `words`, `sentences`, `version`,
`look-limit`, `look` (the `[look]` part, left out when the look limit is
0), `shape` (an exact-shape example, seeded by the turn), `note` (the last
turn's advisory note), `cuts` (the words this voice's last edit cut) and
`canvas` (the canvas inside its ruler). A marker alone on its line that is
filled with nothing takes its line with it, and runs of blank lines close
up to one.

The file is refused, naming its line, for:
- text before the first part;
- an unknown or repeated part, or a missing one;
- an unknown or unclosed marker;
- a `[system]` part without the size and counts, or a `[user]` part without
  the canvas.

## The ruler

        |         1         2
        |12345678901234567890
      1 |the kitten  on the  |
      2 |mat.                |

Column numbers read downwards above the canvas, with a hundreds line past
100 columns. The row numbers are right-aligned, and a `|` sits at each end
of each row. `ruler_problem(reply)` finds a reply that copied any of it.

## Exports

| Name | Meaning |
|---|---|
| `read_instructions(root)` | `input/turn-instructions`'s text |
| `parse(text)` | its parts, checked: `{ system, user, look }` |
| `parse_spec(text, spec)` | any instruction file's parts by a spec `{ source, parts, markers, required }`; the distill prompt (067) reads `input/distill-instructions` with it |
| `fill(body, values)` | a part with its markers filled; a marker alone on its line filled with nothing takes the line |
| `build(opts)` | `{ { role = "system", content }, { role = "user", content } }`; opts: `instructions`, `canvas` (a to-voices record), `voice`, `turn`, `recommended = { words, sentences }`, `look_limit`, `note` |
| `ruler(record)` | the canvas as the model sees it |
| `ruler_problem(reply)` | `{ kind = "ruler", rows }` or nil; 012 has its report line |
| `unruler(text)` | the rows of a ruler drawn in a text, or nil (the stand-in model reads its canvas with it, 405) |
| `look_call(reply)` | `{ focus = "focused"\|"broad", words }` when the reply is one `look FOCUS: WORDS` line, else nil |
| `SOURCE`, `PARTS`, `MARKERS`, `REQUIRED`, `SPEC` | the file's name, parts and markers, and the four as one spec |
