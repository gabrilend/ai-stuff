# 104 — How near each word is

## Current behavior

Nothing exists. Depends on `103` for hover records to read.

## Intended behavior

**From a hover record, produce the proximity spectrum: one number between 0
and 1 per word, saying how near it is to the pointer.** The shape of the
computation is in `docs/002-datapath-the-hover.md`.

Two distances per word, each through its own falloff:

- **along the line** — for words on the pointer's line, how many words away;
  for words on other lines, the horizontal distance in pixels from the
  pointer's word divided by the average word width, so a word directly above
  counts as near along-the-line
- **across lines** — how many lines away

The two falloff results are multiplied. The pointer's word is exactly 1. The
curve shape (how quickly it fades) and its width (how far before it is near
zero) are parameters, not constants in the code; `105` supplies them.

**The spectrum is a list of plain numbers, in word order**, so anything
downstream can read it without knowing how it was made. The paragraph and
spectrum together are the "weighted paragraph" `303` reads.

## Suggested implementation steps

1. `src/` — the spectrum module: one function from (hover record, falloff
   parameters) to list of numbers. Allocate the result list at full length
   first, then fill each slot; no slot depends on another, so a pool of workers
   can fill slices of a long paragraph.
2. Tests on the fixtures: pointer's word is 1; every value is between 0 and 1;
   values on the pointer's line fall monotonically away from it; a word
   directly above the pointer outweighs a word the same number of lines up at
   the far end of its line.
3. A text dump for eyeballing: each line of the paragraph printed with each
   word followed by its weight to two places.

## Related

`docs/002-datapath-the-hover.md` · needs `103` · blocks `105`, `106`
