# 901 — The Android app

phase 9, viewers for the pocket and the wrist

## Current behavior

Nothing exists for the phone.

## Intended behavior

A small Android app (Kotlin, built on kuvalu with the Android command-line
tools) that holds `GET /canvas?after=N` open, parses the canvas from
`docs/canvas-protocol.md`, and draws the grid with marks as colours fading
with age.

## Suggested implementation steps

1. Check whether rmail's Android client (`/home/ritz/programs/r-mail/clients/`)
   has a build setup worth reusing.
2. The app and its parser, checked against the viewer-side reader's test
   canvases (202).
3. Run on an emulator with a screenshot, then on the phone.

## Related documents

- `docs/canvas-protocol.md`
- `docs/datapath-viewers.md`

## Open questions

- Answered: the app holds an rmail mailbox and shows what it receives,
  encrypted by rmail. Whether it collects or is pushed to, and how often,
  is tuned while building (`docs/network.md`).

## Blocked by

204.

## Blocks

903.
