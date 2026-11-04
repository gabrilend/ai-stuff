# 007b — Reading a description

**Phase:** 0 — Tools
**Parent:** 007
**Blocked by:** 007a
**Blocks:** 007c

## Current Behavior
Built in `src/013-reading-a-description.lua`. Sentences are cut at full
stops (not inside numbers), words joined into phrases and stripped of
articles, then matched against the sentence shapes (a list of matchers
tried in order). Refusals come all at once: unknown words with every
equally near legal word ("'wide' or 'wider'"), unknown part names with the
nearest name, ambiguous kind references with the candidates, and a
sentence whose name was only an article ("The a is a box") said plainly.
A part may be measured by itself only in two different extents.

## Intended Behavior
A description's sentences (split on full stops and line ends; case and the
words a, an, the ignored) become statements: { line (whole), kind of
statement (string), subject (part name, string), and its fields }. Part names
are whatever words a declaration used ("the left wheel is a cylinder" names
"left wheel"). A part can also be called by its kind when only one part has
that kind: "the cylinder", "the cylinder shaped thing".

The wall: every sentence that matches no shape, every unknown part name, and
every word outside the vocabulary is reported, all in one pass, with its line
and the nearest legal word (by edit distance) or nearest part name.

## Suggested Implementation Steps
1. src/013-reading-a-description.lua.
2. Tests: each sentence shape reads; a misspelt word gets its suggestion;
   three broken lines give three errors in one run; an ambiguous "the
   cylinder" lists the candidates.
