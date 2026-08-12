# Phase 5 progress — Input drivers

Phase 5 makes the device's input surfaces visible to apps. By the
end of the phase, a 60Hz polling map fires once per frame, reads
the raw state of every button, every analog stick, and both
touch panels, compares against the previous frame, and emits
event boxes downstream apps subscribe to. The radial-menu chord
mechanism assembles D-pad-plus-face-button events. The
handedness and drawer-swap settings from phase 4 are applied at
the event-emission stage so apps downstream see events already
interpreted through the user's preferences.

Phase 5 is the first phase where most of the work is soramech
maps rather than kernel C. The C leaf boxes read GPIO and I2C
registers; the maps that wire them together fire on the
runtime's schedule.


## The engine beneath this phase changed

Phases 2 and 3 were rewritten against the ceramic design; the old
issues are in `issues/superseded/`, with a README explaining what
moved where. In this phase, 501, 502, 505 still describe the older
engine and have not been converted yet. Read them knowing that there
is no quiescence to detect — a program ends when asked, not when it
runs out of work — and "multi-spawn" is simply how every station
behaves, so a box needing to be safe under it is the ordinary rule
rather than a property some boxes have.

A reference to an issue numbered 2xx or 3xx in those files points at
the superseded issue of that number, not at the one holding that
number today.

## The story of the phase

1. `501-polling-loop-map-structure.md` — the 60Hz frame-driven
   map every other input surface hangs off.
2. `502-button-surface.md` — D-pad, ABXY, L/R, the four center
   buttons, the two stick clicks. GPIO reads as C leaf boxes,
   event boxes for down / up / held.
3. `503-analog-stick-surface.md` — left and right stick X/Y
   ADC reads, deadband, eight-direction quantization, click
   events.
4. `504-touch-panel-surface.md` — both touch panels'
   controllers, position and pressure reads, down / move / up
   events with screen id attached.
5. `505-chord-detection.md` — same-frame multi-button
   correlation, the general mechanism the radial menu uses.
6. `506-radial-menu-chord-box.md` — the specific D-pad-plus-
   face-button chord that drives text entry.
7. `507-settings-application.md` — read handedness and
   drawer-swap from `/settings/` at boot and re-read on
   change; apply them to the event stream so consumers don't
   each have to.
8. `508-phase-5-demo.md` — touch screens, push buttons, watch
   counters and surface drawings update through CDC-ACM and on
   the framebuffer.

## Completed issues

None yet.

## Open issues

All of 501 through 508.

## Phase demo

`issues/completed/demos/phase-5/run.sh` will exist once the
phase closes. It builds and flashes a kernel with a tiny test
app statically embedded: each button increments a labeled
counter, the analog sticks move a cursor, touches paint a
single bright pixel where they land. The demo passes when every
input surface produces visible output in the CDC-ACM event log
and the framebuffer matches the expected drawing.
