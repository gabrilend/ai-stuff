<!-- Made by Claude (Opus 5.5), 2026-10-10, from notes/vision, during project initialisation, as the datapath for input decisions; updated whenever an issue changes it. -->
# Datapath: input decisions

```
dial turned       → { dial: one of six (left/right × forward/back/ear), steps: integer, signed }
button pressed    → { button: "A" or "B", down: boolean }
pocket stick      → { x: number −1..1, y: number −1..1 }
cuff (if on)      → same shape as the stick, or as a dial
  → decision table (one entry per input, each pointing to an action;
    a table rather than a chain of if-else)
  → actions:
      change what is shown  → new picture → datapath-light
      move the panel arm    → { reach: number (mm out from the face),
                                turn: number (degrees about the arm's axis) }
```

No taps. No gaze. Every decision is a deliberate physical motion.
