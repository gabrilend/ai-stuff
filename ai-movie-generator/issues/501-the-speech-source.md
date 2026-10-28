# 501 — the speech source

phase 5, the monologue booth

**Depends on:** 101

## Current behavior

No speech exists. Whether speech is recorded or synthesised is an open question.

## Intended behavior

A monologue's audio is either a supplied file or synthesised from its text by a local voice engine, decided by the owner's answer to the open question.

## Suggested implementation steps

1. Answer the open question.
2. If synthesised: confirm the engine and voice model; one voice per cast member.

## Related documents

- docs/datapath-monologue.md
- docs/open-questions.md
