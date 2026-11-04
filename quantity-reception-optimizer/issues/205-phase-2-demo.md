# 205 — Phase 2 demo: a page that answers

## Current behavior

Nothing exists. Needs `201`–`204`.

## Intended behavior

**The extension, live, on a page of quantities.**

`issues/completed/demos/phase-2-demo` installs the host manifest, starts
Firefox with the extension loaded temporarily (`web-ext run`, if it is
installed; otherwise the script says so and stops), and opens a demo page built
from phase 1's fixture paragraphs.

Hovering a quantity draws a plain box beside it with the host's answer: the
quantity record, and the paragraph tinted by its proximity spectrum — phase 1's
picture, now drawn live from the real pointer. Changing the policy in the
settings page and hovering again shows the tint widen or narrow.

A strip at the top of the page counts: hovers sent, quantities found,
no-quantity answers, and the round-trip time (median and slowest) in
milliseconds.

Beside it, the second bridge: the ComfyUI server's address, whether it
answered, its queue length, and a button-free test — hovering the strip's
"ComfyUI" label sends the small fixed graph from `204` and shows the picture
that comes back, with how many seconds it took.

## Suggested implementation steps

1. The demo page and its counter strip.
2. The demo script, which rebuilds the RAM folders behind `tmp/` first.
3. Check `run-phase-demo` lists and runs it.

## Related

needs `201`, `202`, `203`, `204`
