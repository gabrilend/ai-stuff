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

Built as portable C and proven on the laptop twin, whose two screens
stand in for the device's framebuffers.

- **601** surfaces: a rectangle of one screen granted to one owner (a
  station, or the system) where no other owner holds any of it; moved
  and resized under the same check; back to front in the order granted;
  handles that never reach a later grant in the same slot; pixels that
  are retired, not freed, so a box still writing through them is safe.

`src/system/104-surfaces.c`. Test: `twin/tests/105` (32 checks, four
threads asking for overlapping rectangles among them).

- **602** the damage bit: owners mark a surface after writing it; the
  compositor takes the mark (reads and clears in one step) before
  copying, so a mark made during the copy is never lost. Grants,
  resizes and moves mark it.

Also `104-surfaces.c`. Test: `twin/tests/106` (18 checks, three writers
against one compositor thread among them).

- **603** the compositor's frame: a map on its own 60 Hz timer, one frame
  at a time, copies marked surfaces back to front. Where a surface was,
  it first paints the system's background colour; anything over what it
  painted or copied is copied again.

`src/system/107-compositor.c`, the `composite` box in
`src/boxes/108-compositor.c`, `src/maps/compositor.map`. Test:
`twin/tests/109` (24 checks).

- **604** one foreground app per screen: an app is a top-level program;
  only the foreground's surfaces and the system's are copied, and each
  app has the screen to itself, so a background app keeps its surfaces
  where the foreground has its own. A change paints the screen whole.
  Apps hear of changes through the `foreground_changed` event box.

`src/system/110-foreground.c`, `src/boxes/111-foreground.c`,
`program_app_of` in 068. Test: `twin/tests/112` (26 checks).

- **606** the four drawers: the system's, beside the surface table,
  sliding in from their edge in six frames and drawn over everything.
  Each step exposes where the drawer was, so the foreground's surfaces
  and the background come back as the cover lifts. Opened and closed
  from C for now; the center buttons are 607.

`src/system/113-drawers.c`, called from 603's frame. Test:
`twin/tests/114` (26 checks).

## Open issues

Sorted by what each one waits on (scoped once phase 5's twin halves
were built, against main as it stood then). "Unmerged" names the open
pull request a blocker is waiting in.

**Buildable on the twin now.** None left: 601–604 and 606 are built
above, and every other issue waits on a pull request or the device.

**Blocked on an unmerged pull request.**

- **605** — reads the last foregrounds from `/settings/` (408, #48)
  through `read-path` (406, #35).
- **607** — the center buttons' events (502, #218) through the
  drawer-swap setting (507, which itself waits on #48 and #35).
- **608** — drawer contents present the radial menu (506, waiting on
  #35) and hang off 607.
- **609**, **610** — inter-app links, after 608.
- **612** — looks: each app split into its state and a look the user
  chooses (added on main 2026-10-18). Draws into 601's surfaces through
  603; waits on 609 and on 409 and 411 (#69, #83, #92).

**Needs the device.**

- **611** — the demo is the handheld's two screens.
- The device half of 603: copying into the framebuffers the display
  controller scans out (111a–111d, still open).

## Phase demo

`issues/completed/demos/phase-6/run.sh` will exist once the
phase closes. It builds and flashes a kernel with two trivial
demo apps statically embedded. The user walks through: open the
drawer on the bottom screen, follow a link to the second app on
the top screen, open the second app's drawer, follow its link
back to the first app on the bottom screen. The demo passes
when each transition lands cleanly and both apps' state
survives the round trip.
