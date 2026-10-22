# 702 — The Apple Watch app

phase 7, viewers for the pocket and the wrist

## Current behavior

Nothing exists for the watch.

## Intended behavior

The owner: "Definitely an apple watch app."

A watchOS app (Swift, SwiftUI) that holds
`GET /page?after=N&box=WxH&viewer=watch` open and draws the box on the watch
face, relevance as opacity. The watch is the smallest screen, so under the
`smallest-viewer` box rule it sets the page's size for everyone, and the
voices then write for the wrist.

## Suggested implementation steps

1. Confirm a Mac with Xcode is available (watchOS apps cannot be built on
   Linux) and how the watch reaches kuvalu: directly over home wifi, or
   through its paired iPhone.
2. The app and its page parser, tested on the protocol's example.
3. Run in the watch simulator with a screenshot, then on the watch.

## Related documents

- `docs/page-protocol.md`
- `docs/datapath-viewers.md`
- `docs/display-box.md`, "Who decides the size"

## Open questions

- Is there a Mac with Xcode? (`docs/open-questions.md`, 13)
- Reaching kuvalu away from home (`docs/open-questions.md`, 8).

## Blocked by

204.

## Blocks

703.
