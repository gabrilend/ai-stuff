# 027-exact-shape — info

The exact shape a turn must fill, and a reply cut to it (issue 205). The
turn (405) shows the model the example; asking until it fits (404) uses
the cut.

| Name | Type | Meaning |
|---|---|---|
| `EXAMPLE_LINE` | string | "this is the exact shape you'll need to fill", the owner's words |
| `CUT_LINE` | string | "this is all that'd fit, please rephrase the sentences prior to the broken lines" |
| `WORDS` | table | lorem-ipsum words by length, 1 to 12 letters, so any remainder of a row can be closed by one word |
| `example(width, height, seed)` | function | `height` rows, each exactly `width` characters of whole words one space apart, a letter in the first and last columns. The same seed gives the same rows; give the turn number, so each turn gets a fresh example |
| `cut(reply, width, height)` | function | `{ rows, broken, dropped, was_cut, message }`: each row cut at the width (mid-word too), rows past the height dropped and counted, missing rows empty. For a cut reply, `message` is the cut rows, a blank line, `CUT_LINE` and what was cut, e.g. `(row 1 cut at the edge; 2 rows past the last were dropped)` |

Widths are counted in UTF-8 code points (005), as in the fit check. The
chooser is a small linear congruential generator, so the module needs
nothing but LuaJIT.
