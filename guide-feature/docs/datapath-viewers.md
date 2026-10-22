# Datapath: from the page to a person's eyes

Every viewer reads the page protocol (`docs/page-protocol.md`) and draws the
display box (`docs/display-box.md`). No viewer computes relevance. Each one
only decides how a relevance number looks on its kind of screen.

## The path

    page keeper
       │ builds page N
       ├──► tmp/shared-memory/page/current ──► terminal view   (kuvalu)
       │                                   └─► Lua window      (kuvalu)
       └──► page server (HTTP) ──► GET /page?after=N&box=WxH
                                     ├─► HTML page   (any browser)
                                     ├─► Android app (phone)
                                     └─► Apple Watch app (watch)

## The shared parts

- **Page reader (Lua).** A small library: page text in, a page record out.
  The two Lua viewers use it, and the phase-2 tests check it against the
  protocol examples. Fields of the page record:
  - number (whole number), built (string), box width and height, share
    width and height (whole numbers);
  - voices (list of strings), over-box voices (list of strings);
  - thoughts (list of records: voice string, frame whole number, relevance
    number 0–1, text string).

  The page reader throws an error on a malformed page. It does not return a
  partly-filled record.
- **Waiting for the next page.** Local viewers watch `page/current`. Remote
  viewers hold a `GET /page?after=N` open (`docs/page-protocol.md`).
- **The other viewers** (HTML, Android, Apple Watch) each parse the page in
  their own language from the protocol document alone. That is the test that
  the protocol really is a protocol and not one program's private format.

## How each viewer shows relevance

| Viewer | Screen | Relevance becomes | Notes |
|---|---|---|---|
| Lua window | desktop window on kuvalu | opacity and a slow fade-out animation between pages; each voice its own colour | the recommended viewer, with the most room for display ideas |
| terminal view | any terminal on kuvalu | three or four brightness steps of the voice's colour, using standard terminal colour codes; below the lowest step, the thought is not drawn | "limited display features": no animation, no partial opacity |
| HTML page | any browser that can reach the page server | CSS opacity, a fade transition | the remote-access viewer |
| Android app | phone | opacity | asks the page server with its own screen size as `box=` |
| Apple Watch app | watch | opacity, or brightness | the smallest box. Under the `smallest-viewer` box rule it decides the size of the page for everyone |

A viewer whose screen is larger than the box draws the box inside it. A
viewer whose screen is smaller than the box has the wrong box rule for this
setup. It shows an error saying so, rather than squeezing the page.

## What each viewer counts

The desktop viewers write a goodbye receipt (`output/goodbye`) with pages
received, pages drawn, frames drawn, seconds run. They take
`--screenshot SECONDS` and `--key SECONDS NAME` run options, so a test can
drive them without a person and file the picture under `development-history/`.
