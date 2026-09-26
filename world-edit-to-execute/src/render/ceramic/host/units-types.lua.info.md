# units-types.lua

Prints the `lane_units` value type, one named field per unit (`u0` …
`u255`, each a `unit`), since the ceramic engine's value types can't hold
arrays of numbers. The unit's size (36 bytes) is written beside the count,
for the comment it prints. `run-host.sh` splices it into `units-boxes.c`.
