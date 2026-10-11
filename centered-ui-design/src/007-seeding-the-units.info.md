<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 007-seeding-the-units

Scatters the first units and cuboids from the seed (data generation), and names the color-coded sections. Same seed, same world, on every build.

| Offers | Takes | Gives |
|---|---|---|
| `new_stream(seed)`, `next_fraction(stream)` | | a 32-bit xorshift random stream; fractions in [0, 1) |
| `seed_units(front, count, seed, fold)` | unit record array | one in five a foe far out, the rest owned by the seat whose quarter they start in; all idle |
| `seed_cuboids(front, count, seed, fold)` | cuboid record array | lying about, colors in turn (a stream of its own) |
| `SECTIONS`, `CUBOID_SIZE` | | the four sections {r, angle, radius} (tiers, radians); a cuboid's edge at tier 1 |
