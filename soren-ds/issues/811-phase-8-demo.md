# 811 — Phase 8 demo

## Current behavior

Issues 801 through 810 produce the four launch apps. Each works
in isolation; the inter-app links between them — paint to
messenger especially — light up only with everything in place.
Phase 8 needs an end-to-end demo that exercises every app for
its actual purpose.

## Intended behavior

Two handhelds, one laptop, scripted in
`issues/completed/demos/phase-8/run.sh`:

### 1. The editor

- The user (prompted by the script) opens the text editor on
  handheld A's bottom screen.
- Types a short paragraph using the radial-menu chord.
- Saves the document via the drawer to `/programs/note.txt`.
- Switches to insert mode and back to cursor mode.
- The script asserts the file lands on disk with the expected
  bytes and the editor's mode display tracks the L+R toggle.

### 2. The programming environment

- The user opens the programming environment on handheld A's
  top screen.
- The laptop's browser visits `http://<A>:7700/` and the
  editor canvas loads.
- The user builds a small map in the laptop canvas: a `read`
  box emitting "world" wired into the demo's `formatter` box
  wired into `debug-write`.
- Clicks Run. The output streams back through the HTTP
  response: "Hello, world!" appears in the laptop UI and in
  the on-device map view.
- The user edits the formatter to return a different greeting;
  saves; the hot-swap mechanism (411) replaces the running
  generation; the next Run shows the new greeting.
- The script asserts each step.

### 3. The messenger (text first)

- The user opens the messenger on both handhelds. Each device
  appears in the other's peer table.
- A types a short message to B and sends. B's messenger receives.
- B replies. A receives.
- The script asserts both messages persist under
  `/messages/<peer>/` on both devices.

### 4. The paint program and the image handoff

- The user opens paint on handheld A.
- Draws a small known shape (a circle with a known center and
  radius the script can sample).
- Saves the drawing to `/drawings/circle.png`.
- The script samples the saved bitmap at the expected pixel
  positions and asserts the circle is where it should be.

### 5. The full inter-app round trip

- The user opens the messenger on A. The "attach image" drawer
  option is no longer greyed (paint is installed).
- Picks "attach image" — the link follows to paint.
- Loads `/drawings/circle.png` from paint's drawer; follows
  the "to messenger" exit.
- The messenger gets the image in its compose buffer with a
  preview thumbnail.
- The user sends the message with the image to B.
- B's messenger receives the message AND the image attachment.
- The script asserts the received PNG matches the original
  bitwise.

## Suggested implementation steps

1. The script's multi-device, multi-screen orchestration.
2. The map and document seeds the script uses.
3. The bitmap sampler that asserts the painted circle's shape.
4. Per-step pass/fail reporting.

## Related documents

- `docs/002-roadmap.md` — phase 8 demo description.
- `docs/008-apps-overview.md`.

## Blocked by

All of 801 through 810.

## Closes

Phase 8.
