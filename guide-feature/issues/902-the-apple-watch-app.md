# 902 — The Apple Watch app

phase 9, viewers for the pocket and the wrist

## Current behavior

Nothing exists for the watch.

## Intended behavior

The owner: "Definitely an apple watch app."

A watchOS app (Swift, SwiftUI) that holds `GET /canvas?after=N` open and
draws the canvas, with marks as colour. The watch is the smallest screen, so
it can only show a canvas sized for it. That ties this issue to how the
canvas size is chosen (205).

## Suggested implementation steps

1. Confirm a Mac with Xcode is available (watchOS apps cannot be built on
   Linux), and how the watch reaches kuvalu.
2. The app and its parser, checked against the viewer-side reader's test
   canvases (202).
3. Run in the watch simulator with a screenshot, then on the watch.

## Related documents

- `docs/canvas-protocol.md`
- `docs/datapath-viewers.md`

## Open questions

- Is there a Mac with Xcode? (`docs/open-questions.md`, 13)
- How the watch reaches kuvalu (`docs/open-questions.md`, 2).
- Canvas size versus the watch screen (`docs/open-questions.md`, 5).

## Blocked by

204.

## Blocks

903.
