# 053-two-spaces — the two-space renderer

**render(compiled) → frames, facts**, as `026-render-main.lua`'s spine
gives them, for a compiled score with a second space. Each frame: the
world at f/F of its loop (so a score of shapes films the bytes of the
scene it came from), the followed shapes found on the picture, every
pane's strokes stepped on the stroke clock (f/fps seconds) with its own
pool and random stream, the panes' light painted, the world panes laid
into the depth, and the frame composed by `052-frame.lua`. The runner
encodes the frames once, as it does every score.
