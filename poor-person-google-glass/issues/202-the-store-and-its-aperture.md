# 202 — The store and its aperture

**Phase:** 2 — The stored light
**Blocked by:** 201
**Blocks:** 203
**Related documents:** docs/physics-check.md (Q-switching)

## Current Behavior
The store is described, not modelled.

## Intended Behavior
The store's holding time from its size and its mirrors' loss per bounce; the
aperture's rotation sets the release rate; each release's energy comes from
what the store held when it opened. Output: releases over time.

## Suggested Implementation Steps
1. Holding time from size and loss.
2. Rotating aperture and release energy.
3. Tests: worse mirrors give shorter holding and weaker releases.
