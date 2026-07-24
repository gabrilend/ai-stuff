# 015-paths-test — proof for the clock-face paths

Runnable directly (`luajit src/015-paths-test.lua [project-dir]`).
Proves the convention by hand arithmetic: 12 up, 3 east, 6 down;
spoken and fractional hours; the vision's own two hands (clockwise
12-to-7 passing 3 at three-sevenths, counterclockwise 12-to-5
passing 9); tangents perpendicular to radii and signed by the turn;
line midpoints and unit headings; points ignoring progress; and the
walls refusing turnless arcs, zero-length lines, and unreadable
hours. Exits nonzero on failure.
