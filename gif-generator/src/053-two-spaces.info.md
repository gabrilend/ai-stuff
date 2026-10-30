# 053-two-spaces — the two-space renderer

**render(compiled, show) → frames, facts**, as `026-render-main.lua`'s spine
gives them, for a compiled score with a second space. Each frame: the
world at f/F of its loop (so a score of shapes films the bytes of the
scene it came from), the followed shapes found on the picture, every
pane's strokes stepped on the stroke clock (f/fps seconds) with its own
pool and random stream, the panes' light painted, the world panes laid
into the depth, and the frame composed by `052-frame.lua`. The runner
encodes the frames once, as it does every score.

`show` films one half of the score, so the composition can be watched
(the phase 7 demo, `issues/completed/demos/phase-7/`): `"world"` is the
shapes alone (no pane's light, no background glow), and is byte-identical
to the score with its strokes and panes taken away; `"light"` is the
panes' light alone, still hidden and shown by the shapes' depth. Left
out, both, as every score films.
