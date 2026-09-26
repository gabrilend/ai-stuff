# run-engine-tests.sh

Builds every `tests/test-*.c` against the kept engine copy and runs it,
stopping at the first failure. The engine's generated tables come from
serac, run on `stub.map` and `stub-boxes.c` (one box), with the emitted
`main` cut off. Usage: `run-engine-tests.sh [DIR]`.
