# 018-tracks — the track and the timeline

A track binds an activation window, a motion easing, a fade
envelope, a path, and an emitter recipe: one stroke's complete
instructions. The timeline is the array of tracks plus the one step
that runs a whole simulation tick. Sequencing is nothing but
windows — all ordering became numbers at compile time; the runtime
never resolves a dependency. Windows are half-open (alive at their
first instant, gone at exactly start plus duration) so meeting
windows hand off with neither gap nor doubled tick.

## Usable surface

- **track(spec) → track** — spot track: emitter riding a path's tip.
  Refuses zero-duration strokes. Each track carries its own
  emit_tick closure, so field tracks (the fills module) join the
  same timeline without the step ever asking what kind it holds.
- **where(track, t) → x, y, hx, hy, strength | nil** — interrogation
  without consequence, for tests and viewers.
- **window(track, t) → u | nil** — the half-open window fraction.
- **endpoint(track) → x, y** — the landmark later strokes borrow.
- **timeline(list, fx, fy) → timeline** — tracks plus the scene's
  constant force, explicit.
- **step(timeline, pool, rng, t, dt)** — every active track paints,
  then physics moves the world; birth and motion share the frame so
  tips never stutter.
