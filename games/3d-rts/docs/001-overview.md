# 001 — Overview

This project is a small, deliberately minimal 3D real-time strategy game written
in C, rendered with raylib, and threaded with POSIX pthreads. The aesthetic is
honest geometry: rectangular boxes for units, cylinders for projectiles, and a
heightmap surface for terrain. There is no art, no narrative, no resource
economy — only the bones of an RTS, exposed for study.

The vision document at `notes/vision` is the single source of truth for the
game's intent. This document is a friendlier restatement that newcomers can
read first.

## What you do in the game

You command rectangular box units on a hilly terrain. They throw cylindrical
javelins at each other when they have line of sight. Each box that misses gets
worse at hitting that target — variance grows with consecutive misses against
the same opponent. A factory you can place produces more boxes on a 10-second
cadence. You direct units and factory output with click, box-select, and
shift-chained waypoints.

That is the whole game in Phase 1. Nothing else.

## Three guiding decisions

1. **Geometric honesty.** No textures, no models. Rectangles, cylinders,
   heightmap. This forces the design to live in mechanics, not presentation.
2. **Causal physics.** Once a javelin is thrown, nothing alters its course.
   Aim is committed at release; the world does the rest. This means every
   miss is the shooter's mistake, never the projectile's.
3. **Order composition.** Every command — both for units and for factories —
   is either a single point or a shift-built chain of points. The same
   primitive describes "go here," "patrol-style march," and "factory rally
   sequence." Future phases extend this primitive rather than replacing it.

## Phases

Phase 1, **basic movement options**, is the entire current scope. Phase 2 is
**resources**. Phase 3 is **advanced movement options** (patrol, attack-move,
and friends). The roadmap document, `005-roadmap.md`, decomposes each phase
into individual issues.

## Where to read next

- Game rules in detail: `002-mechanics.md`
- Engine and language choices: `003-tech-stack.md`
- Module layout and threading: `004-architecture.md`
- Phase plan and issue list: `005-roadmap.md`
