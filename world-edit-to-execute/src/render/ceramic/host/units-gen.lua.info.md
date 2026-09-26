# units-gen.lua

Prints `units.map`:
- `advance` takes argument 0 (the tick) and fans out to port 1 of
  `move0..7`;
- each `moveL` takes argument 1+L (its request) and gives result L.
