# 701 — The Android app

phase 7, viewers for the pocket and the wrist

## Current behavior

A phone can open the HTML page (603) in its browser.

## Intended behavior

A small Android app (Kotlin, built on kuvalu with the Android command-line
tools) that holds `GET /page?after=N&box=WxH&viewer=phone` open, parses the
page from `docs/page-protocol.md`, and draws the box with relevance as
opacity. Its `box=` comes from the screen size in monospace characters.

## Suggested implementation steps

1. Check whether rmail's Android client (`/home/ritz/programs/r-mail/clients/`)
   has a build setup worth reusing.
2. The app, its page parser, a test of the parser on the protocol's example.
3. Run on an emulator with a screenshot, then on the phone.

## Related documents

- `docs/page-protocol.md`
- `docs/datapath-viewers.md`

## Open questions

- Reaching kuvalu away from home wifi (`docs/open-questions.md`, 8).

## Blocked by

204.

## Blocks

703.
