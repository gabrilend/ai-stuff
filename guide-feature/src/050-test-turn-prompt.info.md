# 050-test-turn-prompt — info

Tests for the turn prompt (049) with this project's own
`input/turn-instructions`:
- the reference prompt for `assets/test-prompts/01-turn-prompt.canvas`, byte
  for byte. After a deliberate change, `--write-reference` writes it again;
  read the difference before committing it;
- the parts in step 4's order, the owner's central instruction, the counts,
  the size, the look call with its limit, the exact shape seeded by the
  turn, and only this voice's own cuts;
- the ruler, up to three digit lines and wide row labels; a reply that
  copies it (whole, the row numbers alone, the bars alone, the column
  numbers alone), and the fit check's report of it;
- the ruler read back by `unruler` (405), and nil where there is none;
- empty markers: no look part, no note, no cuts, and no gap left;
- the instruction file's refusals; the look call's form.

    luajit src/050-test-turn-prompt.lua [--dir ROOT] [--write-reference]
