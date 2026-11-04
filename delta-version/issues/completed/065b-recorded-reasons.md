# Issue 065b: Recorded Reasons

**Status**: Completed 2026-10-10
**Parent**: 065-the-reading-walk.md
**Dependencies**: 065a
**Blocks**: 065d, 065h

## Current Behavior
Each stop in the map carries `alternatives`: passages that say why it was
done this way, each with its source file and line, gathered from two places.
On the kanji-learning-image-generator project, more than half the stops have
at least one; run the map builder for the current count.

## Intended Behavior
Only what was written down is shown; nothing is invented. A passage counts
when it holds a marker phrase ("decided against", "why not", "instead of",
"rather than", "not chosen", "was considered", "set aside", "would have",
"would be", "the choice", "chosen", "because"):
- **comment paragraphs inside the stop** (runs of comment lines between
  blank comment lines or code);
- **issue-file paragraphs** (lines between blank lines, so wrapped prose is
  not cut mid-thought) that name the stop. A word names a stop when it is five
  letters or longer, written as code writes it (with a dot or underscore), or
  four letters and the only stop with that name; shorter or shared names
  ("run", "main") would tie a stop to every paragraph using the ordinary word.
A stop with none says "no alternative was recorded here", which marks a
decision nobody wrote down.

## Suggested Implementation Steps
1. Comment paragraphs with a marker, in the first pass.
2. Issue paragraphs with a marker and a specific name, in the second pass
   (issues/ and issues/completed/).
3. Tests: one comment reason, one issue reason, one unrelated paragraph, one
   stop with nothing written.

## Decided against
- Reading issue files line by line: the first version did, and a reason came
  out as half a sentence ending at the line break.
- Having a model write alternatives where none were recorded: it would invent
  reasons the author never held and present them as the design's history.
