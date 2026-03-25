# 833 - RGB Property 10% Increments

## Status: Complete

## Problem

Setting precise property values on pegs and lines is difficult with the current slider system. Users struggle to match values between objects. Additionally, blue channel (point bonus) should map to meaningful point values like gates use.

## Current Behavior

- RGB sliders use continuous 0-255 values
- Difficult to get matching values between objects
- No visual indication of what values mean
- Point bonus doesn't align with gate point values

## Intended Behavior

1. All RGB property sliders use 10% increments (0%, 10%, 20%, ... 100%)
2. Blue channel (point bonus) maps to specific point values:
   - 0%: 0 points
   - 10%: 10 points
   - 20%: 20 points
   - 30%: 50 points
   - 40%: 100 points
   - 50%: 500 points
   - (higher values could scale further or cap at 500)
3. Red channel (restitution) uses 10% increments for bounciness
4. Green channel (friction) uses 10% increments for grip
5. Display current percentage and mapped value in property panel

## Implementation Steps

1. Update property panel sliders to snap to 10% increments
2. Create point value mapping table for blue channel
3. Update property display to show percentage and actual value
4. Update physics code to use mapped values from table
5. Test that matching values are easy to achieve

## Files Modified

- `src/032-editor-app.c` - Property panel slider behavior, snap to 10% increments

## Implementation

1. Added `INCREMENT_VALUES[11]` array mapping steps 0-10 to 0-255 values
2. Added `POINT_VALUES[11]` array mapping steps to point values (0,10,20,50,100,500,...)
3. Added `snap_to_increment()` helper to snap any value to nearest 10% step
4. Added `value_to_step()` helper to convert 0-255 value to step index
5. Updated slider input to snap values to 10% increments
6. Updated slider display to show percentage (e.g., "70%")
7. Blue channel shows mapped point value (e.g., "40% (100pts)")

## Notes

- Physics code integration (scoring on peg hits) not implemented yet
- Point bonus values are stored but not currently used for scoring
- Future work: wire up point_bonus to actual scoring system
