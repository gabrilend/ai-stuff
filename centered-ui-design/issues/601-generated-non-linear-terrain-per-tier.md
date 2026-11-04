# 601 — Generated non-linear terrain in each tier band

**Phase:** 6 — Foes in every direction
**Blocked by:** 103, 102

**Blocks**: 602, 606, 607, 609
**Related documents:** docs/game-design.md (Center to outer),
docs/datapath-world-tick.md (tier band)

## Current Behavior

Every tier band is open ground.

## Intended Behavior

- Each tier band's terrain grid (cells on the sphere: rings of angle slices
  in a band of latitude, each band crossed in equal time) is
  generated from the terrain random stream: open ground, walls, narrows
  (gaps in walls), high ground (range bonus), rough ground (slow).
- No lanes: generation guarantees several routes outward in every
  direction and at least one route sideways around each band.
- Movement and combat read the terrain (blocked cells, speed and range
  modifiers). Stands path around walls.
- The map layer draws terrain in muted tones through the accordion.

## Suggested Implementation Steps

1. `src/NNN-terrain-generator.lua` (data generation only).
2. Polar-grid pathfinding (A* over cells, costs from tier-time).
3. A connectivity check run on every generated band (test + runtime error).
4. `src/NNN-terrain-layer.lua` (viewing only).
