# 063-test-the-lodge.lua

Tests for `062-build-the-lodge.lua`. Builds small made-up lodges in a
scratch folder and checks each promise of the generator.

`luajit lodge/generator/063-test-the-lodge.lua [DIR] [SCRATCH]`

- `DIR` (string): the project folder; the generator is loaded from it.
- `SCRATCH` (string): a folder holding `pages/`, `out/` and
  `issues/completed/`, made beforehand by `lodge/build --test`
  (default `DIR/tmp/lodge-test`).

Prints one line per check and a total; exits 0 only when every check
passes.

## What it checks

- two rooms linking each other build, and links become pages and sections;
- issue mentions link, every number in a run;
- a section's "pointed at from" note sits at the end of that section and
  returns to the exact paragraph;
- each room links its own stylesheet; the rail marks the current room;
- a dead link, a missing section, an unknown line shape, and a room without
  a stylesheet each stop the build, and every problem is named;
- nothing inside a code span is linked or emphasised.
