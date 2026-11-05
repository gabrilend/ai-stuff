# 020-marks — info

Marks for skimming (issue 201). After each blit, the blitter (016) calls
`mark` with the canvas the blit started from, the new canvas, the blit's
report, the voice and the new version:

- every cell the blit wrote or blanked gets a `word` mark;
- the words of every sentence holding such a cell get a `sentence` mark,
  on the words only, not the spaces between them;
- orphan cells in the report (`report.orphans`, from a future
  `fade-fragments`) get `orphan` marks;
- a cell keeps only its newest mark;
- an older mark more than `lifetime` versions old is dropped and counted.
  Expired orphan cells are listed for blanking.

A blanked cell that is in no word belongs to the sentence of the word
before it on its row, unless that word ends its sentence. Otherwise it
belongs to the sentence of the word after it on its row. If its row is now
empty, it belongs to none.

| Name | Type | Meaning |
|---|---|---|
| `mark(current, new, report, voice, version, lifetime)` | function | `{ marks = runs, counts = { word, sentence, orphan, expired }, expired_orphans }`; counts are in cells |
| `grid(record)` | function | a record's mark runs as `grid[row][column] = { voice, version, kind }` |
| `runs(grid, width, height)` | function | a grid back into runs: the longest stretches on a row with equal voice, version and kind |
| `age(mark, version)` | function | `version - mark.version` |
