# 003-palette-test — proof for the palette

Runnable directly (`luajit src/003-palette-test.lua [project-dir]`).
Asserts the seating chart: black alone at zero, ramps brighten
monotonically, orange seats among embers and purple among violets,
grays keep to the gray ramp at any brightness, brighter light never
seats lower, and the walls refuse unknown hues, forty hues, and no
hues at all. Exits nonzero on any failure.
