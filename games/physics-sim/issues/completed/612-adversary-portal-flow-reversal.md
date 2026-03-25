# 612 - Adversary Portal Flow Reversal

## Status: Completed

## Depends on

None - portal system already implemented (611, 812).

## Problem

Currently adversary balls use the same portal flow direction as player balls (enter through entry portals, exit through exit portals). This doesn't match the "reversed" nature of adversary gameplay where gravity is inverted.

## Current Behavior

- Player balls enter through entry portals and exit from exit portals
- Adversary balls use the same flow direction
- Both ball types interact with portals identically

## Intended Behavior

1. Player balls: Enter entry portals, exit from exit portals (unchanged)
2. Adversary balls: Enter exit portals, exit from entry portals (reversed)
3. Portal channels should work bidirectionally based on ball ownership
4. Same channel connects the same physical locations, just reversed flow

## Suggested Implementation Steps

1. Add ball ownership check in `portal_manager_check_ball`:
   - Determine if ball belongs to player or adversary
   - For player balls: check entry portals, teleport to exits
   - For adversary balls: check exit portals, teleport to entries

2. Update portal zone collision detection:
   - For adversary balls, swap which zones trigger teleportation
   - Entry zones become destinations, exit zones become sources

3. Ensure channel matching still works:
   - Same channel number links portals
   - Just swap source/destination based on ball type

## Files to Modify

- `src/029-portal.c` - Add ball ownership check and reversed flow logic
- `src/029-portal.h` - May need to update function signatures

## Notes

- Ball ownership can be determined by checking ball index ranges or a flag
- This creates interesting gameplay where player and adversary balls flow in opposite directions through the same portal network
- Consider edge case: what if a channel has only entries or only exits? Adversary balls would need the opposite set to function

## Implementation Complete

### Changes Made

Modified `src/029-portal.c`:
- Updated `portal_manager_check_ball()` to check ball ownership via `ball->owner`
- For player balls (owner=0): check ENTRY portals, teleport to EXIT portals (unchanged behavior)
- For adversary balls (owner=1): check EXIT portals, teleport to ENTRY portals (reversed flow)
- Added descriptive logging to indicate which ball type is teleporting and destination type
- Added warning message when source portal has no matching destinations

### Result

Player and adversary balls now flow in opposite directions through the same portal network:
- Player balls fall through entry (blue) → exit (orange)
- Adversary balls float through exit (orange) → entry (blue)

This matches the reversed gravity gameplay where adversary balls float upward.

### Edge Case Handling

If a channel has only entry or only exit portals, a warning is logged. The ball remains in place (no teleport) rather than causing undefined behavior.
