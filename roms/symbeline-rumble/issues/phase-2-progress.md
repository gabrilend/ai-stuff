# Phase 2 progress

**Goal of phase 2** (from `docs/009-roadmap.md`):

> By the end of Phase 2, both targets can render a static 3D scene in
> the sharp band with tilt-shift framing (DS: layered backdrops;
> native: shader post-process). The bottom screen / lower window half
> shows a tactical inset of the same scene.

## Issues in phase 2

| ID  | Title                                        | Status   | Notes |
|-----|----------------------------------------------|----------|-------|
| 201 | Render seam expansion                        | pending  |       |
| 202 | Vertical window and dual-screen layout       | pending  |       |
| 203 | Camera and perspective                       | pending  |       |
| 204 | Model format and loader                      | pending  |       |
| 205 | Texture format and loader                    | pending  |       |
| 206 | Tilt-shift divergence                        | pending  |       |
| 207 | Sharp band rule enforcement                  | pending  |       |
| 208 | Still-life scene assembly                    | pending  |       |
| 209 | Phase 2 capstone demo                        | pending  |       |

## What "done" means for phase 2

- The render seam (camera, mesh, texture, tilt-shift hook, viewport)
  is in place and used by gameplay-shaped code, not just a hello.
- The asset pipeline emits `.srm`, `.srt`, `.srs` files from authoring
  sources, deterministically and per-profile where appropriate.
- The tilt-shift divergence (row D1) is implemented as a paired
  apply/unapply patch per target. The trunk is unaware of the
  technique.
- The sharp-band rule is enforced in code, not just aspiration.
- The capstone produces side-by-side frames and a parity score.

## Forward-stubs introduced in phase 2

(To fill in as issues complete. None expected in phase 2 itself —
phase 2 is the consumer of phase-1 stubs, not the introducer of new
ones.)

## Lessons learned

(To be filled in as issues complete.)

## Deprecated / temporary files

(To be filled in as issues complete.)

## Open questions raised during phase 2

(To be filled in as issues complete. Anticipated: the parity score's
honest threshold, the .srs format's eventual extension surface, how
to author the pre-blurred backdrop sprites without making them
authoring chores.)

## Parity-may-be-pessimism evaluation

The capstone demo (issue 209) tests
`notes/sketches/parity-may-be-pessimism.md`. The evaluation goes here
when the screenshots are reviewed:

- [ ] Native frame looks like a fan-port of the DS frame (hunch
      confirmed; revise parity rule for phase 3).
- [ ] Two frames read as the same game on different screens (hunch
      refuted; parity rule stands).
- [ ] Inconclusive — needs more cases / a different scene to evaluate.
