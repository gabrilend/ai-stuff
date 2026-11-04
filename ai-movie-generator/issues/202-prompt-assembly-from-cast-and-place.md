# 202 — prompt assembly from cast and place

phase 2, shots into motion

**Depends on:** 201, 104

## Current behavior

Shots cannot become picture requests.

## Intended behavior

A shot becomes a picture request: `sees` + cast looks + place look + film style words; seed from the first cast member, else film seed + shot index; width doubled for pans; two requests for dissolves.

## Suggested implementation steps

1. The assembly function.
2. Test: a shot with two cast members and a place gives the expected prompt and seed.

## Related documents

- docs/datapath-shot-to-clip.md
