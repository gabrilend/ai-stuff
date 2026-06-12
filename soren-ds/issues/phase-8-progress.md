# Phase 8 progress — The four apps

Phase 8 ships the launch system's apps. By the end of the phase,
the device runs the soramech-style programming environment, the
dual-pane text editor, the pictochat-style messenger, and the
paint program — each as a soramech map composed mostly of boxes
the earlier phases already shipped. The four apps are built in
dependency order. The messenger's text features land before the
paint program; once paint ships, the messenger's image-attachment
exit lights up and the launch system is complete.

The roadmap calls phase 8 "mostly composition," and that holds:
the input pipeline (phase 5), the compositor and drawers (phase
6), the networking (phase 7), the filesystem (phase 4), and the
runtime (phase 3) carry most of the per-app work. Each app's
issue set covers only its specific UI layout, state, and the few
boxes that don't fit anywhere else.

## The story of the phase

1. `801-editor-rendering-and-input.md` — text panels, vim modes,
   radial-menu chord text entry.
2. `802-editor-persistence-and-integration.md` — open and save
   documents; drawer and inter-app exits.
3. `803-programming-environment-http-and-canvas.md` — on-device
   HTTP server and the editor canvas it serves.
4. `804-programming-environment-run-and-integration.md` —
   running a map from the canvas; drawer and exits.
5. `805-messenger-ui.md` — conversation view, peer list, input
   area.
6. `806-messenger-send-receive-and-persistence.md` — wires
   rmail boxes; stores history.
7. `807-messenger-drawer-and-exits.md` — peer-switching,
   message actions, the image exit (grayed until paint ships).
8. `808-paint-canvas-and-stylus.md` — touch-to-pixel rendering;
   undo and clear.
9. `809-paint-tools-and-handedness.md` — brush, eraser, color
   selection routed through the handedness setting.
10. `810-paint-persistence-and-messenger-handoff.md` — save and
    load drawings; the image return path that lights up the
    messenger's attachment exit.
11. `811-phase-8-demo.md` — each app used for its actual
    purpose, with the paint-to-messenger flow as the proof.

## Completed issues

None yet.

## Open issues

All of 801 through 811.

## Phase demo

`issues/completed/demos/phase-8/run.sh` will exist once the
phase closes. It builds and flashes two devices, launches each
app in turn (the editor on one, the programming environment on
the other; the messenger on both; the paint program on one
sending an image to the other). The demo passes when a written
message arrives, a programmed map runs, a painted picture is
authored, and the picture is delivered as an attachment through
the messenger.
