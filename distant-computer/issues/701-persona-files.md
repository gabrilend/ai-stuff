# 701 — Persona files

phase 7, the voices

## Current behavior

Nothing exists.

## Intended behavior

The vision's "threaded experts (personalities) that relate to the user at
whatever level of abstraction they please". A **voice** is a file in
`voices/<name>`: its name, its level of abstraction when talking to the
owner (from "the metal" to "the shape of the whole"), what it is responsible
for, and a short self-description in its own words. The steward loop picks
a voice for each turn by the work's kind, and puts its file into the turn
prompt. Requests carry `from: <voice>`.

## Suggested implementation steps

1. The voice file format and reader.
2. Choosing a voice per turn (a table from work kind to voice).
3. Two or three first voices, written by the steward itself and filed as
   `commit` requests, so the owner meets them through the gate.

## Related documents

- `docs/core-terms.md`, "voice"

## Blocked by

602.

## Blocks

702, 703.
