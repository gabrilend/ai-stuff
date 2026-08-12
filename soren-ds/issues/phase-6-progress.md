# Phase 6 progress — Compositor, drawers, and inter-app linkage

Phase 6 is where the visible system comes together. By the end of
the phase, multiple soramech boxes can draw into named surfaces
on either screen without painting over each other; the
compositor copies dirty surfaces forward to the screens' frame-
buffers once per frame; the four center buttons open and close
drawer overlays the foreground app populates; and apps reach
each other through named inter-app links that swap the screen's
foreground when followed.

This phase wires together pieces from every earlier phase: the
threading core (phase 2) drives the runtime, the runtime (phase
3) drives the maps, the filesystem (phase 4) holds the persisted
foregrounds and the link declarations, the input drivers (phase
5) drive the activation. Phase 6 adds the rendering and the
navigation primitives apps depend on.


## The engine beneath this phase changed

Phases 2 and 3 were rewritten against the ceramic design; the old
issues are in `issues/superseded/`, with a README explaining what
moved where. In this phase, 602, 610 still describe the older
engine and have not been converted yet. Read them knowing that a value
is delivered by writing into a cell whose own state is the lock, with
no gathering function anywhere; "multi-spawn" is the ordinary rule.

A reference to an issue numbered 2xx or 3xx in those files points at
the superseded issue of that number, not at the one holding that
number today.

## The story of the phase

1. `601-surface-allocation-and-ownership.md` — request a surface
   on a screen at a position; get a handle to draw into.
2. `602-damage-tracking.md` — surfaces mark themselves dirty
   when written; the compositor scans dirty surfaces per frame.
3. `603-compositor-render-loop.md` — once per frame, copy dirty
   surfaces into the right screen's framebuffer.
4. `604-per-screen-foreground.md` — only the foreground app's
   surfaces composite forward; background apps' surfaces stay
   allocated and updated but invisible.
5. `605-boot-foreground-restoration.md` — read the persisted
   last-foreground apps from `/settings/` and start them on
   their respective screens.
6. `606-drawer-surface-mechanism.md` — drawers as overlay
   surfaces that slide in from the screen edge.
7. `607-drawer-button-activation.md` — wire the center-button
   events from phase 5 to opening and closing drawers.
8. `608-drawer-content-delegation.md` — apps populate their
   drawers with utility menus.
9. `609-inter-app-link-declarations.md` — every app declares a
   set of named exits with the target app and the value carried
   forward.
10. `610-link-transition.md` — following a link swaps the
    screen's foreground to the linked app with the value
    delivered to its entry box.
11. `611-phase-6-demo.md` — two trivial apps cross-link across
    screens; drawers open and close; the user walks both
    directions through the link pair.

## Completed issues

None yet.

## Open issues

All of 601 through 611.

## Phase demo

`issues/completed/demos/phase-6/run.sh` will exist once the
phase closes. It builds and flashes a kernel with two trivial
demo apps statically embedded. The user walks through: open the
drawer on the bottom screen, follow a link to the second app on
the top screen, open the second app's drawer, follow its link
back to the first app on the bottom screen. The demo passes
when each transition lands cleanly and both apps' state
survives the round trip.
