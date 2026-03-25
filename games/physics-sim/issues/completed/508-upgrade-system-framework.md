# Issue 801 - Upgrade System Framework

## Status
Pending

## Current Behavior
No upgrade system exists. Players accumulate score but cannot spend it.

## Intended Behavior
- Press a key (U or Tab) to open upgrade menu
- Menu displays available upgrades with costs
- Player can select upgrades to purchase
- Purchases deduct from current score (not high score)
- High score remains as historical maximum
- Menu closes on purchase or cancel key

## Suggested Implementation Steps

1. **Create upgrade data structures**
   - Upgrade struct (name, description, cost, level, max_level)
   - UpgradeManager struct (array of upgrades, UI state)
   - upgrade_manager_create() and upgrade_manager_destroy()

2. **Implement upgrade menu rendering**
   - Semi-transparent overlay when menu is open
   - List upgrades with current level, cost, description
   - Highlight affordable vs unaffordable upgrades
   - Show current score prominently

3. **Add menu input handling**
   - Tab or U to toggle menu open/close
   - Up/Down or number keys to select upgrade
   - Enter to purchase selected upgrade
   - Escape to close without purchasing

4. **Implement purchase logic**
   - Check if player has sufficient score
   - Deduct cost from world->score
   - Increment upgrade level
   - Apply upgrade effect (handled by specific upgrade issues)

5. **Integrate with main loop**
   - Pause ball spawning while menu is open
   - Continue physics simulation (balls still fall)
   - Render menu over game

## Related Documents
- docs/007-upgrade-system-design.md (to be created)
- docs/008-future-ball-types.md (to be created)

## Notes
- Cost scaling: Each upgrade level should cost more than previous
- Formula suggestion: cost = base_cost * (level + 1)
- Max levels prevent infinite scaling
