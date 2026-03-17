# Issue 802 - Spawn Rate Upgrade

## Status
Pending

## Current Behavior
Spawn rate is fixed at SPAWN_RATE (5 balls/sec). Player cannot modify it.

## Intended Behavior
- "Spawn Rate" upgrade available in upgrade menu
- Each level increases spawn rate by fixed amount
- Visual feedback shows current spawn rate
- Upgrade has maximum level cap

## Suggested Implementation Steps

1. **Define upgrade parameters**
   - Base cost: 100 points
   - Rate increase per level: +1 ball/sec
   - Maximum level: 5 (total 10 balls/sec)
   - Cost scaling: 100, 200, 300, 400, 500

2. **Add spawn rate modifier to World or BallManager**
   - spawn_rate_bonus field
   - Effective rate = SPAWN_RATE + spawn_rate_bonus

3. **Register upgrade in UpgradeManager**
   - ID: UPGRADE_SPAWN_RATE
   - Name: "Spawn Rate"
   - Description: "+1 ball/sec"
   - Apply function: increases spawn_rate_bonus

4. **Update spawn credit accumulation**
   - Modify credit accumulation to use effective rate
   - spawn_credits += effective_rate * dt

5. **Update UI display**
   - Show current spawn rate in controls panel
   - Format: "Spawn: X/sec"

## Dependencies
- Issue 801 (Upgrade System Framework) must be complete

## Related Documents
- src/007-ball.c (spawn credit system)
- main.c (spawn handling)

## Notes
- Consider whether auto-spawn should also benefit from rate increase
- Visual indicator could pulse faster at higher spawn rates
