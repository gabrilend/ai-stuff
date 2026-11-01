# 062-three-readings — say it once, pick from three

The front door for `061-readings.lua`, run by `./porch --three` and
`./porch --pick`. It plans the readings from the doors in
`input/cluster`, asks them all at once, each reading in its own
process (`--one`), so a slow or silent door holds up no one, then
prints what each heard and writes the pick page.

## Usable surface

CLI only:

- `luajit src/062-three-readings.lua DIR "a sentence" [--count=N]` — N
  readings (1 to 4, her limit on processes; 3 by default) into
  `output/readings/SLUG/` (`SLUG-2` and on when that sentence was said
  before), then `index.html` there.
- `luajit src/062-three-readings.lua DIR --pick SLUG K [--name=NAME]` —
  reading K's score becomes `input/NAME.lua` (NAME defaults to SLUG).
- `luajit src/062-three-readings.lua DIR --one FOLDER K DOOR SEED` — one
  reading, as the fan-out runs it.
