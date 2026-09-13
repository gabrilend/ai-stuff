# 202 - The source registry

| | |
|---|---|
| Phase | 2 - the harvester |
| Blocked by | 201 |
| Blocks | the scheduler, the archive's branch decision, the licence audit |

## Current behaviour

The survey document lists sources in prose. Nothing machine-readable names them.

## Intended behaviour

One entry per place worth asking, as data. The entry is the single place where
everything about a source is stated, so that adding a source is adding a table
entry rather than editing five files.

| Field | Type | Meaning |
|---|---|---|
| `name` | string | what it is called in logs and provenance |
| `address` | table | how to build a request to it |
| `answers_in` | string | the shape it replies in, which decides the extractor |
| `politeness` | table | the pacing rules of issue 203 |
| `licence` | string | one of: verified redistributable, verified not redistributable, unchecked |
| `licence_note` | string | what was actually read, and where, so the judgement can be re-checked |
| `derived_licence` | string | whether facts *extracted* from it may be redistributed, which is a separate question from whether its bytes may be |
| `split_seam` | string | how a bulk response from it gets cut into small specific files |

The two licence fields being separate is deliberate. A source may forbid
rehosting its files while placing no restriction on the numbers read out of
them, or the reverse. Collapsing them into one field forces the stricter answer
onto both and would needlessly keep facts out of the history branch.

An entry with `licence` unchecked behaves exactly as if it were forbidden. The
failure of not having looked and the failure of having been refused have the
same consequence for someone else's rights.

## Suggested implementation steps

1. Write the registry as a Lua table, one entry per source, with the five open
   sources from the survey document as its first entries.
2. Make the unchecked default explicit in the entry rather than implied by
   absence, so that nobody has to know the rule to read the file correctly.
3. Validate the registry on load: an entry naming an extractor that does not
   exist, or a split seam that no splitter implements, is an error at startup
   rather than a surprise halfway through a long harvest.
