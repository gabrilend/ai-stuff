# Issue 810: Granular Upgrade Levels with Hold-to-Purchase

## Current Behavior

- Spawn rate upgrade: 5 levels max, +1 ball/sec per level
- Ball size upgrade: 3 levels max, -1 radius per level
- Purchase requires individual key presses (one purchase per press)
- High base costs (100, 150 points)

## Intended Behavior

- Spawn rate upgrade: 500 levels max, +0.01 ball/sec per level (same +5 total)
- Ball size upgrade: 300 levels max, -0.01 radius per level (same -3 total)
- Hold ENTER to continuously purchase upgrades
- Lower base costs for incremental purchases (1-2 points)
- Same total effect at max level as before

## Suggested Implementation Steps

1. Update effect constants to 1/100th of current values
2. Update max_level for each upgrade (5→500, 3→300)
3. Update base_cost to lower values (100→1, 150→2)
4. Add purchase timer state to UpgradeManager struct
5. Implement hold-to-purchase with initial delay and repeat rate
6. Update display to show progress bar instead of level numbers

## Notes

This change makes the upgrade system feel more incremental/clicker-style,
allowing gradual progression rather than large discrete jumps.

## Status

Complete

## Implementation Notes

- Spawn rate: 500 levels at +0.01/level = +5 ball/sec total (base cost 1)
- Ball size: 300 levels at -0.01/level = -3 radius total (base cost 2)
- Hold ENTER triggers repeat purchase after 0.3s initial delay
- Repeat rate: 30 purchases/second when holding
- Progress bar UI replaces level numbers for cleaner display
- Percentage shown next to progress bar
