# units-types.lua

Prints the `lane_units` value type, one named field per unit (`u0` …
`u255`, each a `unit`), since the ceramic engine's value types can't hold
arrays of numbers. `run-host.sh` splices it into `units-boxes.c`.
