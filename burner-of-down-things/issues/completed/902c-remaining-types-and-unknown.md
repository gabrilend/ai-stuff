# 902c — Remaining types, and `unknown`

The third piece of 902.

## Current Behavior

Built. `src/081-the-shape-types.lua`'s `recognise(bytes, path)` now has a
recogniser for each of the five remaining types, and answers `unknown`
when none of the closed list matches:
- `program`: a `#!` line, or (path known) an executable file;
- `request`: a first line that is a well-formed tag (`language model
  prompt <number>: <what is wanted>`, 079's form);
- `finding`: a `## ` heading and a `Mechanism: ` line — the Markdown form
  lessons (085) already write and observations (906) will;
- `results`: a well-formed JSON object or array, as the harnesses write
  `result.json` (037), read by a strict checker that builds nothing;
- `source`: 027's language table gives the file's name the role `code`.
`recognise_file` takes a parcel file (079's `{name, path}`). Checked by
`tests/124-checking-remaining-types.lua`, against one fixture per type in
`tests/fixtures/shape-types/`.

Decisions: "the machine's own JSON/markdown shapes" are read as the forms
the machine already writes — result.json for results, the lesson section
for a finding, the tag for a request — so no new format is invented. The
order is program, request, finding, results, source, then 902a's scalars:
each of these is also valid text, and a `#!` script is a program before it
is source. `source` needs a name: the same code with no path is `text`,
not guessed. An empty or space-only file is `unknown` (nothing to
recognise), not `text`. 902a's check expected nil for bytes matching
nothing, the fall-through 902a itself said would end in `unknown` once
902c existed; it now expects `unknown`, still asserting the same thing
(never guessed).

## Intended Behavior

Recognisers for `source` (027's language table says it is code), `program`
(executable bit or a shebang), `results`/`finding`/`request` (the
machine's own JSON/markdown shapes). Anything matching none of the closed
list is `unknown` — never a guess.

## Suggested Implementation Steps

1. The remaining five recognisers. 2. The `unknown` fallback. **Test:**
   an unknown thing is `unknown`, never assigned a guessed type. Done.

## Blocked by

- 902a
- 902b
