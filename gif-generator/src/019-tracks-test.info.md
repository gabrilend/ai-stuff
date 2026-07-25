# 019-tracks-test — proof for tracks and the timeline

Runnable directly (`luajit src/019-tracks-test.lua [project-dir]`).
Proves: window edges exact to the instant (alive at start, gone at
start plus duration); the stroke easing's waypoint at half-window
matches hand arithmetic on the arc; the endpoint landmark sits where
the journey ends; fade-in whispers where hold speaks; two meeting
windows hand off 50 births in 50 ticks with neither gap nor double
(its first draft forgot particles die — the immortal-recipe comment
marks the lesson); zero-duration strokes are refused. Exits nonzero
on failure.
