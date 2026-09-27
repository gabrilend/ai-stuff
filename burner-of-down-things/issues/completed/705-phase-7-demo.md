# 705 — Phase 7 demo

## Current Behavior

Built: `issues/completed/demos/phase-7-demo` and `phase-7-demo.lua`. Uses the real launcher on a scratch copy of the machine: `open`, then one `run` from source to delivered design (with one repair), a second `run` that finds nothing waiting, the design used; the center drawn as bars after the first build and after each request; two requests arriving together, shown in the order noticed and the order the center handled them; the foundation one held and released with `update --go`; the design used again; the ledger's totals as a chart; `view` writing the page, kept in the scratch space and opened in Firefox when a display is present (`NO_BROWSER=1` skips opening).

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
