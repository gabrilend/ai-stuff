# 504 — Hover to picture

## Current behavior

Nothing exists. Needs everything else.

## Intended behavior

**The capstone: the vision, working.** A reader with the extension installed
moves the pointer onto `1234 kg` on any page, and within the time it takes to
draw one picture sees two horses standing side by side — or whatever the
paragraph made more fitting — with one sentence saying "about as heavy as two
horses". They ask for
another with the gesture from `502` and get a different kind of thing.
Changing the context policy in the settings page changes which comparison is
chosen for the same quantity.

This issue is the joining and the checking:

- every message type in `docs/006` is sent and handled somewhere
- every setting the code reads is in the settings file, and every entry in the
  settings file is read somewhere
- the host, started by Firefox, reads `input/` first and writes `goodbye` to
  `output/` when Firefox closes
- no fallback anywhere: grep for any path that substitutes a guess for an
  error, and either remove it or open an issue for it

**And the phase 5 demo**, which is the product itself:
`issues/completed/demos/phase-5-demo` starts ComfyUI's check, the language
model's check, and Firefox with the extension, on a page of quantities from
every dimension. A strip across the top counts, live: hovers, pictures drawn,
pictures from cache, re-rolls, exhaustions, median seconds from hover to
sentence and from hover to picture.

## Suggested implementation steps

1. Walk the whole path by hand on five real pages; write down every rough edge
   as an update to the issue that owns it.
2. The consistency checks above, as a script that runs with the tests.
3. The demo page and script; check `run-phase-demo` lists and runs it.
4. Update every datapath document to describe what was built.

## Related

needs `106`, `205`, `305`, `404`, `501`, `502`, `503`
