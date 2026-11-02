# 1003c — The drafts folder

The third piece of 1003.

## Current Behavior

Built. One file per mechanism, `strategems/drafts/<mechanism's words
joined by dashes>.md` (`name_for`, the hand-written strategems' own naming
style). Each draft records its mechanism on its own `Mechanism:` line,
which `known` reads back, so a mechanism with a draft (or a kept
strategem) is never drafted twice. On a further recurrence `draft_due`
rewrites only the draft's examples section (`with_examples`), keeping
every other section byte for byte — including anything the person has
written there — and an unchanged lessons file changes nothing. Checked by
`tests/113-checking-the-drafts-folder.lua`.

Decision: two mechanisms that differ only in case or punctuation would
share a file name; that is refused, naming both, rather than one quietly
overwriting the other's draft.

## Intended Behavior

Drafts are written to `strategems/drafts/`, one file per mechanism, never
duplicated — a further recurrence updates the existing draft's examples
rather than writing a second file. Done (`name_for`, `with_examples`).

## Suggested Implementation Steps

1. The one-file-per-mechanism naming rule. 2. The update-in-place on a
   further recurrence. **Test:** a third lesson of an already-drafted
   mechanism updates that draft's example list rather than creating a
   second file. Done (`name_for`, `with_examples`).

## Blocked by

- 1003b
