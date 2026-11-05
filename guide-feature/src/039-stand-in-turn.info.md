# 039-stand-in-turn — info

Phase 3's turn (issue 304), until the real one (405) replaces it in
`input/turn-runner`'s `turn` setting. Run by the turn runner as

    scripts/stand-in-turn --dir ROOT --voice NAME --turn N --canvas FILE --out FILE

It reads the to-voices canvas, waits `seconds`, and writes the from-voice
canvas with one word from `words` (both in `input/stand-in-turn`):
word `(turn-1) % #words + 1`, at row `(turn-1) % height + 1`, column
`1 + (n-1) * floor(width/3)` where `n` is the number ending the voice's
name, cut to fit its third. A word already there makes an unchanged turn.

| Function | Meaning |
|---|---|
| `edit(record, voice, turn, words)` | the from-voice record for one turn |
