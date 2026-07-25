# 031-stats-test — proof for the measurer

Runnable directly (`luajit src/031-stats-test.lua [project-dir]`).
Proves: the wall clock moves forward and reads finer than whole
seconds; a measured render is a real gif whose byte count matches
the file's truth and whose facts carry the stage clocks; the
summary counts at least the two reference renders. Exits nonzero on
failure.
