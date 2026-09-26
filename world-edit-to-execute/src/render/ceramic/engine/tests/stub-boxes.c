/*
 * stub-boxes.c - one box, so serac has something to emit (issue 515g)
 *
 * The engine links against tables a build generates (the box places, the
 * map builds). The queue tests use none of them, but the engine needs them
 * to exist; run-engine-tests.sh emits them from stub.map and this box.
 */
int keep(int x) { return x; }
