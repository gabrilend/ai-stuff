# 1003d — The promotion gate

The fourth piece of 1003.

## Current Behavior

Built. `scripts/116-promote-strategem.lua [project] <draft>` is the
person's own step: it moves `strategems/drafts/<draft>.md` to
`strategems/<draft>.md`, retitles it `Strategem:` and names any section
still not written (`111-the-strategem-drafts.lua`'s `promote`). It
refuses a missing draft, a name reaching outside `drafts/`, and a
strategem already kept under that name. Nothing in the machine calls it,
and a turn cannot run it (turns have no command tools). After keeping, a
further recurrence of that mechanism neither drafts again nor touches the
kept file; it is only reported. Checked by
`tests/114-checking-the-promotion-gate.lua`: through four recurrences the
drafting command writes nothing in `strategems/` itself, and the draft
appears there only after the script is run.

Decision: the promotion keeps the move a move (one file, same name) and
changes only the title line; the person changes the rest as they choose.

## Intended Behavior

A draft becomes a strategem only when the person moves it
(`strategems/drafts/x.md` → `strategems/x.md`); the machine never
promotes its own draft.

## Suggested Implementation Steps

1. A promotion command the person runs. **Test:** a draft never appears
   in `strategems/` without that command having been run by a person's
   own invocation, never from within the drafting turn itself. Done: `scripts/116-promote-strategem.lua`.

## Blocked by

- 1003c
