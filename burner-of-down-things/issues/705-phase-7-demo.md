# 705 — Phase 7 demo

## Current Behavior

No demo.

## Intended Behavior

`issues/completed/demos/phase-7-demo`: a fresh case taken from source to
delivered design with one `run` (every phase before this one working
together), then a stream of requests dropped in one by one, the center
printed after each as a bar chart in the terminal — showing its weight
shift toward what is being asked about — and the order of the next requests
changing with it. Ends by writing the case viewer and opening it in Firefox
when a display is present.

## Suggested Implementation Steps

1. The demo script. **Test:** runs through `./run-phase-demo 7` with no
   display (the viewer written, not opened).

## Blocked by

- 704
